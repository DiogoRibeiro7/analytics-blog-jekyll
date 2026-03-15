# frozen_string_literal: true

require "jekyll/utils"

module Datalog
  module Plugins
    class Search < Datalog::PluginSystem::Plugin
      id "datalog-search"
      priority :highest

      def initialize(site, config = {})
        super
        @index_metadata = config.fetch("metadata", {})
      end

      def before_render(document, _payload = nil)
        document.data["datalog_search"] = base_metadata(document)
      end

      def search_indexing(document)
        base_metadata(document)
      end

      private

      def base_metadata(document)
        # Get collection label safely - only Jekyll::Document has the collection method
        collection_label = if document.respond_to?(:collection) && document.collection
                            document.collection.label
                          else
                            document.data["collection"]
                          end

        data = {
          "id" => document.data["id"] || document.data["permalink"] || document.url,
          "title" => document.data["title"],
          "url" => document.url,
          "collection" => collection_label
        }

        Jekyll::Utils.deep_merge_hashes(@index_metadata, data.compact)
      end
    end
  end
end
