# frozen_string_literal: true

require_relative "test_helper"

class AnalyticsDashboardTest < Minitest::Test
  def setup
    @html = SiteBuilder.read("admin/analytics/index.html")
  end

  def test_page_renders_dashboard_container
    assert_includes @html, "analytics-dashboard"
  end

  def test_includes_chart_js_reference
    assert_includes @html, "chart.umd.min.js"
  end

  def test_serializes_analytics_payload
    assert_includes @html, "window.__DATALOG_ANALYTICS__"
  end

  # The dashboard script uses `export`, so it has to load as a module from the
  # built bundle; loaded as a classic script it failed to parse and the
  # dashboard never rendered.
  def test_loads_the_dashboard_bundle_as_a_module
    assert_match(%r{<script type="module" src="/assets/js/dist/analytics-dashboard\.js"></script>}, @html)
    refute_includes @html, 'src="/assets/js/analytics-dashboard.js"'
  end
end
