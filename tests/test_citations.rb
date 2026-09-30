# frozen_string_literal: true

require "json"
require "nokogiri"
require_relative "test_helper"

# In-text citations from BibTeX, CSL-JSON or front matter (#289): numbered or
# author-year markers linked to a bibliography of the cited works, with links
# back, build errors for keys nothing defines, escaping, and the Highwire and
# JSON-LD metadata of what a page cites.
class CitationsTest < Minitest::Test
  BIB = <<~BIB
    @string{jrai = "Journal of Responsible {AI}"}
    @article{rubin1987,
      author = {Rubin, Donald B.},
      title = {Multiple Imputation for Nonresponse in Surveys},
      journal = {Wiley Series in Probability},
      year = {1987},
      doi = {10.1002/9780470316696}
    }
    @book{allison2001,
      author = {Allison, Paul D.},
      title = {Missing Data},
      publisher = {Sage},
      year = 2001
    }
    @article{vanbuuren2018,
      author = {van Buuren, Stef and Groothuis-Oudshoorn, Karin and Robitzsch, Alexander},
      title = {Flexible Imputation of Missing Data},
      journal = jrai # " Letters",
      year = {2018},
      volume = {5}, number = {2}, pages = {10--20},
      url = {https://stefvanbuuren.name/fimd/}
    }
    @misc{unused2020,
      author = {Nobody, Anna},
      title = {Never Cited},
      year = {2020}
    }
  BIB

  ARTICLE = <<~MARKDOWN
    Multiple imputation {% cite rubin1987 %} has critics {% cite allison2001 vanbuuren2018 %}.

    Its variance estimate {% cite rubin1987 p="76" %} is the usual one.
  MARKDOWN

  def build(body: ARTICLE, front_matter: {}, config: {}, files: { "refs/missing.bib" => BIB },
            name: "2026-01-01-missing")
    site = TestSite.build({ title: "Citations", permalink: "/:title/",
                            datalog_plugins: { "enabled" => ["datalog-citations"] } }.merge(config)) do |source|
      source.theme("_layouts", "_includes", "_data")
      files.each { |path, contents| source.write(path, contents) }
      front = { "layout" => "post", "title" => "Missing data", "bibliography" => "refs/missing.bib" }
      source.post(name, body, front.merge(front_matter).compact)
    end
    [site, site.document("#{name.sub(/\A\d{4}-\d{2}-\d{2}-/, '')}/index.html")]
  end

  def markers(doc)
    doc.css(".post-content .datalog-cite").map(&:text)
  end

  def bibliography(doc)
    doc.css(".datalog-bibliography > li")
  end

  # ------------------------------------------------------------ the criterion

  def test_a_post_with_a_bib_file_and_three_cites_numbers_and_links_them
    _, doc = build

    assert_equal ["[1]", "[2, 3]", "[1, p. 76]"], markers(doc)
    assert_equal(%w[cite-rubin1987 cite-allison2001 cite-vanbuuren2018], bibliography(doc).map { |li| li["id"] })
    doc.css(".post-content .datalog-cite a").each do |link|
      assert doc.at_css(link["href"].sub("#", "#")), "#{link['href']} reaches its entry"
    end
    assert_equal "ol", doc.at_css(".datalog-bibliography").name
    assert_equal "References", doc.at_css("#post-bibliography-heading").text
  end

  def test_each_entry_links_back_to_every_place_it_is_cited
    _, doc = build
    rubin = doc.at_css("#cite-rubin1987")
    back = rubin.css(".datalog-bibliography__back a").map { |link| link["href"] }

    assert_equal %w[#cite-ref-rubin1987-1 #cite-ref-rubin1987-2], back
    back.each { |href| assert doc.at_css(href), "#{href} is a citation in the text" }
    assert_equal "Back to citation 2", rubin.css(".datalog-bibliography__back a").last["aria-label"]
  end

  def test_the_entry_links_its_doi_or_its_address
    _, doc = build

    assert_equal "https://doi.org/10.1002/9780470316696", doc.at_css("#cite-rubin1987 a[rel]")["href"]
    assert_equal "https://stefvanbuuren.name/fimd/", doc.at_css("#cite-vanbuuren2018 a[rel]")["href"]
    assert_includes doc.at_css("#cite-vanbuuren2018").text, "Journal of Responsible AI Letters, 5(2), 10\u201320"
    assert_nil doc.at_css("#cite-allison2001 a[rel]"), "no DOI and no address, no link"
  end

  # -------------------------------------------------------------- the styles

  def test_author_year_names_the_authors_and_sorts_the_list
    _, doc = build(front_matter: { "citation_style" => "author-year" })

    assert_equal ["(Rubin 1987)", "(Allison 2001; van Buuren et al. 2018)", "(Rubin 1987, p. 76)"], markers(doc)
    assert_equal(%w[cite-allison2001 cite-rubin1987 cite-vanbuuren2018], bibliography(doc).map { |li| li["id"] })
    assert_equal "ul", doc.at_css(".datalog-bibliography").name
  end

  def test_the_site_sets_the_style_and_a_page_overrides_it
    _, site_wide = build(config: { citations: { "style" => "author-year" } })
    _, own = build(config: { citations: { "style" => "author-year" } }, front_matter: { "citation_style" => "numeric" })

    assert_equal "(Rubin 1987)", markers(site_wide).first
    assert_equal "[1]", markers(own).first
  end

  def test_author_year_tells_apart_two_works_of_one_author_and_year
    bib = <<~BIB
      @article{a, author = {Smith, Ada}, title = {First}, year = {2020}}
      @article{b, author = {Smith, Ada}, title = {Second}, year = {2020}}
      @article{c, author = {Smith, Ada and Jones, Bo}, title = {Third}, year = {2021}}
    BIB
    _, doc = build(body: "{% cite a %} {% cite b %} {% cite c %}", files: { "refs/missing.bib" => bib },
                   front_matter: { "citation_style" => "author-year" })

    assert_equal ["(Smith 2020a)", "(Smith 2020b)", "(Smith and Jones 2021)"], markers(doc)
    assert_includes doc.at_css("#cite-a").text, "(2020a)"
  end

  def test_the_words_follow_the_page_language
    _, doc = build(front_matter: { "lang" => "pt", "citation_style" => "author-year" },
                   config: { theme_options: { "localization" => { "default_locale" => "en",
                                                                  "locales" => %w[en pt] } } })

    assert_includes markers(doc), "(Allison 2001; van Buuren et al. 2018)"
    assert_includes doc.at_css("#cite-vanbuuren2018").text, "Groothuis-Oudshoorn, K. e Robitzsch, A."
    assert_equal "Voltar à citação 1", doc.at_css("#cite-rubin1987 .datalog-bibliography__back a")["aria-label"]
  end

  # --------------------------------------------------------- what is listed

  def test_only_cited_works_are_listed_unless_nocite_asks_for_more
    _, cited = build
    _, one = build(front_matter: { "nocite" => ["unused2020"] })
    _, all = build(body: "No citations in the text.", front_matter: { "nocite" => "all" })

    refute cited.at_css("#cite-unused2020")
    assert_equal "cite-unused2020", bibliography(one).last["id"]
    assert_equal 4, bibliography(all).size
  end

  def test_a_page_that_cites_nothing_has_no_bibliography
    _, doc = build(body: "Plain text.")

    assert_nil doc.at_css(".post-bibliography")
    assert_empty doc.css("meta[name='citation_reference']")
  end

  def test_front_matter_entries_and_csl_json_are_sources_too
    csl = JSON.generate([{ "id" => "csl2019", "type" => "article-journal", "title" => "From CSL",
                           "author" => [{ "family" => "Ng", "given" => "Mei" }],
                           "issued" => { "date-parts" => [[2019, 5]] }, "DOI" => "10.5555/csl.2019" }])
    _, doc = build(body: "{% cite csl2019 %} and {% cite inline2021 %}",
                   files: { "refs/more.json" => csl },
                   front_matter: { "bibliography" => ["refs/more.json"],
                                   "citations" => [{ "id" => "inline2021", "title" => "Inline",
                                                     "authors" => ["Doe, Jo"], "year" => 2021 }] })

    assert_equal ["[1]", "[2]"], markers(doc)
    assert_includes doc.at_css("#cite-csl2019").text, "Ng, M. (2019). From CSL."
    assert_includes doc.at_css("#cite-inline2021").text, "Doe, J. (2021). Inline."
  end

  def test_the_site_names_a_default_bibliography
    _, doc = build(front_matter: { "bibliography" => nil },
                   config: { citations: { "bibliography" => "refs/missing.bib" } })

    assert_equal "[1]", markers(doc).first
  end

  # ---------------------------------------------------------------- errors

  def test_an_unknown_key_stops_the_build_naming_the_page_and_the_key
    error = assert_raises(Jekyll::Errors::FatalException) { build(body: "{% cite nosuch2000 %}") }

    assert_includes error.message, "_posts/2026-01-01-missing.md"
    assert_includes error.message, "\"nosuch2000\""
    assert_includes error.message, "refs/missing.bib"
  end

  def test_a_key_two_entries_share_stops_the_build
    error = assert_raises(Jekyll::Errors::FatalException) do
      build(front_matter: { "citations" => [{ "id" => "rubin1987", "title" => "Again" }] })
    end

    assert_includes error.message, "_posts/2026-01-01-missing.md"
    assert_includes error.message, "\"rubin1987\""
  end

  def test_a_missing_or_malformed_bibliography_stops_the_build
    missing = assert_raises(Jekyll::Errors::FatalException) { build(front_matter: { "bibliography" => "refs/none.bib" }) }
    broken = assert_raises(Jekyll::Errors::FatalException) do
      build(files: { "refs/missing.bib" => "@article{x, title = {unclosed" })
    end

    assert_includes missing.message, "refs/none.bib"
    assert_includes broken.message, "refs/missing.bib"
    assert_includes broken.message, "line 1"
  end

  def test_citing_without_the_plugin_says_what_to_enable
    error = assert_raises(Liquid::ArgumentError) { build(config: { datalog_plugins: { "enabled" => [] } }) }

    assert_includes error.message, "datalog-citations"
  end

  # -------------------------------------------------------------- escaping

  def test_every_value_is_escaped_and_only_http_and_doi_become_links
    bib = <<~'BIB'
      @article{evil,
        author = {<img src=x onerror=alert(1)>, Eve},
        title = {<script>alert(1)</script>},
        journal = {J"our\&nal},
        year = {2020},
        url = {javascript:alert(1)}
      }
    BIB
    _, doc = build(body: %({% cite evil loc="<b>here</b>" %}), files: { "refs/missing.bib" => bib })
    entry = doc.at_css("#cite-evil")

    assert_empty doc.css(".post-content script, .post-bibliography script, img[onerror]")
    assert_includes entry.text, "<script>alert(1)</script>"
    assert_nil entry.at_css("a[href^='javascript']")
    assert_equal "[1, <b>here</b>]", markers(doc).first
  end

  def test_a_key_with_markup_is_refused
    assert_raises(Liquid::ArgumentError) { build(body: %({% cite a"b %})) }
  end

  # -------------------------------------------------------------- metadata

  def research(body)
    site = TestSite.build(title: "Citations", url: "https://example.org",
                          datalog_plugins: { "enabled" => ["datalog-citations"] }) do |source|
      source.theme("_layouts", "_includes", "_data")
      source.write("refs/missing.bib", BIB)
      source.page("paper.md", body, { "layout" => "research", "title" => "A paper", "date" => "2026-01-01",
                                      "bibliography" => "refs/missing.bib", "authors" => ["Ada Smith"] })
    end
    site.document("paper.html")
  end

  def json_ld_citation(doc)
    doc.css("script[type='application/ld+json']").map { |script| JSON.parse(script.text) }
       .find { |data| data["@type"] != "Organization" && data.key?("headline") }&.fetch("citation", nil)
  end

  def test_a_research_article_that_cites_describes_what_it_cites
    doc = research(ARTICLE)
    references = doc.css("meta[name='citation_reference']").map { |meta| meta["content"] }
    citation = json_ld_citation(doc)

    assert_equal 3, references.size
    assert_includes references.first, "citation_title=Multiple Imputation for Nonresponse in Surveys"
    assert_includes references.first, "citation_doi=10.1002/9780470316696"
    assert_equal(["Multiple Imputation for Nonresponse in Surveys", "Missing Data",
                  "Flexible Imputation of Missing Data"], citation.map { |work| work["name"] })
    assert_equal "https://doi.org/10.1002/9780470316696", citation.first["sameAs"]
    assert_equal [{ "@type" => "Person", "name" => "Donald B. Rubin" }], citation.first["author"]
    assert doc.at_css(".research-references .datalog-bibliography"), "the research layout lists what it cites"
  end

  def test_a_research_article_that_cites_nothing_describes_no_citations
    doc = research("No citations here.")

    assert_empty doc.css("meta[name='citation_reference']")
    assert_nil json_ld_citation(doc)
    assert_nil doc.at_css(".research-references")
  end

  # ----------------------------------------------------- plugin and search

  def test_the_plugin_loads_with_search_off_and_adds_to_the_index_with_it_on
    without, = build
    with, = build(config: { datalog_plugins: { "enabled" => %w[datalog-search datalog-citations] } })

    assert_equal ["datalog-citations"], without.jekyll.config.dig("datalog_plugin_state", "active")
    post = ->(site) { site.jekyll.posts.docs.first }
    assert_nil post.call(without).data.dig("datalog_search_extensions", "citations")
    assert_equal %w[allison2001 rubin1987 vanbuuren2018],
                 post.call(with).data.dig("datalog_search_extensions", "citations", "keys")
  end

  def test_an_excerpt_reads_its_citations_as_the_post_does
    site, = build(body: "Opening claim {% cite allison2001 %}.\n\nMore {% cite rubin1987 %}.")
    excerpt = Nokogiri::HTML.fragment(site.jekyll.posts.docs.first.data["excerpt"].output)

    assert_equal "[1]", excerpt.at_css(".datalog-cite").text
    assert_equal "/missing/#cite-allison2001", excerpt.at_css(".datalog-cite a")["href"]
  end

  def test_the_validator_takes_only_the_two_styles
    validate = lambda do |citations|
      config = { "title" => "T", "url" => "https://example.org", "author" => "A", "citations" => citations }
      Datalog::ConfigValidator.new.generate(Struct.new(:config).new(config))
    end

    assert_nil validate.call("style" => "author-year", "bibliography" => ["a.bib"])
    error = assert_raises(Jekyll::Errors::FatalException) { validate.call("style" => "apa") }
    assert_includes error.message, "Invalid value for 'citations.style'"
  end
end
