# frozen_string_literal: true

require "json"
require_relative "test_helper"
require_relative "csp_policy_helpers"

# Who the site is, for search engines (#322): a WebSite node on the homepage
# with the site's name and other names, one Person with a stable @id that the
# homepage, the articles and a ProfilePage all point at, and control over the
# " | site title" a page's <title> ends with.
class SiteIdentityTest < Minitest::Test
  def resolve(config)
    Datalog::SiteIdentity.resolve({ "title" => "Site Title" }.merge(config))
  end

  def test_the_identity_is_off_unless_the_site_asks_for_it
    assert_nil resolve({})
    assert_nil resolve("site_identity" => false)
    assert_nil resolve("site_identity" => { "name" => "Jane Doe", "enabled" => false })
  end

  def test_the_identity_names_the_site_and_its_other_names
    assert_equal({ "name" => "Site Title", "alternate_names" => [] }, resolve("site_identity" => true))
    assert_equal({ "name" => "Jane Doe", "alternate_names" => %w[janedoe jd] },
                 resolve("site_identity" => { "name" => "Jane Doe",
                                              "alternate_names" => ["janedoe", " jd ", "Jane Doe"] }))
    assert_equal ["janedoe"], resolve("site_identity" => { "alternate_name" => "janedoe" })["alternate_names"]
  end

  def test_the_validator_checks_the_setting
    validate = lambda do |identity|
      config = { "title" => "T", "url" => "https://example.org", "author" => "A", "site_identity" => identity }
      Datalog::ConfigValidator.new.generate(Struct.new(:config).new(config))
    end

    assert_nil validate.call(true)
    assert_nil validate.call({ "name" => "Jane", "alternate_names" => ["jane"] })
    error = assert_raises(Jekyll::Errors::FatalException) { validate.call("Jane") }
    assert_includes error.message, "Invalid type for 'site_identity'"
  end

  def test_a_person_record_carries_its_identity_fields_as_lists
    site = { "author" => { "name" => "Jane Doe", "alternate_name" => "janedoe",
                           "roles" => ["Data scientist", "Lecturer"], "expertise" => "Statistics",
                           "github" => "janedoe",
                           "same_as" => ["https://mastodon.example/@jane", "https://github.com/janedoe"] } }
    jane = Datalog::Authors.site_author(site)

    assert_equal ["janedoe"], jane["alternate_names"]
    assert_equal ["Data scientist", "Lecturer"], jane["job_titles"]
    assert_equal ["Statistics"], jane["knows_about"]
    assert_equal ["https://github.com/janedoe", "https://mastodon.example/@jane"], jane["same_as"],
                 "profiles first, then the other addresses, each once"
  end
end

# A personal site built from the theme: the homepage is the owner's profile.
class PersonalSiteIdentityTest < Minitest::Test
  include CspPolicyHelpers

  ROOT = "https://jane.example/"
  PERSON_ID = "#{ROOT}#person".freeze
  WEBSITE_ID = "#{ROOT}#website".freeze
  AUTHOR = {
    "name" => "Jane Doe", "alternate_name" => "janedoe", "roles" => ["Lead Data Scientist", "Professor"],
    "avatar" => "/assets/img/jane.jpg", "bio" => "Writes about <em>missing data</em>.",
    "research_areas" => ["Missing data", "Causal inference"], "affiliation" => "Example University",
    "github" => "janedoe", "orcid" => "0000-0002-1825-0097", "same_as" => ["https://mastodon.example/@jane"]
  }.freeze
  HOME = { "layout" => "home", "title" => "Jane Doe", "schema_type" => "ProfilePage",
           "seo_title" => "Jane Doe (janedoe), data scientist", "seo_title_suffix" => false }.freeze

  def self.site
    @site ||= TestSite.build(url: "https://jane.example", title: "Jane's Notes", description: "Notes on statistics.",
                             permalink: "/:title/", author: AUTHOR,
                             site_identity: { "name" => "Jane Doe", "alternate_names" => ["janedoe"] }) do |source|
      source.theme("_layouts", "_includes", "_data")
      source.page("index.md", "Welcome.", HOME)
      source.post("2026-01-01-an-article", "Body.", "layout: post\ntitle: An article\n")
      source.post("2026-01-02-guest-article", "Body.", { "layout" => "post", "title" => "A guest article",
                                                         "author" => { "name" => "Guest Writer" } })
      source.page("described.md", "Body.", { "layout" => "default", "title" => "Described",
                                             "permalink" => "/described/", "seo_description" => "The SEO description.",
                                             "description" => "The plain description." })
      source.page("renamed.md", "Body.", { "layout" => "default", "title" => "Renamed", "permalink" => "/renamed/",
                                           "seo_title_suffix" => "Jane Doe" })
    end
  end

  def html(path)
    self.class.site.read(path)
  end

  def json_ld(path)
    Nokogiri::HTML5(html(path)).css('script[type="application/ld+json"]').map { |script| JSON.parse(script.text) }
  end

  # Every node on the page, whether a script holds one or a @graph of them.
  def nodes(path)
    json_ld(path).flat_map { |data| data["@graph"] || [data] }
  end

  def node(path, type)
    found = nodes(path).select { |item| item["@type"] == type }
    assert_equal 1, found.size, "#{path} should have one #{type}: #{found.inspect}"
    found.first
  end

  def test_the_homepage_names_the_site
    website = node("index.html", "WebSite")

    assert_equal WEBSITE_ID, website["@id"]
    assert_equal ROOT, website["url"]
    assert_equal "Jane Doe", website["name"]
    assert_equal "janedoe", website["alternateName"]
    assert_equal "Notes on statistics.", website["description"]
    assert_equal({ "@id" => PERSON_ID }, website["publisher"])
    assert_includes html("index.html"), '<meta property="og:site_name" content="Jane Doe" />'
  end

  def test_the_homepage_defines_the_person_in_full
    person = nodes("index.html").find { |item| item["@type"] == "Person" && item.key?("jobTitle") }

    assert_equal PERSON_ID, person["@id"]
    assert_equal ["Jane Doe", "janedoe", "#{ROOT}assets/img/jane.jpg"],
                 person.values_at("name", "alternateName", "image")
    assert_equal ["Lead Data Scientist", "Professor"], person["jobTitle"]
    assert_equal "Writes about missing data.", person["description"]
    assert_equal ["Missing data", "Causal inference"], person["knowsAbout"]
    assert_equal({ "@type" => "Organization", "name" => "Example University" }, person["affiliation"])
    assert_equal ["https://orcid.org/0000-0002-1825-0097", "https://github.com/janedoe", "https://mastodon.example/@jane"],
                 person["sameAs"]
  end

  def test_a_profile_page_has_its_person_as_main_entity
    profile = node("index.html", "ProfilePage")

    assert_equal ROOT, profile["@id"]
    assert_equal({ "@id" => WEBSITE_ID }, profile["isPartOf"])
    assert_equal [PERSON_ID, "Jane Doe"], profile["mainEntity"].values_at("@id", "name")
    refute profile.key?("mainEntityOfPage"), "a ProfilePage is the page; it is not the main entity of another"
  end

  def test_every_json_ld_block_keeps_the_pages_nonce
    page = html("index.html")
    nonce = policy_directives(page)["script-src"].join(" ")[/'nonce-([^']+)'/, 1]
    scripts = Nokogiri::HTML5(page).css('script[type="application/ld+json"]')

    assert_equal 2, scripts.size, "the page's own node, then the site's"
    assert_equal [nonce], scripts.map { |script| script["nonce"] }.uniq
  end

  def test_the_title_suffix_can_be_left_out_or_replaced
    assert_includes html("index.html"), "<title>Jane Doe (janedoe), data scientist</title>"
    assert_includes html("renamed/index.html"), "<title>Renamed | Jane Doe</title>"
    assert_includes html("described/index.html"), "<title>Described | Jane&#39;s Notes</title>",
                    "the default is unchanged"
  end

  def test_an_article_points_at_the_same_person
    article = node("an-article/index.html", "TechArticle")

    assert_equal PERSON_ID, article["author"]["@id"]
    assert_equal "Lead Data Scientist", article["author"]["jobTitle"].first
    assert_equal PERSON_ID, article["publisher"]["@id"]
    assert_equal "#{ROOT}an-article/", article.dig("mainEntityOfPage", "@id"), "the article's own shape is kept"
    types = nodes("an-article/index.html").map { |item| item["@type"] }
    refute_includes types, "WebSite", "only the homepage names the site"
    refute article.key?("isPartOf")
  end

  def test_a_guest_author_is_not_the_site_person
    article = node("guest-article/index.html", "TechArticle")

    assert_equal({ "@type" => "Person", "name" => "Guest Writer" }, article["author"])
    assert_equal PERSON_ID, article["publisher"]["@id"], "the site still publishes it"
  end

  # The meta description and the JSON-LD read the same fields in the same order.
  def test_the_json_ld_description_follows_the_meta_description
    page = html("described/index.html")

    assert_includes page, '<meta name="description" content="The SEO description." />'
    assert_equal "The SEO description.", node("described/index.html", "WebPage")["description"]
  end
end

# The same template for sites that have not asked for any of it, and for a
# site that an organization publishes.
class SiteIdentityDefaultsTest < Minitest::Test
  # absolute_url reads the registered site, which is the demo's.
  ROOT = "https://diogoribeiro7.github.io/"

  def render_schema(site, page)
    site = { "title" => "Example Lab" }.merge(site)
    template = Liquid::Template.parse("{% include meta/schema.html page=page %}")
    html = template.render!({ "site" => site, "page" => page }, registers: { site: SiteBuilder.site })
    html.scan(%r{<script type="application/ld\+json"[^>]*>(.*?)</script>}m).map { |(json)| JSON.parse(json) }
  end

  def test_the_demo_homepage_keeps_its_web_page_schema
    scripts = Nokogiri::HTML5(SiteBuilder.read("index.html")).css('script[type="application/ld+json"]')
    data = scripts.map { |script| JSON.parse(script.text) }

    assert_equal ["WebPage"], data.map { |item| item["@type"] }, "no WebSite node without site_identity"
    assert_equal ROOT, data.first.dig("mainEntityOfPage", "@id")
    refute data.first.key?("isPartOf")
  end

  def test_an_organization_profile_page_names_the_publisher
    site = { "author" => { "name" => "Jane Doe" }, "site_identity" => true,
             "publisher" => { "type" => "Organization", "name" => "Example Lab", "logo" => "/logo.png" } }
    page = { "title" => "About the lab", "url" => "/about/", "schema_type" => "ProfilePage",
             "main_entity" => "publisher" }
    profile = render_schema(site, page).first

    assert_equal "ProfilePage", profile["@type"]
    assert_equal ["Organization", "#{ROOT}#organization", "Example Lab"],
                 profile["mainEntity"].values_at("@type", "@id", "name")
    assert_equal({ "@id" => "#{ROOT}#website" }, profile["isPartOf"])
  end

  def test_an_organization_publishes_the_site_in_the_identity_graph
    site = { "author" => { "name" => "Jane Doe" }, "site_identity" => true,
             "publisher" => { "type" => "Organization", "name" => "Example Lab" } }
    graph = render_schema(site, { "title" => "Home", "url" => "/" }).last["@graph"]

    assert_equal(%w[WebSite Organization], graph.map { |item| item["@type"] })
    assert_equal ["Example Lab", { "@id" => "#{ROOT}#organization" }],
                 [graph.first["name"], graph.first["publisher"]], "site_identity: true names the site by its title"
    assert_equal "#{ROOT}#organization", graph.last["@id"]
  end
end
