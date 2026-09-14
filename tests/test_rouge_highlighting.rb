# frozen_string_literal: true

require_relative "test_helper"
require "nokogiri"

# Code used to be highlighted twice: by Rouge as the site built, then by Prism
# in the browser, which replaced Rouge's markup and left every language it had
# no grammar for as plain text. Rouge now does it alone.
class RougeHighlightingTest < Minitest::Test
  def test_highlights_code_in_a_language_rouge_knows
    html = highlight("def mean(values):\n    return sum(values)", "python")
    fragment = Nokogiri::HTML::DocumentFragment.parse(html)

    assert_equal "def", fragment.at_css("span.k")&.text
    assert_equal "def mean(values):\n    return sum(values)", fragment.text
  end

  def test_escapes_code_and_falls_back_to_plain_text
    html = highlight("<script>alert(1)</script>", "not-a-language")

    refute_includes html, "<script>"
    assert_equal "<script>alert(1)</script>", Nokogiri::HTML::DocumentFragment.parse(html).text
  end

  def test_returns_nothing_for_no_code
    assert_equal "", highlight(nil, "python")
  end

  def test_code_pages_load_no_prism
    html = SiteBuilder.read("2024/04/05/sql-optimization-guide/index.html")

    refute_includes html, "prismjs"
    assert Nokogiri::HTML5(html).at_css(".highlighter-rouge .rouge-code span.k"),
           "kramdown should still highlight the SQL blocks with Rouge"
  end

  # Prism made every code block focusable, so a keyboard user could scroll a
  # wide one; axe reports a scrollable region that cannot take focus.
  def test_code_blocks_can_take_focus
    {
      "2024/04/05/sql-optimization-guide/index.html" => ".highlighter-rouge pre.highlight",
      "packages/statflow/index.html" => ".api-function__examples pre.highlight",
      "notebooks/sample-analysis/index.html" => ".notebook-cell pre.highlight"
    }.each do |page, selector|
      blocks = Nokogiri::HTML5(SiteBuilder.read(page)).css(selector)
      refute_empty blocks, "#{page} should have code blocks matching #{selector}"
      blocks.each { |block| assert_equal "0", block["tabindex"], "#{page}: #{selector} should take focus" }
    end
  end

  def test_package_api_examples_are_highlighted_as_the_site_builds
    doc = Nokogiri::HTML5(SiteBuilder.read("packages/statflow/index.html"))
    example = doc.at_css(".api-function__examples pre.highlight code.language-python")

    refute_nil example, "The statflow page should render a Python API example"
    refute_empty example.css("span[class]"), "The example should carry Rouge's token markup"
  end

  def test_stylesheet_styles_rouge_tokens_and_line_numbers
    css = SiteBuilder.read("assets/css/main.css")

    assert_match(/\.highlight \.k\b/, css)
    assert_match(/\.highlight \.rouge-gutter/, css)
    refute_match(/\.token\./, css, "Prism's token classes should be gone from the stylesheet")
  end

  private

  def highlight(code, language)
    SiteBuilder.site
    Object.new.extend(Jekyll::RougeHighlightFilter).rouge_highlight(code, language)
  end
end
