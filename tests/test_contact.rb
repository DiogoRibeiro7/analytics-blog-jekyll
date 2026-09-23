# frozen_string_literal: true

require_relative "test_helper"

# The contact and collaboration form (#261): the demo's contact page without
# a backend, the markup on a site with one, the prompts that follow the
# category, the privacy wording, and the settings that remove it.
class ContactTest < Minitest::Test
  SERVICES = { "base_url" => "https://api.example.org", "api_version" => "v1", "features" => { "contact" => true } }.freeze

  def test_the_demo_contact_page_falls_back_to_the_email_address
    html = SiteBuilder.read("contact/index.html")

    refute_includes html, "data-contact-form"
    assert_includes html, 'body.dataset.featureContact = "false"'
    assert_match(%r{<a href="mailto:[^"]+">[^<]+</a>}, html)
    assert_includes html, "no message service"
  end

  def test_a_site_with_a_backend_renders_the_form
    doc = render("dynamic_services" => SERVICES)
    root = doc.at_css("section[data-contact-form]")

    assert_equal "https://example.org/", root["data-source-url"]
    form = root.at_css("form.service-form")
    assert_equal %w[idle false], [form["data-state"], form["aria-busy"]]
    assert_equal %w[research-collaboration consulting speaking mentoring reproducibility media other],
                 values_of(form.css("#contact-category option"))
    assert_equal "Research collaboration", form.at_css("#contact-category option").text
    assert form.at_css("input[name=name][required]")
    assert form.at_css("input[name=email][type=email][required]")
    assert form.at_css("input[name=affiliation]:not([required])")
    assert form.at_css("input[name=subject][required]")
    assert form.at_css("textarea[name=message][required][minlength='20']")
    assert form.at_css(".service-form__trap input[name=website][tabindex='-1']"), "the honeypot is out of the tab order"
    assert form.at_css("[data-form-status][role=status][aria-live=polite]")
    assert_includes form.at_css(".service-form__privacy").text, "never shown on the site"
    labels = JSON.parse(root.at_css("script[data-contact-labels]").text)
    assert_equal "Sending the message…", labels["pending"]
    assert_includes labels["errors"]["rate_limited"], "Too many requests"
    prompts = JSON.parse(root.at_css("script[data-contact-prompts]").text)
    assert_includes prompts["research-collaboration"], "question"
    refute prompts.key?("other"), "'other' has no prompt"
  end

  def test_the_prompts_and_the_privacy_wording_can_be_configured
    doc = render("dynamic_services" => SERVICES,
                 "contact" => { "categories" => %w[media other], "prompts" => { "media" => "Outlet and deadline." },
                                "privacy_notice" => "We read every message.", "retention" => "Kept for a year." })

    assert_equal %w[media other], values_of(doc.css("#contact-category option"))
    assert_equal({ "media" => "Outlet and deadline.", "" => "" },
                 JSON.parse(doc.at_css("script[data-contact-prompts]").text))
    assert_equal "We read every message. Kept for a year.", doc.at_css(".service-form__privacy").text
  end

  def test_the_form_is_localized
    pt = render({ "dynamic_services" => SERVICES }, "lang: pt\n")

    assert_equal "Colaboração em investigação", pt.at_css("#contact-category option").text
    assert_includes JSON.parse(pt.at_css("script[data-contact-prompts]").text)["media"], "prazo"
  end

  def test_the_settings_remove_the_form_or_leave_the_email
    off = SERVICES.merge("features" => { "contact" => false })

    assert_nil render("dynamic_services" => SERVICES, "contact" => { "enabled" => false }).at_css("#contact"),
               "contact off"
    fallback = render("dynamic_services" => off)

    assert_nil fallback.at_css("[data-contact-form]"), "the feature off in the services"
    assert_equal "mailto:hello@example.org", fallback.at_css("#contact a")["href"]
    assert_nil render({ "contact_email" => nil }).at_css("#contact"), "no backend and no address: nothing"
  end

  def test_the_page_layout_renders_the_form_only_when_asked
    with_form = render({ "dynamic_services" => SERVICES }, "layout: page\ncontact_form: true\n", "Hello.\n")

    assert with_form.at_css(".page-content [data-contact-form]"), "the form after the content"
    assert_nil render({ "dynamic_services" => SERVICES }, "layout: page\n", "Hello.\n").at_css("[data-contact-form]")
  end

  private

  def values_of(options)
    options.map { |option| option["value"] }
  end

  # A page holding the form, under the given site configuration and front matter.
  def render(config, front_matter = "", body = "{% include components/contact-form.html %}\n")
    front_matter = "layout: null\n#{front_matter}" unless front_matter.include?("layout:")
    TestSite.build({ title: "Contact", contact_email: "hello@example.org" }.merge(config)) do |source|
      source.theme("_includes/components/contact-form.html", "_data/i18n", "_layouts/page.html")
      # The theme's page layout over a bare default one, so the test needs no other include.
      source.layout("default.html", "{{ content }}\n")
      source.page("index.html", body, "title: Contact\n#{front_matter}")
    end.html("index.html")
  end
end
