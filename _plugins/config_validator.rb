# frozen_string_literal: true

require "uri"

module Datalog
  class ConfigValidator < Jekyll::Generator
    safe true
    priority :highest

    DOCUMENTATION_BASE_URL = "https://datalog-theme.github.io/docs/configuration-reference".freeze

    SCHEMA = {
      title: { type: :string, required: true },
      url: { type: :string, required: true, format: :url },
      author: {
        type: :hash,
        required: true,
        schema: {
          name: { type: :string, required: true },
          email: { type: :string, format: :email }
        }
      },
      theme_options: {
        type: :hash,
        schema: {
          math: {
            type: :hash,
            schema: {
              engine: { type: :string, enum: %w[mathjax katex] },
              enabled: { type: :boolean }
            }
          }
        }
      }
    }.freeze

    DEPRECATED_KEYS = {
      "math_engine" => {
        replacement: "theme_options.math.engine",
        message: "'math_engine' has moved under theme_options.math.engine.",
        auto_migrate: true
      }
    }.freeze

    COMMON_SUGGESTIONS = {
      %w[theme_options math engine] => {
        "latex" => "mathjax",
        "mathjax3" => "mathjax"
      }
    }.freeze

    class Validator
      attr_reader :errors, :warnings

      def initialize(config)
        @config = config
        @errors = []
        @warnings = []
      end

      def run
        @errors.clear
        @warnings.clear

        apply_deprecated_migrations
        validate_schema(@config, SCHEMA)

        self
      end

      def formatted_errors
        return "" if errors.empty?

        errors.map { |error| format_error(error) }.join("\n\n") +
          "\n\nBuild failed. Fix the above error in _config.yml and try again."
      end

      private

      def apply_deprecated_migrations
        DEPRECATED_KEYS.each do |path, metadata|
          key_path = normalize_path(path)
          value = dig_value(@config, key_path)
          next if value.nil?

          if metadata[:auto_migrate] && metadata[:replacement]
            target_path = normalize_path(metadata[:replacement])
            existing = dig_value(@config, target_path)
            if existing.nil?
              assign_value(@config, target_path, value)
              @warnings << "Deprecated config key '#{path}' detected. Automatically migrated to '#{metadata[:replacement]}'."
            else
              @warnings << "Deprecated config key '#{path}' detected. Value already set at '#{metadata[:replacement]}', skipping migration."
            end
            remove_value(@config, key_path)
          else
            @warnings << "Deprecated config key '#{path}' detected. #{metadata[:message]}"
          end
        end
      end

      def validate_schema(data, schema, path = [])
        schema.each do |key, rules|
          key_path = path + [key.to_s]
          present, value = fetch_value(data, key)

          if !present
            errors << build_missing_error(key_path) if rules[:required]
            next
          end

          if value.nil?
            errors << build_missing_error(key_path) if rules[:required]
            next
          end

          validate_type(key_path, value, rules)

          next unless rules[:schema] && value.is_a?(Hash)

          validate_schema(value, rules[:schema], key_path)
        end
      end

      def validate_type(path, value, rules)
        expected_type = rules[:type]
        if expected_type && !type_valid?(value, expected_type)
          errors << build_type_error(path, expected_type, value)
          return
        end

        if rules[:enum]
          enum_values = Array(rules[:enum])
          unless enum_values.include?(value)
            errors << build_enum_error(path, enum_values, value)
            return
          end
        end

        case rules[:format]
        when :url
          errors << build_format_error(path, "a valid URL", value) unless url_valid?(value)
        when :email
          errors << build_format_error(path, "a valid email address", value) unless email_valid?(value)
        end
      end

      def fetch_value(data, key)
        return [false, nil] unless data.is_a?(Hash)

        key_str = key.to_s
        if data.key?(key_str)
          [true, data[key_str]]
        elsif data.key?(key.to_sym)
          [true, data[key.to_sym]]
        else
          [false, nil]
        end
      end

      def type_valid?(value, expected_type)
        case expected_type
        when :string
          value.is_a?(String)
        when :integer
          value.is_a?(Integer)
        when :boolean
          value == true || value == false
        when :array
          value.is_a?(Array)
        when :hash
          value.is_a?(Hash)
        else
          true
        end
      end

      def url_valid?(value)
        return false unless value.is_a?(String)

        uri = URI.parse(value)
        uri.is_a?(URI::HTTP) && !uri.host.nil?
      rescue URI::InvalidURIError
        false
      end

      def email_valid?(value)
        return false unless value.is_a?(String)

        /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/.match?(value)
      end

      def build_missing_error(path)
        identifier = path.join(".")
        {
          headline: "Missing required configuration '#{identifier}'",
          path: path,
          expected: "Value required",
          actual: "nil",
          doc_url: documentation_url(path)
        }
      end

      def build_type_error(path, expected_type, value)
        identifier = path.join(".")
        {
          headline: "Invalid type for '#{identifier}'",
          path: path,
          expected: human_type(expected_type),
          actual: value.inspect,
          doc_url: documentation_url(path)
        }
      end

      def build_enum_error(path, enum_values, value)
        identifier = path.join(".")
        suggestion = suggestion_for(path, value)
        {
          headline: "Invalid value for '#{identifier}'",
          path: path,
          expected: enum_values.map { |v| "\"#{v}\"" }.join(" or "),
          actual: value.inspect,
          suggestion: suggestion,
          doc_url: documentation_url(path)
        }
      end

      def build_format_error(path, expectation, value)
        identifier = path.join(".")
        {
          headline: "Invalid value for '#{identifier}'",
          path: path,
          expected: expectation,
          actual: value.inspect,
          doc_url: documentation_url(path)
        }
      end

      def suggestion_for(path, value)
        map = COMMON_SUGGESTIONS[path]
        return unless map

        suggestion = map[value.to_s.downcase]
        return unless suggestion

        "Did you mean \"#{suggestion}\"?"
      end

      def format_error(error)
        lines = []
        lines << "Configuration Error: #{error[:headline]}"
        lines << ""
        lines << "  Path: #{error[:path].join(' → ')}"
        lines << "  Expected: #{error[:expected]}" if error[:expected]
        lines << "  Received: #{error[:actual]}" if error[:actual]
        lines << ""
        lines << "  #{error[:suggestion]}" if error[:suggestion]
        lines << "  Documentation: #{error[:doc_url]}"
        lines.reject!(&:nil?)
        lines.join("\n")
      end

      def documentation_url(path)
        anchor = path.map { |segment| segment.gsub(/[^a-z0-9]+/i, "-") }.join("-").downcase
        "#{DOCUMENTATION_BASE_URL}##{anchor}"
      end

      def human_type(type)
        case type
        when :string then "a String"
        when :integer then "an Integer"
        when :boolean then "a Boolean"
        when :array then "an Array"
        when :hash then "a Hash"
        else
          type.to_s
        end
      end

      def normalize_path(path)
        case path
        when String
          path.split(".")
        when Array
          path.map(&:to_s)
        else
          [path.to_s]
        end
      end

      def dig_value(data, path)
        return nil unless data.is_a?(Hash)

        head, *tail = path
        return nil if head.nil?

        value = data[head] || data[head.to_sym]
        return value if tail.empty?

        dig_value(value, tail)
      end

      def assign_value(data, path, value)
        head, *tail = path
        key_str = head.to_s
        if tail.empty?
          data[key_str] = value
          return
        end

        data[key_str] = {} unless data[key_str].is_a?(Hash)
        assign_value(data[key_str], tail, value)
      end

      def remove_value(data, path)
        return unless data.is_a?(Hash)

        head, *tail = path
        key_str = head.to_s
        if tail.empty?
          data.delete(key_str)
          data.delete(head.to_sym)
          return
        end

        child = data[key_str] || data[head.to_sym]
        return unless child.is_a?(Hash)

        remove_value(child, tail)
      end
    end

    def generate(site)
      validator = Validator.new(site.config)
      validator.run

      validator.warnings.each do |warning|
        logger.warn("config", warning)
      end

      return if validator.errors.empty?

      raise Jekyll::Errors::FatalException, validator.formatted_errors
    end

    private

    def logger
      Jekyll.logger
    end
  end
end
