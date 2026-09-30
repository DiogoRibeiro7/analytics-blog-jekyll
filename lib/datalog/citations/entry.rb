# frozen_string_literal: true

require "cgi"
require "strscan"
require_relative "bibtex"

module Datalog
  module Citations
    # A work a page can cite, in one shape whether it came from BibTeX, CSL-JSON
    # or front matter. Every value is plain text; the HTML methods escape it.
    class Entry
      # A person, or an organisation written as one literal name.
      Name = Struct.new(:family, :given, :literal) do
        def family_name
          literal || family.to_s
        end

        # "Müller, J." in the reference list.
        def listed
          return literal if literal
          return family.to_s if given.to_s.empty?

          "#{family}, #{initials}"
        end

        def initials
          given.to_s.split(/[\s.]+/).reject(&:empty?).map do |part|
            part.split("-").map { |piece| "#{piece[0]}." }.join("-")
          end.join(" ")
        end

        # "Jörg Müller", as a name reads in metadata.
        def full
          literal || [given, family].compact.reject(&:empty?).join(" ")
        end

        # "Müller, Jörg", as Highwire's citation_author has it.
        def inverted
          literal || [family, given].compact.reject(&:empty?).join(", ")
        end
      end

      FIELDS = %i[key type authors title container publisher year volume issue pages doi url note].freeze
      attr_reader(*FIELDS)
      attr_accessor :others

      # Types whose own title is the published thing: set in italics, as in APA.
      STANDALONE = %w[book thesis report webpage].freeze
      DOI = %r{\A(?:https?://(?:dx\.)?doi\.org/|doi:)?(10\.\d{4,9}/\S+)\z}i
      URL = %r{\Ahttps?://[^\s<>"'`]+\z}i

      def initialize(**fields)
        FIELDS.each { |field| instance_variable_set(:"@#{field}", fields[field]) }
        @authors = Array(@authors)
        @others = fields[:others] || false
        @key = @key.to_s
      end

      # ---------------------------------------------------------------- sources

      BIBTEX_TYPES = {
        "article" => "article", "book" => "book", "booklet" => "book", "inproceedings" => "paper-conference",
        "conference" => "paper-conference", "incollection" => "chapter", "inbook" => "chapter",
        "phdthesis" => "thesis", "mastersthesis" => "thesis", "thesis" => "thesis", "techreport" => "report",
        "report" => "report", "online" => "webpage", "electronic" => "webpage", "www" => "webpage"
      }.freeze

      # Where each field of an entry comes from, first match wins.
      BIBTEX_FIELDS = {
        title: %w[title], container: %w[journal journaltitle booktitle series],
        publisher: %w[publisher school institution organization], year: %w[year date],
        volume: %w[volume], issue: %w[number issue], pages: %w[pages], doi: %w[doi]
      }.freeze

      def self.from_bibtex(record)
        fields = record["fields"]
        values = BIBTEX_FIELDS.transform_values do |names|
          value = fields.values_at(*names).compact.first
          value && BibTeX.latex_to_text(value)
        end
        names, others = bibtex_names(fields["author"] || fields["editor"])
        link = [fields["url"], fields["howpublished"]].compact.map { |value| BibTeX.latex_to_text(value) }.first
        address = link if link&.match?(URL)
        note = fields["note"] ? BibTeX.latex_to_text(fields["note"]) : (link unless address)
        new(**values, key: record["key"], type: BIBTEX_TYPES.fetch(record["type"], "misc"), authors: names,
                      others: others, year: values[:year].to_s[/\d{4}/], url: address, note: note)
      end

      # "Last, First and First von Last and {Organisation} and others".
      def self.bibtex_names(value)
        return [[], false] if value.to_s.strip.empty?

        parts = split_top_level(value, /\s+and\s+/i)
        others = parts.last&.strip&.casecmp?("others") || false
        parts.pop if others
        [parts.map { |part| bibtex_name(part.strip) }, others]
      end

      def self.bibtex_name(raw)
        return Name.new(nil, nil, BibTeX.latex_to_text(raw)) if raw.match?(/\A\{.*\}\z/m) && balanced?(raw[1..-2])

        pieces = split_top_level(raw, /\s*,\s*/)
        if pieces.size >= 2
          # "von Last, First" or "von Last, Jr, First"
          family = pieces.first
          family = "#{family}, #{pieces[1]}" if pieces.size > 2
          return Name.new(BibTeX.latex_to_text(family), BibTeX.latex_to_text(pieces.last), nil)
        end

        words = split_top_level(raw, /\s+/)
        return Name.new(BibTeX.latex_to_text(raw), nil, nil) if words.size == 1

        # "First von Last": the family name is the last word with the lowercase
        # particles before it.
        family_start = words.size - 1
        family_start -= 1 while family_start > 1 && words[family_start - 1].match?(/\A[[:lower:]]/)
        given = words[0...family_start].join(" ")
        Name.new(BibTeX.latex_to_text(words[family_start..].join(" ")), BibTeX.latex_to_text(given), nil)
      end

      # Splits at `separator` outside braces.
      def self.split_top_level(value, separator)
        parts = []
        depth = 0
        current = +""
        scanner = StringScanner.new(value)
        until scanner.eos?
          if depth.zero? && scanner.scan(separator)
            parts << current
            current = +""
            next
          end
          char = scanner.getch
          depth += 1 if char == "{"
          depth -= 1 if char == "}"
          current << char
        end
        parts << current
        parts.reject { |part| part.strip.empty? }
      end

      def self.balanced?(text)
        depth = 0
        text.each_char do |char|
          depth += 1 if char == "{"
          depth -= 1 if char == "}"
          return false if depth.negative?
        end
        depth.zero?
      end

      CSL_TYPES = {
        "article-journal" => "article", "article-magazine" => "article", "article-newspaper" => "article",
        "article" => "article", "book" => "book", "chapter" => "chapter", "paper-conference" => "paper-conference",
        "thesis" => "thesis", "report" => "report", "webpage" => "webpage", "post-weblog" => "webpage"
      }.freeze

      def self.from_csl(item)
        names = Array(item["author"] || item["editor"]).map do |name|
          next Name.new(nil, nil, name.to_s) unless name.is_a?(Hash)

          name["literal"] ? Name.new(nil, nil, name["literal"].to_s) : Name.new(name["family"].to_s, name["given"], nil)
        end
        issued = item["issued"] || {}
        year = Array(Array(issued["date-parts"]).first).first || issued["raw"] || issued["literal"]
        url = item["URL"].to_s
        new(key: item["id"], type: CSL_TYPES.fetch(item["type"].to_s, "misc"), authors: names,
            title: item["title"], container: item["container-title"] || item["collection-title"],
            publisher: item["publisher"], year: year.to_s[/\d{4}/], volume: item["volume"]&.to_s,
            issue: item["issue"]&.to_s, pages: item["page"]&.to_s, doi: item["DOI"],
            url: url.match?(URL) ? url : nil, note: item["note"])
      end

      FRONT_MATTER_FIELDS = {
        title: %w[title], container: %w[journal booktitle conference container], publisher: %w[publisher],
        volume: %w[volume], issue: %w[issue number], pages: %w[pages], doi: %w[doi], note: %w[note]
      }.freeze

      # The `citations:` entries a page lists: a map in the fields above, or a
      # string, which is cited by its slug and listed as written.
      def self.from_front_matter(value)
        return new(key: Datalog::Citations.slug(value), type: "misc", title: value.to_s) unless value.is_a?(Hash)

        data = value.transform_keys(&:to_s)
        values = FRONT_MATTER_FIELDS.transform_values { |names| data.values_at(*names).compact.first&.to_s }
        url = data["url"].to_s
        new(**values, key: data["id"] || data["key"], type: data["type"] || "misc",
                      authors: front_matter_names(data["authors"] || data["author"]),
                      year: data["year"].to_s[/\d{4}/], url: url.match?(URL) ? url : nil)
      end

      # ["Doe, Jo", "Ann Roe"] or "Doe, Jo and Ann Roe".
      def self.front_matter_names(authors)
        authors = authors.split(/\s+and\s+/) if authors.is_a?(String)
        Array(authors).map do |name|
          next Name.new(nil, nil, name.to_s) unless name.is_a?(String)

          family, given = name.split(/\s*,\s*/, 2)
          given ? Name.new(family, given, nil) : bibtex_name(name)
        end
      end

      # ------------------------------------------------------------------ links

      # https://doi.org/10.1234/x for a DOI, else the entry's http(s) address;
      # nothing else (javascript:, data:, a relative path) is ever a link.
      def link
        doi_link || (url if url.to_s.match?(URL))
      end

      def doi_link
        match = doi.to_s.strip.match(DOI)
        "https://doi.org/#{match[1]}" if match
      end

      # --------------------------------------------------------------- in text

      # "Smith", "Smith and Jones", "Smith et al.", or the title when there is
      # no author.
      def names_in_text(words)
        family = authors.map(&:family_name)
        return short_title if family.empty?
        return "#{family.first} #{words.fetch(:et_al)}" if family.size > 2 || others
        return "#{family.first} #{words.fetch(:and)} #{family.last}" if family.size == 2

        family.first
      end

      def short_title
        words = title.to_s.split
        words.size > 4 ? "#{words.first(4).join(' ')}\u2026" : title.to_s
      end

      def year_or(no_date)
        year.to_s.empty? ? no_date : year.to_s
      end

      # First author, year, title: the order of an author-year reference list.
      def sort_key
        [authors.first&.family_name.to_s.downcase, year.to_s, title.to_s.downcase]
      end

      # ----------------------------------------------------------------- HTML

      # The entry as the reference list shows it, in the manner of APA:
      #   Müller, J., & Smith, A. (2020). Title. Journal, 12(2), 10-20. https://doi.org/...
      def reference_html(words, suffix: "")
        date = "(#{h(year_or(words.fetch(:no_date)))}#{h(suffix)})."
        parts = []
        if authors.empty?
          parts << "#{title_html}." if title
          parts << date
        else
          parts << "#{h(listed_authors(words))} #{date}"
          parts << "#{title_html}." if title
        end
        parts << "#{container_html}." if container
        parts << "#{h(publisher)}." if publisher && !publisher.empty?
        parts << "#{h(note)}." if note && !note.empty?
        address = link
        parts << %(<a href="#{h(address)}" rel="noopener noreferrer">#{h(address)}</a>) if address
        parts.join(" ").gsub(/([.?!])\./, '\1')
      end

      def listed_authors(words)
        names = authors.first(20).map(&:listed)
        names << words.fetch(:et_al) if others || authors.size > 20
        return names.first.to_s if names.size == 1

        "#{names[0..-2].join(', ')} #{words.fetch(:and)} #{names.last}"
      end

      def title_html
        STANDALONE.include?(type) ? "<em>#{h(title)}</em>" : h(title)
      end

      def container_html
        text = "<em>#{h(container)}</em>"
        text += ", #{h(volume)}" if volume && !volume.empty?
        text += "(#{h(issue)})" if issue && !issue.empty?
        text += ", #{h(pages)}" if pages && !pages.empty?
        text
      end

      # ------------------------------------------------------------- metadata

      # One Highwire citation_reference: "citation_title=...; citation_author=...".
      def highwire
        pairs = [["citation_title", title]]
        authors.each { |name| pairs << ["citation_author", name.inverted] }
        pairs << ["citation_publication_date", year]
        pairs << [type == "paper-conference" ? "citation_conference_title" : "citation_journal_title", container]
        pairs << ["citation_publisher", publisher] if STANDALONE.include?(type)
        pairs.push(["citation_volume", volume], ["citation_issue", issue])
        first, last = pages.to_s.split(/\s*[-\u2013\u2014]+\s*/, 2)
        pairs.push(["citation_firstpage", first], ["citation_lastpage", last])
        pairs << ["citation_doi", doi_link&.delete_prefix("https://doi.org/")]
        pairs.reject { |_, value| value.to_s.strip.empty? }
             .map { |name, value| "#{name}=#{value.to_s.tr(';', ',').strip}" }.join("; ")
      end

      # A schema.org CreativeWork for the JSON-LD `citation` list.
      def json_ld
        work = { "@type" => "CreativeWork", "name" => title.to_s }
        people = authors.map do |name|
          { "@type" => name.literal ? "Organization" : "Person", "name" => name.full }
        end
        work["author"] = people unless people.empty?
        work["datePublished"] = year.to_s if year
        work["isPartOf"] = container.to_s if container
        if doi_link
          work["sameAs"] = doi_link
        elsif link
          work["url"] = link
        end
        work
      end

      private

      def h(value)
        CGI.escapeHTML(value.to_s)
      end
    end

    module_function

    # "Smith and Jones (2020)" in a string entry's text becomes smith-and-jones-2020.
    def slug(value)
      value.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
    end
  end
end
