# frozen_string_literal: true

module Jekyll
  class PublicationsGenerator < Generator
    safe true
    priority :low

    def generate(site)
      publications_data = site.data["publications"]
      # _data/publications.yml is normally a map with `settings` and
      # `manual_entries`; a plain list of entries is read as the manual
      # entries rather than stopping the build with a TypeError.
      publications_data = { "manual_entries" => publications_data } if publications_data.is_a?(Array)
      publications_data = {} unless publications_data.is_a?(Hash)
      site.data["publications"] = publications_data
      settings = publications_data["settings"] || {}
      config_source = site.config.dig("theme_options", "publications", "bibtex_source")
      bibtex_source = settings["bibtex_source"] || config_source

      imported_entries = []
      if bibtex_source
        bibtex_path = site.in_source_dir(bibtex_source)
        if File.exist?(bibtex_path)
          content = File.read(bibtex_path, encoding: "UTF-8")
          imported_entries = parse_bibtex_entries(content)
        else
          Jekyll.logger.warn("PublicationsGenerator:", "BibTeX source not found at #{bibtex_path}")
        end
      end

      manual_entries = Array(publications_data["manual_entries"]).select { |entry| entry.is_a?(Hash) }
      combined = (imported_entries + manual_entries).map { |entry| normalize_entry(entry) }

      academic_citations = site.data.dig("academic", "citations", "per_publication") || {}
      citations_map = {}
      combined.each do |entry|
        identifier = entry["id"] || parameterize(entry["title"])
        citation_info = locate_citation_info(academic_citations, identifier)
        if citation_info
          entry["citations"] = citation_info["total"] || citation_info[:total]
          entry["citations_last_updated"] = citation_info["last_updated"] || citation_info[:last_updated]
        end
        next unless identifier

        citations_map[identifier] = {
          "total" => entry["citations"]&.to_i,
          "last_updated" => entry["citations_last_updated"]
        }
      end

      sort_order = (settings["sort"] || settings["sort_order"] || "descending").to_s
      combined.sort_by! { |entry| [entry["year"] ? entry["year"].to_i : 0, entry["title"].to_s.downcase] }
      combined.reverse! if sort_order == "descending"

      group_field = settings["group_by"] || site.config.dig("theme_options", "publications", "group_by")
      grouped = group_entries(combined, group_field, sort_order)

      include_bibliography = if settings.key?("include_bibliography")
                               settings["include_bibliography"]
                             else
                               site.config.dig(
                                 "theme_options", "publications", "include_bibliography"
                               )
                             end
      exports = settings["export_formats"] || site.config.dig("theme_options", "publications", "export_formats") || []

      metrics_override = site.data.dig("academic", "citations", "metrics") || {}
      metrics = compute_metrics(combined, citations_map, metrics_override)

      publications_data["imported"] = imported_entries
      publications_data["entries"] = combined
      publications_data["grouped"] = grouped if grouped
      publications_data["citation_totals"] = citations_map
      publications_data["metrics"] = metrics
      publications_data["yearly_totals"] = metrics["yearly_totals"]
      return unless include_bibliography

      publications_data["bibliography"] = build_bibliography(combined)
      publications_data["export_formats"] = exports
    end

    private

    ENTRY_REGEX = /@(?<type>\w+)\s*\{\s*(?<key>[^,]+),\s*(?<fields>.*?)\}\s*(?=@|\z)/m

    def parse_bibtex_entries(content)
      entries = []
      content.to_s.scan(ENTRY_REGEX) do |type, key, raw_fields|
        fields = {}
        raw_fields.lines.each do |line|
          cleaned = line.strip
          next if cleaned.empty?

          cleaned = cleaned.delete_suffix(",")
          name, value = cleaned.split("=", 2)
          next unless name && value

          name = name.strip.downcase
          value = value.strip
          value = value.gsub(/\A["{]+/, "").gsub(/["}]+\z/, "")
          fields[name] = value.strip
        end
        entries << {
          "id" => key.strip,
          "type" => type.strip.downcase,
          "title" => fields["title"],
          "authors" => parse_authors(fields["author"]),
          "venue" => fields["journal"] || fields["booktitle"] || fields["institution"],
          "year" => fields["year"],
          "doi" => fields["doi"],
          "url" => fields["url"],
          "raw" => fields
        }
      end
      entries
    end

    def parse_authors(raw)
      return [] unless raw

      raw.split(/\s+and\s+/i).map(&:strip)
    end

    def normalize_entry(entry)
      normalized = entry.transform_keys(&:to_s)
      normalized["authors"] = parse_authors(normalized["authors"]) if normalized["authors"].is_a?(String)
      normalized["year"] = normalized["year"].to_s if normalized["year"]
      normalized
    end

    def locate_citation_info(map, identifier)
      return nil unless identifier

      map[identifier] || map[identifier.to_s] || map[identifier.to_s.downcase]
    end

    def parameterize(value)
      return nil unless value

      value.to_s.downcase.strip.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
    end

    def group_entries(entries, field, sort_order)
      return nil unless field && !field.to_s.empty?

      grouped = entries.group_by { |entry| entry[field.to_s] || "Other" }
      sorted = grouped.sort_by do |group_key, _|
        group_value = group_key.to_s
        if group_value.match?(/\A\d+\z/)
          group_value.to_i
        else
          group_value.downcase
        end
      end
      sorted.reverse! if sort_order == "descending"
      sorted
    end

    def compute_metrics(entries, citations_map, override)
      yearly_totals = Hash.new(0)
      citation_counts = []
      entries.each do |entry|
        year = entry["year"]
        citations = entry["citations"]
        citation_value = citations.to_i if citations
        if citation_value&.positive?
          citation_counts << citation_value
          yearly_totals[year.to_s] += citation_value if year
        elsif year
          yearly_totals[year.to_s] += 1
        end
      end

      citation_counts.sort! { |a, b| b <=> a }
      total = citation_counts.reduce(0, :+)
      h_index = 0
      citation_counts.each_with_index do |count, index|
        h_index = index + 1 if count >= index + 1
      end
      i10_index = citation_counts.count { |count| count >= 10 }

      metrics = {
        "total" => total,
        "h_index" => h_index,
        "i10_index" => i10_index,
        "per_publication" => citations_map,
        "yearly_totals" => yearly_totals
      }

      override.each do |key, value|
        metrics[key.to_s] = if value.is_a?(Hash)
                              merge_nested_hash(metrics[key.to_s], value)
                            else
                              value
                            end
      end

      metrics
    end

    def merge_nested_hash(base, override)
      base = (base || {}).transform_keys(&:to_s)
      override.each do |key, value|
        key = key.to_s
        base[key] = if value.is_a?(Hash)
                      merge_nested_hash(base[key], value)
                    else
                      value
                    end
      end
      base
    end

    def build_bibliography(entries)
      entries.map { |entry| format_bibtex(entry) }.compact
    end

    def format_bibtex(entry)
      type = entry["type"] || "article"
      identifier = entry["id"] || parameterize(entry["title"]) || "reference"
      authors = Array(entry["authors"]).map { |author| author.to_s.strip }.reject(&:empty?)
      buffer = []
      buffer << "@#{type}{ #{identifier},"
      buffer << "  title = { #{entry['title']} }," if entry["title"]
      buffer << "  author = { #{authors.join(' and ')} }," if authors.any?
      buffer << "  year = { #{entry['year']} }," if entry["year"]
      buffer << "  journal = { #{entry['venue']} }," if entry["venue"]
      buffer << "  doi = { #{entry['doi']} }," if entry["doi"]
      buffer << "  url = { #{entry['url']} }," if entry["url"]
      raw_fields = entry["raw"] || {}
      %w[volume number pages publisher].each do |field|
        next unless raw_fields[field]

        buffer << "  #{field} = { #{raw_fields[field]} },"
      end
      buffer << "}"
      buffer.join("\n")
    end
  end
end
