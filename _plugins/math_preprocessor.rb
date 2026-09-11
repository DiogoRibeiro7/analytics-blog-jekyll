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
    {
      regex: /(?<![\\$])(?<open>\$)(?!\$)(?<body>[^$]+?)(?<close>\$)(?!\$)/m,
      tag: "span"
    },
    {
      regex: /(?<open>\\\()(?<body>.+?)(?<close>\\\))/m,
      tag: "span"
    }
  ].freeze

  class Processor
    attr_reader :expressions

    def initialize(content)
      @content = content
      @expressions = []
    end

    def process
      return @content unless @content&.match?(/\$|\\\(|\\\[|\\begin\{/)

      processed = @content.dup
      processed = apply_patterns(processed, DISPLAY_PATTERNS, display: true)
      apply_patterns(processed, INLINE_PATTERNS, display: false)
    end

    private

    def apply_patterns(text, patterns, display: false)
      patterns.reduce(text) do |result, pattern|
        result.gsub(pattern[:regex]) do |match|
          body = Regexp.last_match[:body]
          open = Regexp.last_match[:open]
          close = Regexp.last_match[:close]

          next match if body.nil? || body.strip.empty?

          wrapper_for(match, body, open, close, pattern[:tag], display: display)
        end
      end
    end

    def wrapper_for(_original, latex, open, close, tag, display: false)
      alt_text = derive_alt_text(latex)
      cleaned_source = cleanup_source(latex)
      record_expression(cleaned_source, alt_text)

      attributes = {
        "class" => display ? "math-expression math-expression--source" : "math-expression-inline math-expression--source",
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

    content = document.content
    return unless content&.match?(/\$|\\\(|\\\[|\\begin\{/)

    processor = Processor.new(content)
    updated_content = processor.process
    document.content = updated_content
    document.data["math_expressions"] = processor.expressions if processor.expressions.any?
  end
end

# Posts are documents, so registering them separately ran the preprocessor
# twice on every post and nested each expression inside its own wrapper.
%w[documents pages].each do |scope|
  Jekyll::Hooks.register(scope.to_sym, :pre_render) do |document|
    MathPreprocessor.apply(document)
  end
end
