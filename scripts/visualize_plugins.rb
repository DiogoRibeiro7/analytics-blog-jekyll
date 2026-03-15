#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/datalog/plugin_system"

begin
  Dir[File.expand_path("../lib/datalog/plugins/**/*.rb", __dir__)].sort.each do |plugin_file|
    require plugin_file
  end

  resolver = Datalog::PluginSystem::DependencyResolver.new(
    Datalog::PluginSystem.available_plugins.values,
    available: Datalog::PluginSystem.available_plugins
  )

  order = resolver.resolve

  puts resolver.to_dot(order: order)
rescue Datalog::PluginSystem::PluginDependencyError => e
  warn e.message
  exit 1
end
