# frozen_string_literal: true

require_relative "test_helper"

# The theme ships a single configured locale: theme_options.localization.locales
# in _config.yml lists only `en`, and _data/i18n/ carries en.yml. These tests
# cover the translation machinery for that locale rather than asserting
# multi-language pages the site does not build.
class TestI18n < Minitest::Test
  UNBUILT_LOCALES = %w[pt es ar].freeze

  def test_homepage_declares_the_configured_locale
    html = SiteBuilder.read("index.html")

    assert_includes html, 'lang="en"'
    assert_includes html, 'dir="ltr"'
  end

  def test_no_alternates_are_advertised_for_locales_that_are_not_built
    html = SiteBuilder.read("index.html")

    UNBUILT_LOCALES.each do |code|
      refute_includes html, %(hreflang="#{code}"),
                      "#{code} has no generated pages, so advertising it as an alternate points crawlers at a 404"
    end
  end

  def test_translation_tag_resolves_strings_from_locale_data
    html = SiteBuilder.read("index.html")

    # header.reading_progress in _data/i18n/en.yml.
    assert_includes html, "Reading progress:",
                    "expected the {% t %} tag to render a string from _data/i18n/en.yml"
  end

  def test_translation_prefers_locale_data_over_the_inline_fallback
    html = SiteBuilder.read("admin/analytics/index.html")

    # en.yml spells this "Analytics overview"; the inline fallback in the
    # template spells it "Analytics Overview". Matching the former proves the
    # lookup resolved against the data rather than falling through.
    assert_includes html, "Analytics overview"
    refute_includes html, "Analytics Overview"
  end
end
