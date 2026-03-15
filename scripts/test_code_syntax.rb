#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

root = File.join(__dir__, "..")
syntax_styles = File.read(File.join(root, "_sass", "_syntax-highlighting.scss"))
config_content = File.read(File.join(root, "_config.yml"))
config = YAML.safe_load(config_content, aliases: true)
layout = File.read(File.join(root, "_layouts", "default.html"))
head_include = File.read(File.join(root, "_includes", "head.html"))
post_layout = File.read(File.join(root, "_layouts", "post.html"))

languages = %w[python r sql julia javascript]
components = config.dig("theme_options", "syntax_highlighting", "components") || []
missing_components = languages.reject { |language| components.include?(language) }
raise "Missing Prism components for: #{missing_components.join(", ")}" unless missing_components.empty?

missing_languages = languages.reject do |language|
  syntax_styles.include?("language-#{language}") || config_content.include?("- #{language}") || layout.include?(language)
end
raise "Missing syntax highlighting styles for: #{missing_languages.join(", ")}" unless missing_languages.empty?

unless syntax_styles.include?("code[class*='language-']") && syntax_styles.include?("pre[class*='language-']")
  raise "Base code block styles missing"
end

unless post_layout.include?("code-copy") && post_layout.include?("code-language")
  raise "Post layout missing code copy buttons or language indicators"
end

unless layout.include?("prism_cdn") && head_include.include?("prism_line_numbers_url")
  raise "Prism assets not referenced in default layout/head"
end

puts "Syntax highlighting configuration covers #{languages.join(", ")}"
