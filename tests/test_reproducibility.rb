# frozen_string_literal: true

require "nokogiri"
require "tmpdir"
require_relative "test_helper"
require_relative "../_plugins/reproducibility"

# The "Reproduce this analysis" panel (_plugins/reproducibility.rb and
# _includes/components/reproducibility.html): the code, data, notebook,
# environment and results behind an article, with their identifiers (#246).
class ReproducibilityTest < Minitest::Test
  DEMO_TITLE = "MLOps Walkthrough with Jupyter Notebook Integration"
  REPO = "https://github.com/example/project"
  FULL = {
    "code" => { "url" => REPO, "ref" => "4f2c1ab" },
    "data" => { "doi" => "10.5281/zenodo.1234567", "version" => "v2" },
    "environment" => { "file" => "requirements.txt", "container" => "ghcr.io/example/project:1.4.0",
                       "archive" => "https://doi.org/10.5281/zenodo.7654321" },
    "notebook" => { "url" => "/notebooks/example/" },
    "results" => { "url" => "#{REPO}/releases/tag/results-v1", "version" => "results-v1" }
  }.freeze

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # Positional, since a bare `"key" => value` argument would be read as keywords.
  def resolve(value, baseurl = "")
    page = { "path" => "_posts/2026-01-01-a.md", "reproducibility" => value }
    Datalog::Reproducibility.resolve(page, { "baseurl" => baseurl })
  end

  def artifacts(value, baseurl = "")
    resolve(value, baseurl).fetch("artifacts").to_h { |artifact| [artifact["kind"], artifact] }
  end

  # --- the resolver ---

  def test_every_artifact_is_read_with_its_identifiers
    found = artifacts(FULL)

    assert_equal %w[code data notebook environment results], found.keys
    assert_equal [REPO, "github.com/example/project", true], found["code"].values_at("url", "label", "external")
    assert_equal ["4f2c1ab", "#{REPO}/tree/4f2c1ab"], found["code"].values_at("ref", "ref_url")
    assert_equal ["https://doi.org/10.5281/zenodo.1234567", "10.5281/zenodo.1234567", "v2"],
                 found["data"].values_at("url", "doi", "version")
    assert_equal ["/notebooks/example/", "/notebooks/example/", false],
                 found["notebook"].values_at("url", "label", "external")
    assert_equal ["requirements.txt", "#{REPO}/blob/4f2c1ab/requirements.txt", "ghcr.io/example/project:1.4.0"],
                 found["environment"].values_at("file", "file_url", "container")
    assert_equal ["https://doi.org/10.5281/zenodo.7654321", "doi.org/10.5281/zenodo.7654321"],
                 found["environment"].values_at("archive", "archive_label")
    assert_equal "results-v1", found["results"]["version"]
  end

  def test_partial_metadata_lists_only_what_is_given
    assert_equal %w[data], artifacts("data" => "https://doi.org/10.1/x").keys, "a bare URL is an artifact"
    assert_equal %w[environment], artifacts("environment" => { "container" => "ghcr.io/x:1" }).keys
    refute artifacts("environment" => { "container" => "ghcr.io/x:1" })["environment"].key?("url")
    assert_nil resolve({})
    assert_nil resolve("code" => nil, "data" => "")
    assert_nil resolve("Notes about reproducing this."), "free text is the research layout's notes, not artifacts"
    assert_nil resolve(nil)
  end

  def test_site_paths_take_the_baseurl_and_a_label_replaces_the_address
    found = artifacts({ "notebook" => { "url" => "/notebooks/x/", "label" => "The notebook" },
                        "environment" => { "file" => "/env/requirements.txt" } }, "/blog")

    assert_equal ["/blog/notebooks/x/", "The notebook"], found["notebook"].values_at("url", "label")
    assert_equal "/blog/env/requirements.txt", found["environment"]["file_url"]
  end

  def test_refs_and_files_link_on_known_hosts_only
    gitlab = artifacts("code" => { "url" => "https://gitlab.com/g/p/", "ref" => "v1" }, "environment" => { "file" => "env.yml" })

    assert_equal "https://gitlab.com/g/p/-/tree/v1", gitlab["code"]["ref_url"]
    assert_equal "https://gitlab.com/g/p/-/blob/v1/env.yml", gitlab["environment"]["file_url"]

    elsewhere = artifacts("code" => { "url" => "https://forge.example/p", "ref" => "v1" }, "environment" => { "file" => "env.yml" })

    assert_equal "v1", elsewhere["code"]["ref"]
    refute elsewhere["code"].key?("ref_url")
    refute elsewhere["environment"].key?("file_url"), "a file is shown as text when it cannot be linked"

    unpinned = artifacts("code" => REPO, "environment" => { "file" => "env.yml" })

    assert_equal "#{REPO}/blob/HEAD/env.yml", unpinned["environment"]["file_url"]
    refute artifacts("environment" => { "file" => "env.yml" })["environment"].key?("file_url"), "no repository, no link"
  end

  def test_a_doi_may_be_given_in_any_form
    assert_equal "https://doi.org/10.1/x", artifacts("data" => { "url" => "doi:10.1/x" })["data"]["url"]
    assert_equal "10.1/x", artifacts("data" => { "doi" => "https://doi.org/10.1/x" })["data"]["doi"]
    assert_equal "https://doi.org/10.1/x", artifacts("data" => { "doi" => "doi:10.1/x" })["data"]["url"]
  end

  def test_an_unsafe_or_malformed_url_stops_the_build
    { "javascript:alert(1)" => "code", "github.com/example/project" => "code",
      "ftp://x/y" => "results" }.each do |bad, kind|
      error = assert_raises(Jekyll::Errors::FatalException) { resolve(kind => { "url" => bad }) }

      assert_includes error.message,
                      "_posts/2026-01-01-a.md reproducibility.#{kind}.url is #{bad.inspect}, which is not"
    end
    error = assert_raises(Jekyll::Errors::FatalException) { resolve("environment" => { "archive" => "data:text/html,x" }) }
    assert_includes error.message, "reproducibility.environment.archive"
  end

  # --- the panel ---

  def test_the_panel_lists_each_artifact_with_its_link_and_identifiers
    doc = render(FULL, "/blog")
    panel = doc.at_css("section.reproduce")

    assert_equal "Reproduce this analysis", doc.at_css("##{panel['aria-labelledby']}").text
    assert_equal ["Source code", "Data", "Notebook", "Environment", "Results"], panel.css("dt").map(&:text)
    code = panel.at_css(".reproduce__item--code")

    assert_equal [REPO, "external noopener", "github.com/example/project"],
                 [code.at_css("a.reproduce__link")["href"], code.at_css("a.reproduce__link")["rel"],
                  code.at_css("a.reproduce__link").text]
    assert_equal "at 4f2c1ab", squeeze(code.at_css(".reproduce__detail").text)
    assert_equal "#{REPO}/tree/4f2c1ab", code.at_css(".reproduce__detail a")["href"]
    data_details = panel.css(".reproduce__item--data .reproduce__detail").map { |detail| squeeze(detail.text) }

    assert_equal ["version v2", "DOI 10.5281/zenodo.1234567"], data_details
    notebook = panel.at_css(".reproduce__item--notebook a")

    assert_equal "/blog/notebooks/example/", notebook["href"]
    assert_nil notebook["rel"], "a site path is not external"
    environment = panel.at_css(".reproduce__item--environment")

    assert_equal "#{REPO}/blob/4f2c1ab/requirements.txt", environment.at_css("a code").parent["href"]
    assert_equal "Container ghcr.io/example/project:1.4.0", squeeze(environment.at_css(".reproduce__detail").text)
    assert_equal "Archived environment: doi.org/10.5281/zenodo.7654321", environment.css("a").last.text
  end

  def test_the_panel_escapes_what_it_shows_and_renders_nothing_without_artifacts
    doc = render("code" => { "url" => "https://example.org/?a=1&b=2", "label" => "A <b>repo</b>", "ref" => "v<1>" })

    assert_includes @html, "A &lt;b&gt;repo&lt;/b&gt;"
    assert_includes @html, "<code>v&lt;1&gt;</code>"
    assert_equal "https://example.org/?a=1&b=2", doc.at_css("a.reproduce__link")["href"]
    assert_nil render(nil).at_css(".reproduce")
  end

  def test_labels_follow_the_page_language
    doc = render({ "code" => { "url" => REPO, "ref" => "v1" } }, "", "pt")

    assert_equal "Reproduzir esta análise", doc.at_css(".reproduce__heading").text
    assert_equal ["Código-fonte"], doc.css("dt").map(&:text)
    assert_equal "em v1", squeeze(doc.at_css(".reproduce__detail").text)
  end

  # --- the demo site ---

  def test_the_demo_notebook_post_links_its_code_at_a_tag
    post = SiteBuilder.site.posts.docs.find { |doc| doc.data["title"] == DEMO_TITLE }
    refute_nil post
    html = SiteBuilder.read(File.join(post.url, "index.html"))

    assert_includes html, 'class="reproduce"'
    assert_includes html, 'href="https://github.com/DiogoRibeiro7/analytics-blog-jekyll/tree/v0.8.0"'
    assert_includes html, 'href="https://github.com/DiogoRibeiro7/analytics-blog-jekyll/blob/v0.8.0/requirements.txt"'
    assert_includes html, 'href="/datasets/sample-dataset/"'
  end

  private

  def squeeze(text)
    text.gsub(/\s+/, " ").strip
  end

  # A page holding the panel, with the theme's translations.
  def render(value, baseurl = "", lang = nil)
    FileUtils.mkdir_p(File.join(@dir, "_includes", "components"))
    FileUtils.mkdir_p(File.join(@dir, "_data"))
    FileUtils.cp(File.join(SiteBuilder.root, "_includes", "components", "reproducibility.html"),
                 File.join(@dir, "_includes", "components", "reproducibility.html"))
    FileUtils.cp_r(File.join(SiteBuilder.root, "_data", "i18n"), File.join(@dir, "_data"))
    front_matter = { "layout" => nil, "title" => "Paper", "lang" => lang, "reproducibility" => value }.compact.to_yaml
    File.write(File.join(@dir, "index.html"),
               "#{front_matter}---\n\n{% include components/reproducibility.html page=page %}\n")
    config = Jekyll.configuration(
      "source" => @dir, "destination" => File.join(@dir, "_site"), "quiet" => true, "title" => "Reproduce",
      "url" => "https://example.org", "baseurl" => baseurl, "author" => { "name" => "Test" }
    )
    Jekyll::Site.new(config).process
    @html = File.read(File.join(@dir, "_site", "index.html"))
    Nokogiri::HTML5.fragment(@html)
  end
end
