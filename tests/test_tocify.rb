# frozen_string_literal: true

require_relative "test_helper"
require_relative "../_plugins/toc_filter"

class TocifyFilterTest < Minitest::Test
  def setup
    @filter = Object.new
    @filter.extend(Jekyll::TocifyFilter)
  end

  def test_builds_nested_lists_from_headings
    html = '<h2 id="one">One</h2><p>x</p><h3 id="one-a">One A</h3><h3 id="one-b">One B</h3><h2 id="two">Two</h2>'
    expected = '<ul class="toc-list">' \
               '<li class="toc-item toc-level-2"><a href="#one">One</a>' \
               '<ul><li class="toc-item toc-level-3"><a href="#one-a">One A</a></li>' \
               '<li class="toc-item toc-level-3"><a href="#one-b">One B</a></li></ul></li>' \
               '<li class="toc-item toc-level-2"><a href="#two">Two</a></li></ul>'
    assert_equal expected, @filter.tocify(html, 2, 4)
  end

  def test_respects_the_level_range
    html = '<h1 id="t">Title</h1><h2 id="a">A</h2><h4 id="deep">Deep</h4><h5 id="deeper">Deeper</h5>'
    out = @filter.tocify(html, 2, 4)
    refute_includes out, "#t"
    assert_includes out, "#deep"
    refute_includes out, "#deeper"
  end

  def test_slugifies_headings_without_ids_and_escapes_text
    out = @filter.tocify("<h2>Bias &amp; Variance</h2>", 2, 3)
    assert_includes out, 'href="#bias-variance"'
    assert_includes out, "Bias &amp; Variance</a>"
  end

  def test_returns_empty_string_without_headings
    assert_equal "", @filter.tocify("<p>No headings here</p>", 2, 4)
    assert_equal "", @filter.tocify(nil, 2, 4)
  end

  def test_rendered_post_toc_lists_headings_not_content
    html = SiteBuilder.read(File.join(SiteBuilder.site.posts.docs.find { |doc| doc.data["title"] == "Python Data Wrangling Foundations" }.url, "index.html"))
    start = html.index('<aside class="enhanced-toc')
    refute_nil start, "expected the enhanced table of contents on a post with headings"
    aside = html[start...html.index("</aside>", start)]
    assert_includes aside, 'class="toc-list"'
    assert_match(%r{<a href="#[^"]+">}, aside)
    refute_includes aside, "<h2 id=", "the table of contents must list headings, not repeat the article"
    refute_includes aside, "<p>", "the table of contents must not contain article paragraphs"
  end
end
