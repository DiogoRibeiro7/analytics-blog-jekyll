# frozen_string_literal: true

require "cgi"

module MathPreprocessor
  DISPLAY_PATTERNS = [
    {
      regex: /(?<open>\$\$)(?<body>.+?)(?<close>\$\$)/m,
      tag: "div"
    },
    {
      regex: /(?<open>\\\[)(?<body>.+?)(?<close>\\\])/m,
      tag: "div"
    },
    {
      regex: /(?<open>\\begin\{(?<env>equation\*?|align\*?|gather\*?|multline\*?)\})(?<body>.+?)(?<close>\\end\{\k<env>\})/m,
      tag: "div"
    }
  ].freeze

  INLINE_PATTERNS = [
    # Pandoc's rule for inline math, so prices and shell variables stay text:
    # the opening $ is followed by a non-space, the closing $ follows a
    # non-space and is not followed by a digit, and a blank line ends it.
    {
      regex: /(?<![\\$])(?<open>\$)(?![\s$])(?<body>(?:[^$\\\n]|\\.|\n(?![ \t]*\n))+?)(?<![\s\\])(?<close>\$)(?![$\d])/m,
      tag: "span"
    },
    # MathJax and KaTeX also render math with spaces inside the dollars, such
    # as `$ \frac{a}{b} $`, which the rule above leaves out, so a page whose
    # only math was written that way loaded no engine. Such a pair counts when
    # its body holds a TeX command, a superscript or a subscript, which prices
    # like `$ 5 or $ 10` do not.
    {
      regex: /(?<![\\$])(?<open>\$)(?!\$)(?<body>(?:[^$\\\n]|\\.|\n(?![ \t]*\n))+?)(?<!\\)(?<close>\$)(?![$\d])/m,
      tag: "span",
      requires: /\\[a-zA-Z]+|[\^_]/
    },
    {
      regex: /(?<open>\\\()(?<body>.+?)(?<close>\\\))/m,
      tag: "span"
    }
  ].freeze

  # Code shows dollar signs literally (shell and R variables, amounts in SQL),
  # so fenced blocks, highlight tags, <pre>/<code> elements and inline code
  # spans are set aside before looking for math and put back afterwards.
  CODE_PATTERNS = [
    /^([ \t]*)(`{3,}|~{3,})[^\n]*\n.*?(?:^\1\2[ \t]*$|\z)/m,
    /\{%-?\s*highlight\b.*?\{%-?\s*endhighlight\s*-?%\}/m,
    %r{<(pre|code)\b[^>]*>.*?</\1>}mi,
    /(?<!`)(`+)(?!`)(?:(?!\n[ \t]*\n).)+?(?<!`)\1(?!`)/m
  ].freeze

  # NUL marks masked code, since page content never contains it. It is written as
  # an escape: a raw NUL byte in the source stopped RuboCop from parsing the file.
  PLACEHOLDER = /\x00(\d+)\x00/

  class Processor
    attr_reader :expressions

    def initialize(content)
      @content = content
      @expressions = []
    end

    def process
      return @content unless @content&.match?(/\$|\\\(|\\\[|\\begin\{/)

      @segments = []
      processed = CODE_PATTERNS.reduce(@content.dup) do |text, pattern|
        text.gsub(pattern) { |match| mask(match) }
      end
      processed = apply_patterns(processed, DISPLAY_PATTERNS, display: true)
      processed = apply_patterns(processed, INLINE_PATTERNS, display: false)
      # A segment set aside can contain the placeholder of an earlier one.
      processed = processed.gsub(PLACEHOLDER) { @segments[Regexp.last_match(1).to_i] } while processed.match?(PLACEHOLDER)
      processed
    end

    private

    def mask(segment)
      @segments << segment
      "\x00#{@segments.size - 1}\x00"
    end

    def apply_patterns(text, patterns, display: false)
      patterns.reduce(text) do |result, pattern|
        result.gsub(pattern[:regex]) do |match|
          body = Regexp.last_match[:body]
          open = Regexp.last_match[:open]
          close = Regexp.last_match[:close]

          next match if body.nil? || body.strip.empty?
          next match if pattern[:requires] && !pattern[:requires].match?(body)

          # Each wrapper is set aside like code. Otherwise a later pattern could
          # pair a dollar sign inside it with one in the text that follows.
          mask(wrapper_for(match, body, open, close, pattern[:tag], display: display))
        end
      end
    end

    def wrapper_for(_original, latex, open, close, tag, display: false)
      alt_text = derive_alt_text(latex)
      cleaned_source = cleanup_source(latex)
      record_expression(cleaned_source, alt_text)

      # ARIA forbids aria-label on an element with no role, such as a plain span.
      # axe let it pass while the span held the raw LaTeX as text, and failed it
      # once MathJax rendered the expression; the math role allows the label.
      attributes = {
        "class" => display ? "math-expression math-expression--source" : "math-expression-inline math-expression--source",
        "role" => "math",
        "data-math-alt" => alt_text,
        "data-math-source" => cleaned_source,
        "aria-label" => alt_text,
        "tabindex" => "0"
      }

      attribute_string = attributes.map do |key, value|
        next if value.nil? || value.strip.empty?

        %(#{key}="#{CGI.escapeHTML(value)}")
      end.compact.join(" ")

      inner = "#{open}#{latex}#{close}"
      "<#{tag} #{attribute_string}>#{inner}</#{tag}>"
    end

    def record_expression(latex, alt)
      @expressions << { "latex" => latex, "alt" => alt } if latex && !latex.empty?
    end

    def derive_alt_text(latex)
      comment_alt = extract_comment_alt(latex)
      return comment_alt if comment_alt

      auto_alt_text(latex)
    end

    def extract_comment_alt(latex)
      latex.to_s.lines.each do |line|
        if (match = line.match(/%\s*alt:\s*(.+)$/i))
          return match[1].strip
        end
      end
      nil
    end

    def cleanup_source(latex)
      latex.to_s.strip
    end

    def auto_alt_text(latex)
      text = latex.to_s.dup

      text.gsub!(/\\frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}/) do
        numerator = sanitize_segment(Regexp.last_match[1])
        denominator = sanitize_segment(Regexp.last_match[2])
        "#{numerator} over #{denominator}"
      end

      text.gsub!(/\\int(?:_\{([^}]*)\}|_([^\s^{}]+))?(?:\^\{([^}]*)\}|\^([^\s_{}]+))?/) do
        lower = Regexp.last_match[1] || Regexp.last_match[2]
        upper = Regexp.last_match[3] || Regexp.last_match[4]
        phrase = "integral"
        phrase += " from #{sanitize_segment(lower)}" if lower && !lower.empty?
        phrase += " to #{sanitize_segment(upper)}" if upper && !upper.empty?
        phrase
      end

      text.gsub!(/\\sum(?:_\{([^}]*)\}|_([^\s^{}]+))?(?:\^\{([^}]*)\}|\^([^\s_{}]+))?/) do
        lower = Regexp.last_match[1] || Regexp.last_match[2]
        upper = Regexp.last_match[3] || Regexp.last_match[4]
        phrase = "summation"
        phrase += " from #{sanitize_segment(lower)}" if lower && !lower.empty?
        phrase += " to #{sanitize_segment(upper)}" if upper && !upper.empty?
        phrase
      end

      text.gsub!(/\\sqrt\s*\{([^{}]+)\}/) do
        "square root of #{sanitize_segment(Regexp.last_match[1])}"
      end

      text.gsub!(/\\mathrm\s*\{([^{}]+)\}/) { sanitize_segment(Regexp.last_match[1]) }
      text.gsub!(/\\operatorname\*?\s*\{([^{}]+)\}/) { sanitize_segment(Regexp.last_match[1]) }
      text.gsub!(/\\[a-zA-Z]+\s*/m, " ")
      text.gsub!(/[{}]/, " ")
      text.gsub!(/\s+/, " ")
      text = text.strip

      return "Mathematical expression" if text.empty?

      text
    end

    def sanitize_segment(segment)
      return "" unless segment

      cleaned = segment.gsub(/\\[a-zA-Z]+/, " ")
      cleaned = cleaned.gsub(/[{}]/, " ")
      cleaned.gsub(/\s+/, " ").strip
    end
  end

  module_function

  def apply(document)
    return unless document.respond_to?(:content)
    return unless document.respond_to?(:output_ext) && document.output_ext == ".html"
    # A page that opts out of math rendering keeps its dollar signs and
    # TeX-looking text verbatim.
    return if document.respond_to?(:data) && math_setting(document.data) == false

    content = document.content
    return unless content&.match?(/\$|\\\(|\\\[|\\begin\{/)

    processor = Processor.new(content)
    updated_content = processor.process
    document.content = updated_content
    document.data["math_expressions"] = processor.expressions if processor.expressions.any?
  end

  # `math`, or its alias `mathjax` when `math` is unset, as
  # _includes/meta/math-config.html reads them. A `mathjax: true` in front
  # matter defaults used to win over a page's `math: false`.
  def math_setting(data)
    data["math"].nil? ? data["mathjax"] : data["math"]
  end
end

# Posts are documents, so registering them separately ran the preprocessor
# twice on every post and nested each expression inside its own wrapper.
%w[documents pages].each do |scope|
  Jekyll::Hooks.register(scope.to_sym, :pre_render) do |document|
    MathPreprocessor.apply(document)
  end
end
