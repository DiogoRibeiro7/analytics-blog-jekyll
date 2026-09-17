# frozen_string_literal: true

require_relative "test_helper"
require "rbconfig"
require "tmpdir"
require_relative "../lib/datalog/critical_css"

# `datalog critical-css`, without a browser: the pages it picks, the arguments
# it gives critical, and what it writes. critical_css.enabled had no effect on
# a site installed from the gem, whose critical CSS files were empty (#238).
# tests/test_gem_consumer.rb runs it with critical on a packaged-theme site.
class CriticalCssTest < Minitest::Test
  Site = Struct.new(:config, :source, :theme) do
    def in_source_dir(path)
      File.join(source, path)
    end
  end
  Theme = Struct.new(:includes_path)

  def setup
    @dir = Dir.mktmpdir
    @site_dir = File.join(@dir, "built")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def page(path, classes, robots: "index,follow")
    file = File.join(@site_dir, path)
    FileUtils.mkdir_p(File.dirname(file))
    head = %(<head><meta name="robots" content="#{robots}"></head>)
    File.write(file, %(<html>#{head}<body class="#{classes}"></body></html>))
  end

  def critical_css(settings = {}, critical: nil)
    Datalog::CriticalCss.new(File.join(@dir, "site"), { "enabled" => true }.merge(settings), critical: critical)
  end

  def test_pages_follow_the_layouts_head_html_inlines_for
    page("index.html", "site-body layout-home")
    page("404.html", "site-body layout-default", robots: "noindex,follow")
    page("search/index.html", "site-body layout-search", robots: "noindex,nofollow")
    page("tags/index.html", "site-body layout-page")
    page("about/index.html", "site-body layout-page")
    page("2024/01/01/first/index.html", "site-body layout-post")
    page("feed/index.html", "")

    pages = critical_css.pages_for(@site_dir)

    assert_equal({ "home" => "index.html", "post" => "2024/01/01/first/index.html", "default" => "about/index.html" },
                 pages)
  end

  def test_critical_css_pages_names_the_pages_to_extract_from
    page("index.html", "site-body layout-home")
    page("about/index.html", "site-body layout-page")
    page("blog/index.html", "site-body layout-page")

    pages = critical_css({ "pages" => { "default" => "/blog/" } }).pages_for(@site_dir)

    assert_equal "blog/index.html", pages["default"]
    assert_nil pages["post"], "a site without posts has no page for the post layout"
  end

  def test_arguments_come_from_the_configuration
    settings = { "dimensions" => [{ "width" => 1280, "height" => 720 }],
                 "penthouse_options" => { "timeout" => 60_000 } }
    configured = critical_css(settings)

    assert_equal ["--dimensions", "1280x720"], configured.dimension_arguments
    assert_equal ["--penthouse-timeout", "60000"], configured.penthouse_arguments
    assert_equal ["--dimensions", "1920x1080", "--dimensions", "375x667"], critical_css.dimension_arguments
  end

  def test_run_writes_the_css_critical_prints_for_each_layout
    runner = critical_css(critical: script("puts \"a{content:'{{'}\" if ARGV.include?('--css')"))
    stub_build(runner) do
      page("index.html", "site-body layout-home")
      page("about/index.html", "site-body layout-page")
    end

    written = runner.run

    assert_equal %w[home default], written.keys, "a site without posts has nothing to write for post"
    assert_equal "{% raw %}\na{content:'{{'}\n{% endraw %}\n", File.read(written["home"])
    rendered = Liquid::Template.parse(File.read(written["default"])).render
    assert_equal "a{content:'{{'}", rendered.strip, "the include should render the CSS as written"
  end

  def test_run_stops_when_critical_fails_or_finds_nothing
    [["warn 'Chrome could not start'; exit 1", "Chrome could not start"],
     ["", "found no critical CSS in index.html"]].each do |code, message|
      runner = critical_css(critical: script(code))
      stub_build(runner) { page("index.html", "site-body layout-home") }

      error = assert_raises(Datalog::CriticalCss::Error) { runner.run }
      assert_includes error.message, message
    end
  end

  def test_run_needs_critical_css_enabled
    error = assert_raises(Datalog::CriticalCss::Error) { critical_css({ "enabled" => false }).run }
    assert_includes error.message, "critical_css.enabled is not true"
  end

  # --- The build warning ------------------------------------------------------

  def test_a_production_build_warns_about_empty_critical_css
    source = File.join(@dir, "site")
    theme_includes = File.join(@dir, "theme", "_includes")
    %w[home post default].each { |target| write_include(theme_includes, target, "") }
    write_include(File.join(source, "_includes"), "home", "{% raw %}\nbody{margin:0}\n{% endraw %}\n")
    site = Site.new({ "critical_css" => { "enabled" => true }, "includes_dir" => "_includes" }, source,
                    Theme.new(theme_includes))

    with_jekyll_env("production") do
      warning = Datalog::CriticalCssCheck.warning(site)
      assert_includes warning, "_includes/critical-css/post.html, _includes/critical-css/default.html are empty"
      refute_includes warning, "home.html", "the site's own home.html takes the place of the theme's empty one"

      site.config["critical_css"]["enabled"] = false
      assert_nil Datalog::CriticalCssCheck.warning(site)
    end
    site.config["critical_css"]["enabled"] = true
    with_jekyll_env("development") { assert_nil Datalog::CriticalCssCheck.warning(site) }
  end

  private

  # Stands in for the production build: the block writes the built pages.
  def stub_build(runner, &pages)
    site_dir = @site_dir
    runner.define_singleton_method(:build) do |destination|
      FileUtils.mkdir_p(File.join(destination, "assets", "css"))
      File.write(File.join(destination, "assets", "css", "main.css"), "a{color:red}")
      pages.call
      FileUtils.cp_r(File.join(site_dir, "."), destination)
    end
  end

  def script(code)
    path = File.join(@dir, "critical-#{code.hash.abs}.rb")
    File.write(path, code)
    [RbConfig.ruby, path]
  end

  def write_include(directory, target, content)
    path = File.join(directory, "critical-css", "#{target}.html")
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def with_jekyll_env(value)
    previous = ENV.fetch("JEKYLL_ENV", nil)
    ENV["JEKYLL_ENV"] = value
    yield
  ensure
    ENV["JEKYLL_ENV"] = previous
  end
end
