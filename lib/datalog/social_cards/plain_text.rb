# frozen_string_literal: true

module Datalog
  module SocialCards
    # A title's TeX as readable text: "$\alpha$-stable laws for $X_t^2$"
    # becomes "α-stable laws for X_t²". A share card is an image, so nothing
    # typesets the maths on it; what is left has to read on its own.
    #
    # Inline maths is $...$ or \(...\), display maths $$...$$ or \[...\], by
    # the rules the math preprocessor follows: a dollar sign with a space
    # after it opens maths only when what follows holds a command, ^ or _
    # (`$ \frac{a}{b} $`), and a digit after the closing one makes it money
    # (`$5 and $10`). Outside maths only the escaped characters change.
    module PlainText
      module_function

      GREEK = %w[
        alpha α beta β gamma γ delta δ epsilon ε varepsilon ε zeta ζ eta η theta θ vartheta ϑ iota ι kappa κ
        lambda λ mu μ nu ν xi ξ pi π varpi ϖ rho ρ varrho ϱ sigma σ varsigma ς tau τ upsilon υ phi φ varphi φ
        chi χ psi ψ omega ω Gamma Γ Delta Δ Theta Θ Lambda Λ Xi Ξ Pi Π Sigma Σ Upsilon Υ Phi Φ Psi Ψ Omega Ω
      ].each_slice(2).to_h.freeze

      SYMBOLS = {
        "leq" => "≤", "le" => "≤", "geq" => "≥", "ge" => "≥", "neq" => "≠", "ne" => "≠", "approx" => "≈",
        "sim" => "~", "simeq" => "≃", "equiv" => "≡", "propto" => "∝", "infty" => "∞", "in" => "∈",
        "notin" => "∉", "subset" => "⊂", "subseteq" => "⊆", "cup" => "∪", "cap" => "∩", "times" => "×",
        "cdot" => "·", "pm" => "±", "mp" => "∓", "div" => "÷", "to" => "→", "rightarrow" => "→",
        "leftarrow" => "←", "leftrightarrow" => "↔", "Rightarrow" => "⇒", "implies" => "⇒", "iff" => "⇔",
        "mapsto" => "↦", "sum" => "∑", "prod" => "∏", "int" => "∫", "oint" => "∮", "partial" => "∂",
        "nabla" => "∇", "forall" => "∀", "exists" => "∃", "emptyset" => "∅", "varnothing" => "∅",
        "ldots" => "…", "dots" => "…", "cdots" => "⋯", "prime" => "′", "ell" => "ℓ", "circ" => "∘",
        "langle" => "⟨", "rangle" => "⟩", "mid" => "|", "vert" => "|", "Vert" => "‖", "|" => "‖",
        "lbrace" => "{", "rbrace" => "}", "{" => "{", "}" => "}", "%" => "%", "$" => "$", "&" => "&",
        "#" => "#", "_" => "_", "neg" => "¬", "land" => "∧", "lor" => "∨", "star" => "⋆", "ast" => "∗",
        "degree" => "°", "top" => "T", "intercal" => "T",
        "," => " ", ";" => " ", ":" => " ", " " => " ", "quad" => " ", "qquad" => " ",
        "!" => "", "\\" => " "
      }.freeze

      DOUBLE_STRUCK = { "R" => "ℝ", "N" => "ℕ", "Z" => "ℤ", "Q" => "ℚ", "C" => "ℂ", "P" => "ℙ", "E" => "𝔼" }.freeze

      # Commands whose one argument is all that is left of them.
      KEEP_ARGUMENT = %w[
        text textrm textit textbf textsf texttt mathrm mathbf mathit mathsf mathtt mathcal mathscr mathfrak
        boldsymbol bm operatorname emph mbox hbox displaystyle textstyle
      ].freeze

      ACCENTS = {
        "hat" => "̂", "widehat" => "̂", "bar" => "̄", "overline" => "̅",
        "tilde" => "̃", "widetilde" => "̃", "dot" => "̇", "ddot" => "̈", "vec" => "⃗"
      }.freeze

      # Sizing and spacing that has nothing to say in text.
      DROP = %w[left right big Big bigg Bigg bigl bigr Bigl Bigr limits nolimits displaystyle textstyle].freeze

      SUPERSCRIPTS = "0123456789".chars.zip("⁰¹²³⁴⁵⁶⁷⁸⁹".chars).to_h.freeze
      SUBSCRIPTS = "0123456789".chars.zip("₀₁₂₃₄₅₆₇₈₉".chars).to_h.freeze

      def from_tex(text)
        out = +""
        source = text.to_s
        scanner = Scanner.new(source)
        index = 0
        while index < source.length
          math, length = scanner.math_at(index)
          if math
            out << math_to_text(math)
            index += length
          else
            out << plain_char(source, index)
            index += source[index] == "\\" && "$%&#_{}".include?(source[index + 1].to_s) ? 2 : 1
          end
        end
        out.unicode_normalize(:nfc).gsub(/\s+/, " ").strip
      end

      SPACED_MATH = /\\[a-zA-Z]+|[\^_]/
      DELIMITERS = { "$$" => "$$", "\\[" => "\\]", "\\(" => "\\)" }.freeze

      # Finds where maths opens and closes in one title. The dollar signs that
      # can close maths are found once, and a delimiter that never closes is
      # remembered, so a title of many unclosed openers costs no more than
      # one read of it.
      class Scanner
        def initialize(source)
          @source = source
          @unclosed = {}
          @closers = closers
          @tight_closers = @closers.select { |at| @source[at - 1].match?(/\S/) }
        end

        # [inner TeX, length taken] when maths opens at the index, else nil.
        def math_at(index)
          opener = @source[index, 2]
          return delimited(index, opener) if DELIMITERS.key?(opener)
          return unless @source[index] == "$" && (index.zero? || @source[index - 1] != "\\")

          spaced = @source[index + 1].to_s.match?(/\s/)
          close = (spaced ? @closers : @tight_closers).bsearch { |at| at >= index + 2 }
          body = close && @source[(index + 1)...close]
          return unless body && (!spaced || body.match?(SPACED_MATH))

          [body, close + 1 - index]
        end

        private

        def delimited(index, opener)
          return if @unclosed[opener]

          close = @source.index(DELIMITERS[opener], index + 2)
          return [@source[(index + 2)...close], close + 2 - index] if close

          @unclosed[opener] = true
          nil
        end

        # Each dollar sign that can close inline maths: unescaped, not one of
        # a pair, and not followed by a digit (`$5 and $10` is money).
        def closers
          found = []
          at = -1
          while (at = @source.index("$", at + 1))
            before = @source[at - 1] if at.positive?
            after = @source[at + 1].to_s
            found << at unless at.zero? || ["\\", "$"].include?(before) || after == "$" || after.match?(/\d/)
          end
          found
        end
      end

      def plain_char(source, index)
        char = source[index]
        return char unless char == "\\"

        following = source[index + 1].to_s
        "$%&#_{}".include?(following) && !following.empty? ? following : char
      end

      # Relations stand between spaces, as TeX sets them: "x ≤ y", not "x≤y".
      # The spaces around them are collapsed afterwards, so the pattern needs
      # no `\s*` of its own, which would take quadratic time on a run of them.
      RELATIONS = /[=<>≤≥≠≈≃≡∝∈∉⊂⊆→←↔⇒⇔↦]/

      def math_to_text(tex)
        Reader.new(tex).read.gsub(RELATIONS) { " #{Regexp.last_match(0)} " }.gsub(/\s+/, " ").strip
      end

      # A recursive reading of a maths expression: commands, their arguments,
      # groups, and the superscripts and subscripts after any of them.
      class Reader
        def initialize(tex)
          @tex = tex
          @at = 0
        end

        def read(stop = nil)
          out = +""
          while @at < @tex.length
            char = @tex[@at]
            break if stop && char == stop

            out << case char
                   when "\\" then command
                   when "{" then group
                   when "^" then script(PlainText::SUPERSCRIPTS, "^")
                   when "_" then script(PlainText::SUBSCRIPTS, "_")
                   when "}" then skip("")
                   when "-" then skip("−")
                   when "~" then skip(" ")
                   when "'" then skip("′")
                   else skip(char)
                   end
          end
          out
        end

        private

        def skip(text)
          @at += 1
          text
        end

        def group
          @at += 1
          inner = read("}")
          @at += 1
          inner
        end

        # The next argument: a group, a command, or one character.
        def argument
          @at += 1 while @tex[@at] == " "
          return "" if @at >= @tex.length

          case @tex[@at]
          when "{" then group
          when "\\" then command
          else skip(@tex[@at])
          end
        end

        def command
          @at += 1
          stop = @tex.index(/[^A-Za-z]/, @at) || @tex.length
          name = stop > @at ? @tex[@at...stop] : nil
          if name.nil?
            symbol = @tex[@at].to_s
            @at += 1
            return PlainText::SYMBOLS.fetch(symbol, symbol)
          end
          @at += name.length
          @at += 1 while @tex[@at] == " "
          named(name)
        end

        def named(name)
          return "" if PlainText::DROP.include?(name)
          return PlainText::GREEK[name] if PlainText::GREEK.key?(name)
          return PlainText::SYMBOLS[name] if PlainText::SYMBOLS.key?(name)
          return argument if PlainText::KEEP_ARGUMENT.include?(name)
          return argument.chars.map { |char| PlainText::DOUBLE_STRUCK.fetch(char, char) }.join if name == "mathbb"
          return "#{argument}#{PlainText::ACCENTS[name]}" if PlainText::ACCENTS.key?(name)

          case name
          when "frac", "dfrac", "tfrac" then "#{wrap(argument)}/#{wrap(argument)}"
          when "sqrt"
            optional
            "√#{wrap(argument)}"
          else name # \log, \max, \exp and the rest read as their names
          end
        end

        def optional
          return unless @tex[@at] == "["

          close = @tex.index("]", @at)
          @at = close ? close + 1 : @tex.length
        end

        def script(table, mark)
          @at += 1
          inner = argument.strip
          return "" if inner.empty?
          return inner.chars.map { |char| table[char] }.join if inner.chars.all? { |char| table.key?(char) }

          inner.length == 1 ? "#{mark}#{inner}" : "#{mark}(#{inner})"
        end

        def wrap(text)
          text = text.strip
          text.match?(/\A[\p{L}\p{N}.′]+\z/) ? text : "(#{text})"
        end
      end
    end
  end
end
