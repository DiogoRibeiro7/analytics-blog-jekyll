# frozen_string_literal: true

require_relative "test_helper"

# The `api` comments provider (#253): the thread shell the plugin renders on
# a site with a backend, the settings that reach it, a page choosing the
# provider, the warning without a backend, the endpoint's origin in the
# Content Security Policy, and the demo staying on Giscus.
class CommentsApiTest < Minitest::Test
  SERVICES = { "base_url" => "https://api.example.org", "features" => { "comments" => true } }.freeze
  POST = "2024/01/01/thread/index.html"

  def test_the_api_provider_renders_the_thread_shell
    doc = build(comments: { "provider" => "api" })
    root = doc.at_css(".datalog-comments [data-comments-thread]")

    assert_equal ["/2024/01/01/thread/", "true", "idle"],
                 [root["data-comments-path"], root["data-comments-replies"], root["data-state"]]
    assert_nil root["data-comments-endpoint"]
    assert_equal "Loading the discussion…", root.at_css("[data-comments-status][role=status]").text
    assert root.at_css("ol[data-comments-list][hidden]")
    form = root.at_css("form.service-form[data-comments-form]")
    assert form.at_css("input[name=name][required]")
    assert form.at_css("input[name=email][type=email]:not([required])")
    assert form.at_css("input[name=url][type=url]")
    assert form.at_css("textarea[name=body][required]")
    assert form.at_css("input[type=hidden][name=parent_id]")
    assert form.at_css(".service-form__trap input[name=website][tabindex='-1']")
    assert_includes form.at_css(".service-form__privacy").text, "read before they appear"
    labels = JSON.parse(root.at_css("script[data-comments-labels]").text)
    assert_equal "Replying to {{name}}", labels["replying_to"]
    assert_includes labels["errors"]["unsupported"], "does not offer"
  end

  def test_the_endpoint_replies_and_moderation_settings_reach_the_markup
    doc = build(comments: { "provider" => "api", "endpoint" => "https://comments.example.net/",
                            "replies" => false, "moderation" => false })
    root = doc.at_css("[data-comments-thread]")

    assert_equal "https://comments.example.net/", root["data-comments-endpoint"]
    assert_equal "false", root["data-comments-replies"]
    assert_equal "Your email is never shown.", root.at_css(".service-form__privacy").text
  end

  def test_a_page_can_choose_the_provider_for_itself
    giscus = { "provider" => "giscus", "repo" => "o/r", "repo_id" => "R", "category" => "C", "category_id" => "I" }
    doc = build(comments: giscus, front_matter: "comments:\n  provider: api\n")

    assert doc.at_css("[data-comments-thread]"), "the page's provider wins"
    refute_includes doc.to_html, "giscus.app"
  end

  def test_without_a_backend_the_provider_warns_instead_of_rendering
    doc = build(comments: { "provider" => "api" }, services: nil)

    assert_nil doc.at_css("[data-comments-thread]")
    assert_includes doc.at_css(".datalog-comments-missing").text, "endpoint (or dynamic_services.base_url)"
  end

  def test_the_endpoint_origin_joins_the_content_security_policy
    options = { "provider" => "api", "endpoint" => "https://comments.example.net/v1" }
    policy = csp("dynamic_services" => SERVICES,
                 "datalog_plugins" => { "options" => { "datalog-comments" => options } })

    assert_match(%r{connect-src [^;]*https://api\.example\.org[^;]*https://comments\.example\.net[ ;]}, policy)

    same = csp("dynamic_services" => SERVICES,
               "datalog_plugins" => { "options" => { "datalog-comments" => { "provider" => "api" } } })

    assert_equal 1, same.scan("https://api.example.org").size, "the services origin once, nothing else"
  end

  # The demo's Giscus settings lack the ids, so its posts carry the plugin's
  # "missing settings" note; what matters here is that nothing api-shaped appears.
  def test_the_demo_keeps_giscus_and_loads_no_thread_script
    html = SiteBuilder.read("2024/04/07/data-visualization-plotly-showcase/index.html")

    assert_includes html, 'Comments provider "giscus"'
    refute_includes html, "data-comments-thread"
    assert_includes html, 'body.dataset.featureComments = "false"'
    refute_match(%r{rel="modulepreload"[^>]*/comments\.js}, html)
  end

  private

  # A site with the comments plugin on and one post that shows comments.
  def build(comments:, services: SERVICES, front_matter: "")
    config = {
      "datalog_plugins" => { "enabled" => %w[datalog-search datalog-comments],
                             "options" => { "datalog-comments" => comments } }
    }
    config["dynamic_services"] = services if services
    site_for(config) do |source|
      source.theme("_includes/components/comments-thread.html", "_data/i18n")
      source.layout("post.html", "{{ content }}\n{% if page.datalog_comments %}{% datalog_comments %}{% endif %}\n")
      source.post("2024-01-01-thread", "Hello.", "layout: post\ntitle: Thread\ncomments: true\n#{front_matter}")
    end.html(POST)
  end

  # The policy csp-meta.html writes for a page under the given configuration.
  def csp(config)
    html = site_for(config) do |source|
      source.theme("_includes/csp-meta.html")
      source.page("index.html", "{% include csp-meta.html %}", "layout: null\ntitle: Policy\n")
    end.read("index.html")
    html[/content="([^"]*)"/, 1].to_s
  end

  def site_for(config, &)
    TestSite.build({ title: "Comments", permalink: "/:year/:month/:day/:title/" }.merge(config), &)
  end
end
