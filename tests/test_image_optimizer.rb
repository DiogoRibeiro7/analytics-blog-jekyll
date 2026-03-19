# frozen_string_literal: true

require_relative "test_helper"
require "nokogiri"
require "ostruct"

class ImageOptimizerTest < Minitest::Test
  def setup
    @site = SiteBuilder.site
  end

  # ---------------------------------------------------------------------------
  # Integration tests: verify attributes on built site pages
  # ---------------------------------------------------------------------------

  def test_built_site_images_have_lazy_loading
    html = find_optimized_page
    skip "No HTML page with optimized images found in built site" unless html

    doc = Nokogiri::HTML.fragment(html)
    images = doc.css("img").reject { |img| img["data-no-optimize"] == "true" }
    images.select { |img| img["loading"] }.each do |img|
      assert_equal "lazy", img["loading"],
                   "Expected loading=\"lazy\" on <img src=\"#{img['src']}\">"
    end
  end

  def test_built_site_images_have_decoding_async
    html = find_optimized_page
    skip "No HTML page with optimized images found in built site" unless html

    doc = Nokogiri::HTML.fragment(html)
    images = doc.css("img").reject { |img| img["data-no-optimize"] == "true" }
    images.select { |img| img["decoding"] }.each do |img|
      assert_equal "async", img["decoding"],
                   "Expected decoding=\"async\" on <img src=\"#{img['src']}\">"
    end
  end

  def test_built_site_first_image_gets_fetchpriority_high
    html = find_optimized_page
    skip "No HTML page with optimized images found in built site" unless html

    doc = Nokogiri::HTML.fragment(html)
    images = doc.css("img").reject { |img| img["data-no-optimize"] == "true" }
    prioritized = images.select { |img| img["fetchpriority"] }
    skip "No images with fetchpriority in built site" if prioritized.empty?

    assert_equal "high", prioritized.first["fetchpriority"]
  end

  # ---------------------------------------------------------------------------
  # Unit tests: exercise the process method directly with mock documents
  # ---------------------------------------------------------------------------

  def test_process_adds_lazy_loading
    document = build_mock_document('<html><body><img src="/photo.jpg" width="100" height="100"></body></html>')
    Jekyll::ImageOptimizer.process(document)

    doc = Nokogiri::HTML.fragment(document.output)
    img = doc.at_css("img")
    assert_equal "lazy", img["loading"]
  end

  def test_process_adds_decoding_async
    document = build_mock_document('<html><body><img src="/photo.jpg" width="100" height="100"></body></html>')
    Jekyll::ImageOptimizer.process(document)

    doc = Nokogiri::HTML.fragment(document.output)
    img = doc.at_css("img")
    assert_equal "async", img["decoding"]
  end

  def test_process_assigns_fetchpriority_to_first_image_only
    html = <<~HTML
      <html><body>
        <img src="/first.jpg" width="100" height="100">
        <img src="/second.jpg" width="200" height="200">
      </body></html>
    HTML
    document = build_mock_document(html)
    Jekyll::ImageOptimizer.process(document)

    doc = Nokogiri::HTML.fragment(document.output)
    images = doc.css("img")
    assert_equal "high", images[0]["fetchpriority"],
                 "First image should get fetchpriority=\"high\""
    assert_nil images[1]["fetchpriority"],
               "Second image should not get fetchpriority"
  end

  def test_process_skips_data_no_optimize_images
    html = <<~HTML
      <html><body>
        <img src="/skip.jpg" data-no-optimize="true">
        <img src="/keep.jpg" width="100" height="100">
      </body></html>
    HTML
    document = build_mock_document(html)
    Jekyll::ImageOptimizer.process(document)

    doc = Nokogiri::HTML.fragment(document.output)
    skipped = doc.at_css('img[src="/skip.jpg"]')
    kept = doc.at_css('img[src="/keep.jpg"]')

    assert_nil skipped["loading"],
               "Image with data-no-optimize should not get loading attribute"
    assert_nil skipped["decoding"],
               "Image with data-no-optimize should not get decoding attribute"
    assert_equal "lazy", kept["loading"],
                 "Normal image should still get loading=\"lazy\""
    assert_equal "high", kept["fetchpriority"],
                 "First non-skipped image should get fetchpriority=\"high\""
  end

  def test_process_does_not_overwrite_existing_attributes
    html = '<html><body><img src="/photo.jpg" width="100" height="100" loading="eager" decoding="sync" fetchpriority="low"></body></html>'
    document = build_mock_document(html)
    Jekyll::ImageOptimizer.process(document)

    doc = Nokogiri::HTML.fragment(document.output)
    img = doc.at_css("img")
    assert_equal "eager", img["loading"], "Existing loading should not be overwritten"
    assert_equal "sync", img["decoding"], "Existing decoding should not be overwritten"
    assert_equal "low", img["fetchpriority"], "Existing fetchpriority should not be overwritten"
  end

  def test_process_ignores_non_html_documents
    document = build_mock_document("body { color: red; }", ".css")
    original = document.output.dup
    Jekyll::ImageOptimizer.process(document)
    assert_equal original, document.output
  end

  def test_process_ignores_empty_output
    document = build_mock_document("")
    Jekyll::ImageOptimizer.process(document)
    assert_equal "", document.output
  end

  def test_process_ignores_nil_output
    document = build_mock_document(nil)
    Jekyll::ImageOptimizer.process(document)
    assert_nil document.output
  end

  # ---------------------------------------------------------------------------
  # Unit tests for helper methods
  # ---------------------------------------------------------------------------

  def test_normalize_src_strips_leading_slashes
    result = Jekyll::ImageOptimizer.normalize_src("///assets/img/photo.jpg", nil)
    assert_equal "/assets/img/photo.jpg", result
  end

  def test_normalize_src_preserves_external_urls
    result = Jekyll::ImageOptimizer.normalize_src("https://example.com/photo.jpg", nil)
    assert_equal "https://example.com/photo.jpg", result
  end

  def test_normalize_src_returns_nil_for_nil
    result = Jekyll::ImageOptimizer.normalize_src(nil, nil)
    assert_nil result
  end

  def test_normalize_src_returns_empty_for_empty
    result = Jekyll::ImageOptimizer.normalize_src("", nil)
    assert_equal "", result
  end

  def test_build_srcset_produces_correct_format
    variants = [
      { "url" => "/img/photo-320w.jpg", "width" => 320 },
      { "url" => "/img/photo-640w.jpg", "width" => 640 }
    ]
    result = Jekyll::ImageOptimizer.build_srcset(variants)
    assert_equal "/img/photo-320w.jpg 320w, /img/photo-640w.jpg 640w", result
  end

  def test_build_srcset_skips_incomplete_variants
    variants = [
      { "url" => "/img/photo-320w.jpg", "width" => 320 },
      { "url" => nil, "width" => 640 },
      { "url" => "/img/photo-960w.jpg", "width" => nil }
    ]
    result = Jekyll::ImageOptimizer.build_srcset(variants)
    assert_equal "/img/photo-320w.jpg 320w", result
  end

  def test_scaled_height_calculates_correctly
    result = Jekyll::ImageOptimizer.scaled_height(1000, 500, 500)
    assert_equal 250, result
  end

  def test_scaled_height_handles_zero_width
    result = Jekyll::ImageOptimizer.scaled_height(0, 500, 500)
    assert_equal 500, result
  end

  private

  def find_optimized_page
    all = @site.pages + @site.docs_to_write
    all.each do |page|
      next unless page.respond_to?(:output_ext) && page.output_ext == ".html"
      next unless page.respond_to?(:output) && !page.output.nil? && !page.output.empty?

      doc = Nokogiri::HTML.fragment(page.output)
      optimized_imgs = doc.css('img[loading="lazy"]')
      return page.output unless optimized_imgs.empty?
    end
    nil
  end

  # Build a lightweight mock document for Jekyll::ImageOptimizer.process.
  # The mock carries a manifest entry so that `optimized` becomes true and
  # the output is actually written back.
  def build_mock_document(html, ext = ".html")
    manifest = {}
    if html && ext == ".html"
      frag = Nokogiri::HTML::DocumentFragment.parse(html)
      frag.css("img").each do |img|
        src = img["src"]
        next unless src
        next if img["data-no-optimize"] == "true"
        next unless img["width"] && img["height"]

        manifest[src] = {
          "width" => img["width"].to_i,
          "height" => img["height"].to_i,
          "sources" => [],
          "fallback" => { "variants" => [] }
        }
      end
    end

    site_data = { "datalog_responsive_images" => manifest }
    site_config = { "datalog_image_config" => {} }
    mock_site = OpenStruct.new(data: site_data, config: site_config, baseurl: "")

    MockDocument.new(html, ext, mock_site)
  end

  class MockDocument
    attr_accessor :output
    attr_reader :output_ext, :site

    def initialize(output, ext, site)
      @output = output
      @output_ext = ext
      @site = site
    end

    def respond_to?(method, include_all = false)
      %i[output output= output_ext site].include?(method) || super
    end
  end
end
