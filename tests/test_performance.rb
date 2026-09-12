# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "stringio"
require "zlib"

class PerformanceBundlesTest < Minitest::Test
  CORE_BUDGET = 50 * 1024

  def manifest
    @manifest ||= JSON.parse(File.read(File.join(SiteBuilder.root, "_data/js_manifest.json")))
  end

  # esbuild's metafile, which `npm run build:js` writes next to the bundles.
  def meta
    @meta ||= JSON.parse(File.read(File.join(SiteBuilder.root, "assets/js/dist/meta.json")))
  end

  def bundle_path(url)
    File.join(SiteBuilder.root, url.sub(%r{^/}, ""))
  end

  def gzip_size(path)
    data = File.binread(path)
    buffer = StringIO.new
    Zlib::GzipWriter.wrap(buffer) { |gz| gz.write(data) }
    buffer.string.bytesize
  end

  def test_core_bundle_under_50kb_gzipped
    core = manifest.fetch("core")
    assert File.exist?(bundle_path(core)), "Core bundle missing at #{core}"
    assert_operator gzip_size(bundle_path(core)), :<, CORE_BUDGET, "Core bundle exceeds 50KB gzipped"
  end

  def test_feature_bundles_load_on_demand
    loader = manifest.fetch("loader")
    loader_source = File.read(bundle_path(loader))
    assert_match(/import\(/, loader_source, "Loader should use dynamic imports")
    manifest.fetch("features", {}).each_key do |feature|
      pattern = /import\s+[^\n]*#{Regexp.escape(feature)}/
      refute_match(pattern, loader_source, "Loader eagerly imports #{feature}")
    end
  end

  def test_duplicate_code_across_chunks_under_five_percent
    outputs = meta.fetch("outputs")
    entry_outputs = outputs.select { |_, data| data.key?("entryPoint") }
    total_entry_bytes = entry_outputs.values.sum { |data| data["bytes"] || 0 }

    usage = Hash.new { |hash, input| hash[input] = [] }
    entry_outputs.each do |output_path, data|
      data.fetch("inputs", {}).each do |input_path, info|
        usage[input_path] << { output: output_path, bytes: info["bytesInOutput"] || 0 }
      end
    end

    duplicated_bytes = usage.values.sum do |entries|
      next 0 if entries.size <= 1

      entries.sort_by { |entry| -entry[:bytes] }[1..]&.sum { |entry| entry[:bytes] } || 0
    end

    duplication_ratio = total_entry_bytes.positive? ? duplicated_bytes.to_f / total_entry_bytes : 0.0
    assert_operator duplication_ratio, :<, 0.05, "Duplicate code ratio #{duplication_ratio.round(4)} exceeds 5%"
  end
end
