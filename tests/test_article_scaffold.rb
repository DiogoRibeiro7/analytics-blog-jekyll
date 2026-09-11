# frozen_string_literal: true

require_relative "test_helper"

class ArticleScaffoldTest < Minitest::Test
  def rendered_page(basename)
    page = SiteBuilder.site.pages.find { |candidate| candidate.relative_path.end_with?(basename) }
    refute_nil page, "expected the demo page #{basename}"
    SiteBuilder.read(File.join(page.url, "index.html"))
  end

  def test_pages_show_the_site_author_by_default
    html = rendered_page("about.md")
    assert_match(%r{<dd itemprop="author"[^>]*>\s*<span itemprop="name">[^<]+</span>}, html)
  end

  def test_show_author_false_hides_the_byline
    html = rendered_page("privacy.md")
    refute_match(/itemprop="author"/, html, "show_author: false must remove the byline from the article meta")
    assert_includes html, "<h1 class=\"article-title\"", "the title must still render"
  end

  def test_footer_explore_column_reads_navigation_footer
    html = SiteBuilder.read("index.html")
    footer = html[html.index('<nav class="footer-navigation">')..html.index("</nav>", html.index('<nav class="footer-navigation">'))]
    links = footer.scan(%r{<a href="([^"]+)">}).flatten
    expected = (SiteBuilder.site.data.dig("navigation", "footer") || []).map { |item| item["url"] }
    if expected.empty?
      assert_includes links, "/blog/", "without navigation.footer the demo sections are listed"
    else
      assert_equal expected, links
    end
  end
end
