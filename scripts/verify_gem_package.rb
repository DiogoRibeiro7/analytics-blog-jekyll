# frozen_string_literal: true

# Verifies that a built gem contains everything a site using the theme needs.
#
# The failure this exists to prevent: `assets/js/dist/` is build output and so
# is not tracked by git, while the gemspec selected its files with
# `git ls-files`. The gem therefore shipped `_data/js_manifest.json`, which
# points every page at those bundles, without the bundles themselves, and every
# consumer site requested them and got a 404.
#
# Usage: ruby scripts/verify_gem_package.rb [path/to/datalog-theme-X.Y.Z.gem]

require "json"
require "rubygems/package"
require "tmpdir"

REQUIRED_FILES = [
  "lib/datalog-theme.rb",
  "_data/js_manifest.json",
  "_layouts/home.html",
  "_layouts/post.html",
  "_includes/head.html"
].freeze

# Collects every site-absolute asset path mentioned anywhere in the manifest.
def asset_paths(value, found = [])
  case value
  when String then found << value if value.start_with?("/assets/")
  when Array then value.each { |item| asset_paths(item, found) }
  when Hash then value.each_value { |item| asset_paths(item, found) }
  end
  found
end

gem_path = ARGV[0] || Dir["datalog-theme-*.gem"].max_by { |file| File.mtime(file) }
abort("No gem found. Run `gem build datalog-theme.gemspec` first.") unless gem_path && File.exist?(gem_path)

files = Gem::Package.new(gem_path).spec.files
problems = REQUIRED_FILES.reject { |path| files.include?(path) }.map { |path| "missing #{path}" }

if files.include?("_data/js_manifest.json")
  Dir.mktmpdir do |dir|
    Gem::Package.new(gem_path).extract_files(dir)
    manifest = JSON.parse(File.read(File.join(dir, "_data", "js_manifest.json")))
    referenced = asset_paths(manifest).uniq.sort

    abort("#{File.basename(gem_path)}: js_manifest.json references no bundles at all") if referenced.empty?

    referenced.each do |url|
      path = url.sub(%r{\A/}, "")
      problems << "the manifest points every page at #{url}, which the gem does not contain" unless files.include?(path)
    end
  end
end

if problems.empty?
  puts "#{File.basename(gem_path)}: #{files.size} files, including every bundle its manifest references."
else
  warn "#{File.basename(gem_path)} is missing files that sites using the theme need:"
  problems.each { |problem| warn "  - #{problem}" }
  exit 1
end
