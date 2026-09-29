# frozen_string_literal: true

require_relative "test_helper"

class RelatedRankingTest < Minitest::Test
  Doc = Struct.new(:data, :url, :date, :relative_path)
  Posts = Struct.new(:docs)
  Site = Struct.new(:posts, :config)

  def test_four_rare_tags_beat_a_newer_shared_category
    source = doc("Source", 2024, tags: %w[rare-a rare-b rare-c rare-d], categories: ["Research"])
    rare = doc("Rare", 2020, tags: %w[rare-a rare-b rare-c rare-d])
    broad = doc("Broad", 2026, categories: ["Research"])

    assert_equal [rare, broad], rank(source, rare, broad).first(2)
  end

  def test_manual_picks_keep_their_order_and_a_bad_pick_names_the_post
    source = doc("Source", 2024, tags: ["stats"], related_posts: ["Second", "_posts/2020-01-01-first.md"])
    first = doc("First", 2020, tags: ["stats"])
    second = doc("Second", 2021, tags: ["stats"])

    assert_equal [second, first], rank(source, first, second).first(2)
    source.data["related_posts"] = ["Missing title"]
    error = assert_raises(Jekyll::Errors::FatalException) { rank(source, first, second) }
    assert_includes error.message, source.relative_path
    assert_includes error.message, "Missing title"
  end

  def test_own_series_and_excluded_posts_are_omitted_and_other_series_occurs_once
    source = doc("Source", 2024, tags: ["stats"], series: { "id" => "own" })
    own = doc("Own", 2023, tags: ["stats"], series: { "id" => "own" })
    hidden = doc("Hidden", 2025, tags: ["stats"], related: false)
    first = doc("First", 2022, tags: ["stats"], series: { "id" => "other" })
    second = doc("Second", 2026, tags: ["stats"], series: { "id" => "other" })

    assert_equal [second], rank(source, own, hidden, first, second)
    source.data["related_posts"] = [own.url]
    assert_raises(Jekyll::Errors::FatalException) { rank(source, own, first) }
  end

  def test_threshold_and_opt_out
    source = doc("Source", 2024, categories: ["Broad"])
    candidate = doc("Candidate", 2026, categories: ["Broad"])
    assert_empty rank(source, candidate, settings: { "min_score" => 0.5 })

    source.data["related_posts"] = false
    index = index_for(source, candidate)
    index.assign!
    assert_empty source.data["related"]
  end

  def test_title_excerpt_similarity_is_optional
    source = doc("Bayesian calibration", 2024)
    candidate = doc("Bayesian inference", 2020)

    assert_empty rank(source, candidate)
    assert_equal [candidate], rank(source, candidate, settings: { "weights" => { "text" => 0.4 } })
  end

  def test_a_generated_site_with_500_posts_uses_the_index_and_renders_the_section
    site = TestSite.build do |source|
      source.theme("_includes/post/related-posts.html", "_includes/helpers/date-format.html",
                   "_includes/helpers/array-to-sentence.html", "_data/i18n")
      source.layout("post", "{% include post/related-posts.html page=page %}")
      498.times do |number|
        source.post("2024-01-01-post-#{number}", "Body", "layout: post\ntitle: Post #{number}\ntags: [tag-#{number}]\n")
      end
      source.post("2024-01-02-source", "Body", "layout: post\ntitle: Source\ntags: [signal]\n")
      source.post("2024-01-03-match", "Body", "layout: post\ntitle: Match\ntags: [signal]\n")
    end

    post = site.jekyll.posts.docs.find { |item| item.data["title"] == "Source" }
    assert_equal ["Match"], post.data["related"].map { |item| item["title"] }
    assert_includes post.output, "post-related"
  end

  private

  def doc(title, year, **data)
    slug = title.downcase.tr(" ", "-")
    Doc.new({ "title" => title }.merge(data.transform_keys(&:to_s)), "/#{slug}/", Time.utc(year, 1, 1),
            "_posts/2020-01-01-#{slug}.md")
  end

  def index_for(*posts, settings: {})
    Datalog::RelatedPosts::Index.new(Site.new(Posts.new(posts), { "related_posts" => settings }))
  end

  def rank(source, *candidates, settings: {})
    index_for(source, *candidates, settings: settings).recommendations(source)
  end
end
