# frozen_string_literal: true

require_relative "test_helper"
require "json"

class VisualizationsTest < Minitest::Test
  VISUALIZATIONS_PAGE = "visualizations/index.html"

  def setup
    @page_html = SiteBuilder.read(VISUALIZATIONS_PAGE)
  end

  def test_visualizations_page_exists
    assert File.exist?(SiteBuilder.destination_path(VISUALIZATIONS_PAGE)),
           "Visualizations showcase page should be generated"
  end

  def test_visualization_blocks_cover_supported_engines
    %w[plotly d3 observable bokeh shiny ipywidgets].each do |engine|
      assert_match(/data-viz-type="#{engine}"/, @page_html,
                   "Expected #{engine} block to be present")
    end
  end

  def test_visualization_runtime_assets_are_linked
    manifest_json = @page_html[%r{<script id="datalog-js-manifest"[^>]*type="application/json"[^>]*>(.+?)</script>}m, 1]
    assert manifest_json, "Loader manifest should be embedded for dynamic feature loading"

    manifest = JSON.parse(manifest_json)
    bundle_path = manifest.dig("features", "visualizations")

    assert bundle_path, "Visualization bundle should be listed in the manifest"
    assert_match(%r{/assets/js/dist/visualizations\.js$}, bundle_path,
                 "Visualization runtime script should be emitted through the code-splitting pipeline")
  end
end
