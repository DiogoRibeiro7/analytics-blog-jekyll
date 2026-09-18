# frozen_string_literal: true

require_relative "test_helper"

# MathJax and the search bundle used to load on pages that had no use for
# them: MathJax wherever a `$` appeared, even inside a script, and the search
# bundle on every page, because the header has a search form. Every page also
# inlined data that only the academic pages read, and requested the feature
# bundles it uses only after the core bundle had loaded.
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

  def test_preloads_the_feature_bundles_a_page_uses
    {
      "visualizations/index.html" => "visualizations",
      "notebooks/sample-analysis/index.html" => "notebook"
    }.each do |page, bundle|
      assert_match(%r{rel="modulepreload"[^>]*/#{bundle}\.js}, SiteBuilder.read(page),
                   "#{page} should preload the #{bundle} bundle")
    end

    home = SiteBuilder.read("index.html")
    %w[visualizations notebook academic].each do |bundle|
      refute_match(%r{rel="modulepreload"[^>]*/#{bundle}\.js}, home,
                   "The home page should not preload the #{bundle} bundle")
    end
  end

  def test_inlines_only_the_page_data_a_script_on_the_page_reads
    home = SiteBuilder.read("index.html")
    %w[DatalogAcademic DatalogPublications DatalogTheme DatalogContent].each do |global|
      refute_includes home, "window.#{global} =", "The home page should not inline #{global}"
    end
    assert_includes home, "window.DatalogIntegrations =", "core/github-cards.js reads the integration settings"
  end

  def test_inlines_the_academic_data_where_citations_render
    template = Liquid::Template.parse("{% include meta/scripts-loader.html location='body' %}")
    context = {
      "site" => SiteBuilder.payload["site"],
      "page" => {},
      "content" => '<dd data-citation-metric="total">12</dd>'
    }
    rendered = template.render!(context, registers: { site: SiteBuilder.site })

    assert_includes rendered, "window.DatalogAcademic ="
    assert_includes rendered, "window.DatalogPublications ="
  end

  # `mathjax` was read before `math`, so under a `mathjax: true` in front
  # matter defaults a page could not opt out with `math: false`.
  def test_math_front_matter_wins_over_mathjax
    assert_equal "false", math_enabled("mathjax" => true, "math" => false),
                 "math: false should keep MathJax off under a mathjax: true default"
    assert_equal "true", math_enabled("mathjax" => false, "math" => true)
    assert_equal "true", math_enabled("mathjax" => true), "mathjax should still load MathJax when math is unset"
  end

  # The math preprocessor followed Pandoc's rule for inline math and left out
  # `$ … $` with spaces inside the dollars, which MathJax renders, so a page
  # whose only math was written that way loaded no MathJax.
  def test_loads_mathjax_where_the_only_math_is_padded
    padded = MathPreprocessor::Processor.new('Precision is $ \frac{TP}{TP + FP} $.')
    content = padded.process
    assert_equal "true", math_enabled({ "math_expressions" => padded.expressions }, content)

    prices = MathPreprocessor::Processor.new("It costs $ 5 a month, or $ 50 a year.")
    content = prices.process
    assert_equal "false", math_enabled({ "math_expressions" => prices.expressions }, content)
  end

  private

  def math_enabled(page, content = "")
    template = Liquid::Template.parse("{% include meta/math-config.html page=page %}{{ math_enabled }}")
    context = { "site" => SiteBuilder.payload["site"], "page" => page, "content" => content }
    template.render!(context, registers: { site: SiteBuilder.site }).strip
  end
end
