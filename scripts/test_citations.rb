#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"
require "date"

root = File.join(__dir__, "..")
citation_path = File.join(root, "CITATION.cff")
component_path = File.join(root, "_includes", "components", "citation-tools.html")
head_include_path = File.join(root, "_includes", "head.html")

citation_data = YAML.safe_load_file(citation_path, aliases: true, permitted_classes: [Date])
raise "Citation file missing authors" unless citation_data["authors"]&.any?

raise "Citation metadata missing ORCID identifiers" unless citation_data["authors"].any? { |author| author["orcid"] }

unless citation_data["identifiers"]&.any? { |identifier| identifier["type"] == "url" }
  raise "Citation metadata missing repository URL identifier"
end

component = File.read(component_path)
%w[BibTeX RIS EndNote data-citation-format data-copy-citation].each do |token|
  raise "Citation component missing #{token}" unless component.include?(token)
end

raise "Citation component missing accessible textarea labels" unless component.include?("aria-label=\"BibTeX entry\"")

head_template = File.read(head_include_path)
%w[citation_orcid citation_doi citation_pdf].each do |meta_key|
  raise "Head include missing #{meta_key} metadata" unless head_template.include?(meta_key)
end

puts "Citation tooling verified for BibTeX/RIS/EndNote exports and structured metadata."
