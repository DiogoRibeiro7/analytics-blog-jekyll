# frozen_string_literal: true

require_relative "test_helper"
require "nokogiri"
require "tmpdir"

# A site served from a subdirectory — a GitHub Pages project site, or anything
# behind a path prefix. Every address its pages emit has to carry the baseurl,
# because a path that starts at the domain root points outside the site.
#
# The rest of the suite builds the demo site, whose baseurl is empty, so a
# forgotten prefix is invisible to it. That is how the script manifest came to
# be written without one: the loader imports the bundles it names, the imports
# 404, and the whole theme runs no JavaScript at all (#328).
class BaseurlTest < Minitest::Test
  BASEURL = "/sub"
  # An address that goes somewhere other than this site's own paths.
  ELSEWHERE = %r{\A(?:[a-z][a-z0-9+.-]*:|//|#|\?)}i

  def test_every_link_a_page_emits_starts_at_the_baseurl
    offenders = []
    built_site.each_pair do |path, doc|
      doc.css("[href], [src], [action]").each do |node|
        %w[href src action].each do |attribute|
          value = node[attribute].to_s.strip
          next if value.empty? || value.match?(ELSEWHERE) || !value.start_with?("/")
          next if inside_baseurl?(value)

          offenders << "#{path}: <#{node.name} #{attribute}=\"#{value}\">"
        end
      end
    end

    assert_empty offenders.uniq.first(20),
                 "every site path should start with #{BASEURL}"
  end

  def test_the_manifest_the_loader_reads_carries_the_baseurl
    checked = 0
    built_site.each_pair do |path, doc|
      element = doc.at_css("#datalog-js-manifest")
      next unless element

      manifest = JSON.parse(element.text)
      bundles = [manifest["core"], manifest["loader"]] +
                manifest.fetch("features", {}).values +
                manifest.fetch("entrypoints", {}).values
      bundles.compact.each do |url|
        assert inside_baseurl?(url), "#{path}: the loader would import #{url}, which is outside #{BASEURL}"
      end
      checked += 1
    end

    assert_operator checked, :>, 0, "no page carried a script manifest to check"
  end

  private

  def inside_baseurl?(value)
    value == BASEURL || value.start_with?("#{BASEURL}/")
  end

  # The theme's own layouts, includes and data, built at #{BASEURL} over a
  # handful of pages that between them pull in the header, the footer, the
  # scripts include and a post.
  def built_site
    @built_site ||= Dir.mktmpdir do |dir|
      %w[_layouts _includes _data _sass].each { |path| FileUtils.cp_r(File.join(SiteBuilder.root, path), dir) }
      FileUtils.cp(File.join(SiteBuilder.root, "404.html"), dir)
      FileUtils.mkdir_p(File.join(dir, "_posts"))
      post = { "layout" => "post", "title" => "A post", "tags" => ["statistics"] }
      File.write(File.join(dir, "_posts/2026-01-01-post.md"), "#{post.to_yaml}---\n\n## 1. Introduction\n\nBody.\n")
      File.write(File.join(dir, "index.md"), "#{{ 'layout' => 'page', 'title' => 'Home' }.to_yaml}---\n\nBody.\n")

      config = Jekyll.configuration(
        "source" => dir, "destination" => File.join(dir, "_site"), "quiet" => true,
        "url" => "https://example.test", "baseurl" => BASEURL, "title" => "Site",
        "author" => { "name" => "Test" }, "plugins" => %w[jekyll-feed jekyll-sitemap]
      )
      site = Jekyll::Site.new(config)
      site.process

      pages = site.pages + site.posts.docs
      pages.filter_map do |page|
        next unless page.output_ext == ".html"

        [page.url, Nokogiri::HTML5(page.output)]
      end.to_h
    end
  end
end
