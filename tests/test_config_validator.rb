# frozen_string_literal: true

require_relative "test_helper"
require "ostruct"

class ConfigValidatorTest < Minitest::Test
  def test_required_field_validation
    config = base_config
    config.delete("title")

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "Missing required configuration 'title'"
    assert_includes error.message, "Path: title"
  end

  def test_type_validation
    config = base_config
    config["theme_options"]["math"]["enabled"] = "yes"

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "Invalid type for 'theme_options.math.enabled'"
    assert_includes error.message, "a Boolean"
  end

  def test_enum_validation_with_suggestions
    config = base_config
    config["theme_options"]["math"]["engine"] = "latex"

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "Invalid value for 'theme_options.math.engine'"
    assert_includes error.message, '"mathjax" or "katex"'
    assert_includes error.message, 'Did you mean "mathjax"?'
  end

  def test_nested_schema_validation
    config = base_config
    config["author"].delete("name")

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "Missing required configuration 'author.name'"
    assert_includes error.message, "Path: author → name"
  end

  def test_url_format_validation
    config = base_config
    config["url"] = "ftp://example.com"

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "a valid URL"
  end

  def test_deprecated_key_migration
    config = base_config
    config["theme_options"]["math"].delete("engine")
    config["math_engine"] = "katex"

    validator = Datalog::ConfigValidator::Validator.new(config)
    validator.run

    assert_empty validator.errors
    assert_equal "katex", config.dig("theme_options", "math", "engine")
    refute config.key?("math_engine"), "deprecated key should be removed after migration"
    assert validator.warnings.any? { |warning| warning.include?("math_engine") }
  end

  private

  def run_generator(config)
    validator = Datalog::ConfigValidator.new
    site = OpenStruct.new(config: config)
    validator.generate(site)
  end

  def base_config
    {
      "title" => "Test Site",
      "url" => "https://example.com",
      "author" => {
        "name" => "Test Author",
        "email" => "author@example.com"
      },
      "theme_options" => {
        "math" => {
          "engine" => "mathjax",
          "enabled" => true
        }
      }
    }
  end
end
