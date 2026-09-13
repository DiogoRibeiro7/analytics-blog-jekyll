# frozen_string_literal: true

require_relative "test_helper"

# The page outline and the markup that screen readers and the Content Security
# Policy depend on.
class PageStructureTest < Minitest::Test
  def test_no_page_has_more_than_one_h1
    SiteBuilder.build
    repeated = Dir.glob(File.join(SiteBuilder.destination, "**", "*.html")).filter_map do |path|
      count = File.read(path).scan(/<h1[\s>]/).size
      "#{path.delete_prefix(SiteBuilder.destination)} (#{count})" if count > 1
    end
    assert_empty repeated, "Each page should have one <h1>; the layout's title and the page's own heading both rendered"
  end

  def test_footer_navigation_is_named_and_its_headings_follow_the_page
    html = SiteBuilder.read("index.html")
    footer = html[html.index("<footer")..html.index("</footer>")]
    assert_includes footer, '<nav class="footer-navigation" aria-labelledby="footer-explore-heading">'
    assert_includes footer, '<h2 id="footer-explore-heading">'
    refute_match(/<h[13][\s>]/, footer, "the footer's column titles should be <h2>")
  end

  def test_reading_progress_is_not_announced
    refute_includes SiteBuilder.read("index.html"), "progress-announcement",
                    "a live region for the reading progress is announced on every scroll event"
  end

  def test_body_applies_the_color_scheme_before_anything_renders
    html = SiteBuilder.read("index.html")
    script = html.match(%r{<body[^>]*>\s*<script nonce="([^"]*)">(.*?)</script>}m)
    refute_nil script, "the first element in <body> should be the color scheme script"
    assert_equal html[/'nonce-([^']+)'/, 1], script[1], "the script needs the page's CSP nonce"
    assert_includes script[2], "datalog-color-mode"
  end

  def test_academic_year_chart_sets_bar_heights_the_policy_allows
    html = SiteBuilder.read("academic/index.html")
    refute_match(/class="year-chart__fill"[^>]*style=/, html, "the Content Security Policy drops style attributes")
    assert_match(/<style nonce="[^"]+">\s*\.year-chart__fill\[data-year="[^"]+"\] \{ --bar-height: \d+%; \}/, html)
  end
end
