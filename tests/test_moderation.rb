# frozen_string_literal: true

require_relative "test_helper"

# The moderation inbox (#257): off and out of the way in the demo, the shell
# a site that turns it on gets, the API it talks to, the sign-in link, the
# endpoint in the Content Security Policy of that page only, and the build
# refusing anything named like a secret under `moderation`.
class ModerationTest < Minitest::Test
  SERVICES = { "base_url" => "https://api.example.org", "features" => { "moderation" => true } }.freeze
  INBOX = "{% include components/moderation-inbox.html %}\n"

  def test_the_demo_admin_page_is_off_out_of_the_index_and_linked_from_nowhere
    html = SiteBuilder.read("admin/moderation/index.html")

    assert_includes html, "Moderation is not set up on this site."
    refute_includes html, "data-moderation-inbox"
    assert_match(/<meta name="robots" content="noindex,nofollow"/, html)
    assert_includes html, 'body.dataset.featureModeration = "false"'
    refute_includes SiteBuilder.read("sitemap.xml"), "/admin/moderation/"
    refute_includes SiteBuilder.read("search.json"), "/admin/moderation/"
    refute_includes SiteBuilder.read("index.html"), "/admin/moderation/"
  end

  def test_a_site_that_turns_it_on_gets_the_shell
    doc = render(INBOX, "dynamic_services" => SERVICES,
                        "moderation" => { "enabled" => true, "sign_in_url" => "https://api.example.org/auth/login" })
    root = doc.at_css("section[data-moderation-inbox]")

    assert_equal ["https://example.org/", "include", "idle", nil],
                 [root["data-moderation-site"], root["data-moderation-credentials"], root["data-state"],
                  root["data-moderation-endpoint"]]
    assert_includes root.at_css(".moderation__boundary").text, "nothing here is protected by the page itself"
    assert_equal(%w[type status category path since q], root.css("[data-moderation-filters] [name]").map do |field|
      field["name"]
    end)
    assert_equal "Awaiting a decision", root.at_css("#moderation-status option").text
    assert_includes root.css("#moderation-category option").map(&:text), "Outdated or broken code"
    assert_equal "https://api.example.org/auth/login", root.at_css("[data-moderation-sign-in][hidden] a")["href"]
    assert root.at_css("ol[data-moderation-list]")
    assert_empty root.at_css("ol[data-moderation-list]").children.to_a.reject(&:blank?), "no item in the markup"
    labels = JSON.parse(root.at_css("script[data-moderation-labels]").text)

    assert_equal "Accept for editorial action", labels["actions"]["accept"]
    assert_equal "Pending", labels["statuses"]["pending"]
    assert_includes labels["unauthorized"], "not signed in"
  end

  def test_an_endpoint_of_its_own_is_enough_and_the_credentials_mode_is_configurable
    doc = render(INBOX, "moderation" => { "enabled" => true, "endpoint" => "https://moderation.example.net/",
                                          "credentials" => "same-origin" })
    root = doc.at_css("[data-moderation-inbox]")

    assert_equal ["https://moderation.example.net/", "same-origin"],
                 [root["data-moderation-endpoint"], root["data-moderation-credentials"]]
    assert_includes root.at_css("[data-moderation-sign-in]").text, "Sign in to the moderation service"
  end

  def test_it_is_off_unless_enabled_and_there_is_an_api
    off = SERVICES.merge("features" => { "moderation" => false })

    assert_nil render(INBOX, "dynamic_services" => SERVICES).at_css("[data-moderation-inbox]"), "off by default"
    assert_nil render(INBOX, "moderation" => { "enabled" => true }).at_css("[data-moderation-inbox]"), "no API"
    assert_nil render(INBOX, "dynamic_services" => off,
                             "moderation" => { "enabled" => true }).at_css("[data-moderation-inbox]")
    assert_includes render(INBOX, {}).text, "not set up"
  end

  def test_the_build_refuses_anything_named_like_a_secret_under_moderation
    errors = Datalog::PublicConfiguration.errors("moderation" => { "enabled" => true, "admin_password" => "hunter2",
                                                                   "auth" => { "api_token" => "abc" } })

    assert_equal([%w[moderation admin_password], %w[moderation auth api_token]], errors.map { |error| error[:path] })
    assert_includes errors.first[:expected], "moderation is sent to every reader's browser"
    assert_empty Datalog::PublicConfiguration.errors("moderation" => { "credentials" => "include",
                                                                       "sign_in_url" => "/x" })
  end

  def test_the_endpoint_joins_the_policy_of_the_inbox_page_only
    config = { "moderation" => { "enabled" => true, "endpoint" => "https://moderation.example.net/v1" } }

    assert_match(%r{connect-src [^;]*https://moderation\.example\.net[ ;]}, csp(config, "moderation_inbox: true\n"))
    refute_includes csp(config), "moderation.example.net"
  end

  private

  def render(body, config, front_matter = "")
    TestSite.build(config.merge(title: "Moderation")) do |source|
      source.theme("_includes/components/moderation-inbox.html", "_includes/csp-meta.html", "_data/i18n")
      source.page("index.html", body, "layout: null\ntitle: Inbox\n#{front_matter}")
    end.html("index.html")
  end

  # The policy csp-meta.html writes for a page with the given front matter.
  def csp(config, front_matter = "")
    render("{% include csp-meta.html %}\n", config, front_matter).to_html[/content="([^"]*)"/, 1].to_s
  end
end
