# frozen_string_literal: true

require_relative "test_helper"

# Four things the axe scans of a post with a table of contents, code blocks
# and equation references turned up: the contents' landmark, its colours, the
# layout of a post that has no contents, and the colours of code.
class TocAndContrastTest < Minitest::Test
  POST_WITH_TOC = "2024/04/05/sql-optimization-guide/index.html"
  LIGHT_CODE = "#f6f6f5"   # rgba($color-surface-900, 0.02) over the page
  DARK_CODE = "#272727"    # rgba($dark-surface-300, 0.8) over the page

  def test_the_table_of_contents_is_a_nav_with_the_doc_toc_role
    html = SiteBuilder.read(POST_WITH_TOC)

    assert_match(/<nav class="enhanced-toc[^>]*role="doc-toc"/m, html)
    refute_includes html, '<aside class="enhanced-toc'
  end

  def test_a_post_without_contents_spans_the_wrapper
    assert rule?(%r{\.post-body-wrapper>\.post-content:first-child\{grid-column:1\s*/\s*-1\}}),
           "the article alone in the wrapper should span both columns"

    html = SiteBuilder.read("2024/01/01/introducing-datalog/index.html")

    refute_includes html, "enhanced-toc", "the demo's first post has no headings, so no contents"
    assert_match(/<div class="post-body-wrapper">\s*<div class="post-content"/, html)
  end

  def test_the_contents_use_readable_inks
    assert rule?(/\.is-active\{color:var\(--color-accent-text/), "the active entry uses the accent as text"
    assert rule?(/--color-accent-text:\s*#1d4ed8/), "the light theme defines the accent as text"
    assert rule?(/--color-accent-text:\s*#60a5fa/), "and so does the dark one"
    assert rule?(/\.enhanced-toc__stats\{[^}]*color:var\(--color-text-secondary/),
           "the progress line uses the secondary ink"
    assert_operator contrast("#1d4ed8", "#e0e6f0"), :>=, 4.5
  end

  def test_every_code_token_is_readable_on_the_code_background
    tokens = stylesheet.scan(/([^{}]+)\{([^{}]*)\}/).filter_map do |selectors, body|
      color = body[/(?:^|;)color:(#[0-9a-f]{3,6})\b/i, 1]
      list = selectors.split(",")
      next unless color && list.all? { |selector| selector.match?(/\.highlight \.[a-z0-9]+\z/) }

      [list, color, list.all? { |selector| selector.start_with?("body.dark-mode ") }]
    end

    refute_empty tokens, "expected the syntax rules in the stylesheet"
    tokens.each do |selectors, color, dark|
      ratio = contrast(color, dark ? DARK_CODE : LIGHT_CODE)

      assert_operator ratio, :>=, 4.5, "#{selectors.first} is #{color}: #{ratio.round(2)}:1 on the code background"
    end
  end

  private

  def stylesheet
    SiteBuilder.build
    File.read(SiteBuilder.destination_path("assets/css/main.css"))
  end

  # Whether the stylesheet has the rule, without a failure printing all of it.
  def rule?(pattern)
    stylesheet.match?(pattern)
  end

  def contrast(one, other)
    lighter, darker = [luminance(one), luminance(other)].sort.reverse
    (lighter + 0.05) / (darker + 0.05)
  end

  def luminance(hex)
    digits = hex.delete("#")
    digits = digits.chars.map { |char| char * 2 }.join if digits.size == 3
    red, green, blue = digits.scan(/../).map do |pair|
      channel = pair.to_i(16) / 255.0
      channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end
    (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
  end
end
