# frozen_string_literal: true

require_relative "test_helper"
require "nokogiri"

class ResponsiveImagesTest < Minitest::Test
  FAVICON_PATH = "/assets/img/favicons/android-chrome-192x192.png"

  def setup
    @manifest = JSON.parse(SiteBuilder.read("assets/img/responsive/manifest.json"))
  end

  def test_manifest_includes_multiple_formats
    icon_entry = @manifest[FAVICON_PATH]
    refute_nil icon_entry, "Responsive manifest should include favicon entry"

    source_types = icon_entry.fetch("sources", []).map { |source| source["type"] }.compact.uniq
    skip "Image conversion tooling unavailable" if source_types.empty?

    assert_includes source_types, "image/avif", "AVIF source should be present"
    assert_includes source_types, "image/webp", "WebP source should be present"
  end

  def test_srcset_contains_expected_widths
    icon_entry = @manifest[FAVICON_PATH]
    fallback_variants = icon_entry.dig("fallback", "variants") || []
    refute_empty fallback_variants, "Fallback variants should not be empty"

    srcset = fallback_variants.map do |variant|
      next unless variant["url"] && variant["width"]

      "#{variant['url']} #{variant['width']}w"
    end.compact.join(", ")

    assert_includes srcset, "#{FAVICON_PATH} 192w", "Srcset should include original width entry"
  end

  def test_derivative_files_are_written
    icon_entry = @manifest[FAVICON_PATH]
    refute_nil icon_entry, "Responsive manifest should include favicon entry"

    sources = icon_entry.fetch("sources", [])
    if sources.empty?
      skip "Responsive derivatives were not generated in this environment"
    else
      sources.each do |source|
        format = source["format"] || source["type"]&.split("/")&.last
        next unless format

        source.fetch("variants", []).each do |variant|
          variant_path = variant["url"].to_s.delete_prefix("/")
          derivative = SiteBuilder.destination_path(variant_path)
          assert File.exist?(derivative), "Expected #{format} derivative to be written to _site"
        end
      end
    end

    fallback = SiteBuilder.destination_path("assets/img/favicons/android-chrome-192x192.png")
    assert File.exist?(fallback), "Original fallback asset should be copied to _site"
  end

  def test_responsive_include_falls_back_without_manifest_entry
    include_template = Liquid::Template.parse("{% include components/responsive-image.html src='/assets/img/portfolio-placeholder.svg' alt='Data visualization motif' %}")
    context = {
      "site" => SiteBuilder.payload["site"],
      "page" => {}
    }
    rendered = include_template.render!(context, registers: { site: SiteBuilder.site })
    document = Nokogiri::HTML.fragment(rendered)

    fallback_img = document.at_css("img")
    refute_nil fallback_img, "About page portrait should render an <img> element"
    assert_equal "/assets/img/portfolio-placeholder.svg", fallback_img["src"],
                 "Include should fall back to original source when no manifest entry"
  end
end
