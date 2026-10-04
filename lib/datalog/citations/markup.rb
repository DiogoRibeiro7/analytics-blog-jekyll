# frozen_string_literal: true

require "cgi"

module Datalog
  module Citations
    # The HTML a page's citations become: the label of each cited work, the
    # marker in the text, and the reference list with its links back.
    module Markup
      module_function

      # key => "1" (numeric) or "Smith 2020a" (author-year).
      def labels(entries, style, words)
        return entries.each_with_index.to_h { |entry, index| [entry.key, (index + 1).to_s] } if style == "numeric"

        base = entries.to_h { |entry| [entry.key, [entry.names_in_text(words), entry.year_or(words[:no_date])]] }
        suffixes = {}
        base.group_by { |_, label| label }.each_value do |group|
          next if group.size < 2

          group.each_with_index { |(key, _), index| suffixes[key] = ("a".ord + index).chr }
        end
        base.to_h { |key, (names, year)| [key, "#{names} #{year}#{suffixes[key]}"] }
      end

      # An id for each key, safe in a URL fragment and unique on the page.
      def anchors(entries)
        seen = Hash.new(0)
        entries.to_h do |entry|
          anchor = entry.key.gsub(/[^A-Za-z0-9_.:-]/, "-")
          seen[anchor] += 1
          [entry.key, seen[anchor] > 1 ? "#{anchor}-#{seen[anchor]}" : anchor]
        end
      end

      def marker(links, locator, style)
        tail = locator ? ", #{CGI.escapeHTML(locator)}" : ""
        if style == "numeric"
          %(<span class="datalog-cite">[#{links.join(', ')}#{tail}]</span>)
        else
          %(<span class="datalog-cite">(#{links.join('; ')}#{tail})</span>)
        end
      end

      def locator_text(value, words)
        return nil if value.to_s.empty?

        kind, text = CGI.unescapeHTML(value).split("|", 2)
        kind == "loc" ? text : "#{words[:locators][kind]} #{text}"
      end

      def list_html(entries, labels, anchors, backlinks, style, words)
        return "" if entries.empty?

        tag = style == "numeric" ? "ol" : "ul"
        items = entries.map do |entry|
          suffix = style == "author-year" ? labels[entry.key][/\d([a-z])\z/, 1].to_s : ""
          back = backlinks_html(backlinks[entry.key], words)
          %(<li id="cite-#{anchors[entry.key]}">#{entry.reference_html(words, suffix: suffix)}#{back}</li>)
        end
        %(<#{tag} class="datalog-bibliography datalog-bibliography--#{style}">#{items.join}</#{tag}>)
      end

      # A return arrow for one citation; the arrow and a b c for several, each
      # letter a link back to its place in the text.
      def backlinks_html(refs, words)
        return "" if refs.empty?

        links = refs.each_with_index.map do |ref, index|
          label = CGI.escapeHTML(words[:back].gsub("{{n}}", (index + 1).to_s))
          text = refs.size == 1 ? "↩" : ("a".ord + index).chr
          %(<a href="##{ref}" aria-label="#{label}">#{text}</a>)
        end
        prefix = refs.size == 1 ? "" : "↩ "
        %( <span class="datalog-bibliography__back">#{prefix}#{links.join(' ')}</span>)
      end
    end
  end
end
