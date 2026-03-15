# frozen_string_literal: true

require "set"

module Datalog
  module PluginSystem
    class DependencyResolver
      attr_reader :plugins, :available_plugins

      def initialize(plugins, options = {})
        @plugins = Array(plugins).compact
        @available_plugins = options.fetch(:available, {})
        @graph = {}
        @plugin_map = {}
        @load_order = nil
      end

      def resolve
        build_graph
        validate_dependencies!
        order = perform_topological_sort
        @load_order = order.map { |identifier| @plugin_map[identifier] }
      end

      def load_order
        @load_order ||= resolve
      end

      def dependency_graph
        ensure_graph_built
        @graph.transform_values { |meta| meta[:dependencies].dup }
      end

      def to_dot(order: load_order)
        ensure_graph_built
        ordered_ids = Array(order).map { |klass| klass.respond_to?(:id) ? klass.id : klass.to_s }
        lines = []
        lines << "digraph PluginDependencies {"
        lines << "  rankdir=LR;"

        @graph.each_key do |identifier|
          klass = @plugin_map[identifier]
          priority_label = klass&.respond_to?(:priority) ? klass.priority.to_s : "normal"
          lines << %(  "#{identifier}" [label="#{identifier}\\npriority: #{priority_label}"];)
        end

        @graph.each do |identifier, meta|
          meta[:dependencies].each do |dep|
            lines << %(  "#{identifier}" -> "#{dep}";)
          end
        end

        if ordered_ids.any?
          order_comment = ordered_ids.each_with_index.map { |id, idx| "#{idx + 1}. #{id}" }.join(" | ")
          lines << %(  // Load order: #{order_comment})
        end

        lines << "}"
        lines.join("\n")
      end

      private

      def build_graph
        @plugin_map.clear
        @graph.clear

        plugins.each do |klass|
          next unless klass.respond_to?(:id)

          identifier = klass.id
          @plugin_map[identifier] = klass
          @graph[identifier] ||= { dependencies: Set.new, dependents: Set.new }

          deps = klass.respond_to?(:dependencies) ? Array(klass.dependencies) : []
          deps.each do |dep|
            dep_id = dep.to_s
            @graph[identifier][:dependencies] << dep_id
            (@graph[dep_id] ||= { dependencies: Set.new, dependents: Set.new })
            @graph[dep_id][:dependents] << identifier
          end
        end
      end

      def validate_dependencies!
        missing = {}

        @graph.each do |identifier, meta|
          meta[:dependencies].each do |dependency|
            next if @plugin_map.key?(dependency)

            missing[identifier] ||= []
            missing[identifier] << dependency
          end
        end

        return if missing.empty?

        plugin_id, deps = missing.first
        chain = deps.map { |dep| "#{plugin_id} → #{dep} (missing)" }
        available = normalize_available
        raise PluginDependencyError.missing(plugin_id: plugin_id, missing: deps, chain: chain, available: available)
      end

      def perform_topological_sort
        indegree = Hash.new(0)
        @graph.each_key { |identifier| indegree[identifier] ||= 0 }

        @graph.each do |identifier, meta|
          meta[:dependencies].each do |dependency|
            next unless @plugin_map.key?(dependency)

            indegree[identifier] += 1
          end
        end

        queue = @plugin_map.values.select { |klass| indegree[klass.id].zero? }
        queue.sort_by! { |klass| sort_signature(klass) }

        sorted = []
        until queue.empty?
          current = queue.shift
          sorted << current.id

          dependents = Array(@graph.dig(current.id, :dependents))
          dependents.each do |dependent|
            next unless indegree.key?(dependent)

            indegree[dependent] -= 1
            next unless indegree[dependent].zero?

            queue << @plugin_map[dependent]
            queue.sort_by! { |klass| sort_signature(klass) }
          end
        end

        if sorted.size != @plugin_map.size
          raise PluginDependencyError.circular(cycle: build_cycle(sorted), available: normalize_available)
        end

        sorted
      end

      def sort_signature(klass)
        priority_value = if klass.respond_to?(:priority_value)
                           -klass.priority_value
                         elsif klass.respond_to?(:priority) && klass.priority.respond_to?(:to_sym)
                           -Datalog::PluginSystem::PRIORITY_LEVELS.fetch(klass.priority.to_sym, 0)
                         else
                           0
                         end
        [priority_value, klass.id.to_s]
      end

      def build_cycle(sorted_identifiers)
        remaining = @plugin_map.keys - sorted_identifiers
        return [] if remaining.empty?

        visited = {}
        stack = []

        remaining.each do |identifier|
          cycle = explore_cycle(identifier, visited, stack, remaining)
          return format_cycle(cycle) if cycle
        end

        []
      end

      def explore_cycle(node, visited, stack, remaining)
        state = visited[node]
        return nil if state == :done
        if state == :active
          cycle_start = stack.index(node) || 0
          return stack[cycle_start..] + [node]
        end

        visited[node] = :active
        stack << node

        Array(@graph.dig(node, :dependencies)).each do |dependency|
          next unless @plugin_map.key?(dependency)
          next unless remaining.include?(dependency)

          cycle = explore_cycle(dependency, visited, stack, remaining)
          return cycle if cycle
        end

        stack.pop
        visited[node] = :done
        nil
      end

      def format_cycle(nodes)
        return [] unless Array(nodes).any?

        edges = []
        nodes.each_cons(2) do |from, to|
          edges << "#{from} → #{to}"
        end
        if nodes.length > 1
          edges << "#{nodes.last} → #{nodes.first}"
        end
        edges
      end

      def ensure_graph_built
        build_graph if @graph.empty? && plugins.any?
      end

      def normalize_available
        if available_plugins.respond_to?(:keys)
          available_plugins.keys
        elsif available_plugins.respond_to?(:map)
          available_plugins.map do |value|
            value.respond_to?(:id) ? value.id : value
          end
        else
          Array(available_plugins)
        end
      end
    end
  end
end
