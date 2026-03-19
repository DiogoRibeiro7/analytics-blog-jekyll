# frozen_string_literal: true

require_relative "test_helper"
require "nokogiri"

class MathAccessibilityTest < Minitest::Test
  SAMPLE_PAGE = "2024/04/08/mathematical-proof-numbered-equations/index.html"

  def setup
    @page_html = SiteBuilder.read(SAMPLE_PAGE)
    @document = Nokogiri::HTML(@page_html)
  end

  def test_math_elements_have_aria_labels
    nodes = @document.css("[data-math-alt]")
    refute_empty nodes, "Expected math nodes with data-math-alt attributes"

    nodes.each do |node|
      aria = node["aria-label"]
      assert aria && !aria.strip.empty?, "Math node should expose aria-label text"
    end
  end

  def test_comment_based_alt_text_is_preserved
    labeled = @document.at_css('[data-math-alt*="inner product equals the integral"]')
    refute_nil labeled, "Equation with explicit alt text comment should be annotated"
    assert_includes labeled["aria-label"], "inner product equals the integral"
  end

  def test_auto_alt_text_generation_for_integrals
    inline = @document.css("[data-math-alt]").find { |node| node["data-math-alt"].include?("integral from a to b") }
    refute_nil inline, "Inline integral should generate descriptive alt text"
    assert_includes inline["data-math-alt"], "integral from a to b"
  end

  def test_noscript_fallback_contains_sources
    noscript = @document.css("noscript.math-noscript").first
    refute_nil noscript, "Expected a noscript fallback block for math content"

    message = noscript.at_css("p.math-noscript__message")
    assert_equal "Enable JavaScript to render equations.", message&.text&.strip

    sources = noscript.css("pre.math-noscript__code")
    refute_empty sources, "Noscript block should list LaTeX sources"
    assert sources.any? { |pre| pre.text.include?("\\int_a^b f(x) g(x)") },
           "Noscript block should expose the original LaTeX expression"
  end
end
