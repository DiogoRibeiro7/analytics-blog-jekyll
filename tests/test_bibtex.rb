# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/datalog/citations/entry"
require_relative "../lib/datalog/plugin_system"
require_relative "../lib/datalog/plugins/citations"

# The BibTeX subset lib/datalog/citations reads, and the one shape its
# entries, CSL-JSON items and front-matter entries take (#289).
class BibTeXTest < Minitest::Test
  BibTeX = Datalog::Citations::BibTeX
  Entry = Datalog::Citations::Entry
  WORDS = { and: "and", et_al: "et al.", no_date: "n.d." }.freeze

  def parse(text)
    BibTeX.parse(text)
  end

  def entry(text)
    Entry.from_bibtex(parse(text).first)
  end

  def test_reads_braced_quoted_numeric_and_macro_values_joined_with_hashes
    records = parse(<<~'BIB')
      @string{jrai = "Journal of {AI}"}
      @comment{skipped {nested} text}
      @preamble{ "\newcommand{\noop}[1]{}" }
      Text between entries is skipped.
      @Article{a1, title = {One {Two}}, journal = jrai # " Letters", year = 2020, month = mar}
      @book(b2, title = "Quoted {\"U}ber", note = {a {nested {deeply}} value})
    BIB

    assert_equal(%w[a1 b2], records.map { |record| record["key"] })
    assert_equal "article", records.first["type"]
    assert_equal({ "title" => "One {Two}", "journal" => "Journal of {AI} Letters", "year" => "2020", "month" => "3" },
                 records.first["fields"])
    assert_equal "Über", BibTeX.latex_to_text(records.last["fields"]["title"].delete_prefix("Quoted "))
    assert_equal "a nested deeply value", BibTeX.latex_to_text(records.last["fields"]["note"])
  end

  def test_turns_latex_into_the_characters_it_stands_for
    text = BibTeX.latex_to_text(<<~'TEX'.chomp)
      M{\"u}ller \"o \'e \`a \^o \~n \c{c} \v{S} {\ss} {\o} \& 50\% \{x\} 1--2---3 A~B \emph{Word} \TeX
    TEX

    assert_equal "Müller ö é à ô ñ ç Š ß ø & 50% {x} 1\u20132\u20143 A\u00A0B Word TeX", text
  end

  def test_a_url_command_is_not_an_accent
    assert_equal "https://example.org/x", BibTeX.latex_to_text('\url{https://example.org/x}')
  end

  def test_names_split_on_and_keep_braced_organisations_and_particles
    names = entry(<<~BIB).authors
      @article{x, author = {Müller, Jörg and Ada Smith and {World Health Organization} and Ludwig van Beethoven and others}}
    BIB

    assert_equal [["Müller", "Jörg", nil], ["Smith", "Ada", nil], [nil, nil, "World Health Organization"],
                  ["van Beethoven", "Ludwig", nil]], names.map(&:to_a)
    assert entry("@article{x, author = {A, B and others}}").others
  end

  def test_a_malformed_entry_names_its_line
    error = assert_raises(BibTeX::ParseError) { parse("\n\n@article{x, title = {unclosed") }

    assert_includes error.message, "line 3"
  end

  def test_the_entry_types_and_fields_map_onto_one_shape
    thesis = entry("@phdthesis{t, author = {Lee, Kim}, title = {A Thesis}, school = {MIT}, year = {2019}}")
    chapter = entry("@incollection{c, title = {Ch}, booktitle = {The Book}, year = {2001}, " \
                    "howpublished = {\\url{https://example.org/ch}}}")

    assert_equal ["thesis", "MIT"], [thesis.type, thesis.publisher]
    assert_equal ["chapter", "The Book", "https://example.org/ch"], [chapter.type, chapter.container, chapter.url]
  end

  def test_only_http_addresses_and_dois_become_links
    assert_equal "https://doi.org/10.1234/x.5", entry("@misc{a, doi = {https://doi.org/10.1234/x.5}}").link
    assert_equal "https://doi.org/10.1234/x.5", entry("@misc{a, doi = {doi:10.1234/x.5}}").link
    assert_nil entry("@misc{a, url = {javascript:alert(1)}}").link
    assert_nil entry("@misc{a, doi = {not-a-doi}, url = {/relative}}").link
  end

  def test_in_text_names_follow_the_count_of_authors
    one = entry("@misc{a, author = {Smith, Ada}, year = 2020}")
    two = entry("@misc{a, author = {Smith, Ada and Jones, Bo}}")
    three = entry("@misc{a, author = {Smith, Ada and Jones, Bo and Li, Cy}}")
    none = entry("@misc{a, title = {A Long Title With Many Words}}")

    assert_equal "Smith", one.names_in_text(WORDS)
    assert_equal "Smith and Jones", two.names_in_text(WORDS)
    assert_equal "Smith et al.", three.names_in_text(WORDS)
    assert_equal "A Long Title With\u2026", none.names_in_text(WORDS)
    assert_equal "n.d.", two.year_or(WORDS[:no_date])
  end

  def test_the_reference_is_escaped_html_in_the_manner_of_apa
    html = entry(<<~BIB).reference_html(WORDS)
      @article{a, author = {Smith, Ada Beth and Jones, Bo}, title = {On <b>bold</b> claims},
               journal = {J. Stat}, volume = {3}, number = {2}, pages = {1--9}, year = {2020}, doi = {10.1234/x}}
    BIB

    assert_equal "Smith, A. B. and Jones, B. (2020). On &lt;b&gt;bold&lt;/b&gt; claims. <em>J. Stat</em>, 3(2), " \
                 "1\u20139. <a href=\"https://doi.org/10.1234/x\" rel=\"noopener noreferrer\">https://doi.org/10.1234/x</a>",
                 html
  end

  def test_csl_json_and_front_matter_entries_take_the_same_shape
    csl = Entry.from_csl("id" => "c1", "type" => "book", "title" => "A Book",
                         "author" => [{ "family" => "Ng", "given" => "Mei" }, { "literal" => "The Lab" }],
                         "issued" => { "date-parts" => [[2019, 5, 1]] }, "publisher" => "Press")
    front = Entry.from_front_matter("id" => "f1", "title" => "Paper", "authors" => "Doe, Jo and Roe, Al",
                                    "journal" => "J", "year" => 2021, "url" => "https://example.org")
    plain = Entry.from_front_matter("Smith and Jones (2020), a whole reference")

    assert_equal ["c1", "book", "2019", ["Ng", "The Lab"]],
                 [csl.key, csl.type, csl.year, csl.authors.map(&:family_name)]
    assert_equal ["f1", "2021", "https://example.org", %w[Doe Roe]],
                 [front.key, front.year, front.link, front.authors.map(&:family_name)]
    assert_equal "smith-and-jones-2020-a-whole-reference", plain.key
  end

  def test_metadata_describes_the_work
    work = entry(<<~BIB)
      @inproceedings{a, author = {Smith, Ada}, title = {T; with semicolon}, booktitle = {Conf},
                     pages = {10--12}, year = {2020}, doi = {10.1234/x}}
    BIB

    assert_equal "citation_title=T, with semicolon; citation_author=Smith, Ada; citation_publication_date=2020; " \
                 "citation_conference_title=Conf; citation_firstpage=10; citation_lastpage=12; citation_doi=10.1234/x",
                 work.highwire
    assert_equal({ "@type" => "CreativeWork", "name" => "T; with semicolon",
                   "author" => [{ "@type" => "Person", "name" => "Ada Smith" }], "datePublished" => "2020",
                   "isPartOf" => "Conf", "sameAs" => "https://doi.org/10.1234/x" }, work.json_ld)
  end

  def test_the_tag_takes_keys_and_a_quoted_or_bare_locator
    parse = Datalog::Plugins::Citations.method(:parse_markup)

    assert_equal [%w[a b], "loc|fig. 2 and table 1"], parse.call(%(a b loc="fig. 2 and table 1"))
    assert_equal [%w[a], "p|12"], parse.call("a p='12'")
    assert_equal [%w[a], "pp|3-9"], parse.call("a a pp=3-9")
    assert_raises(Liquid::ArgumentError) { parse.call("a page=3") }
  end

  # Long runs of one character took quadratic time in the regular expressions
  # these replaced; a reader of the site's own files should not be that slow.
  def test_long_inputs_are_read_in_linear_time
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Datalog::Plugins::Citations.parse_markup("a" * 200_000)
    Datalog::Citations::Entry.front_matter_names("#{' ' * 200_000}x")
    Datalog::Citations::Entry.bibtex_names("Smith,#{' ' * 20_000}Ada and #{' ' * 20_000}Lee, Bo")

    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 2
  end
end
