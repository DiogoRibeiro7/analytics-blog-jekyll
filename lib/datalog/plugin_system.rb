# frozen_string_literal: true

require "jekyll"

module Datalog
  module PluginSystem
    HOOKS = %i[before_render after_post_process custom_liquid_tags search_indexing].freeze

    PRIORITY_LEVELS = {
      highest: 40,
      high: 30,
      normal: 20,
      low: 10,
      lowest: 0
    }.freeze

    class PluginDependencyError < StandardError
      attr_reader :plugin_id

      def initialize(message, plugin_id: nil)
        super(message)
        @plugin_id = plugin_id
      end

      def self.missing(plugin_id:, missing:, chain:, available: [])
        missing_list = Array(missing)
        message = String.new("Cannot load '#{plugin_id}'\n")
        descriptor = missing_list.size > 1 ? "Missing dependencies" : "Missing dependency"
        message << "  #{descriptor}: #{missing_list.map { |id| "'#{id}'" }.join(', ')}\n"

        if Array(chain).any?
          message << "\n  Dependency chain:\n"
          Array(chain).each do |step|
            message << "    #{step}\n"
          end
        end

        if Array(available).any?
          message << "\n  Available plugins: #{Array(available).map(&:to_s).sort.join(', ')}\n"
        end

        fix_line = if missing_list.size == 1
                     "  To fix: Add '#{missing_list.first}' to enabled plugins in _config.yml"
                   else
                     joined = missing_list.map { |id| "'#{id}'" }.join(", ")
                     "  To fix: Add #{joined} to enabled plugins in _config.yml"
                   end
        message << "\n" << fix_line

        new(message, plugin_id: plugin_id)
      end

      def self.circular(cycle:, available: [])
        message = String.new("Circular dependency detected\n")
        if Array(cycle).any?
          message << "\n  Cycle:\n"
          Array(cycle).each do |step|
            message << "    #{step}\n"
          end
        end

        if Array(available).any?
          message << "\n  Available plugins: #{Array(available).map(&:to_s).sort.join(', ')}"
        end

        new(message)
      end
    end

    class << self
      attr_accessor :active_plugins, :site

      def available_plugins
        @available_plugins ||= {}
      end

      def register(klass)
        identifier = klass.id
        return unless identifier

        available_plugins[identifier] = klass
      end

      def activate!(site, plugin_instances)
        self.site = site
        self.active_plugins = plugin_instances
      end

      def plugin(identifier)
        Array(active_plugins).find { |instance| instance.id == identifier }
      end

      def active_plugin_ids
        Array(active_plugins).map(&:id)
      end

      def run_hook(hook, *args)
        return unless HOOKS.include?(hook)

        Array(active_plugins).each do |plugin|
          next unless plugin.respond_to?(hook)

          plugin.public_send(hook, *args)
        rescue StandardError => e
          Jekyll.logger.warn("datalog plugin", "#{plugin.id} failed during #{hook}: #{e.message}")
        end
      end

      def collect_hook(hook, *args)
        return {} unless HOOKS.include?(hook)

        Array(active_plugins).each_with_object({}) do |plugin, acc|
          next unless plugin.respond_to?(hook)

          result = plugin.public_send(hook, *args)
          next unless result.is_a?(Hash)

          acc.replace(deep_merge(acc, result))
        rescue StandardError => e
          Jekyll.logger.warn("datalog plugin", "#{plugin.id} failed during #{hook}: #{e.message}")
        end
      end

      private

      def deep_merge(left, right)
        left.merge(right) do |_key, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            deep_merge(old_val, new_val)
          elsif old_val.is_a?(Array) || new_val.is_a?(Array)
            Array(old_val) + Array(new_val)
          else
            new_val
          end
        end
      end
    end

    class Plugin
      class << self
        attr_writer :identifier

        def depends_on(*plugin_ids)
          return dependencies if plugin_ids.empty?

          normalized = plugin_ids.flatten.compact.map(&:to_s).reject(&:empty?)
          @dependencies = (dependencies + normalized).uniq
        end

        def dependencies
          @dependencies ||= []
        end

        def priority(value = nil)
          if value.nil?
            @priority ||= :normal
          else
            symbol = value.to_sym
            unless PRIORITY_LEVELS.key?(symbol)
              raise ArgumentError, "Invalid plugin priority '#{value}'. Allowed: #{PRIORITY_LEVELS.keys.join(', ')}"
            end

            @priority = symbol
          end
        end

        def priority_value
          PRIORITY_LEVELS.fetch(priority, PRIORITY_LEVELS[:normal])
        end

        def id(value = nil)
          if value
            new_id = value.to_s
            registry = Datalog::PluginSystem.available_plugins
            previous_id = @identifier || default_identifier

            if previous_id && registry[previous_id] == self
              registry.delete(previous_id)
            end

            @identifier = new_id
            registry[new_id] = self
          else
            @identifier ||= default_identifier
          end
        end

        def inherited(subclass)
          super
          Datalog::PluginSystem.register(subclass)
        end

        private

        def default_identifier
          raw = name&.split("::")&.last
          raw ||= "plugin-#{object_id}"

          raw.gsub(/([a-z\d])([A-Z])/, "\\1-\\2")
             .tr("_", "-")
             .downcase
        end
      end

      attr_reader :site, :config

      def initialize(site, config = {})
        @site = site
        @config = (config || {}).transform_keys(&:to_s)
      end

      def id
        self.class.id
      end

      def dependencies
        self.class.dependencies
      end

      def priority
        self.class.priority
      end

      def logger
        @logger ||= Jekyll.logger
      end

      def before_render(_document, _payload = nil); end

      def after_post_process(_document); end

      def custom_liquid_tags
        {}
      end

      def search_indexing(_document)
        {}
      end
    end
  end
end

require_relative "plugin_system/dependency_resolver"

