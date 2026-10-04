# frozen_string_literal: true

require_relative "test_helper"

# Article reactions (#255): the strip a post carries on a site with a
# backend, the set of reactions and their labels, the counts setting, and
# the settings and front matter that remove it. No count is ever rendered
# here: the script fills them from the service.
class ReactionsTest < Minitest::Test
  SERVICES = { "base_url" => "https://api.example.org", "features" => { "reactions" => true } }.freeze

  def test_the_demo_without_a_backend_renders_no_strip
    html = SiteBuilder.read("2024/04/05/sql-optimization-guide/index.html")

    refute_includes html, "data-reactions"
    assert_includes html, 'body.dataset.featureReactions = "false"'
    refute_match(%r{rel="modulepreload"[^>]*/reactions\.js}, html)
  end

  def test_a_site_with_a_backend_renders_the_strip_without_any_count
    doc = render("dynamic_services" => SERVICES)
    root = doc.at_css("section[data-reactions]")

    assert_equal ["/", "true", "idle", "false"],
                 [root["data-reactions-path"], root["data-reactions-counts"], root["data-state"], root["aria-busy"]]
    assert_equal "Was this useful?", root.at_css("#reactions-prompt").text
    assert root.at_css("[role=group][aria-labelledby=reactions-prompt]")
    buttons = root.css("button[data-reaction]")

    assert_equal(%w[useful clear interesting needs-clarification], buttons.map { |button| button["data-reaction"] })
    assert_equal(%w[Useful Clear Interesting] << "Needs clarification", buttons.map do |b|
      b.at_css(".reactions__label").text
    end)
    assert(buttons.all? { |button| button["aria-pressed"] == "false" && button["type"] == "button" })
    assert buttons.all? { |button|
      button.at_css("[data-reaction-count][hidden]").text.empty?
    }, "no count in the markup"
    assert root.at_css("[data-reactions-status][role=status][aria-live=polite][hidden]")
    labels = JSON.parse(root.at_css("script[data-reactions-labels]").text)

    assert_equal "Thank you. Your feedback was counted.", labels["thanks"]
    assert_includes labels["errors"]["conflict"], "already"
  end

  def test_the_types_and_the_counts_setting_are_configurable_and_localized
    doc = render("dynamic_services" => SERVICES,
                 "reactions" => { "types" => %w[useful needs-clarification], "counts" => false })

    assert_equal(%w[useful needs-clarification], doc.css("button[data-reaction]").map do |button|
      button["data-reaction"]
    end)
    assert_equal "false", doc.at_css("[data-reactions]")["data-reactions-counts"]

    pt = render({ "dynamic_services" => SERVICES }, "lang: pt\n")

    assert_equal "Foi útil?", pt.at_css("#reactions-prompt").text
    assert_equal "Útil", pt.at_css("button[data-reaction=useful] .reactions__label").text
  end

  def test_the_settings_and_the_page_can_remove_the_strip
    off = SERVICES.merge("features" => { "reactions" => false })

    assert_nil render("dynamic_services" => off).at_css("[data-reactions]"), "the feature off in the services"
    assert_nil render("dynamic_services" => SERVICES, "reactions" => { "enabled" => false }).at_css("[data-reactions]")
    assert_nil render({ "dynamic_services" => SERVICES }, "reactions: false\n").at_css("[data-reactions]"),
               "the page opts out"
    assert_nil render({}).at_css("[data-reactions]"), "no backend, no strip"
  end

  private

  # A page holding the strip, under the given site configuration and front matter.
  def render(config, front_matter = "")
    TestSite.build(config.merge(title: "Reactions")) do |source|
      source.theme("_includes/components/reactions.html", "_data/i18n")
      source.page("index.html", "{% include components/reactions.html %}",
                  "layout: null\ntitle: Paper\n#{front_matter}")
    end.html("index.html")
  end
end
