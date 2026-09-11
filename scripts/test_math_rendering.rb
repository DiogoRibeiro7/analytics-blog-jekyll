#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

math_bundle = File.read(File.join(__dir__, "..", "assets", "js", "math.js"))
head_include = File.read(File.join(__dir__, "..", "_includes", "head.html"))
config_path = File.join(__dir__, "..", "_config.yml")
config = File.read(config_path)
manifest_path = File.join(__dir__, "..", "_data", "js_manifest.json")

abort("JavaScript manifest missing. Run npm run build:js first.") unless File.exist?(manifest_path)

manifest = JSON.parse(File.read(manifest_path))

required_tokens = [
  "MathToolkit",
  "updateEquationReferences",
  "navigator.clipboard",
  "Equation editor",
  "Copy equation",
  "MathJax.startup.promise",
  "typesetPromise"
]

missing = required_tokens.reject { |token| math_bundle.include?(token) }
raise "Math rendering bundle missing: #{missing.join(', ')}" unless missing.empty?

# The math bundle is built by scripts/build_js.mjs and referenced through the
# manifest (see _includes/head.html), not by a fixed /assets/js/math.js path.
math_bundle_path = manifest.dig("features", "math")
unless head_include.include?("tex-chtml.js") && math_bundle_path && head_include.include?("js_manifest.features.math")
  raise "Theme does not reference MathJax CDN and math enhancement bundle"
end

math_engine = config[/math_engine:\s*(\w+)/, 1]
raise "Math engine configuration missing" unless math_engine

raise "KaTeX fallback styles missing for math engine" unless head_include.include?("katex.min.css")

unless config =~ /output:\s*chtml/ && config =~ /accessibility:\s*true/
  raise "Math configuration must enforce chtml output with accessibility enabled"
end

unless math_bundle.include?("MathJax.typesetPromise") && math_bundle.include?("renderLatex")
  raise "Math bundle missing typeset promise handling or render helpers"
end

puts "Math rendering configuration validated (engine: #{math_engine})."
