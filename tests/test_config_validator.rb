# frozen_string_literal: true

require_relative "test_helper"
require "open3"
require "ostruct"
require "rbconfig"
require "tmpdir"

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

  # Jekyll sites commonly set `author: Name`; the validator stopped such a
  # build with "Invalid type for 'author'".
  def test_accepts_an_author_given_as_a_name
    config = base_config
    config["author"] = "Jane Doe"

    run_generator(config)
    pass
  end

  # `jekyll new` writes `url: ""`, and a local build keeps it.
  def test_accepts_an_empty_url
    config = base_config
    config["url"] = ""

    run_generator(config)
    pass
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

  # The theme stopped loading Prism, so a site that still configures it should
  # hear that the settings do nothing.
  def test_warns_that_syntax_highlighting_settings_have_no_effect
    config = base_config
    config["theme_options"]["syntax_highlighting"] = { "cdn" => "https://cdn.jsdelivr.net/npm/prismjs@1.29.0" }

    validator = Datalog::ConfigValidator::Validator.new(config)
    validator.run

    assert_empty validator.errors
    assert(validator.warnings.any? do |warning|
      warning.include?("theme_options.syntax_highlighting") && warning.include?("Rouge")
    end)
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

  # jekyll-sass-converter replaces sass.style with a Symbol in the site's own
  # configuration when it converts a stylesheet.
  def test_accepts_a_sass_style_the_converter_made_a_symbol
    config = base_config
    config["sass"] = { "style" => :compressed }
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

  # --- Documentation link ---

  # Errors linked to a documentation site that was never published.
  def test_errors_link_to_a_reference_that_lists_every_checked_key
    config = base_config
    config["paginate"] = "ten"

    error = assert_raises(Jekyll::Errors::FatalException) { run_generator(config) }
    assert_equal "https://github.com/DiogoRibeiro7/analytics-blog-jekyll/blob/main/docs/configuration-reference.md",
                 error.message[/Documentation: (\S+)/, 1]

    reference = File.read(File.expand_path("../docs/configuration-reference.md", __dir__))
    schema_paths(Datalog::ConfigValidator::SCHEMA).each do |path|
      assert_includes reference, "| `#{path}` |", "docs/configuration-reference.md should list #{path}"
    end
  end

  private

  def schema_paths(schema, prefix = nil)
    schema.flat_map do |key, rules|
      path = [prefix, key].compact.join(".")
      [path, *(rules[:schema] ? schema_paths(rules[:schema], path) : [])]
    end
  end

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

# `jekyll serve` stopped regenerating after its first build: the validator ran
# again on the Symbol jekyll-sass-converter had left in sass.style and stopped
# every rebuild with "Invalid type for 'sass.style'". The site is built in a
# separate process so its hooks and plugins stay out of the other tests.
class ConfigValidatorRebuildTest < Minitest::Test
  VALIDATOR = File.expand_path("../_plugins/config_validator.rb", __dir__)

  # Processes one site twice, as `jekyll serve` does when a file changes, and
  # prints sass.style as the second build left it.
  REBUILD = <<~'RUBY'
    require "jekyll"

    source, validator = ARGV
    require validator

    File.write(File.join(source, "style.scss"), "---\n---\nbody { color: red; }\n")
    config = Jekyll.configuration(
      "source" => source,
      "destination" => File.join(source, "_site"),
      "disable_disk_cache" => true,
      "quiet" => true,
      "title" => "Test Site",
      "url" => "https://example.com",
      "author" => { "name" => "Test Author" },
      "sass" => { "style" => "compressed" }
    )
    site = Jekyll::Site.new(config)
    2.times { site.process }
    puts site.config["sass"]["style"].inspect
  RUBY

  def test_a_site_that_sets_sass_style_rebuilds
    Dir.mktmpdir do |dir|
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, "-e", REBUILD, dir, VALIDATOR)

      assert status.success?, "the second build should succeed:\n#{stdout}#{stderr}"
      assert_equal ":compressed", stdout.lines.last&.strip, "the converter should have rewritten sass.style"
    end
  end
end

# A `mathjax: true` in front matter defaults loaded MathJax on every page in its
# scope, and theme_options.math.enabled, which the user guide's troubleshooting
# table pointed to, does nothing. The build said neither.
class ConfigValidatorMathSettingsTest < Minitest::Test
  def test_warns_when_defaults_load_math_on_every_page_under_auto
    %w[math mathjax].each do |key|
      warnings = warnings_for(
        "theme_options" => { "math" => { "render_on_load" => "auto" } },
        "defaults" => [
          { "scope" => { "path" => "", "type" => "posts" }, "values" => { "layout" => "post", key => true } }
        ]
      )

      assert_equal 1, warnings.size, warnings.inspect
      assert_includes warnings.first, "'#{key}: true' for the pages of type 'posts'"
    end
  end

  def test_no_warning_for_defaults_that_turn_math_off_or_without_auto
    defaults = [{ "scope" => { "path" => "_pages" }, "values" => { "mathjax" => false } }]
    assert_empty warnings_for("theme_options" => { "math" => { "render_on_load" => "auto" } }, "defaults" => defaults)

    defaults = [{ "scope" => { "path" => "" }, "values" => { "mathjax" => true } }]
    assert_empty warnings_for("theme_options" => { "math" => { "render_on_load" => true } }, "defaults" => defaults)
  end

  def test_warns_that_math_enabled_has_no_effect
    [true, false].each do |value|
      warnings = warnings_for("theme_options" => { "math" => { "enabled" => value } })

      warned = warnings.any? do |warning|
        warning.include?("theme_options.math.enabled") && warning.include?("render_on_load")
      end
      assert warned, "enabled: #{value} should warn: #{warnings.inspect}"
    end
  end

  private

  def warnings_for(overrides)
    config = { "title" => "Test Site", "url" => "https://example.com", "author" => "Test Author" }.merge(overrides)
    validator = Datalog::ConfigValidator::Validator.new(config)
    validator.run

    assert_empty validator.errors
    validator.warnings
  end
end
