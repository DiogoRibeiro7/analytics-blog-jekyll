# frozen_string_literal: true

require_relative "test_helper"
require "nokogiri"
require "tmpdir"

# A plot exported for a white page is unreadable on a dark one, and the theme
# has a dark mode. An author exports a second file beside the first —
# power.png and power-dark.png — and the markup offers both (#335).
class DarkImageVariantsTest < Minitest::Test
  PLOT = "/assets/img/plot.png"
  PLOT_DARK = "/assets/img/plot-dark.png"
  DARK_MEDIA = "(prefers-color-scheme: dark)"

  # `source` is where the optimizer looks for an image it has no entry for,
  # to read its size; an empty directory keeps that out of these tests.
  Site = Struct.new(:data, :config, :baseurl, :source)
  Document = Struct.new(:output, :site) do
    def output_ext
      ".html"
    end
  end

  def entry_for(name, width: 1200, height: 600)
    variant = lambda do |format, w|
      { "url" => "/assets/img/responsive/#{name}-#{w}w.#{format}", "width" => w }
    end
    {
      "width" => width, "height" => height,
      "sources" => %w[avif webp].map do |format|
        { "type" => "image/#{format}", "format" => format,
          "variants" => [variant.call(format, 640), variant.call(format, 1200)] }
      end,
      "fallback" => { "type" => "image/png", "format" => "png",
                      "variants" => [variant.call("png", 640),
                                     { "url" => "/assets/img/#{name}.png", "width" => 1200 }] }
    }
  end

  # The linking pass is what pairs the two entries; it runs once per build over
  # the finished manifest.
  def linked_manifest
    manifest = { PLOT => entry_for("plot"), PLOT_DARK => entry_for("plot-dark") }
    Jekyll::ImageOptimizer.send(:link_dark_variants, manifest, {})
    manifest
  end

  def test_an_image_with_a_dark_twin_is_paired_with_it
    entry = linked_manifest[PLOT]

    refute_nil entry["dark"], "plot.png should be paired with plot-dark.png"
    assert_equal PLOT_DARK, entry["dark"]["source"]
  end

  def test_the_twin_is_not_paired_with_itself
    assert_nil linked_manifest[PLOT_DARK]["dark"],
               "plot-dark.png is the twin; it has none of its own"
  end

  def test_an_image_with_no_twin_is_left_alone
    manifest = { PLOT => entry_for("plot") }
    Jekyll::ImageOptimizer.send(:link_dark_variants, manifest, {})

    assert_nil manifest[PLOT]["dark"]
  end

  def test_the_suffix_can_be_configured
    manifest = { PLOT => entry_for("plot"), "/assets/img/plot.night.png" => entry_for("plot.night") }
    Jekyll::ImageOptimizer.send(:link_dark_variants, manifest, { "dark_suffix" => ".night" })

    assert_equal "/assets/img/plot.night.png", manifest[PLOT]["dark"]["source"]
  end

  def test_the_suffix_comes_from_the_site_configuration
    site = Struct.new(:config).new({ "theme_options" => { "images" => { "dark_suffix" => ".night" } } })

    assert_equal ".night", Jekyll::ImageOptimizer.image_config(site)["dark_suffix"]
  end

  # For a site whose file names end in "-dark" for some other reason.
  def test_an_empty_suffix_turns_the_convention_off
    manifest = { PLOT => entry_for("plot"), PLOT_DARK => entry_for("plot-dark") }
    Jekyll::ImageOptimizer.send(:link_dark_variants, manifest, { "dark_suffix" => "" })

    assert_nil manifest[PLOT]["dark"]
  end

  def test_the_dark_sources_come_first_and_carry_the_media_query
    sources = rendered_sources

    # A <picture> takes the first source whose media and type both match, so a
    # dark source placed after a light one of the same type is never reached.
    dark = sources.take_while { |source| source["media"] == DARK_MEDIA }
    types = dark.map { |source| source["type"] }
    assert_equal 3, dark.size, "avif, webp and png, all of the dark twin"
    assert_equal %w[image/avif image/webp image/png], types
    assert(dark.all? { |source| source["srcset"].include?("plot-dark") })
  end

  # Without the twin's own format among the dark sources, a browser with
  # neither AVIF nor WebP falls through to the light <img>.
  def test_the_twins_own_format_is_offered_too
    png = rendered_sources.find { |source| source["media"] == DARK_MEDIA && source["type"] == "image/png" }

    refute_nil png
    assert_equal "/assets/img/responsive/plot-dark-640w.png 640w, /assets/img/plot-dark.png 1200w", png["srcset"]
  end

  def test_the_light_sources_still_follow_with_no_media_query
    light = rendered_sources.reject { |source| source["media"] }
    types = light.map { |source| source["type"] }

    assert_equal %w[image/avif image/webp], types
    assert(light.all? { |source| source["srcset"].include?("/plot-") && !source["srcset"].include?("plot-dark") })
  end

  def test_the_img_still_falls_back_to_the_light_image
    img = rendered_picture.at_css("img")

    assert_equal PLOT, img["src"]
    assert_equal img, rendered_picture.element_children.last, "the <img> should follow every source"
    assert_equal "1200", img["width"]
  end

  # `core/dark-mode.js` overrules the media query when a reader has used the
  # theme toggle, and needs to know which sources to overrule.
  def test_every_dark_source_is_marked_for_the_toggle
    marked = rendered_sources.select { |source| source["data-dark-source"] }

    assert_equal 3, marked.size
    assert(marked.all? { |source| source["media"] == DARK_MEDIA })
  end

  def test_an_image_without_a_twin_gets_no_dark_sources
    picture = render(manifest: { PLOT => entry_for("plot") }).at_css("picture")

    assert(picture.css("source").none? { |source| source["media"] })
  end

  def test_the_variant_urls_take_the_baseurl
    manifest = linked_manifest
    doc = render(manifest: manifest, html: image(src: "/blog#{PLOT}"), baseurl: "/blog")
    dark = doc.css("source").select { |source| source["media"] }

    assert_equal 3, dark.size
    dark.flat_map { |source| source["srcset"].split(", ").map { |candidate| candidate.split.first } }
        .each { |url| assert url.start_with?("/blog/assets/img/"), "#{url} should start with the baseurl" }
  end

  # An author who does not want the convention names the companion outright.
  def test_a_named_companion_is_served_with_its_own_variants
    manifest = { PLOT => entry_for("plot"), "/assets/img/night.png" => entry_for("night") }
    doc = render(manifest: manifest, html: image(dark: "/assets/img/night.png"))
    dark = doc.css("source").select { |source| source["media"] == DARK_MEDIA }
    types = dark.map { |source| source["type"] }

    assert_equal %w[image/avif image/webp image/png], types
    assert(dark.all? { |source| source["srcset"].include?("/night") })
  end

  def test_a_named_companion_wins_over_the_twin_found_beside_the_image
    manifest = linked_manifest.merge("/assets/img/night.png" => entry_for("night"))
    doc = render(manifest: manifest, html: image(dark: "/assets/img/night.png"))
    dark = doc.css("source").select { |source| source["media"] == DARK_MEDIA }

    assert(dark.all? { |source| source["srcset"].include?("/night") },
           "the companion the author named should be the one served")
  end

  def test_the_naming_attribute_does_not_reach_the_reader
    doc = render(manifest: { PLOT => entry_for("plot") }, html: image(dark: PLOT_DARK))

    assert_nil doc.at_css("img")["data-dark-src"], "data-dark-src is an instruction to the build, not markup"
  end

  # An SVG, or an image on another host, never reaches the variant pipeline.
  # It is still a figure with a dark companion.
  def test_a_companion_the_pipeline_never_saw_is_offered_as_it_stands
    html = image(src: "/assets/img/diagram.svg", dark: "/assets/img/diagram-dark.svg")
    picture = render(manifest: {}, html: html).at_css("picture")

    refute_nil picture, "an image with a companion is wrapped even with nothing else generated"
    source = picture.at_css("source")
    assert_equal DARK_MEDIA, source["media"]
    assert_equal "/assets/img/diagram-dark.svg", source["srcset"]
    assert_nil source["type"], "the pipeline knows nothing about a file it never read"
    assert_equal "/assets/img/diagram.svg", picture.at_css("img")["src"]
  end

  def test_an_image_the_author_opted_out_of_keeps_its_light_figure
    html = %(<img src="#{PLOT}" alt="A plot" data-no-optimize="true" data-dark-src="#{PLOT_DARK}">)
    doc = render(manifest: linked_manifest, html: html)

    assert_empty doc.css("picture")
  end

  # A page's hero goes through components/responsive-image.html, which builds
  # its own <picture> and so is left alone by the optimizer. It has to offer
  # the companion itself, or the convention would be true of every image on a
  # site but the one at the top of the page.
  def test_the_responsive_image_include_offers_the_companion_too
    picture = hero_markup.at_css("picture")
    dark = picture.at_css("source[media]")

    refute_nil dark, "the include should offer the dark companion"
    assert_equal DARK_MEDIA, dark["media"]
    assert_equal "/assets/img/plot-dark.png 1200w", dark["srcset"]
    assert_equal "image/png", dark["type"]
    refute_nil dark["data-dark-source"], "the toggle has to be able to find it"
    assert_equal dark, picture.element_children.first
    assert_equal "/assets/img/plot.png", picture.at_css("img")["src"]
  end

  private

  # A site with plot.png and plot-dark.png, showing the first through the
  # include. Without ImageMagick nothing is resized or converted, which leaves
  # each image with one variant: its own file.
  def hero_markup
    self.class.hero_markup ||= Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "_includes/components"))
      FileUtils.mkdir_p(File.join(dir, "assets/img"))
      FileUtils.cp(File.join(SiteBuilder.root, "_includes/components/responsive-image.html"),
                   File.join(dir, "_includes/components"))
      %w[plot.png plot-dark.png].each do |name|
        FileUtils.cp(File.join(SiteBuilder.root, "assets/img/social-card.png"), File.join(dir, "assets/img", name))
      end
      body = %({% include components/responsive-image.html src="#{PLOT}" alt="A plot" %})
      # An .html page, not Markdown: Kramdown reads the include's indented
      # output as a code block.
      File.write(File.join(dir, "index.html"), "---\nlayout: null\n---\n#{body}\n")
      site = Jekyll::Site.new(Jekyll.configuration(
                                "source" => dir, "destination" => File.join(dir, "_site"), "quiet" => true,
                                "title" => "Hero", "url" => "https://example.org", "author" => { "name" => "Test" }
                              ))
      site.process
      Nokogiri::HTML5.fragment(File.read(File.join(dir, "_site/index.html")))
    end
  end

  class << self
    attr_accessor :hero_markup
  end

  def image(src: PLOT, dark: nil)
    attributes = %(src="#{src}" alt="A plot")
    attributes += %( data-dark-src="#{dark}") if dark
    "<p><img #{attributes}></p>"
  end

  def rendered_picture
    @rendered_picture ||= render(manifest: linked_manifest).at_css("picture")
  end

  def rendered_sources
    rendered_picture.css("source")
  end

  def render(manifest:, html: image, baseurl: "")
    document = Document.new(
      "<html><body>#{html}</body></html>",
      Site.new({ "datalog_responsive_images" => manifest }, { "datalog_image_config" => {} }, baseurl, Dir.tmpdir)
    )
    Jekyll::ImageOptimizer.process(document)
    Nokogiri::HTML5(document.output)
  end
end
