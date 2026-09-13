# frozen_string_literal: true

require_relative "test_helper"

# MathJax and the search bundle used to load on pages that had no use for
# them: MathJax wherever a `$` appeared, even inside a script, and the search
# bundle on every page, because the header has a search form.
class FeatureLoadingTest < Minitest::Test
  def test_loads_mathjax_where_the_page_has_math
    {
      "2024/01/01/introducing-datalog/index.html" => "a post with math",
      "notebooks/sample-analysis/index.html" => "a notebook page with math"
    }.each do |page, description|
      assert_includes SiteBuilder.read(page), 'id="mathjax-script"', "#{description} should load MathJax"
    end
  end

  def test_leaves_mathjax_out_where_the_page_has_none
    {
      "2024/04/05/sql-optimization-guide/index.html" => "a post without math",
      "portfolio/sample-project/index.html" => "a page whose only dollar signs are in a script"
    }.each do |page, description|
      html = SiteBuilder.read(page)
      refute_includes html, 'id="mathjax-script"', "#{description} should not load MathJax"
      refute_match(%r{rel="modulepreload"[^>]*/math\.js}, html, "#{description} should not preload the math bundle")
    end
  end

  def test_preloads_the_search_bundle_only_on_the_search_page
    refute_match(%r{rel="modulepreload"[^>]*/search\.js}, SiteBuilder.read("index.html"))
    assert_match(%r{rel="modulepreload"[^>]*/search\.js}, SiteBuilder.read("search/index.html"))
  end
end
