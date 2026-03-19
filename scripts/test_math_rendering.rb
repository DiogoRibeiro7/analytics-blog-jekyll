#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

math_bundle = File.read(File.join(__dir__, "..", "assets", "js", "math.js"))
head_include = File.read(File.join(__dir__, "..", "_includes", "head.html"))
scripts_include = File.read(File.join(__dir__, "..", "_includes", "scripts.html"))
config_path = File.join(__dir__, "..", "_config.yml")
config = File.read(config_path)

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

unless head_include.include?("tex-chtml.js") && scripts_include.include?("/assets/js/math.js")
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
