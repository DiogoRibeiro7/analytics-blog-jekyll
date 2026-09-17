# frozen_string_literal: true

require "json"
require "nokogiri"
require_relative "test_helper"

# The model every author surface reads (_plugins/authors.rb). A post named one
# author, `author: john_doe` put "john_doe" in the byline while the card looked
# the key up in _data/authors.yml, the research layout gave every author the
# site author's ORCID, and JSON-LD listed the site author's profiles only when
# an ORCID was set (#252).
class AuthorsTest < Minitest::Test
  SITE = {
    "author" => { "name" => "Site Author", "affiliation" => "Home University", "orcid" => "0000-0001-2345-6789",
                  "github" => "siteauthor", "twitter" => "siteauthor" },
    "data" => { "authors" => { "jane_doe" => { "name" => "Jane Doe", "affiliation" => "Example Institute",
                                               "orcid" => "https://orcid.org/0000-0002-1825-0097",
                                               "url" => "https://jane.example.org" } } }
  }.freeze

  def authors(page, site = SITE)
    Datalog::Authors.authors(page, site)
  end

  def names(list)
    list.map { |author| author["name"] }
  end

  def only(list)
    assert_equal 1, list.size, list.inspect
    list.first
  end

  def test_a_page_without_authors_has_the_site_author
    author = only(authors({}))

    assert_equal "Site Author", author["name"]
    assert_equal "Home University", author["affiliation"]
    assert author["site_author"]
    assert_equal %w[https://orcid.org/0000-0001-2345-6789 https://github.com/siteauthor https://twitter.com/siteauthor],
                 author["same_as"]
    assert_empty authors({}, {}), "a site without an author has no default author"
  end

  def test_authors_keep_their_order_and_their_own_profiles
    list = authors("authors" => ["jane_doe", { "name" => "Guest Writer", "orcid" => "0000-0003-1419-2405" },
                                 "Site Author"])

    assert_equal ["Jane Doe", "Guest Writer", "Site Author"], names(list)
    jane, guest, site_author = list
    assert_equal ["Example Institute", "https://jane.example.org"], jane.values_at("affiliation", "url")
    assert_nil guest["affiliation"], "a guest author does not get the site author's affiliation"
    assert_equal ["https://orcid.org/0000-0003-1419-2405"], guest["same_as"]
    refute guest["site_author"]
    assert_equal "Home University", site_author["affiliation"]
  end

  def test_a_map_entry_overrides_its_data_record
    jane = only(authors("authors" => [{ "id" => "jane_doe", "affiliation" => "Visiting Lab" }]))

    assert_equal ["Jane Doe", "Visiting Lab"], jane.values_at("name", "affiliation")
  end

  def test_the_single_author_forms_still_work
    assert_equal ["Jane Doe"], names(authors("author" => "jane_doe"))
    assert_equal ["Guest"], names(authors("author" => { "name" => "Guest" }))
    assert_equal %w[Ann Bob], names(authors("authors" => "Ann; Bob"))
    assert_equal ["Jane Doe"], names(authors("authors" => [], "author" => "jane_doe"))
  end

  def test_author_affiliation_applies_to_a_single_author
    guest = only(authors("author" => "Guest", "author_affiliation" => "Guest Institute"))
    assert_equal "Guest Institute", guest["affiliation"]
    assert_nil only(authors("author_affiliation" => ""))["affiliation"], "an empty affiliation removes the site's"
    both = authors("authors" => %w[Guest jane_doe], "author_affiliation" => "X")
    assert_equal([nil, "Example Institute"], both.map { |author| author["affiliation"] })
  end

  def test_contributors_are_listed_apart_with_their_roles
    page = { "contributors" => [{ "name" => "Ada Curator", "role" => "Data curation" }, "jane_doe", " "] }
    contributors = Datalog::Authors.contributors(page, SITE)

    assert_equal([["Ada Curator", "Data curation"], ["Jane Doe", nil]],
                 contributors.map { |contributor| contributor.values_at("name", "role") })
    assert_equal ["Site Author"], names(authors(page))
  end

  def test_profiles_do_not_depend_on_an_orcid
    site = { "author" => { "name" => "Site Author", "github" => "siteauthor" } }

    assert_equal ["https://github.com/siteauthor"], only(authors({}, site))["same_as"]
  end
end

# What the templates make of the model, rendered against the demo site, whose
# author is Diogo Ribeiro.
class AuthorMarkupTest < Minitest::Test
  PAGE = {
    "title" => "A collaborative analysis", "url" => "/collaboration/", "layout" => "post",
    "content" => "<p>Words</p>", "date" => Time.utc(2024, 5, 1),
    "authors" => ["Diogo Ribeiro", { "name" => "Guest <Writer>", "affiliation" => "Lab & Co",
                                     "url" => "https://guest.example", "biography" => "Studies missing data." }],
    "contributors" => [{ "name" => "Ada Curator", "role" => "Data curation" }]
  }.freeze

  def render(source, page = PAGE)
    template = Liquid::Template.parse(source)
    template.render!({ "site" => SiteBuilder.payload["site"], "page" => page }, registers: { site: SiteBuilder.site })
  end

  def json_ld(page = PAGE)
    html = render("{% include meta/schema.html page=page %}", page)
    JSON.parse(html[%r{<script type="application/ld\+json"[^>]*>(.*?)</script>}m, 1])
  end

  def test_json_ld_lists_each_author_and_contributor_as_a_person
    data = json_ld

    diogo, guest = data["author"]
    assert_equal(["Diogo Ribeiro", "Guest <Writer>"], data["author"].map { |author| author["name"] })
    assert_includes diogo["sameAs"], "https://github.com/DiogoRibeiro7"
    assert_equal({ "@type" => "Person", "name" => "Guest <Writer>", "url" => "https://guest.example",
                   "affiliation" => { "@type" => "Organization", "name" => "Lab & Co" } }, guest)
    assert_equal [{ "@type" => "Person", "name" => "Ada Curator" }], data["contributor"]

    assert_kind_of Hash, json_ld(PAGE.merge("authors" => ["Diogo Ribeiro"]))["author"], "one author stays an object"
  end

  def test_the_byline_links_and_escapes_each_person
    html = render("{% assign people = page | page_authors %}{% include components/author-list.html people=people %}" \
                  "{% assign helpers = page | page_contributors %}" \
                  "{% include components/author-list.html people=helpers property='contributor' %}")
    doc = Nokogiri::HTML5.fragment(html)

    assert_equal ["Diogo Ribeiro", "Guest <Writer>"], doc.css('[itemprop="author"] [itemprop="name"]').map(&:text)
    assert_includes html, '<a href="https://guest.example" itemprop="url"><span itemprop="name">Guest &lt;Writer&gt;</span>'
    assert_includes html, ">Lab &amp; Co<"
    assert_equal "Ada Curator (Data curation)", doc.at_css('[itemprop="contributor"]').text.strip
  end

  def test_citation_exports_name_every_author
    html = render("{% include components/citation-tools.html %}")

    assert_includes html, "author = { Diogo Ribeiro and Guest &lt;Writer&gt; }"
    assert_equal ["Diogo Ribeiro", "Guest &lt;Writer&gt;"], html.scan(/^AU  - (.+)$/).flatten
    assert_equal ["Diogo Ribeiro", "Guest &lt;Writer&gt;"], html.scan(/^%A (.+)$/).flatten
    assert_includes html, "Diogo Ribeiro, Guest &lt;Writer&gt; (2024). A collaborative analysis."
  end

  def test_compact_cards_leave_out_the_biography
    card = "{% assign people = page | page_authors %}{% assign guest = people[1] %}" \
           "{% include components/author-bio.html person=guest %}"
    compact = card.sub("person=guest %}", "person=guest compact=true %}")

    assert_includes render(card), "Studies missing data."
    refute_includes render(compact), "Studies missing data."
    assert_includes render(compact), '<span aria-hidden="true">G&lt;</span>', "initials come from the name"
  end

  def test_citation_meta_tags_describe_each_author
    head = SiteBuilder.read("2024/04/05/sql-optimization-guide/index.html")

    assert_includes head, '<meta name="citation_author" content="Diogo Ribeiro" />'
    assert_includes head, '<meta name="citation_author_institution" content="ESMAD - Instituto Politécnico do Porto" />'
    assert_includes head, '<meta name="citation_author_orcid" content="https://orcid.org/0009-0001-2022-7072" />'
  end
end
