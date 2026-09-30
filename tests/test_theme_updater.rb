# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "../lib/datalog/theme/updater"

class ThemeUpdaterTest < Minitest::Test
  # The preflight read _config.yml with a loader that permitted no dates, so a
  # site Jekyll builds failed the update after the checkout had moved.
  def test_a_configuration_with_dates_and_aliases_does_not_stop_the_update
    with_site do |site, theme|
      File.write(File.join(site, "_config.yml"), <<~YAML)
        theme: datalog-theme
        launched: 2024-01-01
        defaults_shared: &post
          layout: post
        defaults:
          - scope: { path: "" }
            values: *post
      YAML

      assert_equal 2, updater(site, { to: "latest" }, [], []).run
      assert_equal "v0.9.0", git(theme, "tag", "--points-at", "HEAD")
      assert_equal "vendor/datalog", git(site, "diff", "--cached", "--name-only")
    end
  end

  def test_dry_run_leaves_checkout_and_index_alone
    with_site do |site, theme|
      before = git(theme, "rev-parse", "HEAD")
      commands = []
      output = []

      assert_equal 0, updater(site, { dry_run: true }, output, commands).run
      assert_equal before, git(theme, "rev-parse", "HEAD")
      assert_empty git(site, "diff", "--cached", "--name-only")
      assert_empty commands
      assert_match(/Update .* to v0\.9\.0/, output.join("\n"))
    end
  end

  def test_dirty_theme_is_rejected_before_mutation
    with_site do |site, theme|
      File.write(File.join(theme, "dirty.txt"), "local work\n")
      commands = []

      error = assert_raises(Datalog::Theme::Updater::Error) do
        updater(site, {}, [], commands).run
      end
      assert_match(/local changes/, error.message)
      assert_equal "v0.8.0", git(theme, "tag", "--points-at", "HEAD")
      assert_empty commands
    end
  end

  def test_updates_stable_release_and_stages_gitlink_with_changelog
    with_site do |site, theme|
      output = []
      commands = []

      assert_equal 2, updater(site, { to: "latest" }, output, commands).run
      assert_equal "v0.9.0", git(theme, "tag", "--points-at", "HEAD")
      assert_equal "vendor/datalog", git(site, "diff", "--cached", "--name-only")
      assert_equal ["npm ci", "npm run build:js", "bundle install"], commands
      assert_includes output.join("\n"), "0.9.0 — Changed"
      assert_includes output.join("\n"), "0.9.0 — Removed"
      assert_includes output.join("\n"), 'git commit -m "Update the DataLog theme to v0.9.0"'

      assert_equal 0, updater(site, {}, [], []).run
    end
  end

  def test_explicit_prerelease_and_site_checks
    with_site do |site, theme|
      FileUtils.mkdir_p(File.join(site, "assets/js"))
      File.write(File.join(site, "assets/js/loader.js"), "old copy\n")
      File.write(File.join(site, "_config.yml"), "layouts_dir: vendor/datalog/_layouts\n")
      output = []

      error = assert_raises(Datalog::Theme::Updater::Error) do
        updater(site, { to: "v0.10.0.pre.1" }, output, []).run
      end
      assert_match(/site check/, error.message)
      assert_equal "v0.10.0.pre.1", git(theme, "tag", "--points-at", "HEAD")
      assert_includes output.join("\n"), "assets/js/loader.js differs"
      assert_includes output.join("\n"), "layouts_dir points into"
      assert_empty git(site, "diff", "--cached", "--name-only")

      File.delete(File.join(site, "assets/js/loader.js"))
      File.write(File.join(site, "_config.yml"), "theme: datalog-theme\n")
      assert_equal 2, updater(site, { to: "v0.10.0.pre.1" }, [], []).run
      assert_equal "vendor/datalog", git(site, "diff", "--cached", "--name-only")
    end
  end

  private

  def updater(site, options, output, commands)
    Datalog::Theme::Updater.new(root: site, options: options,
                                report: ->(message) { output << message },
                                available: ->(_command) { true },
                                execute: lambda { |_env, command, dir|
                                  commands << command
                                  if command == "npm run build:js"
                                    record = File.join(dir, "assets/js/dist/sources.json")
                                    FileUtils.mkdir_p(File.dirname(record))
                                    File.write(record, '{"sources":{}}')
                                  end
                                  true
                                })
  end

  def with_site
    Dir.mktmpdir("datalog-updater") do |dir|
      source = File.join(dir, "source")
      site = File.join(dir, "site")
      FileUtils.mkdir_p([source, site])
      git(source, "init", "-q")
      write_theme(source, "0.8.0")
      git(source, "add", ".")
      git(source, "commit", "-qm", "Old release")
      git(source, "tag", "v0.8.0")
      write_theme(source, "0.9.0")
      git(source, "add", ".")
      git(source, "commit", "-qam", "Stable release")
      git(source, "tag", "v0.9.0")
      write_theme(source, "0.10.0.pre.1")
      git(source, "add", ".")
      git(source, "commit", "-qam", "Prerelease")
      git(source, "tag", "v0.10.0.pre.1")

      git(site, "init", "-q")
      git(site, "-c", "protocol.file.allow=always", "submodule", "add", "-q", source, "vendor/datalog")
      theme = File.join(site, "vendor/datalog")
      git(theme, "checkout", "-q", "--detach", "v0.8.0")
      File.write(File.join(site, "Gemfile"),
                 "source 'https://rubygems.org'\ngem 'datalog-theme', path: 'vendor/datalog'\n")
      File.write(File.join(site, "_config.yml"), "theme: datalog-theme\n")
      git(site, "add", ".")
      git(site, "commit", "-qm", "Add site and submodule")
      yield site, theme
    end
  end

  def write_theme(dir, release)
    FileUtils.mkdir_p(File.join(dir, "assets/js"))
    File.write(File.join(dir, ".gitignore"), "assets/js/dist/\n")
    File.write(File.join(dir, "assets/js/loader.js"), "loader #{release}\n")
    File.write(File.join(dir, "datalog-theme.gemspec"),
               "Gem::Specification.new { |spec| spec.name = 'datalog-theme'; spec.version = '#{release}'; " \
               "spec.summary = 'Theme'; spec.authors = ['Test'] }\n")
    File.write(File.join(dir, "CHANGELOG.md"), <<~CHANGELOG)
      ## [0.9.0] - 2026-01-01
      ### Changed
      - New behavior.
      ### Removed
      - Old behavior.
      ## [0.8.0] - 2025-01-01
      ### Added
      - Initial behavior.
    CHANGELOG
  end

  def git(dir, *args)
    env = { "GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
            "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com" }
    out, err, status = Open3.capture3(env, "git", "-C", dir, *args)
    assert status.success?, "git #{args.join(' ')} failed: #{err}"
    out.strip
  end
end
