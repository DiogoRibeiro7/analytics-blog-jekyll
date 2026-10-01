# frozen_string_literal: true

require_relative "test_helper"
require "rbconfig"
require "json"
require "nokogiri"
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

  # critical 9 takes one --dimensions with the viewports separated by commas;
  # given twice, it kept the last.
  def test_arguments_come_from_the_configuration
    configured = critical_css({ "dimensions" => [{ "width" => 1280, "height" => 720 },
                                                 { "width" => 390, "height" => 844 }] })

    assert_equal ["--engine", "render", "--dimensions", "1280x720,390x844"], configured.arguments
    assert_equal ["--engine", "render", "--dimensions", "1920x1080,375x667"], critical_css.arguments
    assert_equal ["--engine", "static"], critical_css({ "engine" => "static" }).arguments
  end

  # The page reaches critical on its standard input, linking the site's
  # stylesheet and nothing else: no Google Fonts, no inline styles, and no
  # Content Security Policy to refuse the stylesheet the render engine adds.
  def test_critical_reads_the_page_with_only_the_sites_stylesheet
    html = <<~HTML
      <html><head>
      <meta http-equiv="Content-Security-Policy" content="default-src 'self';
        style-src 'self' 'nonce-abc'">
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preload" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans" as="style">
      <link rel="preload" href="/blog/assets/fonts/plex.woff2" as="font" crossorigin>
      <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans">
      <link rel="stylesheet" href="/blog/assets/css/main.css?v=1" media="print">
      <noscript><link rel="stylesheet" href="/blog/assets/css/main.css"></noscript>
      <style>.inline{color:red}</style>
      <link rel="preload" href="/blog/assets/img/hero.webp" as="image">
      </head><body class="site-body"><h1>Title</h1><script>document.body.classList.add("dark-mode")</script></body></html>
    HTML
    page = Nokogiri::HTML5(critical_css.page_for_critical(html))

    assert_equal(["assets/css/main.css"], page.css('link[rel="stylesheet"]').map { |link| link["href"] })
    assert_empty page.css("style, noscript, meta[http-equiv]")
    others = page.css("link[rel]").map { |link| link["href"] } - ["assets/css/main.css"]
    assert_equal ["/blog/assets/img/hero.webp"], others,
                 "nothing that fetches a stylesheet, a font or a connection to them is left"
    refute_nil page.at_css('link[rel="preload"]'), "other links stay"
    assert_equal "Title", page.at_css("h1").text
    refute_nil page.at_css("body script"), "the page's own scripts still run in the render engine"
  end

  def test_run_writes_the_css_critical_prints_for_each_layout
    reads_the_page = <<~RUBY
      html = $stdin.read
      ok = html.include?('href="assets/css/main.css"') && !html.include?("fonts.googleapis") &&
           ARGV == ["--engine", "render", "--dimensions", "1920x1080,375x667"]
      puts "a{content:'{{'}" if ok
    RUBY
    runner = critical_css(critical: script(reads_the_page))
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

    error = assert_raises(Datalog::CriticalCss::Error) { critical_css({ "engine" => "browser" }).run }
    assert_includes error.message, "critical_css.engine is \"browser\""
  end

  # critical 9 dropped penthouse: the options are said to be ignored, not passed.
  def test_penthouse_options_are_ignored_out_loud
    logged = []
    runner = Datalog::CriticalCss.new(File.join(@dir, "site"),
                                      { "enabled" => true, "penthouse_options" => { "timeout" => 60_000 } },
                                      critical: script("puts 'a{b:c}'"), log: ->(message) { logged << message })
    stub_build(runner) { page("index.html", "site-body layout-home") }

    runner.run

    assert(logged.any? { |message| message.include?("penthouse_options is ignored") })
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

# Which critical runs, and whether its command line takes what the theme
# passes. critical 9 refused critical 8's --base, and the unit tests above,
# which check the arguments the theme builds, passed regardless (#360).
class CriticalCssCommandTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  INSTALLED = File.join(ROOT, "node_modules", "critical", "cli.js")

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # The CLI parses every option before it does anything, and --help then
  # prints and exits: a zero status means each option the theme passes is one
  # this critical knows. critical 8's --base exits 1 here.
  def test_the_installed_critical_takes_the_arguments_the_theme_passes
    skip_without_critical
    [{}, { "engine" => "static" }, { "dimensions" => [{ "width" => 800, "height" => 600 }] }].each do |settings|
      arguments = runner(settings).arguments
      output, status = Open3.capture2e("node", INSTALLED, *arguments, "--help")
      assert status.success?, "critical refused #{arguments.inspect}:\n#{output}"
    end
    _output, status = Open3.capture2e("node", INSTALLED, "index.html", "--base", ".", "--help")
    refute status.success?, "an option critical does not know fails, so the check above means something"
  end

  # The static engine needs no browser, so the whole way in can run here:
  # the page on standard input, the stylesheet from the site's root.
  def test_the_installed_critical_extracts_from_a_page_on_its_standard_input
    skip_without_critical
    FileUtils.mkdir_p(File.join(@dir, "assets", "css"))
    File.write(File.join(@dir, "assets", "css", "main.css"), ".used{color:red}.unused{color:blue}")
    html = runner({ "engine" => "static" }).page_for_critical(
      '<html><head><link rel="stylesheet" href="/blog/assets/css/main.css"></head>' \
      '<body><p class="used">Hi</p></body></html>'
    )

    output, errors, status = Open3.capture3("node", INSTALLED, "--engine", "static", stdin_data: html, chdir: @dir)
    assert status.success?, errors
    assert_includes output, ".used"
    refute_includes output, ".unused"
  end

  def test_npx_brings_playwright_only_for_the_render_engine
    assert_equal ["npx", "--yes", "--package", "critical@9", "--package", "playwright@1", "critical"],
                 runner({}).npx_command
    assert_equal ["npx", "--yes", "critical@9"], runner({ "engine" => "static" }).npx_command
  end

  # A site that installed critical 8 for an earlier version of the theme is
  # told to update it, rather than shown "Unknown option '--engine'".
  def test_a_sites_own_critical_8_is_refused_with_the_command_that_updates_it
    site = File.join(@dir, "site")
    bin = File.join(site, "node_modules", ".bin", Gem.win_platform? ? "critical.cmd" : "critical")
    FileUtils.mkdir_p(File.dirname(bin))
    File.write(bin, "")
    FileUtils.mkdir_p(File.join(site, "node_modules", "critical"))
    File.write(File.join(site, "node_modules", "critical", "package.json"), JSON.generate("version" => "8.0.0"))
    runner = Datalog::CriticalCss.new(site, { "enabled" => true })
    runner.define_singleton_method(:node_version) { "22.13.0" }

    error = assert_raises(Datalog::CriticalCss::Error) { runner.critical_command }
    assert_includes error.message, "critical 8.0.0"
    assert_includes error.message, "npm install --save-dev critical@9 playwright"

    File.write(File.join(site, "node_modules", "critical", "package.json"), JSON.generate("version" => "9.0.0"))
    assert_equal [bin], runner.critical_command
  end

  def test_an_older_node_is_named_before_critical_runs
    runner = runner({})
    runner.define_singleton_method(:node_version) { "20.18.0" }
    error = assert_raises(Datalog::CriticalCss::Error) { runner.critical_command }
    assert_equal "critical needs Node.js 22.13.0 or later, and this is Node.js 20.18.0", error.message

    runner.define_singleton_method(:node_version) { nil }
    error = assert_raises(Datalog::CriticalCss::Error) { runner.critical_command }
    assert_includes error.message, "Node.js was not found"
  end

  private

  def runner(settings)
    Datalog::CriticalCss.new(File.join(@dir, "site"), { "enabled" => true }.merge(settings))
  end

  def skip_without_critical
    return if File.file?(INSTALLED)

    flunk "critical is not installed" if ENV["DATALOG_CRITICAL_CSS"] == "required"
    skip "critical is not installed; run `npm ci` first"
  end
end
