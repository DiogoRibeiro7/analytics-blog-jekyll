#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

root = File.join(__dir__, "..")
config = YAML.safe_load_file(File.join(root, "_config.yml"), aliases: true)
File.read(File.join(root, "_config.yml"))
academic_text = File.read(File.join(root, "_data", "academic.yml"))

integrations = config.fetch("integrations", {})
# Only the integrations the theme actually reads (site.integrations.*).
required_integrations = %w[github binder colab]
missing_integrations = required_integrations.reject do |key|
  settings = integrations[key]
  settings && settings["enabled"]
end
raise "Integrations missing enablement: #{missing_integrations.join(', ')}" unless missing_integrations.empty?

raise "Academic data missing Google Scholar profile" unless academic_text.match?(/google_scholar:\s*\n\s+label:/)

raise "Academic data missing ORCID profile" unless academic_text.include?("orcid.org")

%w[total h_index i10_index].each do |metric|
  raise "Citation metrics missing #{metric}" unless academic_text.match?(/metrics:\s*(?:\n\s{4}.+)*\n\s{4}#{metric}:/)
end

puts "Academic integrations verified across configuration, data sources, and citation metrics."
