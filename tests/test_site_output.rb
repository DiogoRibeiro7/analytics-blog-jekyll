# frozen_string_literal: true

require "yaml"
require_relative "test_helper"
require_relative "../lib/datalog/theme/version"

# Checks that used to live in `rake ci:verify`, rewritten against the built
# site and the repository's data. Most of those scripts looked for strings in
# the source files; whatever they covered that no other suite does is here.
class SiteOutputTest < Minitest::Test
  POST = "2024/01/01/introducing-datalog/index.html"

  # The release workflow bumps CITATION.cff with version.rb.
  def test_citation_file_describes_the_current_release
    citation = YAML.safe_load_file(File.join(SiteBuilder.root, "CITATION.cff"), permitted_classes: [Date])

    assert_equal Datalog::Theme::VERSION, citation["version"]
    assert(citation["authors"].any? { |author| author["orcid"] }, "an author should carry an ORCID")
    assert(citation["identifiers"].any? { |identifier| identifier["type"] == "url" },
           "CITATION.cff should link the repository")
  end

  def test_posts_offer_citation_exports_and_scholar_metadata
    html = SiteBuilder.read(POST)

    %w[bibtex ris endnote].each do |format|
      assert_includes html, %(data-citation-format="#{format}")
    end
    assert_includes html, '<meta name="citation_orcid"'
  end

  def test_pages_with_math_announce_its_status
    html = SiteBuilder.read(POST)

    assert_match(/<main[^>]*aria-describedby="math-status"/, html)
    assert_match(/<div[^>]*aria-live="polite"[^>]*id="math-status"/, html)
  end

  def test_links_that_open_a_new_tab_use_noopener
    SiteBuilder.build
    offenders = Dir.glob(File.join(SiteBuilder.destination, "**", "*.html")).flat_map do |path|
      File.read(path).scan(/<a\b[^>]*target="_blank"[^>]*>/).reject do |tag|
        tag[/rel="([^"]*)"/, 1].to_s.split.include?("noopener")
      end
    end

    assert_empty offenders, "a link that opens a new tab without noopener gives that page access to window.opener"
  end

  # An in-page link to an id the page does not have goes nowhere. StatFlow's
  # "See Also" lists turned each whole list into one anchor.
  def test_in_page_links_reach_an_element_on_the_page
    SiteBuilder.build
    broken = Dir.glob(File.join(SiteBuilder.destination, "**", "*.html")).filter_map do |path|
      html = File.read(path)
      ids = html.scan(/\b(?:id|name)="([^"]+)"/).flatten
      missing = html.gsub(%r{<(script|style)\b.*?</\1>}m, "").scan(/href="#([^"]+)"/).flatten.uniq - ids
      "#{path.delete_prefix(SiteBuilder.destination)}: #{missing.join(', ')}" unless missing.empty?
    end

    assert_empty broken
  end

  # Shiny apps and widgets run third-party code in an iframe.
  def test_embedded_apps_are_sandboxed
    source = File.read(File.join(SiteBuilder.root, "assets", "js", "visualizations.js"))

    assert_operator source.scan("iframe.setAttribute('sandbox'").size, :>=, 2
  end
end
