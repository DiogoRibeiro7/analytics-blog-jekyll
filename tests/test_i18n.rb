# frozen_string_literal: true

require_relative "test_helper"

# The theme ships a single configured locale: theme_options.localization.locales
# in _config.yml lists only `en`, and _data/i18n/ carries en.yml. These tests
# cover the translation machinery for that locale rather than asserting
# multi-language pages the site does not build.
class TestI18n < Minitest::Test
  UNBUILT_LOCALES = %w[pt es ar].freeze

  def test_every_literal_template_translation_exists_in_each_shipped_locale
    files = Dir[File.join(SiteBuilder.root, "{_layouts,_includes}", "**", "*.html")]
    keys = files.flat_map do |file|
      source = File.read(file)
      source.scan(/\{%-?\s*t\s+['"]([\w.]+)['"]/).flatten +
        source.scan(/['"]([\w.]+)['"]\s*\|\s*t\b/).flatten
    end.uniq
    %w[en es pt].each do |locale|
      keys.each do |key|
        refute_nil Datalog::I18n.lookup(SiteBuilder.site, locale, key), "#{locale}: missing #{key}"
      end
    end
  end

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

    # global.math_loading in _data/i18n/en.yml, the math status every page carries.
    assert_includes html, "Loading mathematical content",
                    "expected the {% t %} tag to render a string from _data/i18n/en.yml"
  end

  # The tag split its options on every comma, so a quoted value containing one
  # was cut in two and the translation received only a fragment.
  def test_translation_tag_keeps_commas_inside_quoted_options
    template = Liquid::Template.parse(%({% t header.brand_home site: "Doe, Jane" %}))

    assert_equal "Doe, Jane home", template.render!({}, registers: { site: SiteBuilder.site })
  end

  def test_translation_prefers_locale_data_over_the_inline_fallback
    html = SiteBuilder.read("admin/analytics/index.html")

    # en.yml spells this "Analytics overview"; the inline fallback in the
    # template spells it "Analytics Overview". Matching the former proves the
    # lookup resolved against the data rather than falling through.
    assert_includes html, "Analytics overview"
    refute_includes html, "Analytics Overview"
  end

  # _data/navigation.yml names the key for each entry, so the tag has to accept
  # a variable holding a key as well as a key written out. Both are unquoted,
  # so the variable is tried first and a key that is not one is used as written.
  def test_an_unquoted_key_may_be_a_variable_holding_one
    template = Liquid::Template.parse("{% t item.title_key %}")
    rendered = template.render!({ "item" => { "title_key" => "navigation.header.blog.title" } },
                                registers: { site: SiteBuilder.site })

    assert_equal "Blog", rendered
  end

  def test_an_unquoted_key_that_names_no_variable_is_still_a_key
    template = Liquid::Template.parse("{% t post.toc_heading %}")

    assert_equal "On this page", template.render!({}, registers: { site: SiteBuilder.site })
  end

  def test_a_variable_holding_no_key_falls_back_to_the_token
    template = Liquid::Template.parse("{% t item.title_key %}")
    rendered = template.render!({ "item" => {} }, registers: { site: SiteBuilder.site })

    assert_equal "item.title_key", rendered
  end

  def test_quoted_keys_interpolate_their_options
    html = SiteBuilder.read(File.join(SiteBuilder.site.posts.docs.find { |doc| doc.data["title"] == "Python Data Wrangling Foundations" }.url, "index.html"))
    refute_includes html, "{{minutes}}", "the reading-time placeholder must be replaced"
    assert_match(/\d+ mins? read/, html)
  end
end
