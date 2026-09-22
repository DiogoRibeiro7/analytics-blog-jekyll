# frozen_string_literal: true

require "fileutils"
require "json"
require "nokogiri"
require "tmpdir"
require "yaml"

# One way to stand a Jekyll site up for a test.
#
# Most of what this theme does only exists once Jekyll has run: a filter over a
# real page, an include reading real front matter, a plugin writing a real
# file. So a test builds a small site and reads what came out. That was written
# by hand in 27 files, each deciding again what to copy in from the theme and
# which of Jekyll's options mattered, and the copies drifted (#367).
#
#   site = TestSite.build(title: "Licences") do |source|
#     source.theme("_includes/components/license-notice.html", "_data/i18n")
#     source.page("index.html", "{% include components/license-notice.html page=page %}",
#                 "date: 2024-02-20\nlicense: CC-BY-4.0\n")
#   end
#
#   site.html("index.html").at_css(".license-notice")
#
# The site's directory is removed when the process ends, so a test reads from
# it for as long as it lives and cleans nothing up itself.
module TestSite
  # What Jekyll needs to build at all, plus the two fields nearly every page of
  # this theme reads. A test overrides whichever of them it is about.
  DEFAULTS = {
    "quiet" => true,
    "title" => "Test site",
    "url" => "https://example.org",
    "author" => { "name" => "Test" }
  }.freeze

  module_function

  # Builds a site from the files the block writes and returns what it produced.
  # Options are Jekyll's own, as strings or symbols: `baseurl: "/blog"`,
  # `"permalink" => "/:year/:title/"`, `collections: {...}`.
  def build(options = {}, &block)
    source = Source.new(Dir.mktmpdir("datalog-test-site"))
    block&.call(source)
    source.build(options)
  end

  def root
    SiteBuilder.root
  end

  # Removed at the end of the run rather than after each test, so a test can
  # build a site once and read it from several of its own methods.
  def directories
    @directories ||= []
  end

  Minitest.after_run { directories.each { |dir| FileUtils.rm_rf(dir) } }

  # The files of the site, before it is built.
  class Source
    attr_reader :dir

    def initialize(dir)
      @dir = dir
      TestSite.directories << dir
    end

    # Copies part of the theme in, keeping where it sits: a single include, a
    # whole directory, an image. A test that renders one include copies that
    # include, so what it depends on is visible at the call site.
    def theme(*paths)
      paths.each do |path|
        source = File.join(TestSite.root, path)
        raise ArgumentError, "the theme has no #{path}" unless File.exist?(source)

        target = File.join(@dir, path)
        FileUtils.mkdir_p(File.dirname(target))
        File.directory?(source) ? FileUtils.cp_r(source, File.dirname(target)) : FileUtils.cp(source, target)
      end
      self
    end

    # A page, with front matter as YAML text or as a hash. The default is a
    # page with no layout, so what is read back is the page's own content and
    # nothing the theme wraps around it.
    def page(path, body = "", front_matter = "layout: null\n")
      write(path, "---\n#{yaml(front_matter)}---\n\n#{body}\n")
    end

    # A post, named the way Jekyll wants: 2026-01-01-part-one.
    def post(name, body = "", front_matter = "")
      page(File.join("_posts", name.end_with?(".md") ? name : "#{name}.md"), body, front_matter)
    end

    # A document in a collection, for a site whose options declare one.
    def document(collection, name, body = "", front_matter = "")
      page(File.join("_#{collection}", name.end_with?(".md") ? name : "#{name}.md"), body, front_matter)
    end

    def data(name, contents)
      write(File.join("_data", name), contents.is_a?(String) ? contents : contents.to_yaml)
    end

    def layout(name, body)
      write(File.join("_layouts", name.end_with?(".html") ? name : "#{name}.html"), body)
    end

    # Any other file, at a path relative to the site's source.
    def write(path, contents)
      target = File.join(@dir, path)
      FileUtils.mkdir_p(File.dirname(target))
      File.write(target, contents)
      self
    end

    def build(options = {})
      config = DEFAULTS.merge(options.transform_keys(&:to_s))
                       .merge("source" => @dir, "destination" => File.join(@dir, "_site"))
      site = Jekyll::Site.new(Jekyll.configuration(config))
      site.process
      Built.new(@dir, site)
    end

    private

    def yaml(front_matter)
      return front_matter.to_s if front_matter.is_a?(String)

      front_matter.to_yaml.delete_prefix("---\n")
    end
  end

  # What the build produced.
  class Built
    attr_reader :dir, :jekyll

    def initialize(dir, jekyll)
      @dir = dir
      @jekyll = jekyll
    end

    def path(relative)
      File.join(@dir, "_site", relative)
    end

    def exist?(relative)
      File.exist?(path(relative))
    end

    def read(relative)
      File.read(path(relative))
    end

    def json(relative)
      JSON.parse(read(relative))
    end

    # A fragment, which is what a page with no layout is.
    def html(relative)
      Nokogiri::HTML5.fragment(read(relative))
    end

    # A whole document, for a page that went through a layout.
    def document(relative)
      Nokogiri::HTML5(read(relative))
    end

    # For a page whose URL the permalink decides:
    # `site.find("**/part-one/index.html")`. Nil when nothing matched, so the
    # test says what it expected rather than the helper raising past it.
    def find(pattern)
      match = Dir[File.join(@dir, "_site", pattern)].min
      Nokogiri::HTML5.fragment(File.read(match)) if match
    end

    def written
      Dir[File.join(@dir, "_site", "**", "*")].select { |entry| File.file?(entry) }
                                              .map do |entry|
        entry.sub(
          "#{File.join(@dir, '_site')}/", ""
        )
      end
    end
  end
end
