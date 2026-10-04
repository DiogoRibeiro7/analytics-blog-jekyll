# frozen_string_literal: true

require "nokogiri"

module Datalog
  # Splits a rendered document into the passages a reader would recognise: the
  # text under each h2 or h3, keyed by the id the heading already carries.
  #
  # A search result used to point at a whole page. For the long methods posts
  # this theme is built for, that hands the reader a second search problem:
  # find the paragraph. The headings and their ids were already in the page —
  # kramdown writes them, the contents list links to them — and the index was
  # the only thing that never recorded which passage sat under which (#336).
  module SearchSections
    HEADINGS = %w[h2 h3].freeze
    # Their text is markup, not prose: a MathJax configuration block or a
    # JSON-LD blob is not something anyone searches for.
    IGNORED = %w[script style template].freeze
    # What cannot sit in a URL fragment. A page whose Liquid has not run when
    # the index renders can carry a heading id of "{{ group_name | slugify }}",
    # and a link to that fragment would go nowhere; the section still indexes,
    # pointing at the page.
    UNUSABLE_ANCHOR = %r{[\s"'<>{}#%\\/]}

    module_function

    # Takes the document's own rendered HTML, not the finished page, so the
    # headings a layout puts around the article — "About this post", "Reading
    # notes" — cannot turn up as a section of every result.
    def split(html)
      sections = [section_for(nil)]
      collect(Nokogiri::HTML5.fragment(html.to_s), sections)
      sections.filter_map { |section| finish(section) }
    end

    # Walks in document order, opening a section at every heading. An element
    # holding a heading somewhere inside it is walked into rather than taken
    # whole, so a wrapper around part of the article does not swallow the
    # boundaries within it.
    def collect(node, sections)
      node.children.each do |child|
        next unless child.element? || child.text?
        next if child.element? && IGNORED.include?(child.name)

        if child.element? && HEADINGS.include?(child.name)
          sections << section_for(child)
        elsif child.element? && child.css(HEADINGS.join(", ")).any?
          collect(child, sections)
        else
          sections.last[:parts] << prose(child)
        end
      end
    end

    # An element taken whole may still hold a script or a style somewhere
    # inside it — a visualization block carries the code that draws it — and
    # that code is not prose. Liquid's `strip_html` drops those blocks with
    # their contents, so the flattened text of the page does not have them
    # either.
    def prose(node)
      return node.text unless node.element? && node.css(IGNORED.join(", ")).any?

      copy = node.dup
      copy.css(IGNORED.join(", ")).each(&:remove)
      copy.text
    end

    def section_for(heading)
      {
        title: heading ? squeeze(heading.text) : "",
        # A heading with no id — a site that turns kramdown's auto_ids off —
        # still indexes; its section simply links to the page.
        anchor: heading && present(heading["id"]),
        level: heading ? heading.name[1].to_i : 0,
        parts: []
      }
    end

    # The lead paragraphs before the first heading are a section of their own,
    # untitled; so is the whole of a page that has no headings at all.
    def finish(section)
      content = squeeze(section[:parts].join(" "))
      return if section[:title].empty? && content.empty?

      { "title" => section[:title], "anchor" => section[:anchor],
        "level" => section[:level], "content" => content }
    end

    def squeeze(text)
      text.to_s.gsub(/\s+/, " ").strip
    end

    def present(value)
      value = value.to_s.strip
      return if value.empty? || value.match?(UNUSABLE_ANCHOR)

      value
    end
  end

  # `{{ content | markdownify | search_sections }}` in the search index, over
  # the same HTML the flattened text is taken from.
  module SearchSectionsFilter
    def search_sections(html)
      SearchSections.split(html)
    end
  end
end

Liquid::Template.register_filter(Datalog::SearchSectionsFilter)
