# frozen_string_literal: true

module Datalog
  module Plugins
    class Slides < Datalog::PluginSystem::Plugin
      id "datalog-slides"
      depends_on "datalog-search"
      priority :normal

      class SlidesTag < Liquid::Tag
        def render(context)
          plugin = Datalog::PluginSystem.plugin("datalog-slides")
          return "" unless plugin

          plugin.render_slides(context)
        end
      end

      def initialize(site, config = {})
        super
        @defaults = {
          "cdn" => "https://unpkg.com/reveal.js@5",
          "width" => "100%",
          "height" => "600px"
        }.merge(@config)
      end

      def before_render(document, _payload = nil)
        deck = document.data["slides"] || document.data["deck"]
        return unless deck

        normalized = normalize_deck(deck)
        return unless normalized

        document.data["datalog_slides"] = normalized
        document.data["datalog_slides_state"] = storage_key(document)
        slide_state(storage_key(document))[:deck] = normalized
      end

      def custom_liquid_tags
        { "datalog_slides" => SlidesTag }
      end

      def search_indexing(document)
        key = storage_key(document)
        state = @storage&.dig(key, :deck)
        return {} unless state

        {
          "slides" => {
            "src" => state["src"],
            "title" => state["title"],
            "theme" => state["theme"]
          }
        }
      end

      def render_slides(context)
        key = (context.registers[:page] || {})["datalog_slides_state"]
        deck = @storage&.dig(key, :deck)
        return "" unless deck

        render_slides_markup(deck)
      end

      private

      def normalize_deck(deck)
        attributes = case deck
                     when String
                       { "src" => deck }
                     when Hash
                       deck.transform_keys(&:to_s)
                     else
                       {}
                     end

        return nil if attributes.empty?

        merged = @defaults.merge(attributes)
        merged["title"] ||= merged["name"] || merged["src"]
        merged["notes"] ||= attributes["notes"]
        merged
      end

      def render_slides_markup(deck)
        src = deck["src"]
        return placeholder_markup unless src

        <<~HTML.strip
          <div class="datalog-slides-embed" data-provider="reveal">
            <iframe src="#{src}" title="#{deck['title'] || 'Slide deck'}" loading="lazy" allowfullscreen style="width: #{deck['width']}; height: #{deck['height']};"></iframe>
            <p class="datalog-slides-actions">
              <a href="#{src}" target="_blank" rel="noopener">Open slides</a>
              #{cdn_hint(deck)}
            </p>
          </div>
        HTML
      end

      def cdn_hint(deck)
        return "" unless deck["cdn"]

        %(<span class="datalog-slides-cdn">Powered by <code>#{deck['cdn']}</code></span>)
      end

      def placeholder_markup
        "<div class=\"datalog-slides-embed datalog-slides-embed--missing\">Slides unavailable</div>"
      end

      def storage_key(document)
        document.relative_path || document.path
      end

      def slide_state(key)
        @storage ||= {}
        @storage[key] ||= {}
      end
    end
  end
end
