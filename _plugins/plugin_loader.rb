# frozen_string_literal: true

require "jekyll/utils"

require_relative "../lib/datalog/plugin_system"

Dir[File.expand_path("../lib/datalog/plugins/**/*.rb", __dir__)].each do |plugin_file|
  require plugin_file
end

module Datalog
  class PluginLoader < Jekyll::Generator
    safe true
    priority :highest

    def generate(site)
      plugin_classes = enabled_plugins(site).filter_map do |identifier|
        resolve_plugin_class(identifier)
      end

      resolver = Datalog::PluginSystem::DependencyResolver.new(
        plugin_classes,
        available: Datalog::PluginSystem.available_plugins
      )

      ordered_classes = resolver.resolve
      log_dependency_resolution(resolver, ordered_classes)

      instances = ordered_classes.filter_map do |klass|
        instantiate_plugin(site, klass)
      end

      Datalog::PluginSystem.activate!(site, instances)
      register_liquid_tags(instances)

      site.config["datalog_plugin_state"] = {
        "active" => instances.map(&:id),
        "available" => Datalog::PluginSystem.available_plugins.keys.sort
      }
    rescue Datalog::PluginSystem::PluginDependencyError => e
      logger.error("datalog plugin", e.message)
      raise e
    end

    private

    def enabled_plugins(site)
      config = site.config.fetch("datalog_plugins", {})

      plugins =
        case config
        when Array
          config
        when Hash
          Array(config["enabled"] || config["plugins"] || [])
        else
          []
        end

      plugins.each_with_object([]) do |identifier, acc|
        next if identifier.nil?

        value = identifier.to_s.strip
        next if value.empty?

        acc << value unless acc.include?(value)
      end
    end

    def instantiate_plugin(site, klass)
      identifier = klass.id
      config = fetch_plugin_config(site, identifier)
      klass.new(site, config)
    rescue StandardError => e
      logger.error("datalog plugin", "#{identifier} failed to initialize: #{e.message}")
      nil
    end

    def resolve_plugin_class(identifier)
      klass = Datalog::PluginSystem.available_plugins[identifier]
      unless klass
        logger.warn("datalog plugin", "#{identifier} is not registered; skipping")
        return
      end

      klass
    end

    def fetch_plugin_config(site, identifier)
      config = site.config.fetch("datalog_plugins", {})
      return {} unless config.is_a?(Hash)

      options = config.fetch("options", {})
      return {} unless options.is_a?(Hash)

      key = identifier
      value = options[key] || options[key.to_s] || options[key.to_sym]
      value.is_a?(Hash) ? value : {}
    end

    def register_liquid_tags(instances)
      instances.each do |plugin|
        next unless plugin.respond_to?(:custom_liquid_tags)

        tags = plugin.custom_liquid_tags
        unless tags.is_a?(Hash)
          logger.warn("datalog plugin", "#{plugin.id} returned invalid Liquid tags payload; expected a hash")
          next
        end

        tags.each do |tag_name, tag_class|
          next if tag_name.to_s.empty? || tag_class.nil?

          Liquid::Template.register_tag(tag_name, tag_class)
        rescue StandardError => e
          logger.warn("datalog plugin", "#{plugin.id} failed to register #{tag_name} tag: #{e.message}")
        end
      rescue StandardError => e
        logger.warn("datalog plugin", "#{plugin.id} failed while registering Liquid tags: #{e.message}")
      end
    end

    def logger
      Jekyll.logger
    end

    def log_dependency_resolution(resolver, ordered_classes)
      return unless debug_logging?

      identifiers = ordered_classes.map(&:id)
      logger.debug("datalog plugin", "resolved load order: #{identifiers.join(' -> ')}")

      graph = resolver.dependency_graph
      return if graph.empty?

      graph_summary = graph.map do |plugin_id, dependencies|
        deps = Array(dependencies).map(&:to_s).sort
        deps.empty? ? "#{plugin_id}: []" : "#{plugin_id}: [#{deps.join(', ')}]"
      end.join("; ")

      logger.debug("datalog plugin", "dependency graph: #{graph_summary}")
    end

    def debug_logging?
      logger.respond_to?(:debug?) && logger.debug?
    end
  end
end

module Datalog
  module PluginLoaderHooks
    HOOK_SCOPES = %i[pages documents posts].freeze

    module_function

    def register!
      HOOK_SCOPES.each do |scope|
        Jekyll::Hooks.register scope, :pre_render do |document, payload|
          Datalog::PluginSystem.run_hook(:before_render, document, payload)
        end

        Jekyll::Hooks.register scope, :post_render do |document|
          extensions = Datalog::PluginSystem.collect_hook(:search_indexing, document)
          next if extensions.nil? || extensions.empty?

          existing = document.data["datalog_search_extensions"] || {}
          document.data["datalog_search_extensions"] = deep_merge_extensions(existing, extensions)
        end

        Jekyll::Hooks.register scope, :post_write do |document|
          Datalog::PluginSystem.run_hook(:after_post_process, document)
        end
      end
    end

    def deep_merge_extensions(existing, extensions)
      return extensions unless existing.is_a?(Hash)
      return existing unless extensions.is_a?(Hash)

      Jekyll::Utils.deep_merge_hashes(existing, extensions)
    end
  end
end

Datalog::PluginLoaderHooks.register!
