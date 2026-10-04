# frozen_string_literal: true

require_relative "test_helper"
require "fastimage"
require "json"
require "nokogiri"
require "open3"
require "rbconfig"
require "tmpdir"

# Builds a small site whose Markdown shows a PNG, and follows the image from
# the variants the optimizer encodes to the <picture> its pages offer. Every
# variant used to fail before it was encoded, on a call to a
# Jekyll::Utils.which that does not exist, so no site ever got a resized,
# AVIF or WebP copy, and Markdown images were never offered one (#243).
#
# Most tests stand a Ruby script in for ImageMagick and avifenc. The last one
# runs the real encoders when they are installed; the Tests workflow installs
# them and sets DATALOG_IMAGE_TOOLS=required, so there it cannot skip.
class ImageVariantsTest < Minitest::Test
  PLOT = File.join(SiteBuilder.root, "assets/img/social-card.png")
  PLOT_WIDTH = 1200
  WIDTHS = [320, 640, 960, 1200].freeze

  def setup
    @scripts = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@scripts)
  end

  # --- Markup and files -------------------------------------------------------

  def test_markdown_images_are_offered_the_variants_encoded_for_them
    build(encoders: fake_encoders)

    %w[index.html bare.html].each do |page|
      html = read(page)
      picture = Nokogiri::HTML5(html).at_css("picture")
      refute_nil picture, "#{page} should wrap its Markdown image in a <picture>"

      sources = picture.css("source").to_h { |source| [source["type"], srcset_urls(source)] }
      assert_equal %w[image/avif image/webp], sources.keys
      sources.each do |type, urls|
        extension = type.delete_prefix("image/")
        assert_equal(WIDTHS.map { |width| "/blog/assets/img/responsive/plot.png-#{width}w.#{extension}" }, urls)
      end

      img = picture.at_css("img")
      assert_equal "A plot", img["alt"]
      assert_equal %w[1200 630], [img["width"], img["height"]]
      assert_equal WIDTHS.first(3).map { |width| "/blog/assets/img/responsive/plot.png-#{width}w.png" } +
                   ["/blog/assets/img/plot.png"], srcset_urls(img)
      refute_includes html, "</source>", "#{page} should write <source> as a void element"

      (sources.values.flatten + srcset_urls(img)).each do |url|
        assert @site.exist?(url.delete_prefix("/blog")), "#{url} should be written"
      end
    end
  end

  # A plot exported for a white page is unreadable on a dark one, so an author
  # puts plot-dark.png beside plot.png and the build pairs them (#335).
  def test_a_dark_companion_beside_the_image_is_offered_behind_the_scheme_query
    build(encoders: fake_encoders, dark: true)

    picture = Nokogiri::HTML5(read("index.html")).at_css("picture")
    sources = picture.css("source")
    dark = sources.select { |source| source["media"] }
    types = dark.map { |source| source["type"] }
    queries = dark.map { |source| source["media"] }

    assert_equal sources.first, dark.first, "a dark source after a light one of the same type is never reached"
    assert_equal ["(prefers-color-scheme: dark)"] * 3, queries
    assert_equal %w[image/avif image/webp image/png], types
    dark.flat_map { |source| srcset_urls(source) }.each do |url|
      assert_includes url, "plot-dark.png"
      assert @site.exist?(url.delete_prefix("/blog")), "#{url} should be written"
    end
  end

  # The figure is the same figure: one <img>, one alt text, one pair of
  # dimensions, and the light file for a browser that ignores the query.
  def test_the_dark_companion_does_not_change_the_image_it_belongs_to
    build(encoders: fake_encoders, dark: true)

    img = Nokogiri::HTML5(read("index.html")).at_css("picture img")

    assert_equal "/blog/assets/img/plot.png", img["src"]
    assert_equal "A plot", img["alt"]
    assert_equal %w[1200 630], [img["width"], img["height"]]
    assert(srcset_urls(img).none? { |url| url.include?("-dark") })
  end

  def test_the_companion_is_not_paired_with_one_of_its_own
    build(encoders: fake_encoders, dark: true)
    manifest = JSON.parse(read("assets/img/responsive/manifest.json"))

    assert_equal "/assets/img/plot-dark.png", manifest["/assets/img/plot.png"]["dark"]["source"]
    refute manifest["/assets/img/plot-dark.png"].key?("dark"), "plot-dark.png is the twin; it has none of its own"
  end

  def test_a_second_build_takes_the_variants_from_the_cache
    first = build(encoders: fake_encoders)
    replacing(:encode_into_cache, ->(*) { flunk "a cached variant was encoded again" }) do
      build(encoders: fake_encoders, again: first)
    end

    assert Nokogiri::HTML5(read("index.html")).at_css("picture source"), "The rebuilt page should keep its sources"
  end

  def test_image_paths_with_spaces_are_encoded_once_in_the_manifest_and_markup
    site = build(encoders: fake_encoders, filename: "my plot.png",
                 image_url: "/blog/assets/img/my%20plot.png").jekyll
    picture = Nokogiri::HTML5(read("index.html")).at_css("picture")
    urls = picture.css("source, img").flat_map { |node| srcset_urls(node) }

    assert_includes urls, "/blog/assets/img/responsive/my%20plot.png-320w.webp"
    assert_includes urls, "/blog/assets/img/my%20plot.png"
    urls.each do |url|
      refute_match(/\s|%2520/, url)
      path = URI::DEFAULT_PARSER.unescape(url.delete_prefix("/blog"))
      assert @site.exist?(path), "#{url} must point to a written image"
    end
    manifest = JSON.parse(read("assets/img/responsive/manifest.json"))
    entry = manifest.fetch("/assets/img/my plot.png")
    assert_equal "/assets/img/my%20plot.png", entry.dig("fallback", "variants").last["url"]

    source = File.read(File.join(SiteBuilder.root, "_includes/components/responsive-image.html"))
    template = Liquid::Template.parse(source)
    rendered = template.render!({ "site" => site.site_payload["site"],
                                  "include" => { "src" => "/assets/img/my plot.png", "alt" => "A plot" } },
                                registers: { site: site })
    included = Nokogiri::HTML5.fragment(rendered)
    included_urls = included.css("source, img").flat_map { |node| srcset_urls(node) }
    assert_equal urls, included_urls
  end

  # An image offered a variant that was never written would break: a browser
  # does not fall back from a <source> whose file is missing.
  def test_an_encoder_that_fails_leaves_the_image_as_it_was
    build(encoders: fake_encoders(command: script("warn 'no encode delegate'; exit 1")))

    img = Nokogiri::HTML5(read("index.html")).at_css("img")
    refute_equal "picture", img.parent.name
    assert_nil img["srcset"]
    refute @site.exist?("assets/img/responsive/plot.png-320w.webp")
    assert_empty Dir.glob(File.join(@site.dir, ".jekyll-cache", "**", "*.*")),
                 "A failed encode should leave nothing cached"
  end

  def test_without_imagemagick_the_image_keeps_its_original_only
    build(encoders: { "imagemagick" => nil, "writable" => [], "avifenc" => nil })

    img = Nokogiri::HTML5(read("index.html")).at_css("img")
    refute_equal "picture", img.parent.name
    assert_nil img["srcset"]
    assert_equal %w[1200 630], [img["width"], img["height"]]
    refute @site.exist?("assets/img/responsive/plot.png-320w.png")
  end

  def test_variants_false_turns_the_encoders_off
    replacing(:tools, -> { flunk "the encoders were looked up" }) do
      build(config: { "theme_options" => { "images" => { "variants" => false } } })
    end

    assert_nil Nokogiri::HTML5(read("index.html")).at_css("picture")
  end

  def test_imagemagick_writes_only_the_formats_it_lists
    build(encoders: fake_encoders(writable: %w[PNG JPEG], avifenc: false))

    assert_nil Nokogiri::HTML5(read("index.html")).at_css("picture"), "No WebP writer and no avifenc: no sources"
    assert_equal 4, srcset_urls(Nokogiri::HTML5(read("index.html")).at_css("img")).size
  end

  # --- Finding the encoders ---------------------------------------------------

  def test_writable_formats_are_read_from_the_format_list
    imagemagick7 = <<~TEXT
         Format  Mode  Description
      -------------------------------------------------------------------------------
           AVIF  rw+   AV1 Image File Format (1.23.2)
           HEIC  r--   High Efficiency Image Format (1.23.2)
          JPEG* rw-   Joint Photographic Experts Group JFIF format (libjpeg-turbo 3.2.0)
           PNG* rw-   Portable Network Graphics (libpng 1.6.58)
          WEBP* rw+   WebP Image Format (libwebp 1.6.0 [0210])
    TEXT

    # ImageMagick 6, as Ubuntu installs it, prints the module each format comes from.
    imagemagick6 = <<~TEXT
         Format  Module    Mode  Description
      -------------------------------------------------------------------------------
            HEIC  HEIC      r--   High Efficiency Image Format
           JPEG* JPEG      rw-   Joint Photographic Experts Group JFIF format (libjpeg-turbo 2.1.5)
            PNG* PNG       rw-   Portable Network Graphics (libpng 1.6.43)
           WEBP* WEBP      rw+   WebP Image Format (libwebp 1.3.2 [020E])
    TEXT

    assert_equal %w[AVIF JPEG PNG WEBP], Jekyll::ImageOptimizer.parse_writable_formats(imagemagick7)
    assert_equal %w[JPEG PNG WEBP], Jekyll::ImageOptimizer.parse_writable_formats(imagemagick6)
  end

  def test_convert_is_not_taken_for_imagemagick_on_windows
    found = { "convert" => "C:/Windows/System32/convert.exe" }
    replacing(:which, ->(command) { found[command] }) do
      assert_nil Jekyll::ImageOptimizer.detect_tools(windows: true)["imagemagick"]

      replacing(:writable_formats, ->(_) { %w[PNG WEBP] }) do
        found.replace("convert" => "/usr/bin/convert")
        assert_equal ["/usr/bin/convert"], Jekyll::ImageOptimizer.detect_tools(windows: false)["imagemagick"]

        found.replace("convert" => "/usr/bin/convert", "magick" => "/usr/local/bin/magick",
                      "avifenc" => "/usr/bin/avifenc")
        tools = Jekyll::ImageOptimizer.detect_tools(windows: false)
        assert_equal ["/usr/local/bin/magick"], tools["imagemagick"]
        assert_equal ["/usr/bin/avifenc"], tools["avifenc"]
      end
    end
  end

  # --- The real encoders -------------------------------------------------------

  def test_imagemagick_and_avifenc_encode_images_of_the_advertised_size
    tools = Jekyll::ImageOptimizer.detect_tools
    missing = []
    missing << "ImageMagick" unless tools["imagemagick"]
    missing << "ImageMagick's WebP writer" unless tools["writable"].include?("WEBP")
    missing << "avifenc" unless tools["avifenc"]
    unless missing.empty?
      if ENV["DATALOG_IMAGE_TOOLS"] == "required"
        flunk "#{missing.join(', ')} not found. Detected: #{tools.inspect}\n#{format_listing(tools)}"
      end
      skip "#{missing.join(', ')} not installed"
    end

    build(encoders: tools)

    picture = Nokogiri::HTML5(read("index.html")).at_css("picture")
    variants = picture.css("source").map { |source| [source["type"], srcset_urls(source)] }
    variants << ["image/png", srcset_urls(picture.at_css("img")).first(3)]
    variants.each do |type, urls|
      urls.each do |url|
        path = @site.path(url.delete_prefix("/blog"))
        width = url[/-(\d+)w\./, 1].to_i
        assert_equal type.delete_prefix("image/").to_sym, FastImage.type(path), "#{url} should be #{type}"
        assert_equal [width, (630.0 * width / PLOT_WIDTH).round], FastImage.size(path),
                     "#{url} should be #{width}px wide"
      end
    end
  end

  private

  # A site at /blog whose Markdown shows /assets/img/plot.png, once in a layout
  # and once without one. `again:` rebuilds an earlier site's source, for the
  # tests about what a second build does.
  def build(encoders: nil, config: {}, filename: "plot.png", image_url: "/blog/assets/img/plot.png",
            dark: false, again: nil)
    layout = "<!DOCTYPE html><html><body><main class=\"post-content\">{{ content }}</main></body></html>"
    make = lambda do
      @site = TestSite.build({ baseurl: "/blog", title: "Variants", dir: again&.dir }.merge(config)) do |source|
        source.copy("assets/img/social-card.png", "assets/img/#{filename}")
        source.copy("assets/img/social-card.png", "assets/img/#{filename.sub(/(\.\w+)\z/, '-dark\1')}") if dark
        source.layout("default.html", layout)
        source.page("index.md", "![A plot](#{image_url})", "layout: default\n")
        source.page("bare.md", "![A plot](#{image_url})")
      end
    end
    encoders ? replacing(:tools, -> { encoders }) { make.call } : make.call
    @site
  end

  # Writes the last argument, as ImageMagick and avifenc write their output.
  def fake_encoders(command: script("File.binwrite(ARGV.last, ARGV.join(' '))"), writable: %w[PNG JPEG WEBP],
                    avifenc: true)
    { "imagemagick" => command, "writable" => writable, "avifenc" => avifenc ? command : nil }
  end

  # A script file, not `ruby -e`: Ruby would read an argument such as
  # -auto-orient as one of its own options.
  def script(code)
    path = File.join(@scripts, "encoder-#{code.hash.abs}.rb")
    File.write(path, code)
    [RbConfig.ruby, path]
  end

  # Minitest 6 has no stubs: swaps one of the optimizer's methods for the block.
  def replacing(name, replacement)
    original = Jekyll::ImageOptimizer.method(name)
    Jekyll::ImageOptimizer.define_singleton_method(name, &replacement)
    yield
  ensure
    Jekyll::ImageOptimizer.define_singleton_method(name, original)
  end

  # The start of ImageMagick's format list, for a failure message.
  def format_listing(tools)
    return "" unless tools["imagemagick"]

    Open3.capture2e(*tools["imagemagick"], "-list", "format").first.lines.first(12).join
  end

  def read(page)
    @site.read(page)
  end

  def srcset_urls(node)
    node["srcset"].to_s.split(",").map { |candidate| candidate.split.first }
  end
end
