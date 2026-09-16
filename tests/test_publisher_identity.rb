# frozen_string_literal: true

require "json"
require_relative "test_helper"

# Who a page's JSON-LD, a post's microdata and the citation exports name as the
# publisher. The author's affiliation used to fill that role, so every post
# claimed the author's university published it (#240).
class PublisherIdentityTest < Minitest::Test
  POST = "2024/04/05/sql-optimization-guide/index.html"
  SITE_URL = "https://diogoribeiro7.github.io"
  DEFAULT_LOGO = {
    "@type" => "ImageObject",
    "url" => "#{SITE_URL}/assets/img/favicons/android-chrome-512x512.png",
    "width" => 512,
    "height" => 512
  }.freeze

  def schema_with_publisher(html)
    html.scan(%r{<script type="application/ld\+json"[^>]*>(.*?)</script>}m)
        .map { |(json)| JSON.parse(json) }
        .find { |data| data.key?("publisher") }
  end

  # Renders schema.html outside the site build, for settings the demo lacks.
  def render_schema(site, page = {})
    site = { "title" => "Example Site", "url" => SITE_URL }.merge(site)
    page = { "title" => "A post", "url" => "/a-post/", "layout" => "post", "content" => "<p>Words</p>" }.merge(page)
    template = Liquid::Template.parse("{% include meta/schema.html page=page %}")
    schema_with_publisher(template.render!({ "site" => site, "page" => page }, registers: { site: SiteBuilder.site }))
  end

  def test_the_demo_author_publishes_the_demo_and_keeps_their_affiliation
    ["index.html", POST].each do |path|
      data = schema_with_publisher(SiteBuilder.read(path))
      assert_equal({ "@type" => "Person", "name" => "Diogo Ribeiro", "url" => SITE_URL }, data["publisher"], path)
    end

    affiliation = schema_with_publisher(SiteBuilder.read(POST)).dig("author", "affiliation")
    assert_equal({ "@type" => "Organization", "name" => "ESMAD - Instituto Politécnico do Porto" }, affiliation)
  end

  def test_post_microdata_and_citations_do_not_name_the_affiliation
    html = SiteBuilder.read(POST)
    title = SiteBuilder.site.config["title"]

    assert_includes html, '<meta itemprop="publisher" content="Diogo Ribeiro" />'
    assert_includes html, "publisher = { #{title} },"
    assert_includes html, "PB  - #{title}"
    assert_includes html, "%I #{title}"
    refute_match(/(?:publisher = \{|PB  -|%I) ESMAD/, html)
  end

  # A site published by the author's institution names it, and gets the output
  # every site had before.
  def test_an_organization_named_in_the_configuration_publishes
    data = render_schema(
      "author" => { "name" => "Jane Doe", "affiliation" => "Example University" },
      "publisher" => { "type" => "Organization", "name" => "Example University" }
    )

    assert_equal(
      { "@type" => "Organization", "name" => "Example University", "url" => SITE_URL, "logo" => DEFAULT_LOGO },
      data["publisher"]
    )
    assert_equal({ "@type" => "Organization", "name" => "Example University" }, data["author"]["affiliation"])
  end

  def test_an_organization_defaults_to_the_site_title
    data = render_schema("publisher" => { "type" => "Organization" })

    assert_equal "Example Site", data["publisher"]["name"]
  end

  def test_an_organization_logo_and_url_are_made_absolute
    data = render_schema(
      "publisher" => { "type" => "Organization", "name" => "Example Lab", "url" => "/lab/",
                       "logo" => "/assets/img/lab-logo.png" }
    )

    assert_equal "#{SITE_URL}/lab/", data["publisher"]["url"]
    # The size is known only for the theme's own icon.
    assert_equal({ "@type" => "ImageObject", "url" => "#{SITE_URL}/assets/img/lab-logo.png" },
                 data["publisher"]["logo"])
  end

  def test_a_person_named_in_the_configuration_publishes_without_a_logo
    data = render_schema(
      "author" => { "name" => "Jane Doe" },
      "publisher" => { "type" => "Person", "name" => "John Roe", "url" => "https://john.example" }
    )

    assert_equal({ "@type" => "Person", "name" => "John Roe", "url" => "https://john.example" }, data["publisher"])
  end

  def test_the_author_publishes_when_only_a_name_is_configured
    data = render_schema("author" => "Jane Doe")

    assert_equal({ "@type" => "Person", "name" => "Jane Doe", "url" => SITE_URL }, data["publisher"])
    assert_equal "Jane Doe", data["author"]["name"]
    refute data["author"].key?("affiliation")
  end

  def test_the_site_title_publishes_when_there_is_no_author_name
    [{}, { "author" => "" }].each do |site|
      assert_equal(
        { "@type" => "Organization", "name" => "Example Site", "url" => SITE_URL, "logo" => DEFAULT_LOGO },
        render_schema(site)["publisher"]
      )
    end
  end

  def test_a_guest_author_does_not_get_the_site_authors_affiliation
    site = { "author" => { "name" => "Jane Doe", "affiliation" => "Example University" } }

    refute render_schema(site, "author" => "Guest Writer")["author"].key?("affiliation")
    assert_equal "Guest Institute",
                 render_schema(site, "author" => "Guest Writer", "author_affiliation" => "Guest Institute")
                   .dig("author", "affiliation", "name")
    # An empty affiliation in front matter means none, not an empty name.
    refute render_schema(site, "author_affiliation" => "")["author"].key?("affiliation")
  end

  def test_names_are_encoded_as_json
    data = render_schema("publisher" => { "type" => "Organization", "name" => 'The "Quoted" Lab & Co' })

    assert_equal 'The "Quoted" Lab & Co', data["publisher"]["name"]
  end
end
