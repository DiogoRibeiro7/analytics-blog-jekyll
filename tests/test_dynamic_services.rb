# frozen_string_literal: true

require "nokogiri"
require "tmpdir"
require_relative "test_helper"
require_relative "../_plugins/config_validator"

# The dynamic-services contract (#259): the public settings reach the
# browser only when a site has a backend, the Content Security Policy lets
# the browser call it, and a secret in those settings stops the build.
class DynamicServicesTest < Minitest::Test
  SETTINGS = {
    "base_url" => "https://api.example.org/base", "api_version" => "v1", "timeout_ms" => 8000,
    "credentials" => "omit", "features" => { "corrections" => true }
  }.freeze
  POLICY_AFTER = /http-equiv="Content-Security-Policy"\s+content="([^"]*)"/
  POLICY_BEFORE = /content="([^"]*)"\s+http-equiv="Content-Security-Policy"/

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_the_demo_has_no_backend_and_inlines_nothing
    html = SiteBuilder.read("2024/04/05/sql-optimization-guide/index.html")

    refute_includes html, "window.DatalogDynamicServices"
    refute_includes policy(html), "api.example.org"
  end

  def test_a_site_with_a_backend_inlines_its_public_settings_and_allows_the_origin
    html = render("dynamic_services" => SETTINGS)

    assert_match(
      %r{<script nonce="[^"]*">\s*window\.DatalogDynamicServices = \{"base_url":"https://api\.example\.org/base"}, html
    )
    assert_includes html, '"features":{"corrections":true}'
    assert_match(%r{connect-src [^;]*https://api\.example\.org[ ;]}, policy(html))
    refute_includes policy(html), "api.example.org/base", "the policy names the origin, not the path"
  end

  def test_an_empty_base_url_turns_the_services_off
    html = render("dynamic_services" => SETTINGS.merge("base_url" => ""))

    refute_includes html, "window.DatalogDynamicServices"
    refute_includes policy(html), "api.example.org"
  end

  def test_a_secret_in_the_public_settings_stops_the_build
    leaky = SETTINGS.merge("api_key" => "sk_live_1", "mail" => { "password" => "x" })
    validator = Datalog::ConfigValidator::Validator.new(base_config.merge("dynamic_services" => leaky)).run
    validator.errors.concat(Datalog::PublicConfiguration.errors("dynamic_services" => leaky))

    assert_equal 2, validator.errors.size
    assert_includes validator.formatted_errors, "dynamic_services → api_key"
    assert_includes validator.formatted_errors, "dynamic_services → mail → password"
    assert_includes validator.formatted_errors, "every reader's browser"
    assert_empty Datalog::PublicConfiguration.errors("dynamic_services" => SETTINGS), "credentials is a fetch mode"

    error = assert_raises(Jekyll::Errors::FatalException) { render("dynamic_services" => leaky) }
    assert_includes error.message, "Secret in public configuration 'dynamic_services.api_key'"
  end

  def test_the_settings_are_checked_like_the_rest
    config = base_config.merge("dynamic_services" => SETTINGS.merge("credentials" => "maybe", "timeout_ms" => "soon"))
    validator = Datalog::ConfigValidator::Validator.new(config).run

    assert_equal 2, validator.errors.size
    assert_empty Datalog::ConfigValidator::Validator.new(base_config.merge("dynamic_services" => SETTINGS)).run.errors
  end

  private

  def base_config
    {
      "title" => "Site", "url" => "https://example.org", "author" => { "name" => "Test" },
      "theme_options" => { "math" => { "engine" => "mathjax" } }
    }
  end

  # The content-security-policy the page carries, as its content attribute.
  def policy(html)
    html[POLICY_AFTER, 1] || html[POLICY_BEFORE, 1] || ""
  end

  # A page holding the settings include and the policy, under the given site configuration.
  def render(config)
    FileUtils.mkdir_p(File.join(@dir, "_includes", "meta"))
    FileUtils.cp(File.join(SiteBuilder.root, "_includes", "csp-meta.html"),
                 File.join(@dir, "_includes", "csp-meta.html"))
    FileUtils.cp(File.join(SiteBuilder.root, "_includes", "meta", "dynamic-services-config.html"),
                 File.join(@dir, "_includes", "meta", "dynamic-services-config.html"))
    body = "{% include csp-meta.html %}\n{% include meta/dynamic-services-config.html %}"
    File.write(File.join(@dir, "index.html"), "---\nlayout: null\ntitle: Page\n---\n\n#{body}\n")
    site_config = Jekyll.configuration(
      { "source" => @dir, "destination" => File.join(@dir, "_site"), "quiet" => true, "title" => "Services",
        "url" => "https://example.org", "author" => { "name" => "Test" } }.merge(config)
    )
    Jekyll::Site.new(site_config).process
    File.read(File.join(@dir, "_site", "index.html"))
  end
end
