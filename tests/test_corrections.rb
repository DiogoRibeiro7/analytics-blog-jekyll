# frozen_string_literal: true

require_relative "test_helper"

# The correction-report form (#256): the markup a post carries on a site
# with a backend, the settings and the front matter that remove it, the
# categories and their labels, and the bundle's wiring.
class CorrectionsTest < Minitest::Test
  SERVICES = { "base_url" => "https://api.example.org", "api_version" => "v1", "features" => { "corrections" => true } }.freeze

  def test_the_demo_without_a_backend_renders_no_form
    html = SiteBuilder.read("2024/04/05/sql-optimization-guide/index.html")

    refute_includes html, "data-correction-report"
    assert_includes html, 'body.dataset.featureCorrections = "false"'
    refute_match(%r{rel="modulepreload"[^>]*/corrections\.js}, html)
  end

  def test_a_site_with_a_backend_renders_the_form
    doc = render("dynamic_services" => SERVICES)
    root = doc.at_css("details[data-correction-report]")

    assert_equal ["https://example.org/", "Paper"], [root["data-article-url"], root["data-article-title"]]
    assert_equal "Report an error or suggest a correction", root.at_css("summary").text
    form = root.at_css("form.service-form")
    assert_equal %w[idle false], [form["data-state"], form["aria-busy"]]
    assert_equal %w[mathematical-error factual-error citation code reproducibility typo accessibility other],
                 values_of(form.css("#correction-category option"))
    assert_equal "Mathematical error", form.at_css("#correction-category option").text
    assert form.at_css("textarea[name=message][required][minlength='20']")
    assert form.at_css("input[name=contact_email][type=email]")
    assert form.at_css(".service-form__trap input[name=website][tabindex='-1']"), "the honeypot is out of the tab order"
    assert form.at_css("[data-form-status][role=status][aria-live=polite]")
    labels = JSON.parse(root.at_css("script[data-correction-labels]").text)
    assert_equal "Sending the report…", labels["pending"]
    assert_includes labels["errors"]["rate_limited"], "Too many requests"
    assert_equal "Reference: {{id}}", labels["errors"]["reference"]
  end

  def test_the_bundle_is_wired_through_the_manifest_the_flag_and_a_preload
    manifest = JSON.parse(File.read(File.join(SiteBuilder.root, "_data", "js_manifest.json")))

    assert_equal "/assets/js/dist/corrections.js", manifest.dig("features", "corrections")
    assert File.exist?(File.join(SiteBuilder.root, "assets", "js", "dist", "corrections.js")), "the bundle is built"
  end

  def test_the_settings_and_the_page_can_remove_the_form
    off = SERVICES.merge("features" => { "corrections" => false })

    assert_nil form_in(render("dynamic_services" => off)), "the feature off in the services"
    assert_nil form_in(render("dynamic_services" => SERVICES, "corrections" => { "enabled" => false })),
               "corrections off"
    assert_nil form_in(render({ "dynamic_services" => SERVICES }, "corrections: false\n")), "the page opts out"
    assert_nil form_in(render({})), "no backend, no form"
  end

  def test_the_categories_are_configurable_and_localized
    doc = render("dynamic_services" => SERVICES, "corrections" => { "categories" => %w[code typo] })

    assert_equal %w[code typo], values_of(doc.css("#correction-category option"))

    pt = render({ "dynamic_services" => SERVICES }, "lang: pt\n")

    assert_equal "Comunicar um erro ou sugerir uma correção", pt.at_css("summary").text
    assert_equal "Erro matemático", pt.at_css("#correction-category option").text
    labels = JSON.parse(pt.at_css("script[data-correction-labels]").text)

    assert_equal "Referência: {{id}}", labels["errors"]["reference"]
  end

  private

  def form_in(doc)
    doc.at_css("[data-correction-report]")
  end

  def values_of(options)
    options.map { |option| option["value"] }
  end

  # A page holding the form, under the given site configuration and front matter.
  def render(config, front_matter = "")
    TestSite.build(config.merge(title: "Corrections")) do |source|
      source.theme("_includes/components/correction-report.html", "_data/i18n")
      source.page("index.html", "{% include components/correction-report.html %}",
                  "layout: null\ntitle: Paper\n#{front_matter}")
    end.html("index.html")
  end
end
