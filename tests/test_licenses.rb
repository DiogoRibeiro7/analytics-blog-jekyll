# frozen_string_literal: true

require "nokogiri"
require "tmpdir"
require_relative "test_helper"
require_relative "../_plugins/licenses"

# The licence of an article's text and figures, and of its code samples
# (_plugins/licenses.rb): the reuse notice, the rel="license" links and the
# structured data (#251).
class LicensesTest < Minitest::Test
  DEMO_TITLE = "Statistical Analysis Blueprint for Experimental Design"
  CC_BY = "https://creativecommons.org/licenses/by/4.0/"
  MIT_URL = "https://spdx.org/licenses/MIT.html"
  INCLUDES = %w[components/license-notice.html components/license-link.html].freeze

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def page(**data)
    { "date" => Time.new(2024, 2, 20), "author" => "Ada Lovelace" }.merge(data.transform_keys(&:to_s))
  end

  def site(**config)
    { "author" => { "name" => "Test" } }.merge(config.transform_keys(&:to_s))
  end

  # --- the resolver ---

  def test_a_known_identifier_gives_a_name_and_a_url_however_it_is_spelt
    ["CC-BY-4.0", "cc by 4.0", "CC_BY_4.0", "CC BY"].each do |spelling|
      licence = Datalog::Licenses.content(page(license: spelling), site)

      assert_equal ["CC-BY-4.0", "CC BY 4.0", CC_BY], licence.values_at("id", "name", "url"), spelling
    end
    assert_equal "CC0 1.0", Datalog::Licenses.content(page(license: "cc0"), site)["name"]
    assert_equal "https://spdx.org/licenses/GPL-3.0-only.html", Datalog::Licenses.code(page(code_license: "GPL-3.0"), site)["url"]
  end

  def test_an_unknown_identifier_is_a_name_without_a_link
    licence = Datalog::Licenses.content(page(license: "ODC-By 1.0"), site)

    assert_equal "ODC-By 1.0", licence["name"]
    assert_nil licence["url"]
    assert_nil licence["id"]
  end

  def test_a_map_names_a_custom_licence_with_its_holder_and_year
    custom = { "name" => "OGL v3", "url" => "https://ogl/3/", "holder" => "The Lab", "year" => "2026" }
    licence = Datalog::Licenses.content(page(license: custom), site)

    assert_equal ["OGL v3", "https://ogl/3/", "The Lab", 2026], licence.values_at("name", "url", "holder", "year")
    assert_equal false, licence["people"], "a holder who is not an author is an organisation"
  end

  def test_a_map_whose_name_is_an_identifier_is_filled_in
    licence = Datalog::Licenses.content(page(license: { "name" => "CC-BY-SA-4.0", "holder" => "Ada Lovelace" }), site)

    assert_equal "CC BY-SA 4.0", licence["name"]
    assert_equal "https://creativecommons.org/licenses/by-sa/4.0/", licence["url"]
    assert_equal true, licence["people"], "a holder who is an author is a person"
  end

  def test_the_site_default_applies_unless_the_page_replaces_or_declines_it
    with_default = site(content_license: "CC-BY-4.0")

    assert_equal "CC BY 4.0", Datalog::Licenses.content(page, with_default)["name"]
    assert_equal "CC BY-SA 4.0", Datalog::Licenses.content(page(license: "CC-BY-SA-4.0"), with_default)["name"]
    assert_nil Datalog::Licenses.content(page(license: false), with_default)
    assert_nil Datalog::Licenses.content(page, site)
  end

  def test_datasets_and_packages_carry_their_own_licence_only
    with_default = site(content_license: "CC-BY-4.0")

    assert_nil Datalog::Licenses.content(page(collection: "datasets"), with_default)
    assert_equal "MIT", Datalog::Licenses.content(page(collection: "packages", license: "MIT"), with_default)["name"]
  end

  def test_the_holder_and_year_come_from_the_authors_and_the_date_unless_given
    licence = Datalog::Licenses.content(page(license: "CC-BY-4.0", authors: ["Ada Lovelace", "Alan Turing"]), site)

    assert_equal ["Ada Lovelace", "Alan Turing"], licence["holders"]
    assert_equal "Ada Lovelace, Alan Turing", licence["holder"]
    assert_equal true, licence["people"]
    assert_equal 2024, licence["year"]

    institutional = site(content_license: { "id" => "CC-BY-4.0", "holder" => "The Lab", "year" => 2020 })
    licence = Datalog::Licenses.content(page(license: "CC0-1.0"), institutional)

    assert_equal ["The Lab", 2020, false], licence.values_at("holder", "year", "people"),
                 "the site default's holder and year apply to a page that names another licence"
  end

  def test_all_rights_reserved_has_no_link
    licence = Datalog::Licenses.content(page(license: "All rights reserved"), site)

    assert_equal ["All rights reserved", nil, true], licence.values_at("name", "url", "reserved")
  end

  def test_the_code_licence_is_separate_from_the_content_licence
    with_defaults = site(content_license: "CC-BY-4.0", code_license: "MIT")

    assert_equal "MIT", Datalog::Licenses.code(page, with_defaults)["name"]
    assert_equal "Apache 2.0", Datalog::Licenses.code(page(code_license: "Apache-2.0"), with_defaults)["name"]
    assert_nil Datalog::Licenses.code(page(code_license: false), with_defaults)
    assert_nil Datalog::Licenses.code(page, site)
  end

  # --- the notice ---

  def test_the_notice_names_the_holder_and_links_each_licence
    doc = render("code_license: MIT\n", "content_license" => "CC-BY-4.0")
    notice = doc.at_css(".content-license")

    hrefs = notice.css("a[rel=license]").map { |link| link["href"] }

    assert_equal "© 2024 Test. Text and figures under CC BY 4.0. Code samples under MIT.", squeeze(notice.text)
    assert_equal [CC_BY, MIT_URL], hrefs
  end

  def test_the_notice_escapes_a_custom_licence
    doc = render("license:\n  name: Bold <b>terms</b> & more\n  url: https://example.org/?a=1&b=2\n  holder: A <i>Lab</i>\n")
    notice = doc.at_css(".content-license")

    assert_includes notice.inner_html, "Bold &lt;b&gt;terms&lt;/b&gt; &amp; more"
    assert_includes notice.inner_html, "A &lt;i&gt;Lab&lt;/i&gt;"
    assert_equal "https://example.org/?a=1&b=2", notice.at_css("a[rel=license]")["href"]
  end

  def test_all_rights_reserved_reads_as_a_sentence
    doc = render("license: all-rights-reserved\n")

    assert_equal "© 2024 Test. All rights reserved.", squeeze(doc.at_css(".content-license").text)
    assert_nil doc.at_css(".content-license a")
  end

  def test_a_page_that_declines_the_default_renders_nothing
    assert_nil render("license: false\n", "content_license" => "CC-BY-4.0").at_css(".content-license")
    assert_nil render("").at_css(".content-license")
  end

  def test_labels_follow_the_page_language
    doc = render("lang: pt\nlicense: CC-BY-4.0\n")

    assert_equal "© 2024 Test. Texto e figuras sob CC BY 4.0.", squeeze(doc.at_css(".content-license").text)
  end

  # --- the demo site ---

  def test_the_demo_post_carries_its_licences_in_the_notice_the_head_and_the_structured_data
    html = demo_post_html

    assert_includes html, %(<link rel="license" href="#{CC_BY}" />)
    assert_includes html, "© 2024 Diogo Ribeiro."
    text_terms = %(Text and figures under <a class="license-link" rel="license" href="#{CC_BY}">CC BY 4.0</a>.)

    assert_includes html, text_terms
    code_terms = %(Code samples under <a class="license-link" rel="license" href="#{MIT_URL}">MIT</a>.)

    assert_includes html, code_terms

    schema = JSON.parse(html[%r{<script type="application/ld\+json"[^>]*>(.*?)</script>}m, 1])

    assert_equal CC_BY, schema["license"]
    assert_equal 2024, schema["copyrightYear"]
    assert_equal({ "@type" => "Person", "name" => "Diogo Ribeiro" }, schema["copyrightHolder"])
  end

  def test_the_demo_dataset_links_its_own_licence
    dataset = SiteBuilder.site.collections["datasets"].docs.find { |doc| doc.data["license"] == "CC-BY-4.0" }
    refute_nil dataset, "expected a demo dataset licensed CC-BY-4.0"
    html = SiteBuilder.read(File.join(dataset.url, "index.html"))

    assert_includes html, %(<strong>License:</strong> <a class="license-link" rel="license" href="#{CC_BY}">CC BY 4.0</a>)
  end

  def test_print_styles_keep_the_licence_address
    css = SiteBuilder.read("assets/css/main.css")

    assert_match(/@media print\{\.content-license a\[href\]::after\{content:" \(" attr\(href\) "\)"\}\}/, css)
  end

  private

  def squeeze(text)
    text.gsub(/\s+/, " ").strip
  end

  def demo_post_html
    post = SiteBuilder.site.posts.docs.find { |doc| doc.data["title"] == DEMO_TITLE }
    refute_nil post, "expected the experimental design demo post to exist"
    SiteBuilder.read(File.join(post.url, "index.html"))
  end

  # A page holding the notice, with the theme's translations.
  def render(front_matter, config = {})
    INCLUDES.each do |name|
      FileUtils.mkdir_p(File.join(@dir, "_includes", File.dirname(name)))
      FileUtils.cp(File.join(SiteBuilder.root, "_includes", name), File.join(@dir, "_includes", name))
    end
    FileUtils.mkdir_p(File.join(@dir, "_data"))
    FileUtils.cp_r(File.join(SiteBuilder.root, "_data", "i18n"), File.join(@dir, "_data"))
    body = "{% include components/license-notice.html page=page %}"
    File.write(File.join(@dir, "index.html"), "---\nlayout: null\ndate: 2024-02-20\n#{front_matter}---\n\n#{body}\n")
    site_config = Jekyll.configuration(
      { "source" => @dir, "destination" => File.join(@dir, "_site"), "quiet" => true, "title" => "Licences",
        "url" => "https://example.org", "author" => { "name" => "Test" } }.merge(config)
    )
    Jekyll::Site.new(site_config).process
    Nokogiri::HTML5.fragment(File.read(File.join(@dir, "_site", "index.html")))
  end
end
