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

  # Jekyll reads `_plugins/` for a site but not for a theme gem. Sites name the
  # theme in their `plugins:` list, which makes Jekyll require lib/datalog-theme.rb,
  # and that has to be enough to register the tags the layouts use.
  def test_entry_point_registers_the_liquid_tags_the_layouts_use
    script = <<~RUBY
      require "jekyll"
      require #{ROOT.join('lib/datalog-theme.rb').to_s.inspect}
      puts !Liquid::Template.tags["t"].nil?
    RUBY

    stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-e", script, chdir: ROOT.to_s)

    assert status.success?, "loading the gem entry point failed: #{stderr}"
    assert_equal "true", stdout.strip,
                 "requiring the theme should register the {% t %} tag its layouts use"
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
