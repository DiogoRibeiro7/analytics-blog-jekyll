# frozen_string_literal: true

require_relative "test_helper"

class MathRenderingTest < Minitest::Test
  SAMPLE_PAGE = "2024/01/01/introducing-datalog/index.html"

  def setup
    @page_html = SiteBuilder.read(SAMPLE_PAGE)
  end

  def test_mathjax_script_is_loaded
    assert_match(/id=\"mathjax-script\"/, @page_html,
                 "MathJax script tag should be present for LaTeX rendering")
    assert_match(%r{https://cdn\.jsdelivr\.net/npm/mathjax@3/}, @page_html,
                 "MathJax CDN should be referenced")
  end

  def test_math_configuration_is_available
    assert_match(/window\.MathJax\s*=\s*\{/, @page_html,
                 "MathJax global configuration should be embedded")
    assert_match(/displayMath:\s*\[\['\$\$', '\$\$'\], \['\\\\\[', '\\\\\]'\]\]/, @page_html,
                 "Display math delimiters should be configured")
  end

  def test_math_content_is_preserved
    assert_includes @page_html, "$\\int_0^1 x^2 \\mathrm{d}x = \\tfrac{1}{3}$",
                    "Inline math expressions should survive the build"
  end
end
