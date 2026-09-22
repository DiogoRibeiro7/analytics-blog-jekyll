# frozen_string_literal: true

require "nokogiri"
require "tmpdir"
require_relative "test_helper"
require_relative "../_plugins/revisions"

# The revision history of an article (_plugins/revisions.rb): what changed,
# when and why, for a post corrected while keeping its URL (#245).
class RevisionsTest < Minitest::Test
  Doc = Struct.new(:data, :relative_path)
  DEMO_TITLE = "Statistical Analysis Blueprint for Experimental Design"
  INCLUDES = %w[components/revision-notice.html components/revision-history.html helpers/date-format.html].freeze

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def normalize(data)
    doc = Doc.new(data, "_posts/2019-03-12-limits.md")
    Datalog::Revisions.normalize!(doc)
    doc.data
  end

  def revision(date, type = nil, summary = "Changed.")
    { "date" => date, "type" => type, "summary" => summary }.compact
  end

  def day(time)
    time.strftime("%F")
  end

  def days(data)
    data["revisions"].map { |entry| day(entry["date"]) }
  end

  def build_error(data)
    assert_raises(Jekyll::Errors::FatalException) { normalize(data) }
  end

  # --- the plugin ---

  def test_a_page_without_revisions_is_left_alone
    data = { "title" => "Plain", "last_modified_at" => "2020-01-01" }

    assert_equal data, normalize(data.dup)
  end

  def test_a_revision_is_announced_and_dates_the_modification
    entry = revision("2026-09-16", "correction", "Fixed.").merge("details_url" => "https://x/1")
    data = normalize("date" => Time.new(2019, 3, 12), "revisions" => [entry])

    assert_equal [{ "date" => Time.new(2026, 9, 16), "type" => "correction", "summary" => "Fixed.",
                    "details_url" => "https://x/1", "substantive" => true }], data["revisions"]
    assert_equal data["revisions"].first, data["revision_notice"]
    assert_equal Time.new(2026, 9, 16), data["last_modified_at"]
  end

  def test_revisions_are_sorted_newest_first_and_the_newest_correction_or_update_is_announced
    data = normalize("revisions" => [revision("2026-10-01", "editorial"), revision("2026-09-16", "correction"),
                                     revision("2024-03-12", "update"), revision("2027-01-05", "review")])

    assert_equal %w[2027-01-05 2026-10-01 2026-09-16 2024-03-12], days(data)
    assert_equal "2026-09-16", day(data["revision_notice"]["date"]), "a review or an editorial change makes no notice"
    assert_equal "2026-10-01", day(data["last_modified_at"]), "a review does not change the article"
  end

  def test_revisions_on_one_day_keep_their_order
    same_day = [revision("2026-09-16", "update", "First"), revision("2026-09-16", "update", "Second")]
    data = normalize("revisions" => same_day)

    assert_equal(%w[First Second], data["revisions"].map { |entry| entry["summary"] })
  end

  def test_a_later_modification_date_of_the_page_is_kept
    kept = normalize("last_modified_at" => "2027-05-01", "revisions" => [revision("2026-09-16")])
    updated = normalize("updated" => Date.new(2027, 5, 1), "revisions" => [revision("2026-09-16")])
    replaced = normalize("last_modified_at" => Date.new(2020, 1, 1), "revisions" => [revision("2026-09-16")])

    assert_equal "2027-05-01", kept["last_modified_at"]
    assert_equal "2027-05-01", day(updated["last_modified_at"])
    assert_equal Time.new(2026, 9, 16), replaced["last_modified_at"]
  end

  def test_a_review_alone_changes_nothing
    data = normalize("revisions" => [revision("2026-09-16", "review")])

    assert_nil data["last_modified_at"]
    assert_nil data["revision_notice"]
  end

  def test_a_date_may_be_a_date_a_time_or_a_string
    data = normalize("revisions" => [revision(Date.new(2026, 9, 16)), revision(Time.new(2026, 9, 15, 10)),
                                     revision("2026-09-14"), revision("13 September 2026")])

    assert_equal %w[2026-09-16 2026-09-15 2026-09-14 2026-09-13], days(data)
    assert(data["revisions"].all? { |entry| entry["date"].is_a?(Time) })
  end

  def test_a_malformed_or_missing_date_stops_the_build
    error = build_error("revisions" => [revision("yesterday")])
    assert_includes error.message, "_posts/2019-03-12-limits.md revision 1 has the date \"yesterday\", which is not"

    error = build_error("revisions" => [revision(nil)])
    assert_includes error.message, "revision 1 has the date nil"

    error = build_error("revisions" => [revision("2026-09-16"), revision(2026)])
    assert_includes error.message, "revision 2 has the date 2026"
  end

  def test_the_type_defaults_to_update_and_must_be_known
    data = normalize("revisions" => [revision("2026-09-16", nil), revision("2026-09-15", "Correction")])

    assert_equal(%w[update correction], data["revisions"].map { |entry| entry["type"] })

    error = build_error("revisions" => [revision("2026-09-16", "typo")])
    assert_includes error.message, "revision 1 has the type \"typo\"; it takes correction, update, review, editorial"
  end

  def test_a_summary_is_required
    error = build_error("revisions" => [revision("2026-09-16", "update", " ")])

    assert_includes error.message, "revision 1 needs a summary"
  end

  def test_revisions_must_be_a_list_of_maps
    error = build_error("revisions" => "Fixed the maths")
    assert_includes error.message, "has revisions that is not a list"

    error = build_error("revisions" => ["Fixed the maths"])
    assert_includes error.message, "revision 1 is not a map"
  end

  def test_revision_notice_false_keeps_the_notice_off
    data = normalize("revision_notice" => false, "revisions" => [revision("2026-09-16", "correction")])

    assert_equal false, data["revision_notice"]
    assert_equal 1, data["revisions"].size
  end

  # --- the includes ---

  def test_the_notice_names_the_correction_and_links_to_the_details_and_the_history
    doc = render(<<~YAML)
      revisions:
        - date: 2026-09-16
          type: correction
          summary: Fixed <b>the</b> proof & more.
          details_url: https://example.org/pr/1
    YAML
    notice = doc.at_css(".revision-notice")

    assert_equal "revision-notice revision-notice--correction", notice["class"]
    assert doc.at_css("##{notice['aria-labelledby']}"), "the notice is labelled by its lead"
    assert_equal "Corrected on September 16, 2026.", notice.at_css(".revision-notice__lead").text
    assert_includes notice.inner_html, "Fixed &lt;b&gt;the&lt;/b&gt; proof &amp; more."
    assert_equal "https://example.org/pr/1", notice.at_css(".revision-notice__details")["href"]
    assert_equal "#revision-history", notice.at_css(".revision-notice__history")["href"]
    assert doc.at_css("section#revision-history[aria-labelledby=revision-history-heading] #revision-history-heading")
  end

  def test_the_history_lists_every_revision_newest_first_and_ends_with_the_publication
    doc = render(<<~YAML, "baseurl" => "/blog")
      date: 2019-03-12
      revisions:
        - date: 2024-03-12
          type: update
          summary: Updated the examples.
        - date: 2026-01-05
          type: review
          summary: Read through; nothing changed.
        - date: 2025-06-01
          type: editorial
          summary: Reworded the introduction.
          details_url: /changes/
    YAML
    items = doc.css(".revision-history__item")

    assert_equal(%w[2026-01-05 2025-06-01 2024-03-12 2019-03-12], items.map { |item| item.at_css("time")["datetime"] })
    types = items.map { |item| item.at_css(".revision-history__type").text }
    assert_equal %w[Review Editorial Update Published], types
    assert_equal "/blog/changes/", doc.at_css(".revision-history__details")["href"], "a site path gets the baseurl"
    assert_equal "Updated on March 12, 2024.", doc.at_css(".revision-notice__lead").text,
                 "the newest correction or update, not the newest revision"
  end

  def test_a_review_or_an_editorial_change_makes_no_notice
    doc = render("revisions:\n  - date: 2026-01-05\n    type: review\n    summary: Read through.\n")

    assert_nil doc.at_css(".revision-notice")
    assert_equal 1, doc.css(".revision-history__item").size
  end

  def test_revision_notice_false_leaves_only_the_history
    doc = render(<<~YAML)
      revision_notice: false
      revisions:
        - date: 2026-01-05
          type: correction
          summary: Fixed.
    YAML

    assert_nil doc.at_css(".revision-notice")
    assert doc.at_css("#revision-history")
  end

  def test_labels_follow_the_page_language
    doc = render("lang: pt\nrevisions:\n  - date: 2026-09-16\n    type: correction\n    summary: Corrigido.\n")

    assert_equal "Corrigido em 16 de Setembro de 2026.", doc.at_css(".revision-notice__lead").text
    assert_equal "Histórico de revisões", doc.at_css("#revision-history-heading").text
    assert_equal "Correção", doc.at_css(".revision-history__type").text
  end

  def test_a_page_without_revisions_renders_neither
    doc = render("title: Plain\n")

    assert_nil doc.at_css(".revision-notice")
    assert_nil doc.at_css("#revision-history")
  end

  # --- the demo site ---

  def test_the_demo_post_announces_its_correction_and_dates_its_update
    html = demo_post_html
    updated = %r{<dt class="post-meta-term">Updated</dt>\s*<dd class="post-meta-definition">September 10, 2024</dd>}

    assert_includes html, 'class="revision-notice revision-notice--correction"'
    assert_includes html, "Corrected on September 10, 2024."
    assert_match updated, html
    assert_includes html, 'itemprop="dateModified" content="2024-09-10T00:00:00'
    assert_includes html, '<section class="revision-history" id="revision-history"'
    assert_equal 3, html.scan('class="revision-history__item ').size, "two revisions and the publication"
  end

  def test_the_demo_post_structured_data_carries_the_correction
    json = demo_post_html[%r{<script type="application/ld\+json"[^>]*>(.*?)</script>}m, 1]
    schema = JSON.parse(json)
    corrections = schema.fetch("correction")

    assert_equal "2024-02-20", schema["datePublished"][0, 10]
    assert_equal "2024-09-10", schema["dateModified"][0, 10]
    assert_equal 1, corrections.size
    assert_equal "CorrectionComment", corrections.first["@type"]
    assert_equal "2024-09-10", corrections.first["datePublished"][0, 10]
    assert_includes corrections.first["text"], "pwr.2p.test"
    assert_equal "https://github.com/DiogoRibeiro7/analytics-blog-jekyll", corrections.first["url"]
  end

  def test_the_sitemap_dates_the_demo_post_by_its_correction
    sitemap = SiteBuilder.read("sitemap.xml")

    assert_match(%r{<loc>[^<]*#{Regexp.escape(demo_post.url)}</loc>\s*<lastmod>2024-09-10T}, sitemap)
  end

  private

  def demo_post
    @demo_post ||= SiteBuilder.site.posts.docs.find { |doc| doc.data["title"] == DEMO_TITLE }
  end

  def demo_post_html
    refute_nil demo_post, "expected the experimental design demo post to exist"
    SiteBuilder.read(File.join(demo_post.url, "index.html"))
  end

  # A page holding the two includes, with the theme's translations.
  def render(front_matter, config = {})
    includes = %w[revision-notice revision-history].map { |name| "{% include components/#{name}.html page=page %}" }
    TestSite.build(config.merge(title: "Revisions")) do |source|
      source.theme(*INCLUDES.map { |name| "_includes/#{name}" }, "_data/i18n")
      source.page("index.html", includes.join, "layout: null\n#{front_matter}")
    end.html("index.html")
  end
end
