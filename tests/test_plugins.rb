# frozen_string_literal: true

require_relative "test_helper"

class PluginLoaderTest < Minitest::Test
  def setup
    @search_index = SiteBuilder.json("search.json")
  end

  def test_citation_metadata_is_exposed
    doc = document_titled("Research Article Template with Citations and BibTeX")
    refute_nil doc, "expected research article to exist in search index"

    extensions = doc.fetch("extensions", {})
    assert extensions.key?("citations"), "citations extension should be present"
    assert_equal 2, extensions.dig("citations", "count")
    assert_includes extensions.dig("citations", "keys"), "li2010"
  end

  def test_slides_metadata_is_captured
    doc = document_titled("Plotly Visualization Showcase for Executive Dashboards")
    refute_nil doc, "expected Plotly showcase post to be indexed"

    extensions = doc.fetch("extensions", {})
    assert_equal "https://slides.datalog-theme.dev/plotly-story.html", extensions.dig("slides", "src")
    assert_equal "Plotly Showcase Slides", extensions.dig("slides", "title")
  end

  def test_comments_extension_describes_provider
    doc = document_titled("Plotly Visualization Showcase for Executive Dashboards")
    extensions = doc.fetch("extensions", {})
    assert_equal "giscus", extensions.dig("comments", "provider")
    assert_equal "pathname", extensions.dig("comments", "mapping")
  end

  private

  def document_titled(title)
    @search_index["documents"].find { |doc| doc["title"] == title }
  end
end

