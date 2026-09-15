# frozen_string_literal: true

require "json"
require_relative "test_helper"

# The <head> of the built pages: one tag of each kind, no empty values, and the
# pages that search engines should leave out.
class HeadMetadataTest < Minitest::Test
  UNLISTED = {
    "404.html" => "/404.html",
    "search/index.html" => "/search/",
    "admin/analytics/index.html" => "/admin/analytics/"
  }.freeze

  def head_of(path)
    html = SiteBuilder.read(path)
    html[0...html.index("</head>")]
  end

  # The default layout repeated tags head.html already writes.
  def test_tags_appear_once
    post = "2024/04/05/sql-optimization-guide/index.html"
    { "index.html" => "the home page", post => "a post with tags" }.each do |path, description|
      head = head_of(path)
      [/<meta name="format-detection"/, %r{<link rel="preconnect" href="https://cdn\.jsdelivr\.net"}, /<meta name="robots"/].each do |tag|
        assert_equal 1, head.scan(tag).size, "#{description} should have one #{tag.source}"
      end
    end
    assert_equal 1, head_of(post).scan(/<meta name="keywords"/).size, "a post with tags should have one keywords tag"
  end

  def test_verification_tags_render_only_when_set
    refute_match(/<meta name="[^"]*(?:verification|msvalidate\.01)" content="\s*"/, head_of("index.html"))
  end

  def test_error_search_and_admin_pages_are_not_indexed
    assert_includes head_of("index.html"), '<meta name="robots" content="index,follow"'
    sitemap = SiteBuilder.read("sitemap.xml")
    UNLISTED.each do |path, url|
      assert_match(/<meta name="robots" content="noindex/, head_of(path), "#{url} should ask not to be indexed")
      refute_includes sitemap, "#{url}</loc>", "#{url} should not be listed in the sitemap"
    end
  end

  def test_structured_data_has_no_empty_values
    SiteBuilder.build
    Dir.glob(File.join(SiteBuilder.destination, "**", "*.html")).each do |path|
      page = path.delete_prefix(SiteBuilder.destination)
      File.read(path).scan(%r{<script type="application/ld\+json"[^>]*>(.*?)</script>}m).each do |(json)|
        data = JSON.parse(json)
        assert_kind_of String, data["headline"], "#{page} needs a headline" if data.key?("headline")
        data.each { |key, value| refute_equal "", value, "#{page} has an empty #{key}" }
      end
    end
  end
end
