# frozen_string_literal: true

module Datalog
  # Collects the fenced code blocks of every page and document for the search
  # index. The index template used to split `doc.content` on backticks, but
  # Jekyll renders documents before pages, so by the time search.json rendered
  # that content was HTML and every document's code list came out empty.
  module SearchCodeBlocks
    # An opening fence of three or more backticks or tildes with an optional
    # language, the code, and a closing fence of the same characters.
    FENCE = /^ {0,3}(`{3,}|~{3,})[ \t]*([^\s`~{]*)[^\n]*\n(.*?)^ {0,3}\1[ \t]*$/m

    module_function

    def extract(source)
      text = source.to_s.gsub("\r\n", "\n")
      text.scan(FENCE).map do |_fence, language, code|
        { "language" => language.empty? ? "text" : language.downcase, "code" => code.chomp }
      end
    end
  end
end

# Content is still the author's source before rendering starts. Collection
# docs only: site.documents also lists a collection's static files.
Jekyll::Hooks.register :site, :pre_render do |site|
  (site.pages + site.collections.values.flat_map(&:docs)).each do |item|
    item.data["search_code"] = Datalog::SearchCodeBlocks.extract(item.content)
  end
end
