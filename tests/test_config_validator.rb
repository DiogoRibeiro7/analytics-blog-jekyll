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
    assert(validator.warnings.any? { |warning| warning.include?("math_engine") })
  end

  # --- Markdown / Highlighter enums ---

  def test_invalid_markdown_engine
    config = base_config
    config["markdown"] = "redcarpet"

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "Invalid value for 'markdown'"
    assert_includes error.message, '"kramdown" or "commonmark"'
  end

  def test_valid_markdown_engine
    config = base_config
    config["markdown"] = "kramdown"
    assert_nil run_generator(config) # no error
  end

  def test_invalid_highlighter
    config = base_config
    config["highlighter"] = "prism"

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "Invalid value for 'highlighter'"
  end

  # --- Paginate type ---

  def test_paginate_must_be_integer
    config = base_config
    config["paginate"] = "ten"

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "Invalid type for 'paginate'"
    assert_includes error.message, "an Integer"
  end

  def test_valid_paginate
    config = base_config
    config["paginate"] = 10
    assert_nil run_generator(config)
  end

  # --- Features boolean checks ---

  def test_features_boolean_validation
    config = base_config
    config["features"] = { "mathjax" => "yes" }

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "Invalid type for 'features.mathjax'"
    assert_includes error.message, "a Boolean"
  end

  def test_valid_features
    config = base_config
    config["features"] = {
      "mathjax" => true,
      "search" => true,
      "dark_mode_toggle" => false,
      "notebook_support" => true,
      "portfolio" => true,
      "datasets" => true
    }
    assert_nil run_generator(config)
  end

  # --- Notebooks ---

  def test_notebooks_enabled_boolean
    config = base_config
    config["notebooks"] = { "enabled" => "yes" }

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "Invalid type for 'notebooks.enabled'"
  end

  def test_valid_notebooks_config
    config = base_config
    config["notebooks"] = {
      "enabled" => true,
      "source" => "_notebooks",
      "output_dir" => "notebooks"
    }
    assert_nil run_generator(config)
  end

  # --- Sass ---

  def test_invalid_sass_style
    config = base_config
    config["sass"] = { "style" => "minified" }

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "Invalid value for 'sass.style'"
    assert_includes error.message, '"compressed" or "expanded"'
  end

  def test_valid_sass_style
    config = base_config
    config["sass"] = { "style" => "compressed" }
    assert_nil run_generator(config)
  end

  # --- Plugins array ---

  def test_plugins_must_be_array
    config = base_config
    config["plugins"] = "jekyll-feed"

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "Invalid type for 'plugins'"
    assert_includes error.message, "an Array"
  end

  # --- Collections hash ---

  def test_collections_must_be_hash
    config = base_config
    config["collections"] = ["portfolio"]

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "Invalid type for 'collections'"
    assert_includes error.message, "a Hash"
  end

  # --- SEO ---

  def test_seo_type_validation
    config = base_config
    config["seo"] = { "type" => 123 }

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "Invalid type for 'seo.type'"
  end

  # --- Valid complete config ---

  def test_full_valid_config_passes
    config = base_config
    config.merge!(
      "markdown" => "kramdown",
      "highlighter" => "rouge",
      "permalink" => "pretty",
      "paginate" => 10,
      "timezone" => "Europe/Lisbon",
      "collections" => { "portfolio" => { "output" => true } },
      "plugins" => %w[jekyll-feed jekyll-seo-tag],
      "features" => { "mathjax" => true, "search" => true },
      "notebooks" => { "enabled" => true, "source" => "_notebooks" },
      "seo" => { "type" => "ResearchProject", "name" => "DataLog" },
      "sass" => { "style" => "compressed" }
    )
    assert_nil run_generator(config)
  end

  # --- Email format ---

  def test_invalid_email_format
    config = base_config
    config["author"]["email"] = "not-an-email"

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_includes error.message, "a valid email address"
  end

  # --- Missing optional sections don't error ---

  def test_missing_optional_sections_pass
    config = {
      "title" => "Minimal Site",
      "url" => "https://example.com",
      "author" => { "name" => "Author" }
    }
    assert_nil run_generator(config)
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
