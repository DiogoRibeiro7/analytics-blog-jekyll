# frozen_string_literal: true

require "jekyll"

module Datalog
  # Gives sites that install the theme the two pages search needs.
  #
  # A theme gem can ship layouts, includes, sass and assets, but not pages: a
  # site's pages come from its own source directory. The theme therefore
  # shipped the search interface and its JavaScript while the page that renders
  # it and the page that builds its index stayed behind in this repository, so
  # search was missing entirely from every site using the gem.
  #
  # Both are generated here from the shipped includes, for any site with
  # `features.search` enabled that has not already defined them itself.
  class SearchPages < Jekyll::Generator
    safe true
    priority :low

    INDEX_URL = "/search.json"
    PAGE_URL = "/search/"

    def generate(site)
      return unless search_enabled?(site)

      add_index(site) unless defines?(site, INDEX_URL)
      add_page(site) unless defines?(site, PAGE_URL)
    end

    private

    def search_enabled?(site)
      features = site.config["features"]
      features.is_a?(Hash) && features["search"]
    end

    # A site that ships its own search page or index keeps it untouched.
    def defines?(site, url)
      site.pages.any? { |page| page.url == url }
    end

    def add_index(site)
      page = Jekyll::PageWithoutAFile.new(site, site.source, "", "search.json")
      page.content = "{% include search/index-data.json %}"
      page.data.merge!(
        "layout" => nil,
        "permalink" => INDEX_URL,
        "sitemap" => false
      )
      site.pages << page
    end

    def add_page(site)
      search_config = site.config["search"]
      search_config = {} unless search_config.is_a?(Hash)

      page = Jekyll::PageWithoutAFile.new(site, site.source, "search", "index.html")
      page.content = "{% include search/page.html %}"
      page.data.merge!(
        "layout" => search_config["layout"] || "page",
        "title" => search_config["title"] || "Search",
        "permalink" => PAGE_URL,
        "page_classes" => "search-page",
        # Results can contain LaTeX and code, so both engines are wanted here
        # even when the rest of the site loads them only where they appear.
        "math" => true,
        "syntax_highlighting" => true
      )
      page.data["subtitle"] = search_config["subtitle"] if search_config["subtitle"]
      site.pages << page
    end
  end
end
