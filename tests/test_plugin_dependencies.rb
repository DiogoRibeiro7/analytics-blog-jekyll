# frozen_string_literal: true

require_relative "test_helper"

class PluginDependencyResolverTest < Minitest::Test
  def test_site_records_dependency_order
    active = SiteBuilder.site.config.dig("datalog_plugin_state", "active")
    refute_nil active, "expected datalog_plugin_state to be populated"
    assert_equal %w[datalog-search datalog-citations datalog-slides datalog-comments], active
  end

  def test_resolver_orders_by_dependency_and_priority
    available = Datalog::PluginSystem.available_plugins
    resolver = Datalog::PluginSystem::DependencyResolver.new(
      %w[datalog-search datalog-citations datalog-slides datalog-comments].map { |key| available[key] },
      available: available
    )

    order = resolver.resolve.map(&:id)
    assert_equal %w[datalog-search datalog-citations datalog-slides datalog-comments], order
  end

  def test_missing_dependency_error_message
    plugin = build_stub_plugin(id: "test-missing", dependencies: ["non-existent"])
    resolver = Datalog::PluginSystem::DependencyResolver.new([plugin], available: Datalog::PluginSystem.available_plugins)

    error = assert_raises(Datalog::PluginSystem::PluginDependencyError) { resolver.resolve }
    assert_includes error.message, "Cannot load 'test-missing'"
    assert_includes error.message, "Missing dependency: 'non-existent'"
    assert_includes error.message, "Dependency chain"
  ensure
    Datalog::PluginSystem.available_plugins.delete("test-missing")
  end

  def test_circular_dependency_detection
    plugin_a = build_stub_plugin(id: "cycle-a", dependencies: ["cycle-b"])
    plugin_b = build_stub_plugin(id: "cycle-b", dependencies: ["cycle-a"])
    resolver = Datalog::PluginSystem::DependencyResolver.new(
      [plugin_a, plugin_b],
      available: Datalog::PluginSystem.available_plugins
    )

    error = assert_raises(Datalog::PluginSystem::PluginDependencyError) { resolver.resolve }
    assert_includes error.message, "Circular dependency detected"
    assert_includes error.message, "cycle-a"
    assert_includes error.message, "cycle-b"
  ensure
    Datalog::PluginSystem.available_plugins.delete("cycle-a")
    Datalog::PluginSystem.available_plugins.delete("cycle-b")
  end

  private

  def build_stub_plugin(id:, dependencies: [])
    plugin = Class.new(Datalog::PluginSystem::Plugin) do
      depends_on(*dependencies) if dependencies.any?
    end

    plugin.id(id)
    registry = Datalog::PluginSystem.available_plugins
    registry[id] = plugin
    plugin
  end
end
