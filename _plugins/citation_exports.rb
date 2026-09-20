# frozen_string_literal: true

module Datalog
  module CitationExports
    module_function

    TYPES = {
      "article" => ["article", "JOUR", "Journal Article"],
      "journal" => ["article", "JOUR", "Journal Article"],
      "blog" => %w[misc BLOG Blog],
      "dataset" => %w[misc DATA Dataset],
      "software" => ["misc", "COMP", "Computer Program"],
      "book" => %w[book BOOK Book],
      "inproceedings" => ["inproceedings", "CPAPER", "Conference Paper"],
      "misc" => %w[misc GEN Generic]
    }.freeze

    def text(value)
      value.to_s.gsub(/\s+/, " ").strip
    end

    def bibtex(value)
      text(value).gsub(/[\\&%$#_{}~^]/) do |character|
        { "\\" => '\\textbackslash{}', "~" => '\\textasciitilde{}', "^" => '\\textasciicircum{}' }
          .fetch(character) { "\\#{character}" }
      end
    end

    def render(record, authors, kind, key)
      bib_type, ris_type, endnote_type = TYPES.fetch(kind.to_s.downcase, TYPES["misc"])
      names = authors.map { |author| text(Authors.value(author, "name") || author) }
      bib_names = authors.each_with_index.map do |author, index|
        name = bibtex(names[index])
        Authors.value(author, "type") == "Organization" ? "{#{name}}" : name
      end
      fields = { "title" => bibtex(record["title"]), "author" => bib_names.join(" and ") }
      record.each { |field, value| fields[field] = bibtex(value) unless field == "title" || value.to_s.empty? }
      body = fields.map { |field, value| "  #{field} = { #{value} }" }.join(",\n")
      bib = "@#{bib_type}{ #{key},\n#{body}\n}"

      { "bibtex" => bib, "ris" => ris(record, names, ris_type), "endnote" => endnote(record, names, endnote_type) }
    end

    def ris(record, names, type)
      lines = ["TY  - #{type}", "TI  - #{text(record['title'])}"]
      lines.concat(names.map { |name| "AU  - #{name}" })
      { "year" => "PY", "publisher" => "PB", "journal" => "JO", "doi" => "DO", "url" => "UR",
        "volume" => "VL", "number" => "IS" }.each do |field, tag|
        lines << "#{tag}  - #{text(record[field])}" unless record[field].to_s.empty?
      end
      unless record["pages"].to_s.empty?
        first, last = text(record["pages"]).split(/[-–—]+/, 2)
        lines << "SP  - #{first}"
        lines << "EP  - #{last}" if last
      end
      (lines << "ER  -").join("\n")
    end

    def endnote(record, names, type)
      lines = ["%0 #{type}", "%T #{text(record['title'])}"]
      lines.concat(names.map { |name| "%A #{name}" })
      { "year" => "D", "publisher" => "I", "journal" => "J", "doi" => "R", "url" => "U",
        "volume" => "V", "number" => "N", "pages" => "P" }.each do |field, tag|
        lines << "%#{tag} #{text(record[field])}" unless record[field].to_s.empty?
      end
      lines.join("\n")
    end
  end

  module CitationExportFilters
    def citation_exports(page, options = {})
      site = @context["site"]
      get = ->(key) { Authors.value(options, key) || Authors.value(page, key) }
      title = get.call("title") || Authors.value(site, "title")
      authors = Authors.value(options, "authors") || Authors.authors(page, site)
      authors = Authors.entries(authors)
      publisher = get.call("publisher") || Authors.value(Authors.value(site, "publisher"), "name") ||
                  Authors.value(site, "title")
      key = slugify(get.call("citation_key") || Authors.value(page, "slug") || title)
      kind = get.call("citation_type") || Authors.value(options, "type") || "article"
      record = {
        "title" => title, "year" => (date(get.call("date"), "%Y") if get.call("date")),
        "publisher" => publisher, "journal" => get.call("journal") || get.call("publication"),
        "doi" => get.call("doi"), "url" => absolute_url(get.call("url") || "/"),
        "volume" => get.call("volume"), "number" => get.call("issue") || get.call("number"),
        "pages" => get.call("pages")
      }
      CitationExports.render(record, authors, kind, key)
    end
  end
end

Liquid::Template.register_filter(Datalog::CitationExportFilters)
