# frozen_string_literal: true

require "nokogiri"
require "tmpdir"
require_relative "test_helper"

# Numbered figures and tables and the references to them (_plugins/references.rb).
# Authors typed "Figure 2" by hand, which went wrong whenever an article was
# reordered; equations alone were numbered, by MathJax (#250).
class ReferencesTest < Minitest::Test
  FIGURE = <<~LIQUID
    {%% figure id="%<id>s" src="/assets/img/%<id>s.png" alt="%<alt>s" %%}
    %<caption>s
    {%% endfigure %%}
  LIQUID

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def figure(id, caption = "A caption.", alt: "A plot")
    format(FIGURE, id: id, alt: alt, caption: caption)
  end

  def table(id, caption = "A table.")
    "{% table id=\"#{id}\" %}\n#{caption}\n\n| n | runs |\n|---|------|\n| 50 | 1000 |\n{% endtable %}\n"
  end

  def test_targets_are_numbered_in_page_order_and_references_link_to_them
    doc = build(<<~MARKDOWN)
      See {% ref fig-late %}, {% ref tab-runs %} and {% ref fig-early %}.

      #{figure('fig-early')}
      #{table('tab-runs')}
      #{figure('fig-late')}
      Back to {% ref fig-early %}.
    MARKDOWN

    assert_equal ["Figure 1.", "Table 1.", "Figure 2."], doc.css(".datalog-ref-label").map(&:text)
    assert_equal({ "#fig-late" => "Figure 2", "#tab-runs" => "Table 1", "#fig-early" => "Figure 1" },
                 doc.css("a.datalog-ref").first(3).to_h { |link| [link["href"], link.text] })
    assert_equal "Figure 1", doc.css("a.datalog-ref").last.text
    assert_equal(%w[fig-early tab-runs fig-late], doc.css("[data-ref-target]").map { |target| target["id"] })
  end

  def test_reordering_renumbers_every_reference
    first = build("{% ref fig-a %}\n\n#{figure('fig-a')}\n#{figure('fig-b')}")
    swapped = build("{% ref fig-a %}\n\n#{figure('fig-b')}\n#{figure('fig-a')}")

    assert_equal "Figure 1", first.at_css("a.datalog-ref").text
    assert_equal "Figure 2", swapped.at_css("a.datalog-ref").text
  end

  def test_a_duplicate_id_stops_the_build
    error = assert_raises(Jekyll::Errors::FatalException) { build(figure("fig-a") + table("fig-a")) }
    assert_includes error.message, "two numbered figures, tables or statements with the id \"fig-a\""
  end

  def test_a_reference_to_nothing_stops_the_build
    error = assert_raises(Jekyll::Errors::FatalException) { build("{% ref fig-missing %}\n\n#{figure('fig-a')}") }
    assert_includes error.message, "refers to \"fig-missing\", which no numbered figure, table or statement"
  end

  def test_captions_hold_markdown_and_math
    doc = build(figure("fig-a", "Power for *small* $\\delta$.") + table("tab-a", "Runs for $n = 50$."))

    caption = doc.at_css("figure figcaption")
    assert_equal "em", caption.at_css("em")&.name
    assert caption.at_css('[role="math"]'), "math in a caption goes through the math preprocessor"
    table = doc.at_css("table#tab-a")
    assert_equal "caption", table.element_children.first.name, "a table's caption is its first child"
    assert_includes table.at_css("caption").text, "Table 1. Runs for"
  end

  def test_a_table_tag_needs_exactly_one_table
    error = assert_raises(StandardError) { build("{% table id=\"tab-a\" %}\nNo table here.\n{% endtable %}") }
    assert_includes error.message, "holds 0 tables"
  end

  def test_attributes_are_escaped_and_the_image_takes_the_baseurl
    doc = build(figure("fig-a", alt: "The 'null' <model> & more"), config: { "baseurl" => "/blog" })

    img = doc.at_css("figure img")
    assert_equal "/blog/assets/img/fig-a.png", img["src"]
    assert_equal "The 'null' <model> & more", img["alt"]
  end

  def test_labels_follow_the_page_language
    doc = build("{% ref tab-a %}\n\n#{figure('fig-a')}\n#{table('tab-a')}", front_matter: "lang: pt\n")

    assert_equal ["Figura 1.", "Tabela 1."], doc.css(".datalog-ref-label").map(&:text)
    assert_equal "Tabela 1", doc.at_css("a.datalog-ref").text
  end

  def test_pages_without_the_tags_are_left_alone
    html = build_html("![A plot](/assets/img/plot.png)\n\n| n | runs |\n|---|------|\n| 50 | 1000 |\n")

    refute_includes html, "data-ref"
    refute_includes html, "<caption>"
  end

  # Jekyll runs no hooks for excerpts: a post whose first paragraph refers to a
  # figure showed "fig-power" in its summary and in listings.
  def test_an_excerpt_takes_its_numbers_from_its_post
    FileUtils.mkdir_p(File.join(@dir, "_posts"))
    File.write(File.join(@dir, "_posts", "2024-05-01-power.md"),
               "---\nlayout: null\n---\nAs {% ref tab-runs %} and {% ref fig-power %} show.\n\n" \
               "#{figure('fig-power')}\n#{table('tab-runs')}")
    listing = build("{% for post in site.posts %}{{ post.excerpt }}{% endfor %}", config: { "baseurl" => "/blog" })

    links = listing.css("a.datalog-ref").to_h { |link| [link.text, link["href"]] }
    post = "/blog/2024/05/01/power.html"
    assert_equal({ "Table 1" => "#{post}#tab-runs", "Figure 1" => "#{post}#fig-power" }, links)
  end

  def test_an_invalid_id_is_rejected
    error = assert_raises(StandardError) { build("{% ref 2-fig %}") }
    assert_includes error.message, "needs an id that starts with a letter"
  end

  def test_print_styles_keep_numbered_targets_whole
    css = SiteBuilder.read("assets/css/main.css")

    assert_match(/@media print\{[^}]*\[data-ref-target\]\{break-inside:avoid\}/, css)
  end

  private

  def build(body, config: {}, front_matter: "")
    Nokogiri::HTML5.fragment(build_html(body, config: config, front_matter: front_matter))
  end

  # A page with no layout, so the output is the page's own content.
  def build_html(body, config: {}, front_matter: "")
    FileUtils.mkdir_p(File.join(@dir, "_data"))
    FileUtils.cp_r(File.join(SiteBuilder.root, "_data", "i18n"), File.join(@dir, "_data"))
    File.write(File.join(@dir, "index.md"), "---\nlayout: null\n#{front_matter}---\n\n#{body}")
    site_config = Jekyll.configuration(
      "source" => @dir, "destination" => File.join(@dir, "_site"), "quiet" => true,
      "title" => "References", "url" => "https://example.org", "author" => { "name" => "Test" }
    ).merge(config)
    Jekyll::Site.new(site_config).process
    File.read(File.join(@dir, "_site", "index.html"))
  end
end
