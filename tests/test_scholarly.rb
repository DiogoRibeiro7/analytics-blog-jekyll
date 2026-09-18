# frozen_string_literal: true

require "nokogiri"
require "tmpdir"
require_relative "test_helper"
require_relative "../_plugins/scholarly"

# Scholarly discovery metadata (_plugins/scholarly.rb and
# _includes/meta/scholarly.html): which pages get the Highwire and Dublin
# Core tags, and what they carry (#247).
class ScholarlyTest < Minitest::Test
  INCLUDES = %w[meta/scholarly.html meta/publisher.html].freeze
  PAPER = <<~YAML
    scholarly: true
    date: 2024-02-20
    authors:
      - name: Ada Lovelace
        affiliation: Analytical Engines
        orcid: 0000-0002-1825-0097
    description: On the engine.
    doi: 10.1000/engine
    pdf_url: /papers/engine.pdf
    journal: Notes
    volume: 3
    number: 2
    pages: 12–34
    issn: 1234-5678
    keywords: [engines, notes]
  YAML

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def page(**data)
    { "title" => "Paper", "layout" => "post", "collection" => "posts" }.merge(data.transform_keys(&:to_s))
  end

  def site(**config)
    { "author" => { "name" => "Test" } }.merge(config.transform_keys(&:to_s))
  end

  def scholarly?(page, site)
    Datalog::Scholarly.scholarly?(page, site)
  end

  # --- which pages ---

  def test_a_post_is_not_scholarly_unless_it_or_the_site_says_so
    refute scholarly?(page, site)
    assert scholarly?(page(scholarly: true), site)
    assert scholarly?(page, site(scholarly: true))
    refute scholarly?(page(scholarly: false), site(scholarly: true))
    refute scholarly?(page(scholarly: "yes"), site(scholarly: true)), "only true opts a page in"
  end

  def test_a_research_article_is_scholarly_unless_it_says_otherwise
    assert scholarly?(page(layout: "research"), site)
    assert scholarly?(page(layout: "page", collection: "research"), site)
    refute scholarly?(page(layout: "research", scholarly: false), site)
  end

  def test_the_site_may_name_collections_and_layouts
    notebook = page(layout: "notebook", collection: "notebooks")

    assert scholarly?(notebook, site(scholarly: ["notebooks"]))
    refute scholarly?(page, site(scholarly: ["notebooks"]))
    assert scholarly?(page, site(scholarly: "notebooks, posts"))
    assert scholarly?(page(layout: "research"), site(scholarly: ["notebooks"]))
  end

  # --- the tags ---

  def test_a_scholarly_page_gets_the_highwire_tags
    doc = render(PAPER)

    assert_equal ["Paper"], metas(doc, "citation_title")
    assert_equal ["Ada Lovelace"], metas(doc, "citation_author")
    assert_equal ["Analytical Engines"], metas(doc, "citation_author_institution")
    assert_equal ["https://orcid.org/0000-0002-1825-0097"], metas(doc, "citation_author_orcid")
    assert_equal ["2024/02/20"], metas(doc, "citation_publication_date")
    assert_equal ["https://example.org/"], metas(doc, "citation_public_url")
    assert_equal ["https://example.org/"], metas(doc, "citation_fulltext_html_url")
    assert_equal ["https://example.org/papers/engine.pdf"], metas(doc, "citation_pdf_url")
    assert_equal ["10.1000/engine"], metas(doc, "citation_doi")
    assert_equal ["Notes"], metas(doc, "citation_journal_title")
    assert_equal %w[3], metas(doc, "citation_volume")
    assert_equal %w[2], metas(doc, "citation_issue")
    assert_equal %w[12], metas(doc, "citation_firstpage")
    assert_equal %w[34], metas(doc, "citation_lastpage")
    assert_equal ["1234-5678"], metas(doc, "citation_issn")
    assert_equal ["Test"], metas(doc, "citation_publisher")
    assert_equal ["en"], metas(doc, "citation_language")
    assert_equal ["engines; notes"], metas(doc, "citation_keywords")
  end

  def test_a_scholarly_page_gets_the_dublin_core_tags
    doc = render(PAPER, "content_license" => "CC-BY-4.0")

    assert_equal "http://purl.org/dc/elements/1.1/", doc.at_css("link[rel='schema.DC']")["href"]
    assert_equal ["Paper"], metas(doc, "DC.title")
    assert_equal ["Ada Lovelace"], metas(doc, "DC.creator")
    assert_equal ["2024-02-20"], metas(doc, "DC.date")
    assert_equal ["https://doi.org/10.1000/engine"], metas(doc, "DC.identifier")
    assert_equal %w[Text], metas(doc, "DC.type")
    assert_equal ["Test"], metas(doc, "DC.publisher")
    assert_equal ["https://creativecommons.org/licenses/by/4.0/"], metas(doc, "DC.rights")
    assert_equal ["On the engine."], metas(doc, "DC.description")
  end

  def test_each_of_several_authors_gets_their_own_tags_in_order
    doc = render(<<~YAML)
      scholarly: true
      authors:
        - name: Ada Lovelace
          affiliation: Analytical Engines
          orcid: 0000-0002-1825-0097
        - Alan Turing
    YAML
    author_tags = doc.css("meta").map { |meta| meta["name"] }.select { |name| name.to_s.start_with?("citation_author") }

    assert_equal ["Ada Lovelace", "Alan Turing"], metas(doc, "citation_author")
    assert_equal %w[citation_author citation_author_institution citation_author_orcid citation_author], author_tags,
                 "an author's institution and ORCID follow that author"
    assert_equal ["Ada Lovelace", "Alan Turing"], metas(doc, "DC.creator")
  end

  def test_citation_authors_names_the_indexed_authors_alone
    doc = render("scholarly: true\nauthor: Ada Lovelace\ncitation_authors: \"Ann Lee; Bo Kim\"\n")

    assert_equal ["Ann Lee", "Bo Kim"], metas(doc, "citation_author")
    assert_equal ["Ann Lee", "Bo Kim"], metas(doc, "DC.creator")
    assert_empty metas(doc, "citation_author_institution")
  end

  def test_a_field_the_page_lacks_leaves_its_tag_out
    doc = render("scholarly: true\nauthor: Ada Lovelace\n")

    optional = %w[citation_publication_date citation_pdf_url citation_doi citation_journal_title
                  citation_conference_title citation_volume citation_issue citation_firstpage citation_issn
                  citation_keywords DC.date DC.rights]
    optional.each { |name| assert_empty metas(doc, name), "#{name} has nothing to say" }
    assert_equal ["https://example.org/"], metas(doc, "DC.identifier"), "the URL stands in for a DOI"
    assert_empty doc.css("meta[content='']"), "no tag is emitted empty"
  end

  def test_a_doi_given_as_a_url_is_kept
    doc = render("scholarly: true\ndoi: https://doi.org/10.1000/engine\n")

    assert_equal ["https://doi.org/10.1000/engine"], metas(doc, "DC.identifier")
    assert_equal ["https://doi.org/10.1000/engine"], metas(doc, "citation_doi")
  end

  def test_the_tags_are_escaped
    doc = render("scholarly: true\ntitle: A <b>bold</b> & brave paper\nauthor: O'Brien <script>\n")

    assert_equal ["A bold & brave paper"], metas(doc, "citation_title")
    assert_includes @html, "content=\"A bold &amp; brave paper\""
    assert_equal ["O'Brien <script>"], metas(doc, "citation_author")
    assert_includes @html, "O&#39;Brien &lt;script&gt;"
  end

  def test_a_page_that_is_not_scholarly_gets_no_tags
    doc = render("author: Ada Lovelace\ndoi: 10.1000/engine\n")

    assert_empty doc.css("meta, link")
  end

  # --- the demo site ---

  def test_demo_posts_carry_the_tags_and_other_pages_do_not
    post = SiteBuilder.read("2024/04/05/sql-optimization-guide/index.html")

    assert_includes post, '<meta name="citation_title" content="'
    assert_includes post, '<meta name="citation_public_url" content="https://diogoribeiro7.github.io/2024/04/05/sql-optimization-guide/" />'
    assert_includes post, '<meta name="DC.creator" content="Diogo Ribeiro" />'
    refute_includes post, 'name="citation_orcid"'

    home = SiteBuilder.read("index.html")

    refute_includes home, 'name="citation_title"'
    refute_includes home, 'name="DC.title"'
  end

  private

  def metas(doc, name)
    doc.css("meta[name='#{name}']").map { |meta| meta["content"] }
  end

  # A page holding the include, with the site's author and publisher.
  def render(front_matter, config = {})
    INCLUDES.each do |name|
      FileUtils.mkdir_p(File.join(@dir, "_includes", File.dirname(name)))
      FileUtils.cp(File.join(SiteBuilder.root, "_includes", name), File.join(@dir, "_includes", name))
    end
    body = "{% include meta/scholarly.html %}"
    File.write(File.join(@dir, "index.html"), "---\nlayout: null\ntitle: Paper\n#{front_matter}---\n\n#{body}\n")
    site_config = Jekyll.configuration(
      { "source" => @dir, "destination" => File.join(@dir, "_site"), "quiet" => true, "title" => "Scholarly",
        "url" => "https://example.org", "author" => { "name" => "Test" } }.merge(config)
    )
    Jekyll::Site.new(site_config).process
    @html = File.read(File.join(@dir, "_site", "index.html"))
    Nokogiri::HTML5.fragment(@html)
  end
end
