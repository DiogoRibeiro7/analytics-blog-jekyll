# frozen_string_literal: true

require "date"
require "time"

module Datalog
  class Audit
    # What each check looks for in one file. A check returns [line, message]
    # pairs; Audit names the check, its kind and the file.
    class Checks
      KINDS = %w[theorem lemma proposition corollary definition assumption example remark].freeze
      # **Definition 2.**, __Theorem (Bayes)__, > **Lemma**, *Proof.*
      STATEMENT = /\A\s*(?:>\s*)*(?:[-*+]\s+)?(\*\*|__)(#{(KINDS + ['proof']).join('|')})\b[^*_\n]*\1/i
      PROOF = /\A\s*(?:>\s*)*(\*|_)proof\.?\1/i
      TYPED_NUMBER = /\b(Figure|Fig\.|Table)\s+(\d+)\b/
      REFERENCES = /\A\s{0,3}(?:\#{1,6}\s+|\*\*)
                    (References|Bibliography|Works\ cited|Literature\ cited|Sources)(?:\*\*)?[\s\#]*\z/ix
      REPOSITORY = %r{https?://(?:www\.)?(?:github\.com|gitlab\.com|bitbucket\.org|codeberg\.org)/[\w.-]+/[\w.-]+}i
      NOTEBOOK = /\.ipynb\b|colab\.research\.google\.com|mybinder\.org|nbviewer\./i
      DOI = %r{doi\.org/10\.\d{4,9}/|\bdoi:\s*10\.\d{4,9}/}i
      MARKDOWN_IMAGE = /!\[([^\]\n]*)\]\(\s*<?([^)\s>]+)/
      HTML_IMAGE = /<img\b[^>]*>/i
      IMAGE_FILE = /\.(?:png|jpe?g|gif|svg|webp|avif|bmp|tiff?)\z/i
      MARKDOWN_LINK = %r{(?<!!)\[[^\]\n]*\]\(\s*<?(/(?!/)[^)\s>]*)}
      HTML_LINK = %r{\bhref\s*=\s*["'](/(?!/)[^"']*)["']}i
      PART = /\bpart[\s_-]*(\d+|[ivx]+)\b/i
      # A link to a page of the site, and link text that names another part.
      SITE_LINK = %r{\[([^\]\n]*)\]\(\s*<?/}
      SEQUENCE_TEXT = /\b(?:part\s+(?:\d+|[ivx]+)|(?:next|previous)\s+(?:part|post|article|chapter))\b/i

      def initialize(reader:, known_keys:, settings:)
        @reader = reader
        @known_keys = known_keys
        @settings = settings
      end

      # --------------------------------------------------------- opportunities

      def statements(file)
        file.each_line.filter_map do |line, number|
          match = line.match(STATEMENT) || line.match(PROOF)
          next unless match

          kind = (match[2] || "proof").downcase
          [number, "#{kind.capitalize} typed by hand (#{match[0].strip}): {% #{kind} %} numbers it and " \
                   "{% ref %} links to it"]
        end
      end

      def figures(file)
        file.each_line.filter_map do |line, number|
          match = line.match(TYPED_NUMBER)
          next unless match

          tag = match[1] == "Table" ? "table" : "figure"
          [number, "\"#{match[0]}\" typed by hand: {% #{tag} %} numbers it and {% ref %} keeps the " \
                   "number right when the order changes"]
        end
      end

      def references(file)
        return [] if file.body.include?("{% cite") || file.body.include?("{%- cite")

        file.each_line.filter_map do |line, number|
          next unless line.match?(REFERENCES)

          [number, "a references section written by hand: {% cite %} from a BibTeX file numbers the " \
                   "citations and lists the works they cite"]
        end.first(1)
      end

      def reproducibility(file)
        return [] if !file.post? || file.front_matter.key?("reproducibility")

        file.each_line do |line, number|
          found = line[REPOSITORY] || line[NOTEBOOK] || line[DOI]
          if found
            return [[number, "links #{found} but has no reproducibility: block, which sets out the code, " \
                             "data and environment behind the article"]]
          end
        end
        []
      end

      def revisions(file)
        data = file.front_matter
        return [] unless file.post? && !data.key?("revisions")

        published = to_time(data["date"]) || date_from_name(file.relative)
        return [] unless published

        key = %w[last_modified_at updated].find { |name| data[name] }
        edited = key ? to_time(data[key]) : @reader.git_dates[file.relative]
        return [] unless edited && edited - published > revision_gap

        source = key ? "`#{key}`" : "its last commit"
        [[key ? file.key_line(key) : 1,
          "edited #{(edited.to_date - published.to_date).to_i} days after publication (#{source}) with no " \
          "revisions: entry, which tells readers what changed"]]
      end

      # Posts whose titles or file names say "Part 2", or that link to the next
      # part by hand, and are in no series.
      def series(file)
        return [] if file.front_matter.key?("series") || !file.post?

        found = []
        title = file.front_matter["title"].to_s
        part = title[PART] || File.basename(file.relative)[PART]
        if part
          where = title[PART] ? "title" : "file name"
          found << [file.key_line("title"), "\"#{part}\" in the #{where} and no series: series: numbers the " \
                                            "parts and links each to the next"]
        end
        file.each_line do |line, number|
          link = line.scan(SITE_LINK).flatten.find { |text| text.match?(SEQUENCE_TEXT) }
          found << [number, "links to \"#{link}\" by hand: series: links the parts in order"] if link
        end
        found.first(2)
      end

      # -------------------------------------------------------------- problems

      # Fields other themes read and DataLog does not, named so the finding
      # says where a key came from.
      FOREIGN = {
        "Minimal Mistakes" => %w[author_profile seo_type read_time share related sidebar toc_sticky toc_label
                                 toc_icon header_image],
        "Just the Docs" => %w[nav_exclude nav_order parent grand_parent has_children has_toc search_exclude],
        "Chirpy" => %w[pin math_rendering mermaid media_subpath]
      }.freeze

      def front_matter(file)
        file.front_matter.keys.reject { |key| @known_keys.include?(key.to_s) }.map do |key|
          theme = FOREIGN.find { |_, keys| keys.include?(key.to_s) }&.first
          reason = theme ? "a #{theme} field DataLog ignores" : "a typo, or a field of another theme"
          [file.key_line(key), "front matter key \"#{key}\" is read by no layout, include or plugin: #{reason} " \
                               "(audit.known_keys lists a site's own)"]
        end
      end

      def images(file)
        found = []
        file.each_line do |line, number|
          line.scan(MARKDOWN_IMAGE) do |alt, src|
            problem = alt_problem(alt, src)
            found << [number, "image #{src} #{problem}"] if problem
          end
          line.scan(HTML_IMAGE) do
            tag = Regexp.last_match(0)
            src = tag[/\bsrc\s*=\s*["']([^"']*)["']/i, 1].to_s
            alt = tag[/\balt\s*=\s*["']([^"']*)["']/i, 1]
            problem = alt.nil? ? "has no alt attribute" : (alt_problem(alt, src) unless alt.empty?)
            found << [number, "image #{src} #{problem}"] if problem
          end
        end
        found
      end

      def links(file)
        found = []
        file.each_line do |line, number|
          (line.scan(MARKDOWN_LINK) + line.scan(HTML_LINK)).flatten.each do |target|
            path = strip_baseurl(target)
            next if path.include?("{{") || ignored_link?(path) || @reader.built?(path)

            found << [number, "links #{target}, which the site does not build"]
          end
        end
        found
      end

      # Posts only: a page such as the search page loads the engine for math
      # its script fetches, which the page's own source cannot show.
      def math(file)
        data = file.front_matter
        return [] unless file.post?

        key = data.key?("math") ? "math" : ("mathjax" if data.key?("mathjax"))
        return [] unless key && [true, false].include?(data[key])

        found = detect_math(file.body)
        if data[key] == true && !found
          [[file.key_line(key), "#{key}: true loads the math engine, but the page has no math it can find"]]
        elsif data[key] == false && found
          [[file.key_line(key), "#{key}: false leaves the page's math (#{found}) as LaTeX source"]]
        else
          []
        end
      end

      private

      def alt_problem(alt, src)
        text = alt.to_s.strip
        return "has no alt text" if text.empty?

        name = File.basename(src.to_s.split(/[?#]/).first.to_s)
        "has its file name as alt text" if text.match?(IMAGE_FILE) || text == name || text == File.basename(name, ".*")
      end

      def strip_baseurl(target)
        base = @reader.config["baseurl"].to_s.chomp("/")
        base.empty? || !target.start_with?("#{base}/") ? target : target.delete_prefix(base)
      end

      def ignored_link?(path)
        Array(@settings["ignore_links"]).any? { |prefix| path.start_with?(prefix.to_s) }
      end

      # The first expression the math preprocessor would render, or nil.
      def detect_math(body)
        return nil unless defined?(::MathPreprocessor::Processor)

        processor = ::MathPreprocessor::Processor.new(body)
        processor.process
        expression = processor.expressions.first
        expression && expression["latex"].to_s.strip[0, 40]
      end

      def revision_gap
        (@settings["revision_after_days"] || 30).to_i * 86_400
      end

      def to_time(value)
        case value
        when Time then value
        when Date then value.to_time
        when String then Time.parse(value)
        end
      rescue ArgumentError
        nil
      end

      def date_from_name(relative)
        stamp = File.basename(relative)[/\A\d{4}-\d{2}-\d{2}/]
        stamp && Time.parse(stamp)
      end
    end
  end
end
