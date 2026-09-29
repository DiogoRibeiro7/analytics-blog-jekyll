# frozen_string_literal: true

require_relative "test_helper"

class ArchiveTest < Minitest::Test
  def test_tag_and_category_pages_use_the_post_link_anchors_and_limit_long_groups
    site = fixture(archive_limit: 1)
    tags = site.document("tags/index.html")
    categories = site.document("categories/index.html")

    assert_equal 1, tags.css("h1").size
    assert_equal %w[research ruby], (tags.css(".archive-section h2").map { |heading| heading["id"] })
    assert_equal ["#research", "#ruby"], (tags.css(".archive-section nav a").map { |link| link["href"] })
    assert_equal 2, tags.css("#ruby + .archive-list li, #ruby ~ details li").size
    assert_equal 1, tags.css("details").size
    assert_equal "Research", categories.at_css("#research").text.split.first
    assert_equal 2, categories.css("#research + .archive-list li, #research ~ details li").size
  end

  def test_years_descend_and_optional_months_have_a_heading_below_the_year
    site = fixture(archive_months: true)
    years = site.document("years/index.html")

    assert_equal %w[2026 2025], (years.css(".archive-section > section > h2").map { |heading| heading["id"] })
    assert_equal ["2026-02", "2026-01"], (years.css("[id='2026'] ~ section h3").map { |heading| heading["id"] })
    assert_equal 1, years.css("h1").size
    assert_equal 3, years.css(".archive-section time").size
  end

  def test_topic_matches_tags_or_categories_and_lists_a_series_once
    site = fixture
    topic = site.document("topic/index.html")

    assert_equal 1, topic.css("#archive-series ~ .archive-list li").size
    assert_equal 1, topic.css("#archive-articles ~ .archive-list li").size
    assert_includes topic.at_css("#archive-series ~ .archive-list").text, "Study series"
    assert_includes topic.at_css("#archive-articles ~ .archive-list").text, "Standalone"
    refute_includes topic.at_css("#archive-articles ~ .archive-list").text, "Part"
  end

  def test_the_starter_ships_the_three_index_pages
    %w[year tag category].each do |type|
      file = File.join(SiteBuilder.root, "template", "_pages", "archive-#{type}.md")
      assert File.file?(file)
      assert_includes File.read(file), "archive: #{type}"
    end
  end

  private

  def fixture(**year_options)
    TestSite.build do |source|
      source.theme("_layouts", "_includes", "_data/i18n")
      source.page("tags/index.md", "Browse by tag.", "layout: archive\ntitle: Tags\narchive: tag\narchive_limit: 1\n")
      source.page("categories/index.md", "Browse by category.",
                  "layout: archive\ntitle: Categories\narchive: category\n")
      source.page("years/index.md", "Browse by year.",
                  { "layout" => "archive", "title" => "Years", "archive" => "year" }
                    .merge(year_options.transform_keys(&:to_s)))
      source.page("topic/index.md", "A curated introduction.", <<~YAML)
        layout: archive
        title: Topic
        archive: topic
        topic:
          tags: [ruby]
          categories: [Research]
          featured: [/2026/02/01/standalone/]
      YAML
      source.post("2025-01-01-part-one", "Part one.",
                  "layout: null\ntitle: Part One\ntags: [ruby]\ncategories: [Research]\n" \
                  "series:\n  id: study\n  title: Study series\n  order: 1\n")
      source.post("2026-01-01-part-two", "Part two.",
                  "layout: null\ntitle: Part Two\ntags: [ruby]\ncategories: [Research]\n" \
                  "series:\n  id: study\n  order: 2\n")
      source.post("2026-02-01-standalone", "Standalone.",
                  "layout: null\ntitle: Standalone\ntags: [research]\n")
    end
  end
end
