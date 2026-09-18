# frozen_string_literal: true

require "nokogiri"
require "tmpdir"
require_relative "test_helper"

# Webmentions (#258): the receiver advertised in the head, the "Mentioned
# elsewhere" section a post carries on a site with a backend, the kinds it
# lists, and the settings and front matter that remove either. No mention
# is ever rendered here: the script fills the list from the service.
class WebmentionsTest < Minitest::Test
  SERVICES = { "base_url" => "https://api.example.org", "features" => { "webmentions" => true } }.freeze
  RECEIVER = "https://mentions.example.org/webmention"

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_the_demo_advertises_no_receiver_and_renders_no_section
    html = SiteBuilder.read("2024/04/05/sql-optimization-guide/index.html")

    refute_includes html, 'rel="webmention"'
    refute_includes html, "data-webmentions"
    assert_includes html, 'body.dataset.featureWebmentions = "false"'
    refute_match(%r{rel="modulepreload"[^>]*/webmentions\.js}, html)
  end

  def test_the_receiver_is_advertised_with_the_standard_link
    with = render("webmentions" => { "endpoint" => RECEIVER })

    assert_equal RECEIVER, with.at_css("link[rel=webmention]")["href"]
    assert_nil render({}).at_css("link[rel=webmention]"), "no endpoint, no discovery"
    assert_nil render("webmentions" => { "endpoint" => RECEIVER, "enabled" => false }).at_css("link[rel=webmention]")
    assert_nil render("webmentions" => { "endpoint" => "" }).at_css("link[rel=webmention]")
  end

  def test_a_site_with_a_backend_renders_the_section_without_any_mention
    doc = render("dynamic_services" => SERVICES)
    root = doc.at_css("section[data-webmentions]")

    assert_equal ["https://example.org/", "mention,reply", "idle"],
                 [root["data-webmentions-target"], root["data-webmentions-types"], root["data-state"]]
    assert_equal "Mentioned elsewhere", root.at_css("#webmentions-heading").text
    assert_includes root.at_css(".webmentions__intro").text, "not comments"
    assert_equal "Looking for mentions from other websites…", root.at_css("[data-webmentions-status][role=status]").text
    assert root.at_css("ul[data-webmentions-list][hidden]")
    assert_empty root.at_css("ul[data-webmentions-list]").children.to_a.reject(&:blank?), "no mention in the markup"
    labels = JSON.parse(root.at_css("script[data-webmentions-labels]").text)

    assert_equal "Reply", labels["types"]["reply"]
    assert_equal "No mentions from other websites yet.", labels["empty"]
  end

  def test_the_kinds_are_configurable_and_the_section_is_localized
    doc = render("dynamic_services" => SERVICES, "webmentions" => { "types" => %w[mention reply repost like] })

    assert_equal "mention,reply,repost,like", doc.at_css("[data-webmentions]")["data-webmentions-types"]

    pt = render({ "dynamic_services" => SERVICES }, "lang: pt\n")

    assert_equal "Mencionado noutros sites", pt.at_css("#webmentions-heading").text
    assert_equal "Resposta", JSON.parse(pt.at_css("script[data-webmentions-labels]").text)["types"]["reply"]
  end

  def test_the_settings_and_the_page_can_remove_the_section
    off = SERVICES.merge("features" => { "webmentions" => false })

    assert_nil render("dynamic_services" => off).at_css("[data-webmentions]"), "the feature off in the services"
    assert_nil render("dynamic_services" => SERVICES,
                      "webmentions" => { "enabled" => false }).at_css("[data-webmentions]")
    assert_nil render({ "dynamic_services" => SERVICES }, "webmentions: false\n").at_css("[data-webmentions]")
    assert_nil render({}).at_css("[data-webmentions]"), "no backend, no section"
  end

  private

  # A page holding the discovery link and the section, under the given
  # site configuration and front matter.
  def render(config, front_matter = "")
    FileUtils.mkdir_p(File.join(@dir, "_includes", "components"))
    FileUtils.mkdir_p(File.join(@dir, "_includes", "meta"))
    FileUtils.mkdir_p(File.join(@dir, "_data"))
    %w[components/webmentions.html meta/webmention-discovery.html].each do |include|
      FileUtils.cp(File.join(SiteBuilder.root, "_includes", include), File.join(@dir, "_includes", include))
    end
    FileUtils.cp_r(File.join(SiteBuilder.root, "_data", "i18n"), File.join(@dir, "_data"))
    body = "{% include meta/webmention-discovery.html %}\n{% include components/webmentions.html %}\n"
    File.write(File.join(@dir, "index.html"), "---\nlayout: null\ntitle: Paper\n#{front_matter}---\n\n#{body}")
    site_config = Jekyll.configuration(
      { "source" => @dir, "destination" => File.join(@dir, "_site"), "quiet" => true, "title" => "Mentions",
        "url" => "https://example.org", "author" => { "name" => "Test" } }.merge(config)
    )
    Jekyll::Site.new(site_config).process
    Nokogiri::HTML5.fragment(File.read(File.join(@dir, "_site", "index.html")))
  end
end
