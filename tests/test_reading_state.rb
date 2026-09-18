# frozen_string_literal: true

require "nokogiri"
require "tmpdir"
require_relative "test_helper"

# Local reading state (#260): the markup a post and the saved-articles page
# carry for assets/js/reading-state, the settings that remove it, and the
# bundle's wiring (manifest, loader flag, preload).
class ReadingStateTest < Minitest::Test
  POST = "2024/04/05/sql-optimization-guide/index.html"

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_a_post_carries_the_bookmark_the_panel_and_the_toolbar
    doc = Nokogiri::HTML5.fragment(SiteBuilder.read(POST))
    bookmark = doc.at_css("[data-bookmark-toggle]")
    root = doc.at_css("[data-reading-state]")

    assert_equal ["false", "/2024/04/05/sql-optimization-guide/"], [bookmark["aria-pressed"], bookmark["data-article"]]
    assert_equal "Save for later", bookmark.text.strip
    assert_equal "/saved/", doc.at_css(".post-tools a.post-tool--link")["href"]
    assert_equal ["/2024/04/05/sql-optimization-guide/", "true", "true"],
                 [root["data-article"], root["data-progress"], root["data-highlights"]]
    assert root.at_css("[data-reading-resume][hidden]"), "the resume prompt is hidden until there is a position"
    assert root.at_css("[data-reading-toolbar][role=toolbar][hidden]"),
           "the toolbar is hidden until there is a selection"
    assert_equal "Your private highlights", root.at_css("#reading-notes-heading").text
    assert_includes root.at_css(".reading-notes__intro").text, "never sent anywhere"
    assert root.at_css("template[data-reading-item-template] [data-annotation-note]")
    %w[data-reading-export data-reading-import data-reading-erase-article data-reading-erase-all].each do |control|
      assert root.at_css("[#{control}]"), "#{control} is offered"
    end
    assert_equal "", root.at_css("[data-reading-status][aria-live=polite]").text
  end

  def test_the_saved_page_lists_the_reader_s_articles
    doc = Nokogiri::HTML5.fragment(SiteBuilder.read("saved/index.html"))
    list = doc.at_css("[data-reading-list]")

    assert_equal "{{percent}}% read", list["data-progress-label"]
    assert list.at_css("[data-reading-list-items]")
    assert list.at_css("[data-reading-erase-all][data-confirm]")
    assert_nil list.at_css("[data-reading-erase-article]"), "the list has no single article to erase"
  end

  def test_the_manifest_the_flag_and_the_preload_name_the_bundle
    manifest = JSON.parse(File.read(File.join(SiteBuilder.root, "_data", "js_manifest.json")))
    post = SiteBuilder.read(POST)

    assert_equal "/assets/js/dist/reading-state.js", manifest.dig("features", "reading-state")
    assert File.exist?(File.join(SiteBuilder.root, "assets", "js", "dist", "reading-state.js")), "the bundle is built"
    assert_includes post, 'body.dataset.featureReadingState = "auto"'
    assert_match(%r{rel="modulepreload"[^>]*/reading-state\.js}, post)
    assert_match(%r{rel="modulepreload"[^>]*/reading-state\.js}, SiteBuilder.read("saved/index.html"))
    refute_match(%r{rel="modulepreload"[^>]*/reading-state\.js}, SiteBuilder.read("index.html"))
  end

  def test_the_settings_remove_the_layer_or_its_parts
    assert_nil render("enabled" => false).at_css("[data-reading-state], [data-bookmark-toggle]")
    without_bookmarks = render("bookmarks" => false)
    assert_nil without_bookmarks.at_css("[data-bookmark-toggle]")
    assert without_bookmarks.at_css("[data-reading-state]")

    without_highlights = render("highlights" => false, "progress" => false)
    root = without_highlights.at_css("[data-reading-state]")
    assert_equal %w[false false], [root["data-progress"], root["data-highlights"]]
    assert_nil root.at_css("[data-reading-toolbar]")
    assert_nil root.at_css("[data-reading-resume]")
    assert_equal "Your reading data", root.at_css("#reading-notes-heading").text
    assert root.at_css("[data-reading-erase-all]"), "the data controls stay"

    assert_nil render({}).at_css(".post-tool--link"), "no link without a list page"
  end

  def test_labels_follow_the_page_language
    doc = render({}, "pt")

    assert_equal "Guardar para depois", doc.at_css("[data-bookmark-label]").text
    assert_equal "Os seus destaques privados", doc.at_css("#reading-notes-heading").text
  end

  private

  # A page holding the bookmark and the panel, under the given reading_state settings.
  def render(settings, lang = nil)
    FileUtils.mkdir_p(File.join(@dir, "_includes", "components"))
    FileUtils.mkdir_p(File.join(@dir, "_data"))
    %w[reading-state-bookmark reading-state-panel].each do |name|
      FileUtils.cp(File.join(SiteBuilder.root, "_includes", "components", "#{name}.html"),
                   File.join(@dir, "_includes", "components", "#{name}.html"))
    end
    FileUtils.cp_r(File.join(SiteBuilder.root, "_data", "i18n"), File.join(@dir, "_data"))
    front_matter = { "layout" => nil, "title" => "Paper", "lang" => lang }.compact.to_yaml
    body = "{% include components/reading-state-bookmark.html %}{% include components/reading-state-panel.html %}"
    File.write(File.join(@dir, "index.html"), "#{front_matter}---\n\n#{body}\n")
    config = Jekyll.configuration(
      "source" => @dir, "destination" => File.join(@dir, "_site"), "quiet" => true, "title" => "Reading",
      "url" => "https://example.org", "author" => { "name" => "Test" },
      "theme_options" => { "reading_state" => settings }
    )
    Jekyll::Site.new(config).process
    Nokogiri::HTML5.fragment(File.read(File.join(@dir, "_site", "index.html")))
  end
end
