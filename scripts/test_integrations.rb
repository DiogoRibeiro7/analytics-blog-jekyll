#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

root = File.join(__dir__, "..")
config = YAML.safe_load(File.read(File.join(root, "_config.yml")), aliases: true)
config_text = File.read(File.join(root, "_config.yml"))
academic_text = File.read(File.join(root, "_data", "academic.yml"))

integrations = config.fetch("integrations", {})
required_integrations = %w[github binder colab kaggle observable zenodo scholar orcid researchgate academia]
missing_integrations = required_integrations.reject do |key|
  settings = integrations[key]
  settings && settings["enabled"]
end
raise "Integrations missing enablement: #{missing_integrations.join(", ")}" unless missing_integrations.empty?

academic_integrations = config.dig("theme_options", "academic_integrations") || {}
missing_segments = %w[google_scholar orcid researchgate academia submissions calendar badges collaboration].reject do |segment|
  academic_integrations.key?(segment)
end
raise "Academic integration settings missing #{missing_segments.join(", ")}" unless missing_segments.empty?

unless academic_text.match?(/google_scholar:\s*\n\s+label:/)
  raise "Academic data missing Google Scholar profile"
end

unless academic_text.include?("orcid.org")
  raise "Academic data missing ORCID profile"
end

%w[total h_index i10_index].each do |metric|
  unless academic_text.match?(/metrics:\s*(?:\n\s{4}.+)*\n\s{4}#{metric}:/)
    raise "Citation metrics missing #{metric}"
  end
end

puts "Academic integrations verified across configuration, data sources, and citation metrics."
