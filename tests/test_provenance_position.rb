# frozen_string_literal: true

require "nokogiri"
require_relative "test_helper"

# Where the author and editorial note goes (#317). It stood between the topics
# and the article body, a screenful on a phone before the first sentence; by
# default it now follows the article, in the document as well as on screen,
# and a row of the metadata points to it.
class ProvenancePositionTest < Minitest::Test
  NOTE = {
    "why_this_exists" => "To see where the note goes.",
    "evidence" => "This fixture.",
    "reviewed_at" => "2026-09-13"
  }.freeze

  POST = {
    "layout" => "post",
    "title" => "A post with a note",
    "reproducibility" => { "code" => { "url" => "https://github.com/example/analysis", "ref" => "4f2c1ab" } },
    "revisions" => [{ "date" => "2026-09-14", "type" => "update", "summary" => "Added a figure." }]
  }.freeze

  # The parts of the page the note is placed among, by their selectors.
  LANDMARKS = {
    "taxonomy" => ".post-taxonomy",
    "note" => "aside.content-provenance",
    "body" => ".post-content",
    "reproduce" => ".reproduce",
    "history" => "#revision-history",
    "citation" => ".citation-tools"
  }.freeze

  def build(config: {}, front_matter: {})
    site = TestSite.build({ title: "Provenance", permalink: "/:title/" }.merge(config)) do |source|
      source.theme("_layouts", "_includes", "_data")
      front = POST.merge(NOTE).merge("tags" => ["method"]).merge(front_matter)
      source.post("2026-01-01-note", "The article's first sentence.", front)
    end
    site.document("note/index.html")
  end

  # The landmarks the page has, in the order the document holds them.
  def order(doc)
    found = LANDMARKS.filter_map { |name, css| (node = doc.at_css(css)) && [name, node] }
    found.sort_by { |(_, node)| node }.map(&:first)
  end

  def pointer(doc)
    doc.css(".post-meta-list a[href='#content-provenance']")
  end

  def test_by_default_the_note_follows_the_article_and_the_reproducibility_panel
    doc = build

    assert_equal %w[taxonomy body reproduce note history citation], order(doc)
    assert_equal 1, doc.css("aside.content-provenance").size
    assert_equal "content-provenance", doc.at_css("aside.content-provenance")["id"]
  end

  def test_the_metadata_points_to_the_note_and_says_when_the_article_was_reviewed
    doc = build
    row = pointer(doc).first.ancestors("div").first

    assert_equal 1, pointer(doc).size
    assert_equal "Author and editorial note", row.at_css("dt").text.strip
    assert_match(/\AReviewed .*2026 · How this article was made\z/, row.at_css("dd").text.gsub(/\s+/, " ").strip)
  end

  def test_without_a_review_date_the_row_holds_the_link_alone
    doc = build(front_matter: { "reviewed_at" => nil })

    assert_equal "How this article was made", pointer(doc).first.ancestors("dd").first.text.strip
  end

  def test_the_site_can_put_the_note_back_before_the_article
    doc = build(config: { theme_options: { "provenance" => { "position" => "start" } } })

    assert_equal %w[taxonomy note body reproduce history citation], order(doc)
    assert_empty pointer(doc), "with the note right there, the metadata does not point to it"
  end

  def test_a_post_chooses_over_the_site
    at_start = build(front_matter: { "provenance_position" => "start" })
    at_end = build(config: { theme_options: { "provenance" => { "position" => "start" } } },
                   front_matter: { "provenance_position" => "end" })

    assert_equal %w[taxonomy note body reproduce history citation], order(at_start)
    assert_equal %w[taxonomy body reproduce note history citation], order(at_end)
    assert_equal 1, pointer(at_end).size
  end

  def test_a_post_without_the_fields_has_neither_note_nor_row
    doc = build(front_matter: NOTE.transform_values { nil })

    assert_nil doc.at_css("aside.content-provenance")
    assert_empty pointer(doc)
    assert_nil doc.at_css(".post-meta-list dt:contains('Author and editorial note')")
  end

  def test_the_validator_takes_only_the_two_positions
    validate = lambda do |position|
      config = { "title" => "T", "url" => "https://example.org", "author" => "A",
                 "theme_options" => { "provenance" => { "position" => position } } }
      Datalog::ConfigValidator.new.generate(Struct.new(:config).new(config))
    end

    assert_nil validate.call("start")
    assert_nil validate.call("end")
    error = assert_raises(Jekyll::Errors::FatalException) { validate.call("bottom") }
    assert_includes error.message, "Invalid value for 'theme_options.provenance.position'"
  end
end
