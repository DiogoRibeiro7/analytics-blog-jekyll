# frozen_string_literal: true

require_relative "test_helper"

# Newsletter subscriptions (#254): no form without a backend, the form's
# markup with one (ids apart per placement, topics, the consent wording for
# double opt-in, the privacy link), the page the emails link to, and the
# settings that remove them.
class SubscriptionsTest < Minitest::Test
  SERVICES = { "base_url" => "https://api.example.org", "features" => { "subscriptions" => true } }.freeze
  FORM = %w[footer post].map { |where| "{% include components/subscribe-form.html where='#{where}' %}\n" }.join.freeze
  MANAGE = "{% include components/subscription-manage.html %}\n"

  def test_the_demo_without_a_backend_renders_no_form_and_an_honest_manage_page
    home = SiteBuilder.read("index.html")

    refute_includes home, "data-subscribe"
    assert_includes home, 'body.dataset.featureSubscriptions = "false"'

    manage = SiteBuilder.read("subscriptions/index.html")

    assert_includes manage, "Subscriptions are not set up on this site."
    refute_includes manage, "data-subscription-manage"
    assert_match(/<meta name="robots" content="noindex,follow"/, manage)
    refute_includes SiteBuilder.read("sitemap.xml"), "/subscriptions/"
  end

  def test_a_site_with_a_backend_renders_the_form_with_ids_apart_per_placement
    doc = two_forms
    forms = doc.css("section[data-subscribe]")
    footer = forms.first

    assert_equal(%w[subscribe-form-footer subscribe-form-post], forms.map { |form| form.at_css("form")["id"] })
    assert_equal doc.css("[id]").map { |node| node["id"] }.uniq.size, doc.css("[id]").size, "no id twice"
    # The footer is rendered once for every page: its form says nothing of the page.
    assert_equal [nil, nil, "true"],
                 [footer["data-subscribe-source"], footer["data-subscribe-locale"],
                  footer["data-subscribe-double-opt-in"]]
    assert_equal ["https://example.org/", "en"],
                 [forms.last["data-subscribe-source"], forms.last["data-subscribe-locale"]]
    assert_nil footer["aria-labelledby"], "two same-named landmarks on a post otherwise"
    assert_equal "Subscribe for updates", footer.at_css("h3.subscribe__heading").text
    assert forms.last.at_css("h2.subscribe__heading"), "a section heading outside the footer"
  end

  def test_the_form_asks_for_an_address_and_topics_and_states_the_consent
    footer = two_forms.at_css("section[data-subscribe]")

    assert footer.at_css("input[name=email][type=email][required][autocomplete=email]")
    assert_equal(%w[new-articles datasets], footer.css("input[name=topics][checked]").map { |box| box["value"] })
    assert_includes footer.at_css(".subscribe__topics").text, "New articles"
    assert footer.at_css(".service-form__trap input[name=website][tabindex='-1']")
    privacy = footer.at_css(".service-form__privacy")

    assert_includes privacy.text, "asking you to confirm"
    assert_equal "/privacy/", privacy.at_css("a")["href"]
    labels = JSON.parse(footer.at_css("script[data-subscribe-labels]").text)

    assert_includes labels["pending"], "Check your inbox"
    assert_equal "This address is already subscribed.", labels["duplicate"]
  end

  def test_single_opt_in_no_topics_and_another_language
    doc = render(FORM, "dynamic_services" => SERVICES, "subscriptions" => { "double_opt_in" => false })
    form = doc.at_css("[data-subscribe]")

    assert_equal "false", form["data-subscribe-double-opt-in"]
    assert_nil form.at_css("[name=topics]"), "no topics configured, no fieldset"
    refute_includes form.at_css(".service-form__privacy").text, "asking you to confirm"
    assert_nil form.at_css(".service-form__privacy a"), "no privacy_url, no link"

    pt = render(FORM, { "dynamic_services" => SERVICES, "subscriptions" => { "topics" => %w[datasets] } }, "lang: pt\n")

    assert_equal "pt", pt.css("[data-subscribe]").last["data-subscribe-locale"]
    assert_includes pt.at_css(".subscribe__topics").text, "Conjuntos de dados"
  end

  def test_the_manage_page_offers_the_three_flows
    doc = render(MANAGE, "dynamic_services" => SERVICES, "subscriptions" => { "topics" => %w[new-articles datasets] })
    root = doc.at_css("section[data-subscription-manage]")

    assert_equal %w[idle false], [root["data-state"], root["aria-busy"]]
    assert root.at_css("[data-manage-status][role=status][aria-live=polite][hidden]")
    assert_includes root.at_css("[data-manage-idle]").text, "link in one of the emails"
    assert root.at_css("[data-manage-unsubscribe-panel][hidden] button[data-manage-unsubscribe]")
    preferences = root.at_css("form[data-manage-preferences][hidden]")

    assert_equal(%w[new-articles datasets], preferences.css("input[name=topics]").map { |box| box["value"] })
    assert_empty preferences.css("input[name=topics][checked]"), "the service says which are ticked"
    assert preferences.at_css("button[type=submit]")
    labels = JSON.parse(root.at_css("script[data-manage-labels]").text)

    assert_includes labels["invalid_link"], "not valid any more"
  end

  def test_the_settings_remove_the_form
    off = SERVICES.merge("features" => { "subscriptions" => false })

    assert_nil render(FORM, "dynamic_services" => off).at_css("[data-subscribe]"), "the feature off in the services"
    assert_nil render(FORM, "dynamic_services" => SERVICES,
                            "subscriptions" => { "enabled" => false }).at_css("[data-subscribe]")
    assert_nil render(FORM, {}).at_css("[data-subscribe]"), "no backend, no form"
    assert_includes render(MANAGE, {}).text, "not set up"
  end

  private

  # The footer's and a post's form on one page, with topics and a privacy page.
  def two_forms
    render(FORM, "dynamic_services" => SERVICES,
                 "subscriptions" => { "topics" => %w[new-articles datasets], "privacy_url" => "/privacy/" })
  end

  def render(body, config, front_matter = "")
    TestSite.build(config.merge(title: "Subscriptions")) do |source|
      source.theme("_includes/components/subscribe-form.html",
                   "_includes/components/subscription-manage.html", "_data/i18n")
      source.page("index.html", body, "layout: null\ntitle: Paper\n#{front_matter}")
    end.html("index.html")
  end
end
