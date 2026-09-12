# frozen_string_literal: true

require_relative "test_helper"

class SriFilterTest < Minitest::Test
  SAMPLE_PAGE = "index.html"

  def setup
    @site = SiteBuilder.site
    @integrity_map = @site.data["cdn-integrity"] || {}
  end

  def test_cdn_urls_in_output_have_integrity_attributes
    html = SiteBuilder.read(SAMPLE_PAGE)
    @integrity_map.each_key do |url|
      next unless references?(html, url)

      entry = @integrity_map[url]
      assert_includes html, entry["integrity"],
                      "Expected integrity hash for #{url} to appear in built output"
    end
  end

  def test_non_cdn_url_passes_through_unchanged
    context = make_liquid_context
    filter = Object.new
    filter.extend(Jekyll::SriFilter)
    filter.instance_variable_set(:@context, context)

    plain_url = "/assets/css/style.css"
    result = filter.add_sri(plain_url)
    assert_equal plain_url, result,
                 "Non-CDN URL should be returned unchanged when not in integrity map"
  end

  def test_crossorigin_attribute_is_included
    html = SiteBuilder.read(SAMPLE_PAGE)
    @integrity_map.each do |url, entry|
      next unless references?(html, url) && entry["crossorigin"]

      assert_includes html, %(crossorigin="#{entry['crossorigin']}"),
                      "Expected crossorigin attribute for #{url}"
    end
  end

  def test_known_cdn_url_produces_integrity_string
    context = make_liquid_context
    filter = Object.new
    filter.extend(Jekyll::SriFilter)
    filter.instance_variable_set(:@context, context)

    cdn_url = @integrity_map.keys.first
    skip "No CDN integrity entries configured" unless cdn_url

    result = filter.add_sri(cdn_url)
    entry = @integrity_map[cdn_url]

    assert_includes result, cdn_url, "Result should contain the original URL"
    assert_includes result, entry["integrity"], "Result should contain the integrity hash"
    if entry["crossorigin"]
      assert_includes result, %(crossorigin="#{entry['crossorigin']}),
                      "Result should contain crossorigin attribute"
    end
  end

  private

  # A URL loaded by the page, as opposed to one merely mentioned in the theme
  # options that scripts-loader.html serialises into window.DatalogTheme.
  def references?(html, url)
    html.match?(/\b(?:src|href)="#{Regexp.escape(url)}"/)
  end

  def make_liquid_context
    registers = { site: @site }
    Liquid::Context.new({}, {}, registers)
  end
end
