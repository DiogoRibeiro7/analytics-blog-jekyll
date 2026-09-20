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

  def test_built_site_never_marks_a_lazy_image_high_priority
    html_outputs.each do |url, html|
      Nokogiri::HTML5(html).css('img[loading="lazy"][fetchpriority="high"]').each do |img|
        flunk "#{url}: <img src=\"#{img['src']}\"> is both lazy and high priority"
      end
    end
  end

  def test_built_home_page_leaves_priority_to_its_preloaded_hero
    doc = Nokogiri::HTML5(SiteBuilder.read("index.html"))
    assert doc.at_css('link[rel="preload"][as="image"]'), "The home page should preload its hero image"

    card = doc.at_css(".card-media img")
    skip "No post card image on the home page" unless card
    assert_equal "lazy", card["loading"], "A post card image below the hero should be lazy"
    assert_nil card["fetchpriority"], "A post card image should not compete with the hero"
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

  def test_process_fetches_the_first_content_image_early_and_the_rest_lazily
    html = <<~HTML
      <html><body>
        <header><img src="/logo.png" width="40" height="40"></header>
        <div class="post-content">
          <img src="/first.jpg" width="100" height="100">
          <img src="/second.jpg" width="200" height="200">
        </div>
      </body></html>
    HTML
    document = build_mock_document(html)
    Jekyll::ImageOptimizer.process(document)

    doc = Nokogiri::HTML.fragment(document.output)
    first = doc.at_css('img[src="/first.jpg"]')
    assert_equal "high", first["fetchpriority"], "The first content image should get fetchpriority=\"high\""
    assert_nil first["loading"], "The first content image should not be lazy"
    %w[/logo.png /second.jpg].each do |src|
      img = doc.at_css("img[src=\"#{src}\"]")
      assert_equal "lazy", img["loading"], "#{src} should be lazy"
      assert_nil img["fetchpriority"], "#{src} should not get fetchpriority"
    end
  end

  def test_process_prioritises_no_image_when_the_page_preloads_one
    html = <<~HTML
      <html><head><link rel="preload" as="image" href="/hero.webp"></head><body>
        <div class="page-content"><img src="/card.jpg" width="100" height="100"></div>
      </body></html>
    HTML
    document = build_mock_document(html)
    Jekyll::ImageOptimizer.process(document)

    img = Nokogiri::HTML.fragment(document.output).at_css("img")
    assert_equal "lazy", img["loading"]
    assert_nil img["fetchpriority"], "The preloaded hero should be the page's only early image"
  end

  def test_process_does_not_prioritise_a_content_image_the_author_made_lazy
    html = '<html><body><div class="post-content"><img src="/photo.jpg" width="100" height="100" loading="lazy"></div></body></html>'
    document = build_mock_document(html)
    Jekyll::ImageOptimizer.process(document)

    img = Nokogiri::HTML.fragment(document.output).at_css("img")
    assert_equal "lazy", img["loading"]
    assert_nil img["fetchpriority"], "A lazy image should not get fetchpriority=\"high\""
  end

  def test_process_skips_data_no_optimize_images
    html = <<~HTML
      <html><body><div class="post-content">
        <img src="/skip.jpg" data-no-optimize="true">
        <img src="/keep.jpg" width="100" height="100">
        <img src="/later.jpg" width="100" height="100">
      </div></body></html>
    HTML
    document = build_mock_document(html)
    Jekyll::ImageOptimizer.process(document)

    doc = Nokogiri::HTML.fragment(document.output)
    skipped = doc.at_css('img[src="/skip.jpg"]')
    kept = doc.at_css('img[src="/keep.jpg"]')
    later = doc.at_css('img[src="/later.jpg"]')

    assert_nil skipped["loading"],
               "Image with data-no-optimize should not get loading attribute"
    assert_nil skipped["decoding"],
               "Image with data-no-optimize should not get decoding attribute"
    assert_equal "high", kept["fetchpriority"],
                 "First optimized content image should get fetchpriority=\"high\""
    assert_equal "lazy", later["loading"],
                 "Later images should still get loading=\"lazy\""
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

  def test_normalize_src_skips_protocol_relative_urls
    result = Jekyll::ImageOptimizer.normalize_src("///assets/img/photo.jpg", nil)
    assert_nil result
  end

  def test_normalize_src_skips_external_urls
    result = Jekyll::ImageOptimizer.normalize_src("https://example.com/photo.jpg", nil)
    assert_nil result
  end

  def test_normalize_src_returns_nil_for_nil
    result = Jekyll::ImageOptimizer.normalize_src(nil, nil)
    assert_nil result
  end

  def test_normalize_src_returns_nil_for_empty
    result = Jekyll::ImageOptimizer.normalize_src("", nil)
    assert_nil result
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

  def html_outputs
    (@site.pages + @site.docs_to_write).filter_map do |page|
      next unless page.respond_to?(:output_ext) && page.output_ext == ".html"
      next if page.output.nil? || page.output.empty?

      [page.url, page.output]
    end
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
