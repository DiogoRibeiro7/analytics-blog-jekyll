# frozen_string_literal: true

require "shellwords"

module Datalog
  module Plugins
    class Citations < Datalog::PluginSystem::Plugin
      id "datalog-citations"
      depends_on "datalog-search"
      priority :high

      class CiteTag < Liquid::Tag
        def initialize(tag_name, markup, tokens)
          super
          args = Shellwords.split(markup)
          @citation_key = args.shift
          @label = args.shift
        end

        def render(context)
          plugin = Datalog::PluginSystem.plugin("datalog-citations")
          return missing_placeholder unless plugin

          plugin.render_citation(context, @citation_key, @label)
        end

        private

        def missing_placeholder
          "<span class=\"datalog-citation datalog-citation--missing\">[citation]</span>"
        end
      end

      class BibliographyTag < Liquid::Tag
        def render(context)
          plugin = Datalog::PluginSystem.plugin("datalog-citations")
          return "" unless plugin

          plugin.render_bibliography(context)
        end
      end

      def initialize(site, config = {})
        super
        @state = {}
      end

      def before_render(document, _payload = nil)
        citations = collect_citations(document)
        state = ensure_state(document)
        state[:lookup] = citations
        state[:order] = []
        document.data["datalog_citations"] = citations
        document.data["datalog_bibliography"] = citations.values
        document.data["datalog_citation_state"] = state[:key]
        if config["bibliography_title"]
          document.data["datalog_bibliography_title"] = config["bibliography_title"]
        end
      end

      def custom_liquid_tags
        {
          "datalog_cite" => CiteTag,
          "datalog_bibliography" => BibliographyTag
        }
      end

      def search_indexing(document)
        state = resolve_state(document)
        return {} unless state && state[:lookup]&.any?

        {
          "citations" => {
            "count" => state[:lookup].size,
            "keys" => state[:lookup].keys.sort
          }
        }
      end

      def render_citation(context, key, label)
        return missing_markup unless key

        state = state_from_context(context)
        return missing_markup unless state

        normalized_key = key.to_s
        entry = state[:lookup][normalized_key]
        return missing_markup unless entry

        state[:order] << normalized_key unless state[:order].include?(normalized_key)
        index = state[:order].index(normalized_key) + 1
        text = label || entry[:label] || "[#{index}]"
        text = text.gsub("%{n}", index.to_s)

        if entry[:url]
          %(<a class="datalog-citation" href="#{entry[:url]}" rel="noopener" data-citation="#{normalized_key}">#{text}</a>)
        else
          %(<span class="datalog-citation" data-citation="#{normalized_key}">#{text}</span>)
        end
      end

      def render_bibliography(context)
        state = state_from_context(context)
        return "" unless state && state[:lookup]&.any?

        entries = state[:order].map { |key| state[:lookup][key] }.compact
        entries = state[:lookup].values if entries.empty?

        items = entries.each_with_index.map do |entry, idx|
          anchor = entry[:id] || "citation-#{idx + 1}"
          %(<li id="cite-#{anchor}">#{entry[:formatted]}</li>)
        end

        %(<ol class="datalog-bibliography">#{items.join}</ol>)
      end

      private

      def collect_citations(document)
        entries = Array(document.data["citations"] || document.data["references"])
        global = Array(site.data.dig("citations", document.data["citation_group"]))
        entries += global if global.any?

        entries.each_with_object({}) do |entry, acc|
          normalized = normalize_entry(entry)
          next unless normalized[:id]

          acc[normalized[:id]] = normalized
        end
      end

      def normalize_entry(entry)
        case entry
        when String
          identifier = entry.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
          { id: identifier, title: entry, formatted: entry }
        when Hash
          normalized = entry.transform_keys(&:to_sym)
          normalized[:id] = normalized[:id].to_s if normalized[:id]
          normalized[:formatted] ||= build_formatted_entry(normalized)
          normalized
        else
          {}
        end
      end

      def build_formatted_entry(entry)
        authors = Array(entry[:authors] || entry[:author]).join(", ")
        year = entry[:year]
        title = entry[:title]
        container = entry[:journal] || entry[:conference] || entry[:publisher]
        segments = []
        segments << authors unless authors.empty?
        segments << "(#{year})" if year
        segments << "<em>#{title}</em>" if title
        segments << container if container
        segments << entry[:url] if entry[:url] && !entry[:url].empty?
        segments.compact.join(". ")
      end

      def ensure_state(document)
        key = document.relative_path || document.path
        @state[key] = { key: key }.merge(@state[key] || {})
      end

      def resolve_state(document)
        key = document.data["datalog_citation_state"] || document.relative_path || document.path
        @state[key]
      end

      def state_from_context(context)
        page = context.registers[:page] || {}
        key = page["datalog_citation_state"]
        @state[key]
      end

      def missing_markup
        "<span class=\"datalog-citation datalog-citation--missing\">[citation]</span>"
      end
    end
  end
end

