# frozen_string_literal: true

require_relative "test_helper"

# The correction-report form (#256): the markup a post carries on a site
# with a backend, the settings and the front matter that remove it, the
# categories and their labels, and the bundle's wiring.
class CorrectionsTest < Minitest::Test
  SERVICES = { "base_url" => "https://api.example.org", "api_version" => "v1", "features" => { "corrections" => true } }.freeze

  def test_the_demo_without_a_backend_offers_email_instead_of_a_form
    html = SiteBuilder.read("2024/04/05/sql-optimization-guide/index.html")

    refute_includes html, "data-correction-report"
    assert_includes html, "data-correction-fallback"
    assert_includes html, 'body.dataset.featureCorrections = "auto"'
    refute_match(%r{rel="modulepreload"[^>]*/corrections\.js}, html)
  end

  def test_a_site_with_a_backend_renders_the_form
    doc = render("dynamic_services" => SERVICES)
    root = doc.at_css("details[data-correction-report]")
    assert_nil doc.at_css("[data-correction-fallback]")

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

  def test_a_static_github_site_has_an_encoded_issue_link_and_public_notice
    doc = render({ "repository" => "https://github.com/example/research",
                   "corrections" => { "issue_labels" => ["correction", "needs review"] } },
                 "title: 'Paper <script> & findings'\n")
    link = doc.at_css("[data-correction-fallback]")
    params = URI.decode_www_form(URI.parse(link["href"]).query).to_h

    assert_equal "https://github.com/example/research/issues/new", link["href"].split("?").first
    assert_equal "Correction: Paper <script> & findings", params["title"]
    assert_includes params["body"], "https://example.org/"
    assert_equal "correction,needs review", params["labels"]
    assert_equal "body", link["data-correction-body-param"]
    assert_includes doc.at_css(".correction-report__note").text, "public"
    refute_includes doc.to_html, "<script> & findings"
    assert_nil form_in(doc)
  end

  def test_gitlab_email_and_opt_out_modes
    gitlab = render("repository" => "https://gitlab.com/team/subgroup/project")
    link = gitlab.at_css("[data-correction-fallback]")
    assert_equal "https://gitlab.com/team/subgroup/project/-/issues/new", link["href"].split("?").first
    assert_equal "Correction: Paper", URI.decode_www_form(URI.parse(link["href"]).query).to_h["issue[title]"]

    email = render("contact_email" => "reader@example.org")
    link = email.at_css("[data-correction-fallback]")
    assert_match(%r{\Amailto:reader@example\.org\?}, link["href"])
    assert_includes URI.decode_www_form(URI.parse(link["href"]).query).to_h["body"], "https://example.org/"
    assert_nil email.at_css(".correction-report__note")

    assert_nil render("repository" => "javascript:alert(1)").at_css("[data-correction-fallback]")
    assert_nil render("repository" => "https://github.com.evil.example/a/b").at_css("[data-correction-fallback]")
    assert_nil render("corrections" => { "fallback" => "issue" }, "contact_email" => "reader@example.org")
                    .at_css("[data-correction-fallback]")
    assert_nil render("corrections" => { "fallback" => "none" }, "repository" => "https://github.com/a/b")
                    .at_css("[data-correction-fallback]")
    assert_nil render({ "repository" => "https://github.com/a/b" }, "corrections: false\n")
                    .at_css("[data-correction-fallback]")
    assert_nil render("repository" => "https://github.com/a/b", "corrections" => { "enabled" => false })
                    .at_css("[data-correction-fallback]")
    assert render("repository" => "https://github.com/a/b", "dynamic_services" =>
                  SERVICES.merge("features" => { "corrections" => false })).at_css("[data-correction-fallback]")
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
      title_line = front_matter.start_with?("title:") ? "" : "title: Paper\n"
      source.page("index.html", "{% include components/correction-report.html %}",
                  "layout: null\n#{title_line}#{front_matter}")
    end.html("index.html")
  end
end
