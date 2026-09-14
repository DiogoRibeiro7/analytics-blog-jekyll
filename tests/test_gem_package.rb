# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "open3"
require "pathname"
require "rbconfig"
require "rubygems/specification"

# What a site using the published gem needs, as opposed to what works inside
# this repository. Everything here was broken in 0.6.1: the gem shipped a
# manifest pointing at bundles it did not contain, did not declare the
# sanitizer its plugins require, and never registered the Liquid tags its own
# layouts use, so no consumer site could build at all.
class GemPackageTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("..").expand_path

  def setup
    @spec = Gem::Specification.load(ROOT.join("datalog-theme.gemspec").to_s)
    refute_nil @spec, "the gemspec should load"
  end

  def test_ships_every_bundle_the_manifest_references
    unless ROOT.join("assets/js/dist").directory?
      skip "browser bundles are not built; run `npm run build:js` first"
    end

    manifest = JSON.parse(ROOT.join("_data/js_manifest.json").read)
    referenced = asset_paths(manifest).uniq.sort
    refute_empty referenced, "the manifest should reference at least one bundle"

    referenced.each do |url|
      path = url.sub(%r{\A/}, "")
      assert_includes @spec.files, path,
                      "the manifest points every page at #{url}, so the gem has to contain #{path}"
    end
  end

  # The demo site keeps its navigation, social profiles, author profile, CV and
  # publication exports in _data and assets, which the gem otherwise ships, so
  # every site using the theme published them.
  def test_leaves_out_the_demo_sites_data_and_downloads
    %w[_data/i18n/en.yml _data/js_manifest.json _data/cdn-integrity.yml].each do |path|
      assert_includes @spec.files, path, "the layouts need #{path} to render"
    end

    %w[
      _data/navigation.yml
      _data/social.yml
      _data/config/author.yml
      _data/publications.yml
      assets/templates/diogo-ribeiro-cv.md
      assets/publications/publications.bib
    ].each do |path|
      refute_includes @spec.files, path, "#{path} belongs to the demo site, not the theme"
    end
  end

  # esbuild's metafile describes a build, not anything a page loads. The gem
  # used to ship a committed copy that no longer matched its own bundles.
  def test_leaves_out_the_build_records
    %w[_data/js_meta.json assets/js/dist/meta.json assets/js/dist/manifest.json].each do |path|
      refute_includes @spec.files, path, "#{path} is a record of the build, which no page loads"
    end
  end

  def test_declares_the_gems_the_shipped_plugins_require
    required = Dir[ROOT.join("_plugins", "*.rb")].flat_map do |plugin|
      File.readlines(plugin).filter_map { |line| line[/\A\s*require "([a-z0-9_-]+)"/, 1] }
    end.uniq

    third_party = required & %w[loofah nokogiri mini_magick fastimage]
    declared = @spec.dependencies.map(&:name)

    third_party.each do |gem_name|
      assert_includes declared, gem_name,
                      "_plugins require #{gem_name}, so the gemspec has to depend on it"
    end
  end

  # The gemspec said Ruby 3.0, while the sass-embedded and nokogiri releases it
  # resolves need 3.2.
  def test_requires_the_ruby_its_dependencies_need
    assert @spec.required_ruby_version.satisfied_by?(Gem::Version.new("3.2.0"))
    refute @spec.required_ruby_version.satisfied_by?(Gem::Version.new("3.1.9"))
  end

  # Open-ended requirements accepted any future major release untested.
  def test_bounds_every_runtime_dependency_below_its_next_major_version
    @spec.runtime_dependencies.each do |dependency|
      bounded = dependency.requirement.requirements.any? { |operator, _version| %w[~> <].include?(operator) }
      assert bounded, "#{dependency.name} #{dependency.requirement} has no upper bound"
    end
  end

  # jekyll-archives and jekyll-remote-theme were used by nothing, and googleauth
  # (with the Google Cloud gems it brings) only by a GA4-configured dashboard.
  def test_does_not_make_every_site_install_unused_or_optional_gems
    declared = @spec.runtime_dependencies.map(&:name)
    %w[jekyll-archives jekyll-remote-theme googleauth].each do |gem_name|
      refute_includes declared, gem_name
    end
  end

  # Pages load the bundles and the loader; a site copies every theme asset into
  # its output, so the unbundled sources were published by every site.
  def test_ships_the_loader_but_not_the_unbundled_script_sources
    assert_includes @spec.files, "assets/js/loader.js"
    %w[assets/js/main.js assets/js/search/engine.js assets/js/core/dark-mode.js].each do |path|
      refute_includes @spec.files, path, "no page loads #{path}; the bundles in assets/js/dist are built from it"
    end
  end

  # Jekyll reads `_plugins/` for a site but not for a theme gem. Sites name the
  # theme in their `plugins:` list, which makes Jekyll require lib/datalog-theme.rb,
  # and that has to be enough to register the tags the layouts use.
  def test_entry_point_registers_the_liquid_tags_the_layouts_use
    script = <<~RUBY
      require "jekyll"
      require #{ROOT.join('lib/datalog-theme.rb').to_s.inspect}
      puts %w[t include_cached].all? { |tag| Liquid::Template.tags[tag] }
    RUBY

    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-e", script, chdir: ROOT.to_s)

    assert status.success?, "loading the gem entry point failed: #{stderr}"
    assert_equal "true", stdout.strip,
                 "requiring the theme should register the {% t %} and {% include_cached %} tags its layouts use"
  end

  private

  def asset_paths(value, found = [])
    case value
    when String then found << value if value.start_with?("/assets/")
    when Array then value.each { |item| asset_paths(item, found) }
    when Hash then value.each_value { |item| asset_paths(item, found) }
    end
    found
  end
end
