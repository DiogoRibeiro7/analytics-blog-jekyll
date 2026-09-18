# frozen_string_literal: true

require_relative "test_helper"
require "nokogiri"

# The markup a page gets for an image with generated copies: a <picture> with
# an AVIF and a WebP <source>, around an <img> that keeps its attributes. Only
# the responsive-image include rendered a <picture>, so a Markdown image never
# got one (#243). tests/test_image_variants.rb builds sites that encode them.
class ImagePictureMarkupTest < Minitest::Test
  PLOT = "/assets/img/plot.png"

  Site = Struct.new(:data, :config, :baseurl)
  Document = Struct.new(:output, :site) do
    def output_ext
      ".html"
    end
  end

  def plot_entry(sources: true)
    variant = ->(format, width) { { "url" => "/assets/img/responsive/plot-#{width}w.#{format}", "width" => width } }
    {
      "width" => 1200,
      "height" => 600,
      "sources" => (sources ? %w[avif webp] : []).map do |format|
        { "type" => "image/#{format}", "format" => format, "variants" => [variant[format, 640], variant[format, 1200]] }
      end,
      "fallback" => { "variants" => [variant["png", 640], { "url" => PLOT, "width" => 1200 }] }
    }
  end

  def test_process_wraps_an_image_in_a_picture_with_its_modern_formats
    html = <<~HTML
      <html><body><div class="post-content">
        <p><img src="#{PLOT}" alt="A plot" class="wide" id="plot" title="Power" data-zoom="true"></p>
      </div></body></html>
    HTML
    document = build_document(html, { PLOT => plot_entry })
    Jekyll::ImageOptimizer.process(document)

    picture = Nokogiri::HTML5(document.output).at_css("p > picture")
    refute_nil picture, "The image should be wrapped in a <picture>"
    sources = picture.css("source")
    assert_equal(%w[image/avif image/webp], sources.map { |source| source["type"] })
    assert_equal "/assets/img/responsive/plot-640w.avif 640w, /assets/img/responsive/plot-1200w.avif 1200w",
                 sources.first["srcset"]
    assert(sources.all? { |source| source["sizes"] == "100vw" })

    img = picture.at_css("img")
    assert_equal img, picture.element_children.last, "The <img> should follow the sources"
    { "src" => PLOT, "alt" => "A plot", "class" => "wide", "id" => "plot", "title" => "Power", "data-zoom" => "true",
      "width" => "1200", "height" => "600", "fetchpriority" => "high", "decoding" => "async", "sizes" => "100vw",
      "srcset" => "/assets/img/responsive/plot-640w.png 640w, #{PLOT} 1200w" }.each do |name, value|
      assert_equal value, img[name], "The <img> should keep #{name}"
    end
  end

  def test_process_puts_the_baseurl_in_front_of_variant_urls
    html = %(<html><body><img src="/blog#{PLOT}" alt="A plot"></body></html>)
    document = build_document(html, { PLOT => plot_entry }, baseurl: "/blog")
    Jekyll::ImageOptimizer.process(document)

    doc = Nokogiri::HTML5(document.output)
    urls = (doc.css("source") + doc.css("img")).flat_map do |node|
      node["srcset"].split(", ").map { |candidate| candidate.split.first }
    end
    refute_empty urls
    urls.each { |url| assert url.start_with?("/blog/assets/img/"), "#{url} should start with the baseurl" }
    assert_equal "/blog#{PLOT}", doc.at_css("img")["src"]
  end

  def test_process_leaves_an_authors_picture_and_srcset_alone
    html = <<~HTML
      <html><body>
        <picture><source type="image/webp" srcset="/custom.webp"><img src="#{PLOT}" alt="Own picture"></picture>
        <img src="#{PLOT}" srcset="#{PLOT} 1x, /plot-2x.png 2x" alt="Own srcset">
      </body></html>
    HTML
    document = build_document(html, { PLOT => plot_entry })
    Jekyll::ImageOptimizer.process(document)

    doc = Nokogiri::HTML5(document.output)
    assert_equal 1, doc.css("picture").size, "No second <picture> should be added"
    assert_equal(["/custom.webp"], doc.css("source").map { |source| source["srcset"] })
    own_srcset = doc.at_css('img[alt="Own srcset"]')
    assert_equal "#{PLOT} 1x, /plot-2x.png 2x", own_srcset["srcset"]
    refute_equal "picture", own_srcset.parent.name
  end

  def test_process_offers_nothing_when_only_the_original_exists
    entry = plot_entry(sources: false).merge("fallback" => { "variants" => [{ "url" => PLOT, "width" => 1200 }] })
    document = build_document(%(<html><body><img src="#{PLOT}" alt="A plot"></body></html>), { PLOT => entry })
    Jekyll::ImageOptimizer.process(document)

    img = Nokogiri::HTML5(document.output).at_css("img")
    refute_equal "picture", img.parent.name
    assert_nil img["srcset"], "A srcset naming only the original adds nothing"
    assert_nil img["sizes"]
    assert_equal %w[1200 600], [img["width"], img["height"]]
  end

  def test_process_leaves_opted_out_remote_and_unlisted_images_unwrapped
    html = <<~HTML
      <html><body>
        <img src="#{PLOT}" alt="Opted out" data-no-optimize="true">
        <img src="https://example.com#{PLOT}" alt="Remote">
        <img src="/assets/img/unlisted.png" alt="Unlisted">
      </body></html>
    HTML
    document = build_document(html, { PLOT => plot_entry })
    Jekyll::ImageOptimizer.process(document)

    doc = Nokogiri::HTML5(document.output)
    assert_empty doc.css("picture")
    assert(doc.css("img").none? { |img| img["srcset"] })
  end

  # A page without a layout is a fragment, which the HTML4 serializer wrote with
  # a </source> end tag.
  def test_process_writes_void_source_elements_in_a_page_without_a_layout
    document = build_document(%(<p><img src="#{PLOT}" alt="A plot"></p>), { PLOT => plot_entry })
    Jekyll::ImageOptimizer.process(document)

    assert_includes document.output, "<picture><source type=\"image/avif\""
    refute_includes document.output, "</source>"
  end

  private

  def build_document(html, manifest, baseurl: "")
    Document.new(html, Site.new({ "datalog_responsive_images" => manifest }, { "datalog_image_config" => {} }, baseurl))
  end
end
