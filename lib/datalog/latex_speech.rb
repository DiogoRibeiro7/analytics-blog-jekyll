# frozen_string_literal: true

require "json"

module Datalog
  # Reads a LaTeX expression as words, for the label a screen reader announces.
  # Symbols are spoken as words, since a screen reader may skip "∈" or "ℝ" at
  # its usual settings. A command is read, or dropped when it draws nothing,
  # but never lost because no table knows it: an unknown one is read by its
  # name (#417).
  #
  # The browser reads expressions the same way (assets/js/math/latex-speech.js),
  # from the same table, latex_speech/words.json, and both test suites check
  # tests/fixtures/latex-speech.json.
  module LatexSpeech
    TABLE = JSON.parse(File.read(File.expand_path("latex_speech/words.json", __dir__))).freeze
    WORDS = TABLE["greek"].to_h { |name| [name, name] }
                          .merge(TABLE["greek"].to_h { |name| ["#{name[0].upcase}#{name[1..]}", "capital #{name}"] })
                          .merge(TABLE["words"]).freeze
    BIG_OPERATORS = TABLE["big_operators"].freeze
    LIMITS = TABLE["limits"].freeze
    TEXT = TABLE["text"].to_set.freeze
    TEXT_MODE = TABLE["text_mode"].to_set.freeze
    STYLES = TABLE["styles"].freeze
    ACCENTS = TABLE["accents"].freeze
    SILENT_WITH_ARGUMENT = TABLE["silent_with_argument"].to_set.freeze
    SIZES = TABLE["sizes"].to_set.freeze
    MATRICES = TABLE["matrices"].to_set.freeze
    WITH_COLUMNS = TABLE["with_columns"].to_set.freeze
    MAX_DEPTH = 64

    module_function

    # The words a LaTeX expression reads as, or "" when it has none.
    def speak(latex)
      # Single spaces, none inside brackets or before punctuation. After the
      # collapse each pattern matches a fixed character or two, so none
      # backtracks.
      words = Reader.new(tokenize(latex), depth: 0, environments: []).read
                    .gsub(/[[:space:]]+/, " ")
                    .gsub(/ ([,;:.!?)\]}])/, '\1')
                    .gsub(/([(\[{]) /, '\1')
                    .gsub(/;(?=;)/, "")
      # A line break or a separator at either end reads as nothing.
      edge = [" ", ";", ","]
      chars = words.chars
      chars.shift while edge.include?(chars.first)
      chars.pop while edge.include?(chars.last)
      chars.join
    end

    # Splits LaTeX into commands, brace groups and characters. It walks the
    # text once, keeping open groups on a stack rather than recursing, and
    # drops an unescaped % and the rest of its line.
    def tokenize(source)
      chars = source.to_s.chars
      root = []
      stack = [root]
      index = 0
      while index < chars.length
        char = chars[index]
        current = stack.last
        case char
        when "\\"
          token, index = command_token(chars, index)
          current << token if token
        when "{"
          group = { type: :group, tokens: [] }
          current << group
          stack << group[:tokens]
          index += 1
        when "}"
          stack.pop if stack.length > 1
          index += 1
        when "%"
          index += 1 while index < chars.length && chars[index] != "\n"
        else
          if char.match?(/[[:space:]]/)
            current << { type: :space } unless current.last && current.last[:type] == :space
          else
            current << { type: :char, value: char }
          end
          index += 1
        end
      end
      root
    end

    # The command a backslash at `index` starts: a run of letters, or the one
    # character after it. A backslash that ends the text is none.
    def command_token(chars, index)
      finish = index + 1
      finish += 1 while finish < chars.length && letter?(chars[finish])
      finish += 1 if finish == index + 1 && finish < chars.length
      token = { type: :command, name: chars[(index + 1)...finish].join } if finish > index + 1
      [token, finish]
    end

    def letter?(char)
      char.match?(/\A[a-zA-Z]\z/)
    end

    # Reads one list of tokens, as the browser's speak() does.
    class Reader
      SPECIAL = {
        "frac" => :fraction, "dfrac" => :fraction, "tfrac" => :fraction, "cfrac" => :fraction,
        "binom" => :binomial, "dbinom" => :binomial, "tbinom" => :binomial, "sqrt" => :root,
        "begin" => :environment_change, "end" => :environment_change, "\\" => :line_break, "pmod" => :pmod,
        "textcolor" => :text_color, "overset" => :marked, "stackrel" => :marked, "underset" => :marked
      }.freeze

      def initialize(tokens, context)
        @tokens = tokens
        @context = context
        @inner = context.merge(depth: context[:depth] + 1)
        @index = 0
        @out = +""
      end

      def read
        return "" if @context[:depth] > MAX_DEPTH

        while @index < @tokens.length
          token = @tokens[@index]
          @index += 1
          case token[:type]
          when :space then @out << " "
          when :group then @out << Reader.new(token[:tokens], @inner).read
          when :char then character(token[:value])
          else command(token[:name])
          end
        end
        @out
      end

      private

      def character(char)
        return @out << char if @context[:text]

        case char
        when "^" then word(superscript(argument))
        when "_" then word("sub #{read_tokens(argument)}")
        when "'" then primes
        when "&" then @out << (MATRICES.include?(current_environment) || current_environment == "cases" ? ", " : " ")
        when "~" then @out << " "
        else @out << char
        end
      end

      def command(name)
        return send(SPECIAL[name], name) if SPECIAL.key?(name)
        return big_operator(name) if BIG_OPERATORS.key?(name)
        return limit(name) if LIMITS.key?(name)
        return word("approaches") if name == "to" && @context[:approaches]

        family(name)
      end

      def family(name)
        if TEXT.include?(name)
          star
          word(read_tokens(argument, @inner.merge(text: TEXT_MODE.include?(name))))
        elsif STYLES.key?(name) then word("#{STYLES[name]} #{read_tokens(argument)}")
        elsif ACCENTS.key?(name) then word("#{read_tokens(argument)} #{ACCENTS[name]}")
        elsif SIZES.include?(name) then @index += 1 if char?(@tokens[@index], ".")
        elsif SILENT_WITH_ARGUMENT.include?(name)
          star
          argument
        elsif WORDS.key?(name) then word(WORDS[name])
        elsif LatexSpeech.letter?(name[0])
          # A function name (\sin, \log) is read as written, and so is a command
          # nothing here knows, rather than lost.
          word(name)
        end
      end

      def fraction(_name)
        top = read_tokens(argument)
        word("#{top} over #{read_tokens(argument)}")
      end

      def binomial(_name)
        top = read_tokens(argument)
        word("#{top} choose #{read_tokens(argument)}")
      end

      def root(_name)
        degree = optional
        order = degree ? read_tokens(degree) : "2"
        word("#{TABLE['roots'][order] || "#{order}th root"} of #{read_tokens(argument)}")
      end

      def environment_change(name)
        environment = argument.filter_map { |token| token[:value] if token[:type] == :char }.join.strip.sub("*", "")
        if name == "begin"
          @context[:environments] << environment
          argument if WITH_COLUMNS.include?(environment)
        else
          @context[:environments].pop
        end
        kind = if environment == "cases" then "cases"
               elsif MATRICES.include?(environment) then "matrix"
               end
        word(name == "begin" ? kind : "end #{kind}") if kind
      end

      def line_break(_name)
        optional
        word(";")
      end

      def pmod(_name)
        word("mod #{read_tokens(argument)}")
      end

      def text_color(_name)
        argument
        word(read_tokens(argument, @inner.merge(text: true)))
      end

      def marked(name)
        mark = read_tokens(argument)
        word("#{read_tokens(argument)} with #{mark} #{name == 'underset' ? 'below' : 'above'}")
      end

      def big_operator(name)
        found = limits(@inner)
        lower = found[:lower]
        upper = found[:upper]
        phrase = BIG_OPERATORS[name]
        phrase += if lower && !lower.empty? && upper && !upper.empty? then " from #{lower} to #{upper}"
                  elsif lower && !lower.empty? then " over #{lower}"
                  elsif upper && !upper.empty? then " to #{upper}"
                  else ""
                  end
        word(phrase)
      end

      def limit(name)
        found = limits(@inner.merge(approaches: true))
        parts = [LIMITS[name]]
        parts << "as #{found[:lower]}" if found[:lower] && !found[:lower].empty?
        parts << "to the power #{found[:upper]}" if found[:upper] && !found[:upper].empty?
        word(parts.join(" "))
      end

      # The sub- and superscript after an operator, in either order.
      def limits(lower_context)
        found = {}
        loop do
          skip_spaces
          token = @tokens[@index]
          if command?(token, "limits") || command?(token, "nolimits")
            @index += 1
          elsif char?(token, "_") && !found.key?(:lower)
            @index += 1
            found[:lower] = read_tokens(argument, lower_context)
          elsif char?(token, "^") && !found.key?(:upper)
            @index += 1
            found[:upper] = read_tokens(argument)
          else
            return found
          end
        end
      end

      def superscript(raised)
        single = raised.length == 1 ? raised.first : nil
        return "degrees" if command?(single, "circ")
        return "transpose" if command?(single, "top")

        content = read_tokens(raised)
        TABLE["superscripts"].fetch(content) { "to the power #{content}" }
      end

      def primes
        count = 1
        while char?(@tokens[@index], "'")
          count += 1
          @index += 1
        end
        word(TABLE["primes"][count] || Array.new(count, "prime").join(" "))
      end

      def current_environment
        @context[:environments].last
      end

      def word(value)
        @out << " #{value} " if value && !value.empty?
      end

      def skip_spaces
        @index += 1 while @tokens[@index] && @tokens[@index][:type] == :space
      end

      # The next argument: a group's tokens, or a single token.
      def argument
        skip_spaces
        token = @tokens[@index]
        return [] unless token

        @index += 1
        token[:type] == :group ? token[:tokens] : [token]
      end

      def optional
        skip_spaces
        return nil unless char?(@tokens[@index], "[")

        collected = []
        @index += 1
        while @index < @tokens.length && !char?(@tokens[@index], "]")
          collected << @tokens[@index]
          @index += 1
        end
        @index += 1
        collected
      end

      def star
        @index += 1 if char?(@tokens[@index], "*")
      end

      def read_tokens(tokens, context = @inner)
        Reader.new(tokens, context).read.strip
      end

      def char?(token, value)
        token && token[:type] == :char && token[:value] == value
      end

      def command?(token, name)
        token && token[:type] == :command && token[:name] == name
      end
    end
  end
end
