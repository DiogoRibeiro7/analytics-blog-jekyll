# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "jekyll"

require_relative "../_plugins/search_pages"

# A theme gem cannot ship pages, so sites installing the theme had the search
# interface and its JavaScript but neither the page that renders it nor the one
# that builds its index. The generator supplies both.
class SearchPagesTest < Minitest::Test
  def test_generates_both_pages_when_search_is_enabled
    with_site("features" => { "search" => true }) do |site|
      generate(site)
      urls = site.pages.map(&:url)

      assert_includes urls, "/search.json", "sites with search enabled need an index"
      assert_includes urls, "/search/", "sites with search enabled need a search page"

      index = site.pages.find { |page| page.url == "/search.json" }
      assert_equal "{% include search/index-data.json %}", index.content
      refute index.data["sitemap"], "the index should stay out of the sitemap"

      page = site.pages.find { |page| page.url == "/search/" }
      assert_equal "{% include search/page.html %}", page.content
      assert page.data["math"], "search results can contain LaTeX"
    end
  end

  def test_generates_nothing_when_search_is_disabled
    with_site("features" => { "search" => false }) do |site|
      generate(site)

      assert_empty site.pages.map(&:url)
    end
  end

  def test_generates_nothing_when_features_are_absent
    with_site({}) do |site|
      generate(site)

      assert_empty site.pages.map(&:url)
    end
  end

  # A site that ships its own search page keeps it: the generator fills a gap
  # rather than overriding a choice.
  def test_leaves_a_site_that_defines_its_own_pages_alone
    with_site("features" => { "search" => true }) do |site|
      existing = Jekyll::PageWithoutAFile.new(site, site.source, "", "search.json")
      existing.data["permalink"] = "/search.json"
      existing.content = "custom"
      site.pages << existing

      generate(site)

      indexes = site.pages.select { |page| page.url == "/search.json" }
      assert_equal 1, indexes.size, "the generator should not add a second index"
      assert_equal "custom", indexes.first.content
    end
  end

  private

  def generate(site)
    Datalog::SearchPages.new(site.config).generate(site)
  end

  def with_site(overrides)
    Dir.mktmpdir do |dir|
      config = Jekyll.configuration(
        "source" => dir,
        "destination" => File.join(dir, "_site"),
        "quiet" => true
      ).merge(overrides)

      site = Jekyll::Site.new(config)
      site.read

      yield site
    end
  end
end
