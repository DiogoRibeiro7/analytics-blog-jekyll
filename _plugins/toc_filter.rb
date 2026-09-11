# frozen_string_literal: true

require "nokogiri"

# `tocify` builds a nested list of links to the headings of a rendered HTML
# fragment. The table-of-contents includes (`components/enhanced-toc.html`,
# `toc.html`) call it as `content | tocify: h_min, h_max`.
#
# Headings keep the ids kramdown gives them; a heading without an id gets a
# slug of its text, which still needs an anchor in the page to be useful.
module Jekyll
  module TocifyFilter
    def tocify(html, h_min = 2, h_max = 4)
      return "" if html.nil? || html.to_s.strip.empty?

      lowest = h_min.to_i.clamp(1, 6)
      highest = h_max.to_i.clamp(lowest, 6)
      fragment = Nokogiri::HTML::DocumentFragment.parse(html.to_s)
      selector = (lowest..highest).map { |level| "h#{level}" }.join(",")

      headings = fragment.css(selector).filter_map do |node|
        text = node.text.strip
        next if text.empty?

        id = node["id"].to_s.strip
        id = Jekyll::Utils.slugify(text) if id.empty?
        [node.name[1].to_i, id, text]
      end
      return "" if headings.empty?

      tocify_render_list(headings, lowest)
    end

    private

    def tocify_render_list(headings, top_level)
      out = +""
      open_levels = []
      headings.each do |level, id, text|
        level = [level, top_level].max
        if open_levels.empty?
          out << %(<ul class="toc-list">)
          open_levels << level
        elsif level > open_levels.last
          out << "<ul>"
          open_levels << level
        else
          out << "</li>"
          while open_levels.size > 1 && level < open_levels.last
            out << "</ul></li>"
            open_levels.pop
          end
        end
        out << %(<li class="toc-item toc-level-#{level}"><a href="##{id}">#{tocify_escape_text(text)}</a>)
      end
      out << "</li>"
      out << "</ul></li>" * (open_levels.size - 1)
      out << "</ul>"
      out
    end

    def tocify_escape_text(text)
      text.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
    end
  end
end

Liquid::Template.register_filter(Jekyll::TocifyFilter)
