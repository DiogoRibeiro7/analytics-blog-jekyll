# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/test_site"
require "json"
require "nokogiri"

# The heading _includes/layouts/default/article.html writes above every
# layout built on the default one. It repeated a post's date and author above
# the post's own, put a summary taken from the first paragraph ("Installation",
# "Key artifacts"), the time of the build as "Published" and a byline above the
# package, dataset, project, notebook and home pages' own headers, and made
# every page a ScholarlyArticle in microdata whatever its JSON-LD said (#411).
class ArticleScaffoldTest < Minitest::Test
  OWN_HEADERS = %w[index.html packages/statflow/index.html datasets/sample-dataset/index.html
                   notebooks/sample-analysis/index.html portfolio/exploratory-energy-insights/index.html].freeze
  UNDATED = %w[packages/statflow/index.html datasets/sample-dataset/index.html notebooks/sample-analysis/index.html
               portfolio/exploratory-energy-insights/index.html].freeze
  POST = "2024/04/03/r-statistical-analysis-visualizations/index.html"

  def rendered_page(basename)
    page = SiteBuilder.site.pages.find { |candidate| candidate.relative_path.end_with?(basename) }
    refute_nil page, "expected the demo page #{basename}"
    Nokogiri::HTML5(SiteBuilder.read(File.join(page.url, "index.html")))
  end

  def document(path)
    Nokogiri::HTML5(SiteBuilder.read(path))
  end

  def test_pages_show_the_site_author_by_default_labelled
    meta = rendered_page("about.md").at_css("header.article-header .article-meta")

    refute_nil meta
    assert_equal(["Author"], meta.css("dt").map { |term| term.text.strip })
    assert_includes meta.at_css("dd").text, "Diogo Ribeiro"
    assert_empty meta.css("[itemprop]"), "the byline belongs to no microdata item"
  end

  def test_show_author_false_hides_the_byline
    page = rendered_page("privacy.md")
    assert_nil page.at_css("header.article-header .author-list"), "show_author: false removes the byline"
    refute_nil page.at_css("h1.article-title"), "the title must still render"
  end

  # The post's own row has its date and author; the heading has the title and
  # the summary its author wrote, not the first paragraph again.
  def test_a_post_shows_its_date_and_author_once
    page = document(POST)
    header = page.at_css("header.article-header")
    summary = header.at_css(".article-summary").text.strip

    assert_nil header.at_css(".article-meta")
    assert_equal 1, page.css(".post-meta-list").size
    assert_equal "Fit hierarchical models in R, visualize partial pooling with ggplot2, and highlight reproducible " \
                 "figure exports.", summary
    refute_equal page.at_css(".article-body p").text.strip, summary
  end

  def test_layouts_with_their_own_header_get_nothing_above_it
    OWN_HEADERS.each do |path|
      assert_nil document(path).at_css("header.article-header"), "#{path} has a header of its own"
    end
  end

  # The JSON-LD describes each page; microdata comes only from a layout's own
  # item, which for a post now carries its headline itself.
  def test_no_page_is_a_scholarly_article_around_its_content
    Dir.glob("**/*.html", base: SiteBuilder.destination).each do |path|
      article = document(path).at_css("article.content-block")
      next unless article

      assert_nil article["itemscope"], "#{path} wraps its content in a microdata item"
    end
    post = document(POST).at_css('.post-wrapper[itemtype="https://schema.org/TechArticle"]')
    assert_equal "Multilevel Modeling in R with ggplot2 Diagnostics",
                 post.at_css('meta[itemprop="headline"]')["content"]
  end

  # Jekyll gives an undated document the build's time; it is no publication date.
  def test_an_undated_document_is_published_at_no_date
    UNDATED.each do |path|
      page = document(path)
      dates = page.css('script[type="application/ld+json"]').map { |node| JSON.parse(node.text) }
                  .filter_map { |block| block["datePublished"] }
      assert_empty dates, "#{path} is published at the build's time"
      assert_nil page.at_css('meta[name="citation_publication_date"], meta[name="DC.date"]'), path
    end

    notebook = document("notebooks/sample-analysis/index.html").at_css(".notebook-article__meta").text
    refute_includes notebook, "Published", "the notebook records no time, and the checkout's is not one"
    refute_includes notebook, "Executed"
    assert_includes notebook, "Last updated"
  end

  def test_published_date_tells_a_real_date_from_the_builds
    build = Time.utc(2026, 10, 2, 12, 0, 0)

    assert_nil Datalog::PageDates.published({ "date" => build }, build)
    assert_nil Datalog::PageDates.published({}, build)
    assert_equal Date.new(2024, 4, 3), Datalog::PageDates.published({ "date" => Date.new(2024, 4, 3) }, build)
    assert_equal "2024-04-03", Datalog::PageDates.published({ "date" => "2024-04-03" }, build)
    assert_nil Datalog::PageDates.published({ "date" => "not a date" }, build)
  end

  # The research layout renders its own <h1>; the scaffold wrote a second.
  def test_a_research_article_has_one_heading
    site = TestSite.build do |source|
      source.theme("_layouts", "_includes", "_data")
      source.page("paper.md", "Body.", "layout: research\ntitle: A study\ndate: 2025-01-02\n")
    end
    page = site.document("paper.html")

    assert_equal(["A study"], page.css("h1").map { |heading| heading.text.strip })
    assert_nil page.at_css(".article-meta")
  end

  def test_footer_explore_column_reads_navigation_footer
    html = SiteBuilder.read("index.html")
    start = html.index('<nav class="footer-navigation"')
    footer = html[start..html.index("</nav>", start)]
    links = footer.scan(%r{<a href="([^"]+)">}).flatten
    expected = (SiteBuilder.site.data.dig("navigation", "footer") || []).map { |item| item["url"] }
    if expected.empty?
      assert_includes links, "/blog/", "without navigation.footer the demo sections are listed"
    else
      assert_equal expected, links
    end
  end
end
