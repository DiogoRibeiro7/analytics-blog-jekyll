# frozen_string_literal: true

require_relative "test_helper"
require "ostruct"
require "base64"

class NotebookSanitizationTest < Minitest::Test
  def setup
    Datalog::NotebookRenderer.reset_sanitization_metrics!
    @site = OpenStruct.new(config: {})
  end

  def test_script_tags_are_removed
    html = "<div><script>alert('x')</script><p>Safe</p></div>"
    sanitized = Datalog::NotebookRenderer.sanitize_html(
      html,
      context: :markdown,
      site: @site,
      metadata: { cell_index: 0 }
    )

    refute_includes sanitized, "<script"
    assert_includes sanitized, "<p>Safe</p>"

    stats = Datalog::NotebookRenderer.sanitization_metrics_snapshot
    assert_operator stats[:markdown][:removed_nodes], :>=, 1
  end

  def test_math_notation_is_preserved
    html = "<p>Equation: \\(x^2 + 1\\)</p>"
    sanitized = Datalog::NotebookRenderer.sanitize_html(
      html,
      context: :markdown,
      site: @site,
      metadata: { cell_index: 1 }
    )

    assert_includes sanitized, "\\(x^2 + 1\\)"
  end

  def test_viz_block_attributes_are_sanitized
    html = <<~HTML
      <div class="viz-block" data-config='{"safe":true}' data-evil="javascript:alert('nope')">
        <span class="viz-canvas" data-state="ready"></span>
        <script>alert('bad')</script>
      </div>
    HTML

    sanitized = Datalog::NotebookRenderer.sanitize_visualization_html(
      html,
      site: @site,
      metadata: { cell_index: 2, output_index: 0 }
    )

    assert_includes sanitized, "viz-block"
    assert_includes sanitized, "data-config"
    refute_includes sanitized, "data-evil"
    refute_includes sanitized, "<script"
  end

  def test_data_uri_images_respected
    data = Base64.strict_encode64("a" * 128)
    html = %(<img src="data:image/png;base64,#{data}" alt="chart" />)
    sanitized = Datalog::NotebookRenderer.sanitize_html(
      html,
      context: :output,
      site: @site,
      metadata: { cell_index: 3, kind: :image }
    )

    assert_includes sanitized, "data:image/png"
  end

  def test_large_data_uri_images_are_removed
    limit = Datalog::NotebookRenderer::MAX_DATA_URI_BYTES + 10
    data = Base64.strict_encode64("b" * limit)
    html = %(<img src="data:image/png;base64,#{data}" alt="too big" />)
    sanitized = Datalog::NotebookRenderer.sanitize_html(
      html,
      context: :output,
      site: @site,
      metadata: { cell_index: 4, kind: :image }
    )

    refute_includes sanitized, "data:image/png"
  end
end
