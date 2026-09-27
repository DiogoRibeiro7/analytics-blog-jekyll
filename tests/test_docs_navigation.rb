# frozen_string_literal: true

require_relative "test_helper"

class DocsNavigationTest < Minitest::Test
  def test_docs_guides_search_and_project_paths
    Dir.mktmpdir("datalog-docs") do |dir|
      source = File.join(SiteBuilder.root, "docs/site")
      config = Jekyll.configuration(
        "source" => source,
        "destination" => File.join(dir, "site"),
        "config" => [File.join(source, "_config.yml")],
        "baseurl" => "/preview",
        "quiet" => true
      )
      Jekyll::Site.new(config).process

      html = Nokogiri::HTML5(File.read(File.join(dir, "site/guides/installation/index.html")))
      assert_equal "/preview/guides/installation/", html.at_css('.docs-sidebar [aria-current="page"]')["href"]
      assert_equal "/preview/search/", html.at_css('form.site-search')["action"]
      assert_equal "/preview/guides/configuration/", html.at_css('.docs-pagination a:last-child')["href"]
      assert html.at_css('.docs-on-this-page a[href="#requirements"]'), "guide contents should link to a real heading"
      assert html.at_css('.docs-content h2#requirements'), "the contents target should exist"
      assert html.at_css('.docs-sidebar__repo[href*="analytics-blog-jekyll"]')

      assert File.exist?(File.join(dir, "site/search/index.html")), "search page should be generated"
      index = JSON.parse(File.read(File.join(dir, "site/search.json")))
      assert_includes index.to_s, "Install DataLog", "the guide should be discoverable in search"
    end
  end
end
