# frozen_string_literal: true

require "nokogiri"
require_relative "test_helper"

class PatchRegressionsTest < Minitest::Test
  def test_author_records_validate_shapes_and_resolve_names_and_profiles
    site = { "data" => { "authors" => { "jane" => { "name" => "Jane Smith", "affiliation" => "Lab" } } } }
    assert_equal "Lab", Datalog::Authors.authors({ "authors" => ["Jane Smith"] }, site).first["affiliation"]
    [{ "nam" => "Jane" }, ["Ann", "Bo"], true].each do |entry|
      error = assert_raises(Jekyll::Errors::FatalException) do
        Datalog::Authors.authors({ "path" => "bad.md", "authors" => [entry] }, site)
      end
      assert_includes error.message, "bad.md"
    end
    author = Datalog::Authors.authors({ "author" => { "name" => "Jane", "twitter" => "@jane",
                                                      "github" => "https://github.com/jane/" } }, site).first
    assert_equal %w[https://github.com/jane https://twitter.com/jane], author["same_as"]
  end

  def test_partial_licence_maps_inherit_the_default_and_preserve_year_ranges
    site = { "content_license" => "CC-BY-4.0" }
    page = { "license" => { "holder" => "The Lab", "year" => "2024-2026" } }
    licence = Datalog::Licenses.content(page, site)
    assert_equal ["CC BY 4.0", "2024-2026", "The Lab"], licence.values_at("name", "year", "holder")
    assert_equal "CC BY 4.0", Datalog::Licenses.content({ "license" => true }, site)["name"]
    assert_raises(Jekyll::Errors::FatalException) { Datalog::Licenses.content({ "license" => ["MIT"] }, site) }
  end

  def test_reproducibility_links_resolve_the_repository_and_encode_route_arguments
    helper = Datalog::Reproducibility
    assert_equal "https://github.com/example/project/tree/fix%2Fone",
                 helper.host_url("https://GitHub.com/example/project.git/tree/main/posts/power?x=1#usage", :tree, "fix/one")
    assert_equal "https://gitlab.com/team/sub/project/-/blob/main/envs/my%20env%20%231.yml",
                 helper.host_url("https://gitlab.com/team/sub/project/-/tree/main#usage", :blob, "main", "envs/my env #1.yml")
    doi = "10.1002/(SICI)1234<ABC>3.0.CO;2-1"
    url = helper.resolve({ "reproducibility" => { "data" => { "doi" => doi } } }, {})["artifacts"].first["url"]
    assert_equal doi, URI::DEFAULT_PARSER.unescape(url.delete_prefix("https://doi.org/"))
    refute_includes url, "<"
  end

  def test_image_variants_distinguish_source_extensions_and_skip_relative_urls
    site = SiteBuilder.site
    png = Jekyll::StaticFile.new(site, site.source, "/assets/img", "chart.png")
    jpg = Jekyll::StaticFile.new(site, site.source, "/assets/img", "chart.jpg")
    urls = [png, jpg].map { |file| Jekyll::ImageOptimizer.variant_static_file(site, file, 640, "webp", "cache").url }
    assert_equal 2, urls.uniq.length
    assert_nil Jekyll::ImageOptimizer.normalize_src("plot.png", site)
    assert_equal "/assets/img/wide plot.png", Jekyll::ImageOptimizer.normalize_src("/assets/img/wide%20plot.png", site)
    doc = Struct.new(:output, :output_ext, :site).new('<img src="/assets/img/social-card.png" width="10">', ".html",
                                                      site)
    Jekyll::ImageOptimizer.process(doc)
    assert_nil Nokogiri::HTML.fragment(doc.output).at_css("img")["height"]
  end

  def test_citation_exports_keep_records_whole_escape_tex_and_map_types
    record = { "title" => "95% & R_squared {Bayes} #1 $", "year" => "2026", "url" => "https://example.test/a",
               "number" => "2", "pages" => "12–19" }
    authors = [{ "name" => "World Health Organization", "type" => "Organization" }]
    %w[article dataset software].zip(%w[JOUR DATA COMP]).each do |kind, type|
      exports = Datalog::CitationExports.render(record, authors, kind, "test")
      refute_match(/\n\s*\n/, exports["ris"])
      refute_match(/\n\s*\n/, exports["endnote"])
      assert exports["ris"].start_with?("TY  - #{type}\n")
      assert_includes exports["ris"], "IS  - 2\nSP  - 12\nEP  - 19"
      assert_includes exports["bibtex"], '95\% \& R\_squared \{Bayes\} \#1 \$'
      assert_includes exports["bibtex"], "author = { {World Health Organization} }"
    end
  end

  def with_built_regression_site(archives: false)
    title = "When p < 0.05 and power > 80%: a<b test </script>"
    post = { "layout" => "post", "title" => title, "description" => "p < 0.05 & power > 80%",
             "updated" => "2026-03-05", "scholarly" => true, "tags" => ["statistics"], "categories" => ["research"],
             "citation_authors" => "Smith, Jane; Tester, Ada" }
    research = { "layout" => "research", "title" => "Research", "issue" => "7",
                 "authors" => [{ "name" => "The Lab", "type" => "Organization" }] }
    site = TestSite.build(url: "https://example.test", baseurl: "/sub", title: "Site",
                          author: { "name" => "Jane </script>" },
                          plugins: %w[jekyll-feed jekyll-sitemap]) do |source|
      source.theme("_layouts", "_includes", "_data")
      source.post("2026-01-01-test", "Body.", post)
      source.page("research.md", "Body.", research)
      %w[tags categories].each { |name| source.page("#{name}.md", "Archive", "permalink: /#{name}/\n") } if archives
    end
    yield site.jekyll, title, site.dir
  end

  def test_built_titles_and_exports_preserve_plain_text
    with_built_regression_site do |site, title, _dir|
      doc = Nokogiri::HTML5(site.posts.docs.first.output)
      assert_equal title, doc.at_css("h1").text
      assert_empty doc.css('a[href*="/tags/#"], a[href*="/categories/#"]')
      assert_equal "#{title} | Site", doc.at_css("title").text
      %w[og:title twitter:title citation_title DC.title].each do |name|
        assert_equal title, doc.at_css("meta[property='#{name}'], meta[name='#{name}']")["content"]
      end
      names = doc.css('meta[name="citation_author"]').map { |meta| meta["content"] }
      assert_equal ["Smith, Jane", "Tester, Ada"], names
      assert_includes doc.at_css('textarea[id^="ris-"]').text, title
    end
  end

  def test_existing_archives_keep_their_links_and_baseurl
    with_built_regression_site(archives: true) do |site, _title, _dir|
      doc = Nokogiri::HTML5(site.posts.docs.first.output)
      assert doc.at_css('a[href="/sub/tags/#statistics"]')
      assert doc.at_css('a[href="/sub/categories/#research"]')
    end
  end

  def test_schema_dates_and_research_authors
    with_built_regression_site do |site, title, dir|
      post = site.posts.docs.first
      doc = Nokogiri::HTML5(post.output)
      schemas = doc.css('script[type="application/ld+json"]').map { |script| JSON.parse(script.text) }
      article = schemas.find { |schema| schema["@type"] == "TechArticle" }
      assert_equal title, article["headline"]
      assert_equal "https://example.test/sub/", article["publisher"]["url"]
      assert_equal "https://example.test/sub/", article["author"]["url"]
      assert_equal "Jane </script>", article["author"]["name"]
      assert_equal Time.parse("2026-03-05"), post.data["last_modified_at"]
      assert_includes File.read(File.join(dir, "_site/feed.xml")), "2026-03-05"
      assert_includes File.read(File.join(dir, "_site/sitemap.xml")), "2026-03-05"
      research = Nokogiri::HTML5(File.read(File.join(dir, "_site/research.html")))
      schema = JSON.parse(research.at_css('script[type="application/ld+json"]').text)
      assert_equal "ScholarlyArticle", schema["@type"]
      assert_equal "Organization", schema["author"]["@type"]
      assert_includes research.at_css('textarea[id^="ris-"]').text, "IS  - 7"
    end
  end
end
