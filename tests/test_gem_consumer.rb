# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
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

  def test_packaged_theme_builds_a_site_without_the_demo_content
    Dir.mktmpdir do |dir|
      theme = package_into(File.join(dir, "theme"))
      site = write_site(File.join(dir, "site"))

      output, status = build(site, theme)

      assert status.success?, "a minimal site should build against the packaged theme:\n#{output}"
      assert_published_pages(site)
      assert_no_demo_content(site)
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

  private

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

  def build(site, theme_root)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-e", BUILD, site, theme_root, chdir: site)
    ["#{stdout}#{stderr}", status]
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
