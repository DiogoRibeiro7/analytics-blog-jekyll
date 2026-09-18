# frozen_string_literal: true

require "nokogiri"
require "tmpdir"
require_relative "test_helper"
require_relative "../_plugins/series"

# Article series (_plugins/series.rb and _includes/components/series-nav.html):
# the parts in order, "Part k of n", and the previous and next parts (#244).
class SeriesTest < Minitest::Test
  Doc = Struct.new(:data, :url, :relative_path)
  Site = Struct.new(:documents, :pages, :data)

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def doc(title, series = nil, **extra)
    slug = title.downcase.tr(" ", "-")
    data = { "title" => title, "series" => series }.merge(extra.transform_keys(&:to_s)).compact
    Doc.new(data, "/#{slug}/", "_posts/2026-01-01-#{slug}.md")
  end

  def normalize(*docs, data: {})
    Datalog::Series.normalize!(Site.new(docs, [], data))
    docs.map { |document| document.data["series"] }
  end

  # --- the plugin ---

  def test_parts_are_ordered_by_their_order_and_know_their_neighbours
    third = doc("Sensitivity", { "id" => "missing", "order" => 3 })
    first = doc("Mechanisms", { "id" => "missing", "order" => 1 })
    second = doc("Imputation", { "id" => "missing", "order" => 2 })
    normalize(third, first, second)

    assert_equal([1, 2, 3], [first, second, third].map { |part| part.data["series"]["position"] })
    assert_equal([3, 3, 3], [first, second, third].map { |part| part.data["series"]["count"] })
    assert_equal(%w[Mechanisms Imputation Sensitivity], second.data["series"]["parts"].map { |part| part["title"] })
    assert_equal([false, true, false], second.data["series"]["parts"].map { |part| part["current"] })
    assert_nil first.data["series"]["previous"]
    assert_equal "/imputation/", first.data["series"]["next"]["url"]
    assert_equal(["/mechanisms/", "/sensitivity/"], second.data["series"].values_at("previous", "next").map do |p|
      p["url"]
    end)
    assert_nil third.data["series"]["next"]
  end

  def test_the_flat_form_and_the_data_file_give_the_same_series
    registry = { "series" => { "missing" => { "title" => "Missing Data", "description" => "Three parts." } } }
    flat = doc("Mechanisms", "missing", series_order: 1)
    mapped = doc("Imputation", { "id" => "missing", "order" => "2" })
    normalize(flat, mapped, data: registry)

    assert_equal "Missing Data", flat.data["series"]["title"]
    assert_equal "Three parts.", mapped.data["series"]["description"]
    assert_equal [1, 2], [flat, mapped].map { |part| part.data["series"]["order"] }, "a string order counts"
  end

  def test_the_title_comes_from_a_part_or_from_the_id
    titled = doc("Two", { "id" => "missing-data", "order" => 2, "title" => "Missing Data and Inference" })
    plain = doc("One", { "id" => "missing-data", "order" => 1 })
    normalize(titled, plain)

    assert_equal "Missing Data and Inference", plain.data["series"]["title"]
    assert_equal "Missing Data", normalize(doc("Only", "missing-data", series_order: 1)).first["title"]
  end

  def test_a_series_of_one_and_gaps_in_the_orders
    only = normalize(doc("Only", { "id" => "solo", "order" => 1 })).first

    assert_equal [1, 1], only.values_at("position", "count")
    refute only.key?("previous")
    refute only.key?("next")

    gapped = normalize(doc("First", { "id" => "gap", "order" => 1 }), doc("Last", { "id" => "gap", "order" => 4 }))

    assert_equal([[1, 2], [2, 2]], gapped.map { |part| part.values_at("position", "count") })
  end

  def test_two_parts_with_one_order_stop_the_build
    error = assert_raises(Jekyll::Errors::FatalException) do
      normalize(doc("A", { "id" => "missing", "order" => 2 }), doc("B", { "id" => "missing", "order" => 2 }))
    end

    assert_includes error.message,
                    "_posts/2026-01-01-a.md and _posts/2026-01-01-b.md are both part 2 of the series \"missing\""
  end

  def test_a_part_without_a_whole_number_order_stops_the_build
    [nil, "three", 0, 1.5].each do |order|
      error = assert_raises(Jekyll::Errors::FatalException) { normalize(doc("A", { "id" => "missing", "order" => order })) }

      assert_includes error.message, "_posts/2026-01-01-a.md is part of the series \"missing\" without an order",
                      order.inspect
    end
  end

  def test_a_series_without_an_id_or_of_the_wrong_shape_stops_the_build
    error = assert_raises(Jekyll::Errors::FatalException) { normalize(doc("A", { "order" => 1 })) }
    assert_includes error.message, "has a series without an id"

    error = assert_raises(Jekyll::Errors::FatalException) { normalize(doc("A", 3)) }
    assert_includes error.message, "has a series that is neither a name nor a map"
  end

  def test_documents_without_a_series_are_left_alone
    plain = doc("Plain")
    normalize(plain, doc("Off", false))

    refute plain.data.key?("series")
  end

  # --- the navigation ---

  def test_the_navigation_lists_the_parts_and_marks_the_current_one
    build
    nav = post_doc("part-two").at_css("nav.series-nav:not(.series-nav--compact)")

    assert nav.at_css("##{nav['aria-labelledby']}"), "the navigation is labelled by its heading"
    assert_equal "Series Missing Data Part 2 of 3", squeeze(nav.at_css(".series-nav__heading").text)
    assert_equal "Three parts.", nav.at_css(".series-nav__description").text
    progress = nav.at_css("progress")

    assert_equal %w[2 3], [progress["value"], progress["max"]]
    assert_equal ["Part One", "Part Two", "Part Three"], nav.css("ol li a").map(&:text)
    assert_equal(["/blog/2026/01/02/part-two/"], nav.css("a[aria-current=page]").map { |link| link["href"] })
    assert_equal "/blog/2026/01/01/part-one/", nav.at_css("a[rel=prev]")["href"]
    assert_equal "/blog/2026/01/03/part-three/", nav.at_css("a[rel=next]")["href"]
    assert_equal "Next part Part Three", squeeze(nav.at_css("a[rel=next]").text)
  end

  def test_the_first_and_last_parts_lack_a_neighbour_and_the_end_repeats_the_links
    build
    first = post_doc("part-one")
    last = post_doc("part-three")

    assert_nil first.at_css("a[rel=prev]")
    assert_equal 2, first.css("a[rel=next]").size, "the top and the compact navigation both link the next part"
    assert_nil last.at_css("a[rel=next]")
    assert_equal 2, last.css("a[rel=prev]").size

    compact = last.at_css("nav.series-nav--compact")

    assert_equal "Series: Missing Data", compact["aria-label"]
    assert_equal "Missing Data · Part 3 of 3", squeeze(compact.at_css(".series-nav__context").text)
  end

  def test_a_series_of_one_and_a_post_without_a_series
    build
    alone = post_doc("alone")

    assert_equal "Series Alone Part 1 of 1", squeeze(alone.at_css(".series-nav__heading").text)
    assert_nil alone.at_css(".series-nav__links")
    assert_nil alone.at_css("nav.series-nav--compact")
    assert_empty post_doc("plain").css(".series-nav")
  end

  def test_titles_are_escaped_and_labels_follow_the_page_language
    build
    doc = post_doc("part-two")

    assert_includes doc.to_html, "Part Two"
    assert_includes post_doc("escaped").at_css(".series-nav__title").text, "Bold <b>title</b> & more"
    refute_includes post_doc("escaped").to_html, "<b>title</b>"
    assert_equal "Série Missing Data Parte 2 de 3", squeeze(post_doc("part-two-pt").at_css(".series-nav__heading").text)
  end

  # --- the demo site ---

  def test_the_demo_python_series_is_navigable
    part = SiteBuilder.site.posts.docs.find do |doc|
      doc.data["title"] == "Feature Engineering with pandas Window Functions"
    end
    refute_nil part
    html = SiteBuilder.read(File.join(part.url, "index.html"))

    assert_includes html, 'class="series-nav"'
    assert_includes html, "Python for Data Science"
    assert_includes html, "Part 2 of 3"
    assert_includes html, 'aria-current="page"'
    refute_includes SiteBuilder.read("2024/01/01/introducing-datalog/index.html"), 'class="series-nav"'
  end

  private

  def squeeze(text)
    text.gsub(/\s+/, " ").strip
  end

  def post_doc(slug)
    path = Dir[File.join(@dir, "_site", "**", slug, "index.html")].first
    refute_nil path, "expected #{slug} to be built"
    Nokogiri::HTML5.fragment(File.read(path))
  end

  # A site of five posts: a three-part series, one in Portuguese, a series of one and a plain post.
  def build
    FileUtils.mkdir_p(File.join(@dir, "_posts"))
    FileUtils.mkdir_p(File.join(@dir, "_includes", "components"))
    FileUtils.mkdir_p(File.join(@dir, "_data"))
    FileUtils.cp(File.join(SiteBuilder.root, "_includes", "components", "series-nav.html"),
                 File.join(@dir, "_includes", "components", "series-nav.html"))
    FileUtils.cp_r(File.join(SiteBuilder.root, "_data", "i18n"), File.join(@dir, "_data"))
    File.write(File.join(@dir, "_data", "series.yml"), "missing:\n  title: Missing Data\n  description: Three parts.\n")
    body = "{% include components/series-nav.html page=page %}" \
           "{% include components/series-nav.html page=page compact=true %}"
    {
      "2026-01-01-part-one" => "title: Part One\nseries:\n  id: missing\n  order: 1\n",
      "2026-01-02-part-two" => "title: Part Two\nseries: missing\nseries_order: 2\n",
      "2026-01-03-part-three" => "title: Part Three\nseries:\n  id: missing\n  order: 3\n",
      "2026-01-04-part-two-pt" => "title: Parte Dois\nlang: pt\nseries:\n  id: outra\n  title: Missing Data\n  " \
                                  "order: 2\n",
      "2026-01-05-part-one-pt" => "title: Parte Um\nlang: pt\nseries:\n  id: outra\n  order: 1\n",
      "2026-01-06-part-three-pt" => "title: Parte Três\nlang: pt\nseries:\n  id: outra\n  order: 3\n",
      "2026-01-07-alone" => "title: Alone\nseries:\n  id: alone\n  order: 1\n",
      "2026-01-08-escaped" => "title: Escaped\nseries:\n  id: esc\n  title: Bold <b>title</b> & more\n  order: 1\n",
      "2026-01-09-plain" => "title: Plain\n"
    }.each do |name, front_matter|
      File.write(File.join(@dir, "_posts", "#{name}.md"), "---\nlayout: null\n#{front_matter}---\n\n#{body}\n")
    end
    config = Jekyll.configuration(
      "source" => @dir, "destination" => File.join(@dir, "_site"), "quiet" => true, "title" => "Series",
      "url" => "https://example.org", "baseurl" => "/blog", "author" => { "name" => "Test" },
      "permalink" => "/:year/:month/:day/:title/"
    )
    Jekyll::Site.new(config).process
  end
end
