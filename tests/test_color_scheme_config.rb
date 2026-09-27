# frozen_string_literal: true

require_relative "test_helper"

class ColorSchemeConfigTest < Minitest::Test
  def test_default_accepts_only_supported_modes
    config = {
      "title" => "Test Site",
      "url" => "https://example.com",
      "author" => { "name" => "Test Author" },
      "theme_options" => { "color_scheme" => { "default" => "sepia" } }
    }

    validate = -> { Datalog::ConfigValidator.new.generate(Struct.new(:config).new(config)) }
    error = assert_raises(Jekyll::Errors::FatalException) { validate.call }
    assert_includes error.message, "Invalid value for 'theme_options.color_scheme.default'"

    %w[dark light system].each do |mode|
      config["theme_options"]["color_scheme"]["default"] = mode
      assert_nil validate.call
    end
  end
end
