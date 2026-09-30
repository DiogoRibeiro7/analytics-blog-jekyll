# frozen_string_literal: true

require "strscan"

module Datalog
  module Citations
    # A practical subset of BibTeX, read without a dependency.
    #
    # It reads every entry type (`@article`, `@book`, `@inproceedings`,
    # `@incollection`, `@phdthesis`, `@techreport`, `@misc`, `@online` and the
    # rest) and the fields `Entry.from_fields` knows; others are kept but not
    # shown. Values may be braced, quoted, bare numbers or `@string` macros,
    # joined with `#`; the month abbreviations (`jan` ... `dec`) are predefined.
    # `@comment`, `@preamble` and text between entries are skipped. The common
    # LaTeX accents and escapes become their characters, and the braces that
    # protect capitals are dropped.
    #
    # A malformed entry raises ParseError with its line, so the build says where.
    module BibTeX
      class ParseError < StandardError; end

      MONTHS = %w[jan feb mar apr may jun jul aug sep oct nov dec].each_with_index.to_h do |name, index|
        [name, (index + 1).to_s]
      end.freeze

      ACCENTS = {
        '"' => "\u0308", "'" => "\u0301", "`" => "\u0300", "^" => "\u0302", "~" => "\u0303",
        "=" => "\u0304", "." => "\u0307", "u" => "\u0306", "v" => "\u030C", "H" => "\u030B",
        "c" => "\u0327", "k" => "\u0328", "r" => "\u030A"
      }.freeze
      SYMBOLS = {
        "ss" => "ß", "o" => "ø", "O" => "Ø", "aa" => "å", "AA" => "Å", "ae" => "æ", "AE" => "Æ",
        "oe" => "œ", "OE" => "Œ", "l" => "ł", "L" => "Ł", "i" => "ı", "j" => "ȷ"
      }.freeze

      module_function

      # [{ "type" => "article", "key" => "smith2020", "fields" => { "title" => "..." } }, ...]
      # The values are as written, braces and LaTeX included: names need their
      # braces to be split (Entry), and latex_to_text makes the rest plain text.
      def parse(text)
        scanner = StringScanner.new(text.to_s)
        macros = MONTHS.dup
        entries = []
        until scanner.eos?
          break unless scanner.skip_until(/@/)

          type = scanner.scan(/[A-Za-z]+/).to_s.downcase
          scanner.skip(/\s*/)
          open = scanner.scan(/[{(]/)
          raise ParseError, "line #{line(scanner)}: @#{type} is not followed by { or (" unless open

          close = open == "{" ? "}" : ")"
          case type
          when "comment", "preamble", ""
            skip_balanced(scanner, open, close)
          when "string"
            name, value = read_field(scanner, macros)
            macros[name] = value if name
            scanner.skip(/\s*[})]/)
          else
            entries << read_entry(scanner, type, close, macros)
          end
        end
        entries
      end

      def read_entry(scanner, type, close, macros)
        start = line(scanner)
        scanner.skip(/\s*/)
        key = scanner.scan(/[^,\s})]+/)
        raise ParseError, "line #{start}: @#{type} has no citation key" unless key

        fields = {}
        loop do
          scanner.skip(/\s*,?\s*/)
          break if scanner.skip(Regexp.new("\\#{close}"))
          raise ParseError, "line #{start}: @#{type}{#{key}, ...} is not closed" if scanner.eos?

          name, value = read_field(scanner, macros)
          raise ParseError, "line #{line(scanner)}: a field of #{key} has no name" unless name

          fields[name] = value
        end
        { "type" => type, "key" => key, "fields" => fields }
      end

      def read_field(scanner, macros)
        scanner.skip(/\s*/)
        name = scanner.scan(/[A-Za-z][\w:.-]*/)
        return [nil, nil] unless name

        scanner.skip(/\s*=\s*/) || raise(ParseError, "line #{line(scanner)}: #{name} has no = and value")
        parts = []
        loop do
          scanner.skip(/\s*/)
          parts << read_value(scanner, macros)
          break unless scanner.skip(/\s*#\s*/)
        end
        [name.downcase, parts.join.gsub(/\s+/, " ").strip]
      end

      def read_value(scanner, macros)
        if scanner.skip(/\{/)
          read_braced(scanner)
        elsif scanner.skip(/"/)
          read_quoted(scanner)
        elsif (number = scanner.scan(/\d+/))
          number
        elsif (macro = scanner.scan(/[A-Za-z][\w:.-]*/))
          macros.fetch(macro.downcase, macro)
        else
          raise ParseError, "line #{line(scanner)}: expected a value near #{scanner.peek(20).inspect}"
        end
      end

      # The text up to the brace that closes the one already read, inner braces kept.
      def read_braced(scanner)
        depth = 1
        value = +""
        until depth.zero?
          raise ParseError, "line #{line(scanner)}: a braced value is not closed" if scanner.eos?

          char = scanner.getch
          if char == "\\"
            value << char << scanner.getch.to_s
            next
          end
          depth += 1 if char == "{"
          depth -= 1 if char == "}"
          value << char unless depth.zero?
        end
        value
      end

      def read_quoted(scanner)
        depth = 0
        value = +""
        loop do
          raise ParseError, "line #{line(scanner)}: a quoted value is not closed" if scanner.eos?

          char = scanner.getch
          if char == "\\"
            value << char << scanner.getch.to_s
            next
          end
          break if char == '"' && depth.zero?

          depth += 1 if char == "{"
          depth -= 1 if char == "}"
          value << char
        end
        value
      end

      def skip_balanced(scanner, open, close)
        depth = 1
        until depth.zero? || scanner.eos?
          char = scanner.getch
          depth += 1 if char == open
          depth -= 1 if char == close
        end
      end

      # LaTeX as BibTeX files write it, turned into the characters it stands for.
      def latex_to_text(value)
        text = accents(value.gsub(/\s+/, " ").strip)
        text = text.gsub(/\{?\\(#{SYMBOLS.keys.sort_by(&:size).reverse.join('|')})(?![A-Za-z])\s*\}?/) do
          SYMBOLS.fetch(Regexp.last_match(1))
        end
        # Escaped braces survive the removal of the braces that only protect case.
        text = text.gsub("\\{", "@@LBRACE@@").gsub("\\}", "@@RBRACE@@")
                   .gsub(/\\([&%$#_])/, '\1')
                   .gsub("---", "\u2014").gsub("--", "\u2013")
                   .gsub(/(?<!\\)~/, "\u00A0")
                   .gsub(/\\(TeX|LaTeX|BibTeX)(?![A-Za-z])/, '\1')
                   .gsub(/\\[A-Za-z]+\s*/, "")
        text.delete("{}").gsub("@@LBRACE@@", "{").gsub("@@RBRACE@@", "}").gsub(/\s+/, " ").strip
      end

      # An accent over one letter: \"{u}, {\"u}, \"u, \'{\i}. A letter command
      # (\c, \v, \u, ...) counts only with a brace or a space after it, so \url
      # is not \u followed by "rl".
      SYMBOL_MARKS = %("'`^~=.)
      LETTER_MARKS = "uvHckr"
      ACCENT = /\{?\\(?:([#{Regexp.escape(SYMBOL_MARKS)}])\s*|([#{LETTER_MARKS}])(?:\s+|(?=\{)))\{?\\?([A-Za-z])\}?\}?/

      def accents(text)
        text.gsub(ACCENT) do
          mark = Regexp.last_match(1) || Regexp.last_match(2)
          (Regexp.last_match(3) + ACCENTS.fetch(mark)).unicode_normalize(:nfc)
        end
      end

      def line(scanner)
        scanner.string[0...scanner.pos].count("\n") + 1
      end
    end
  end
end
