#!/usr/bin/env ruby
# frozen_string_literal: true

require "pathname"
require "json"
require "zlib"
require "stringio"

root = Pathname.new(File.join(__dir__, ".."))
manifest_path = root.join("_data/js_manifest.json")
meta_path = root.join("assets/js/dist/meta.json")

abort("JavaScript manifest missing. Run node scripts/build_js.mjs first.") unless manifest_path.exist?
abort("JavaScript metafile missing. Run node scripts/build_js.mjs first.") unless meta_path.exist?

manifest = JSON.parse(manifest_path.read)
features = manifest.fetch("features", {})

core_path = root.join(manifest.fetch("core").sub(%r{^/}, ""))

def gzip_size(path)
  data = path.binread
  buffer = StringIO.new
  Zlib::GzipWriter.wrap(buffer) { |gz| gz.write(data) }
  buffer.string.bytesize
end

raise "Core bundle exceeds 50KB gzipped" if gzip_size(core_path) > 50 * 1024

visualizations_bundle = features["visualizations"]
if visualizations_bundle
  bundle_path = root.join(visualizations_bundle.sub(%r{^/}, ""))
  bundle = bundle_path.read
  required_tokens = %w[Plotly d3 Observable Bokeh Shiny]
  missing_tokens = required_tokens.reject { |token| bundle.include?(token) }
  raise "Visualization bundle missing integrations: #{missing_tokens.join(', ')}" unless missing_tokens.empty?
  raise "Visualization bundle missing IntersectionObserver lazy loading" unless bundle.include?("IntersectionObserver")
end

puts "JavaScript bundles meet performance budgets and configuration."
