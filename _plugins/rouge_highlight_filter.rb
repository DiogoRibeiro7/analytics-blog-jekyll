# frozen_string_literal: true

require "rouge"

# `rouge_highlight` highlights code with Rouge as the site builds, the way
# kramdown highlights fenced code blocks. Includes that print code passed to
# them, such as `components/api-function.html`, call it as
# `code | rouge_highlight: language` inside `<pre class="highlight"><code>`;
# the notebook converter calls `RougeHighlightFilter.highlight` for code cells.
# The result is escaped; a language Rouge does not know comes back as plain
# text.
module Jekyll
  module RougeHighlightFilter
    # kramdown's opening tag for a block Rouge highlighted.
    KRAMDOWN_CODE_BLOCK = '<pre class="highlight">'

    def self.highlight(code, language = nil)
      return "" if code.nil?

      source = code.to_s
      lexer = Rouge::Lexer.find_fancy(language.to_s.strip.downcase, source) || Rouge::Lexers::PlainText
      Rouge::Formatters::HTML.new.format(lexer.lex(source))
    end

    def rouge_highlight(code, language = nil)
      RougeHighlightFilter.highlight(code, language)
    end
  end
end

Liquid::Template.register_filter(Jekyll::RougeHighlightFilter)

# A code block wider than the page scrolls, and a keyboard user can only scroll
# it once it takes focus. Prism made every block focusable in the browser; the
# blocks kramdown highlights get the attribute here, and the includes and the
# notebook converter write it themselves.
Jekyll::Hooks.register %i[pages documents], :post_convert do |document|
  block = Jekyll::RougeHighlightFilter::KRAMDOWN_CODE_BLOCK
  next unless document.content&.include?(block)

  document.content = document.content.gsub(block, '<pre class="highlight" tabindex="0">')
end
