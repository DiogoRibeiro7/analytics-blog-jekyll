# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "rubygems/specification"
require "tmpdir"

# Builds a minimal site the way someone installing the theme would, each in a
# separate process so the theme's hooks and plugins never reach the other
# tests. tests/test_gem_package.rb checks what the gem contains; this checks
# that a site using it builds and publishes nothing from the demo site.
#
# Two kinds of install are covered. The packaged gem is simulated by copying
# the gemspec's file list into a directory and resolving the theme from there.
# A Git checkout or local path install resolves the theme from the repository
# itself, which is also the demo site (see lib/datalog/theme/repository_checkout.rb).
class GemConsumerTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  # Strings that identify the maintainer in the demo site's configuration,
  # data files and downloads.
  MAINTAINER_MARKERS = %w[Diogo Ribeiro ESMAD DiogoRibeiro7 dfr@esmad debastos 0009-0001-2022-7072].freeze

  # These tests build a consumer site in a fresh process, which is the point
  # of them: it is the only way to see what a site gets when it installs the
  # theme rather than when it is the theme. It also means the parent never
  # loads lib/datalog/theme/*.rb, so those files read 0% under an in-process
  # coverage run although they are exercised here. The child measures itself
  # and SimpleCov merges the two resultsets.
  COVERAGE = <<~'RUBY'
    if ENV["COVERAGE"]
      require "simplecov"
      theme = ENV.fetch("COVERAGE_ROOT")
      SimpleCov.command_name("gem-consumer-#{Process.pid}")
      SimpleCov.root(theme)
      SimpleCov.coverage_dir(File.join(theme, "coverage"))
      SimpleCov.start { track_files "{lib,_plugins}/**/*.rb" }
    end
  RUBY

  BUILD = <<~'RUBY'
    require "jekyll"

    source, theme_root = ARGV
    # Resolve the theme's files from theme_root instead of the installed gem.
    Jekyll::Theme.prepend(Module.new { define_method(:root) { theme_root } })

    config = Jekyll.configuration(
      "source" => source,
      "destination" => File.join(source, "_site"),
      "disable_disk_cache" => true,
      "quiet" => true
    )
    Jekyll::Site.new(config).process
  RUBY

  CRITICAL_CSS = <<~'RUBY'
    require "jekyll"
    require "datalog/cli"

    source, theme_root, critical = ARGV
    Jekyll::Theme.prepend(Module.new { define_method(:root) { theme_root } })
    Datalog::CLI.start(["critical-css", "--root", source, "--critical", critical])
  RUBY

  def test_packaged_theme_builds_a_site_without_the_demo_content
    Dir.mktmpdir do |dir|
      theme = package_into(File.join(dir, "theme"))
      site = write_site(File.join(dir, "site"))

      output, status = build(site, theme)

      assert status.success?, "a minimal site should build against the packaged theme:\n#{output}"
      assert_published_pages(site)
      assert_no_demo_content(site)

      stylesheet = File.read(File.join(site, "_site", "assets", "css", "main.css"))
      refute_includes stylesheet, ".search-app", "a site without features.search should not carry the search styles"
    end
  end

  # critical_css.enabled did nothing for a site installed from the gem, whose
  # critical CSS files are empty (#238). `datalog critical-css` writes its own.
  def test_critical_css_command_gives_a_packaged_theme_site_its_critical_css
    critical = File.join(ROOT, "node_modules", ".bin", Gem.win_platform? ? "critical.cmd" : "critical")
    unless File.file?(critical)
      flunk "critical is not installed" if ENV["DATALOG_CRITICAL_CSS"] == "required"
      skip "critical is not installed; run `npm ci` first"
    end

    Dir.mktmpdir do |dir|
      theme = package_into(File.join(dir, "theme"))
      site = write_site(File.join(dir, "site"), "critical_css:\n  enabled: true\n")

      output, status = build(site, theme, CRITICAL_CSS, critical)
      assert status.success?, "datalog critical-css should write the site's critical CSS:\n#{output}"
      output, status = build(site, theme, BUILD, env: { "JEKYLL_ENV" => "production" })
      assert status.success?, output

      { "index.html" => "home", "about.html" => "default", "2026/01/01/hello.html" => "post" }.each do |page, target|
        html = File.read(File.join(site, "_site", page))
        css = html[%r{<style data-critical-css="#{target}"[^>]*>(.*?)</style>}m, 1].to_s
        refute_empty css.strip, "#{page} should inline the #{target} critical CSS"
        refute_includes css, "{% raw %}"
        assert_match(/<link rel="stylesheet" href="[^"]*main\.css" media="print" data-async-style/, html)
        assert_match(%r{<noscript>\s*<link rel="stylesheet" href="[^"]*main\.css" />}, html)
      end
    end
  end

  def test_repository_checkout_stops_the_build_until_the_demo_configuration_is_ignored
    Dir.mktmpdir do |dir|
      site = write_site(File.join(dir, "site"))

      output, status = build(site, ROOT)

      refute status.success?, "the build should stop rather than inherit the demo configuration"
      assert_includes output, "ignore_theme_config: true"
    end
  end

  def test_repository_checkout_with_the_demo_configuration_ignored_builds_without_the_demo_content
    Dir.mktmpdir do |dir|
      site = write_site(File.join(dir, "site"), "ignore_theme_config: true\n")

      output, status = build(site, ROOT)

      assert status.success?, "a checkout install that ignores the demo configuration should build:\n#{output}"
      assert_published_pages(site)
      assert_no_demo_content(site)
    end
  end

  # A Git submodule at vendor/datalog, installed as a path gem and named as the
  # theme (docs/install.md). Before it, a site pointed layouts_dir and the rest
  # into the submodule and copied the theme's assets and _data in by hand.
  def test_theme_in_a_git_submodule_builds_the_site_from_the_submodule
    Dir.mktmpdir do |dir|
      site, theme = write_submodule_site(dir)

      output, status = build(site, theme)

      assert status.success?, "a site using the theme from a submodule should build:\n#{output}"
      assert_published_pages(site)
      assert_no_demo_content(site)
      published = File.join(site, "_site")
      %w[assets/js/dist/core.js assets/js/loader.js assets/css/main.css].each do |file|
        assert File.exist?(File.join(published, file)), "#{file} should be published from the submodule"
      end
      refute File.exist?(File.join(published, "assets/js/core/navigation.js")), "no page loads the script sources"
      refute Dir.exist?(File.join(published, "vendor")), "the submodule itself should not be published"
    end
  end

  def test_bundles_built_from_other_sources_stop_the_build
    Dir.mktmpdir do |dir|
      site, theme = write_submodule_site(dir)
      File.write(File.join(theme, "assets/js/core/navigation.js"), "// updated\n", mode: "a")

      output, status = build(site, theme)
      refute status.success?, "bundles older than the submodule's sources should stop the build"
      assert_includes output, "assets/js/core/navigation.js has changed"
      assert_includes output, "npm run build:js"

      FileUtils.rm_rf(File.join(theme, "assets/js/dist"))
      output, status = build(site, theme)
      refute status.success?, "a submodule whose bundles were never built should stop the build"
      assert_includes output, "assets/js/dist/sources.json is missing"
    end
  end

  def test_copies_of_theme_files_that_differ_from_the_theme_stop_the_build
    Dir.mktmpdir do |dir|
      site, theme = write_submodule_site(dir)
      FileUtils.mkdir_p(File.join(site, "assets/js/dist"))
      FileUtils.mkdir_p(File.join(site, "_data"))
      FileUtils.cp(File.join(theme, "assets/js/dist/core.js"), File.join(site, "assets/js/dist/core.js"))
      File.write(File.join(site, "assets/js/dist/search.js"), "// a bundle from an earlier version\n")
      File.write(File.join(site, "_data/js_manifest.json"), JSON.generate("core" => "/assets/js/dist/core-0.7.js"))

      output, status = build(site, theme)

      refute status.success?, "copies that differ from the theme's files should stop the build"
      listed = output[/differ from the theme's: (.*?)\. A site's file/, 1].to_s.split(", ")
      assert_includes listed, "assets/js/dist/search.js"
      assert_includes listed, "_data/js_manifest.json"
      refute_includes listed, "assets/js/dist/core.js", "a copy identical to the theme's does no harm"
    end
  end

  private

  def write_submodule_site(dir)
    unless File.file?(File.join(ROOT, "assets/js/dist/sources.json"))
      skip "browser bundles are not built; run `npm run build:js` first"
    end

    site = write_site(File.join(dir, "site"), "ignore_theme_config: true\nexclude:\n  - vendor\n")
    theme = File.join(site, "vendor", "datalog")
    checkout_into(theme)
    [site, theme]
  end

  # What `git submodule add` checks out, and the bundles `npm run build:js`
  # then builds in it.
  def checkout_into(theme)
    tracked, = Open3.capture2("git", "ls-files", "-z", chdir: ROOT)
    built = Dir.glob("assets/js/dist/**/*", base: ROOT)
    (tracked.split("\x0") + built).each do |file|
      source = File.join(ROOT, file)
      next unless File.file?(source)

      target = File.join(theme, file)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(source, target)
    end
  end

  def package_into(theme)
    spec = Gem::Specification.load(File.join(ROOT, "datalog-theme.gemspec"))
    spec.files.each do |file|
      target = File.join(theme, file)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(File.join(ROOT, file), target)
    end
    theme
  end

  def write_site(site, extra_config = "")
    {
      "_config.yml" => <<~YAML + extra_config,
        title: Consumer Site
        url: "https://example.com"
        theme: datalog-theme
        plugins:
          - datalog-theme
        author:
          name: Jane Consumer
      YAML
      "index.md" => "---\nlayout: home\ntitle: Home\n---\nWelcome.\n",
      "about.md" => "---\nlayout: page\ntitle: About\n---\nAbout this site.\n",
      "_posts/2026-01-01-hello.md" => "---\nlayout: post\ntitle: Hello\n---\nA first post.\n"
    }.each do |path, content|
      target = File.join(site, path)
      FileUtils.mkdir_p(File.dirname(target))
      File.write(target, content)
    end
    site
  end

  def build(site, theme_root, script = BUILD, *, env: {})
    stdout, stderr, status = Open3.capture3(coverage_env(env), RbConfig.ruby, "-e",
                                            "#{COVERAGE}#{script}", site, theme_root, *, chdir: site)
    ["#{stdout}#{stderr}", status]
  end

  def coverage_env(env)
    return env unless ENV["COVERAGE"]

    env.merge("COVERAGE" => "1", "COVERAGE_ROOT" => ROOT)
  end

  def assert_published_pages(site)
    %w[index.html about.html 2026/01/01/hello.html feed.xml].each do |page|
      assert File.exist?(File.join(site, "_site", page)), "the build should publish #{page}"
    end
  end

  def assert_no_demo_content(site)
    output = File.join(site, "_site")
    leaks = Dir.glob(File.join(output, "**", "*")).select { |path| File.file?(path) }.filter_map do |path|
      found = MAINTAINER_MARKERS.select { |marker| File.binread(path).include?(marker) }
      "#{path.delete_prefix("#{output}/")} (#{found.join(', ')})" unless found.empty?
    end

    assert_empty leaks, "the site should publish nothing that identifies the theme's maintainer"
    refute Dir.exist?(File.join(output, "assets", "templates")), "the demo's CV templates should not be published"
    refute Dir.exist?(File.join(output, "assets", "publications")), "the demo's publication exports should not be published"
  end
end
