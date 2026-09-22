# frozen_string_literal: true

require_relative "test_helper"
require "cgi"
require "json"
require "nokogiri"

# A search result used to point at a whole page, which for a long methods post
# hands the reader a second search problem: find the paragraph. The index now
# records which passage sits under which heading (#336).
class SearchSectionsTest < Minitest::Test
  def sections_of(html)
    Datalog::SearchSections.split(html)
  end

  def titles(sections)
    sections.map { |section| section["title"] }
  end

  def test_each_heading_opens_a_section
    sections = sections_of(<<~HTML)
      <p>An opening paragraph.</p>
      <h2 id="method">Method</h2>
      <p>How it was done.</p>
      <h2 id="results">Results</h2>
      <p>What came of it.</p>
    HTML
    texts = sections.map { |section| section["content"] }

    assert_equal ["", "Method", "Results"], titles(sections)
    assert_equal ["An opening paragraph.", "How it was done.", "What came of it."], texts
  end

  # The text before the first heading belongs to the page, not to any section
  # of it, so it has no title and nothing to link to.
  def test_the_lead_paragraphs_are_an_untitled_section
    lead = sections_of("<p>Before any heading.</p><h2 id=\"a\">A</h2><p>After.</p>").first

    assert_equal "", lead["title"]
    assert_nil lead["anchor"]
    assert_equal 0, lead["level"]
    assert_equal "Before any heading.", lead["content"]
  end

  def test_a_page_without_headings_is_one_section
    sections = sections_of("<p>Just prose.</p><p>More of it.</p>")

    assert_equal 1, sections.size
    assert_equal "Just prose. More of it.", sections.first["content"]
  end

  def test_nothing_is_emitted_for_a_page_with_no_content
    assert_empty sections_of("")
    assert_empty sections_of("   \n  ")
  end

  def test_a_subsection_does_not_leak_into_the_section_above_it
    sections = sections_of(<<~HTML)
      <h2 id="method">Method</h2>
      <p>The outline.</p>
      <h3 id="sampling">Sampling</h3>
      <p>The detail.</p>
    HTML
    levels = sections.map { |section| section["level"] }

    assert_equal ["Method", "Sampling"], titles(sections)
    assert_equal "The outline.", sections.first["content"]
    assert_equal [2, 3], levels
  end

  def test_the_anchor_is_the_id_the_heading_already_carries
    sections = sections_of('<h2 id="checking-for-heteroscedasticity">Checking for heteroscedasticity</h2><p>Text.</p>')

    assert_equal "checking-for-heteroscedasticity", sections.first["anchor"]
  end

  # kramdown will number a duplicate heading id and a site can turn auto_ids
  # off altogether. Such a section still indexes; it links to the page.
  def test_a_heading_without_an_id_indexes_with_no_anchor
    sections = sections_of("<h2>Languages</h2><p>Python, R.</p>")

    assert_equal "Languages", sections.first["title"]
    assert_nil sections.first["anchor"]
    assert_equal "Python, R.", sections.first["content"]
  end

  # "1. Introduction" gives id="1-introduction", which is not a valid CSS
  # identifier. It is a perfectly good URL fragment, and the section link is a
  # href, so it is kept exactly as written — the contents list's handler fed
  # one to querySelector and the links died (#330).
  def test_an_id_that_starts_with_a_digit_is_kept_as_it_is
    sections = sections_of('<h2 id="1-introduction">1. Introduction</h2><p>Text.</p>')

    assert_equal "1-introduction", sections.first["anchor"]
  end

  def test_a_heading_inside_a_wrapper_still_splits_the_page
    sections = sections_of(<<~HTML)
      <p>Lead.</p>
      <div class="notebook-cell">
        <h2 id="loading">Loading the data</h2>
        <p>Inside the wrapper.</p>
      </div>
    HTML

    assert_equal ["", "Loading the data"], titles(sections)
    assert_equal "Inside the wrapper.", sections.last["content"]
  end

  # Their text is markup, not prose. A JSON-LD blob is not something anyone
  # searches for, and it would drown the section it sat in.
  def test_script_and_style_text_is_left_out
    sections = sections_of('<h2 id="a">A</h2><p>Prose.</p><script>var x = 1;</script><style>.a{color:red}</style>')

    assert_equal "Prose.", sections.first["content"]
  end

  def test_whitespace_is_squeezed_the_way_the_flattened_text_is
    sections = sections_of("<h2 id=\"a\">  A  heading  </h2><p>One.</p>\n\n<p>Two.</p>")

    assert_equal "A heading", sections.first["title"]
    assert_equal "One. Two.", sections.first["content"]
  end

  def test_the_text_of_a_figure_and_a_code_block_counts_as_the_sections_text
    sections = sections_of(<<~HTML)
      <h2 id="a">A</h2>
      <figure><img src="/p.png" alt="A plot"><figcaption>The caption.</figcaption></figure>
      <pre><code>import pandas</code></pre>
    HTML

    assert_includes sections.first["content"], "The caption."
    assert_includes sections.first["content"], "import pandas"
  end
end

# The same, read off the built index rather than the splitter.
class SearchSectionsIndexTest < Minitest::Test
  # Headings the layout puts around an article. A split over the finished page
  # would make "Reading notes" a section of every post.
  LAYOUT_HEADINGS = %w[post-info-heading post-taxonomy-heading reading-notes-heading post-comments-heading
                       post-related-heading webmentions-heading subscribe-heading footer-explore-heading
                       citation-tools-heading open-science-badges-heading].freeze

  def setup
    @index = SiteBuilder.json("search.json")
    @documents = @index["documents"]
  end

  def sections
    @documents.flat_map { |doc| doc["sections"] || [] }
  end

  def test_every_document_carries_its_sections
    @documents.each do |doc|
      assert_kind_of Array, doc["sections"], "#{doc['url']} should carry a sections array"
      doc["sections"].each do |section|
        assert_equal %w[anchor content level title].sort, section.keys.sort
      end
    end
  end

  def test_posts_are_split_at_their_headings
    posts = @documents.select { |doc| doc["type"] == "post" }
    split = posts.count { |doc| doc["sections"].size > 1 }

    assert_operator split, :>, posts.size / 2, "most posts have headings and should be split at them"
  end

  def test_the_headings_the_layout_adds_are_not_sections
    leaked = sections.select do |section|
      section["anchor"] && LAYOUT_HEADINGS.any? { |heading| section["anchor"].include?(heading) }
    end

    assert_empty leaked.map { |section| section["title"] },
                 "the split runs over the document's own content, not the finished page"
    assert(sections.none? { |section| section["title"] == "Reading notes" })
  end

  # `strip_html` leaves the page's flattened text with its entities, so R code
  # reads "model &lt;- lmer(...)" there; a section reads it as the characters
  # they stand for, which is both what the page shows and what anyone would
  # search for. The two are compared with that difference undone.
  def test_a_sections_text_is_the_pages_text
    @documents.each do |doc|
      page = Nokogiri::HTML5.fragment(doc["content"]).text
      doc["sections"].each do |section|
        next if section["content"].empty?

        # The first words are enough: whitespace around a heading is squeezed
        # differently in the two passes.
        opening = section["content"].split.first(4).join(" ")
        assert_includes page, opening, "#{doc['url']} section #{section['title'].inspect}"
      end
    end
  end

  # A page whose Liquid has not run by the time the index renders can carry a
  # heading id of "{{ group_name | slugify }}". A link to that fragment goes
  # nowhere, so the section keeps its text and points at the page instead.
  def test_the_deep_links_would_resolve
    anchored = sections.select { |section| section["anchor"] }

    refute_empty anchored
    anchored.each do |section|
      assert_equal section["anchor"], CGI.escape(section["anchor"]).gsub("%23", "#"),
                   "#{section['anchor'].inspect} is not usable as a URL fragment"
      refute_includes section["anchor"], "#", "an anchor is the fragment, not a URL"
    end
  end

  # Sectioning repeats the body text, which the issue expected to double the
  # file. It does not: gzip folds the duplicate away, and the index is served
  # compressed. This keeps that from drifting.
  def test_the_index_stays_within_its_budget
    bytes = SiteBuilder.read("search.json").bytesize
    per_document = bytes / @documents.size

    assert_operator per_document, :<, 6_000,
                    "#{bytes} bytes over #{@documents.size} documents is #{per_document} each"
  end
end
