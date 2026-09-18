# frozen_string_literal: true

require "uri"

module Datalog
  # The dynamic-services settings are inlined into every page for the
  # browser (docs/dynamic-services.md), so a key that names a secret is a
  # leak whatever its value; the validator reports each one.
  module PublicConfiguration
    module_function

    # `credentials` is fetch's cookie mode, not a secret, so "credential" is not in the list.
    SECRET_KEY = /secret|token|password|passwd|api_key|apikey|private_key/i

    def errors(config)
      services = config["dynamic_services"]
      return [] unless services.is_a?(Hash)

      secret_keys(services, ["dynamic_services"]).map do |path|
        {
          headline: "Secret in public configuration '#{path.join('.')}'",
          path: path,
          expected: "no credential: dynamic_services is sent to every reader's browser, so a key, token or " \
                    "password belongs on the server, never in _config.yml",
          actual: "a key named '#{path.last}'"
        }
      end
    end

    def secret_keys(hash, path)
      hash.flat_map do |key, value|
        here = path + [key.to_s]
        found = key.to_s.match?(SECRET_KEY) ? [here] : []
        value.is_a?(Hash) ? found + secret_keys(value, here) : found
      end
    end
  end

  class ConfigValidator < Jekyll::Generator
    safe true
    priority :highest

    # docs/ is not part of the built site, so errors link to the file on GitHub.
    DOCUMENTATION_URL = "https://github.com/DiogoRibeiro7/analytics-blog-jekyll/blob/main/docs/configuration-reference.md"

    # A licence: an identifier such as CC-BY-4.0 or MIT, or a map naming one.
    LICENSE = {
      type: %i[string hash],
      schema: {
        id: { type: :string },
        name: { type: :string },
        url: { type: :string },
        holder: { type: %i[string array] },
        year: { type: %i[integer string] }
      }
    }.freeze

    SCHEMA = {
      title: { type: :string, required: true },
      url: { type: :string, required: true, format: :url },
      # `author: Jane Doe` is a common Jekyll setting; the hash adds an email and profile links.
      author: {
        type: %i[string hash],
        required: true,
        schema: {
          name: { type: :string, required: true },
          email: { type: :string, format: :email }
        }
      },
      # Who publishes the site in structured data and citations. Without it, the author does.
      publisher: {
        type: :hash,
        schema: {
          type: { type: :string, enum: %w[Person Organization] },
          name: { type: :string },
          url: { type: :string },
          logo: { type: :string }
        }
      },
      # The licence of the site's articles (text and figures) and of their code samples.
      content_license: LICENSE,
      code_license: LICENSE,
      # Which pages get scholarly discovery metadata: true for every post, or a list of collections and layouts.
      scholarly: { type: %i[boolean array string] },
      dynamic_services: {
        type: :hash,
        schema: {
          base_url: { type: :string, format: :url }, api_version: { type: %i[string integer] },
          timeout_ms: { type: :integer }, credentials: { type: :string, enum: %w[omit same-origin include] },
          features: { type: :hash }, paths: { type: :hash }, csrf_header: { type: :string }, csrf_cookie: { type: :string }
        }
      },
      # The correction-report form on posts (components/correction-report.html).
      corrections: {
        type: :hash,
        schema: { enabled: { type: :boolean }, categories: { type: :array } }
      },
      # The contact and collaboration form (components/contact-form.html).
      contact: {
        type: :hash,
        schema: {
          enabled: { type: :boolean }, categories: { type: :array }, prompts: { type: :hash },
          privacy_notice: { type: :string }, retention: { type: :string }
        }
      },
      # "Was this useful?" after a post (components/reactions.html).
      reactions: {
        type: :hash,
        schema: { enabled: { type: :boolean }, counts: { type: :boolean }, types: { type: :array } }
      },
      # Webmentions: the receiver advertised in the head, the mentions shown under a post.
      webmentions: {
        type: :hash,
        schema: { enabled: { type: :boolean }, endpoint: { type: :string }, types: { type: :array } }
      },
      # The newsletter form and the page its emails link to (components/subscribe-form.html).
      subscriptions: {
        type: :hash,
        schema: {
          enabled: { type: :boolean }, double_opt_in: { type: :boolean }, placement: { type: :array },
          topics: { type: :array }, privacy_url: { type: :string }
        }
      },
      markdown: { type: :string, enum: %w[kramdown commonmark] },
      highlighter: { type: :string, enum: %w[rouge pygments] },
      permalink: { type: :string },
      paginate: { type: :integer },
      timezone: { type: :string },
      collections: { type: :hash },
      plugins: { type: :array },
      features: {
        type: :hash,
        schema: {
          mathjax: { type: :boolean },
          search: { type: :boolean },
          dark_mode_toggle: { type: :boolean },
          notebook_support: { type: :boolean },
          portfolio: { type: :boolean },
          datasets: { type: :boolean }
        }
      },
      notebooks: {
        type: :hash,
        schema: {
          enabled: { type: :boolean },
          source: { type: :string },
          output_dir: { type: :string }
        }
      },
      seo: {
        type: :hash,
        schema: {
          type: { type: :string },
          name: { type: :string }
        }
      },
      sass: {
        type: :hash,
        schema: {
          style: { type: :string, enum: %w[compressed expanded] }
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
          },
          # The "Reading mode" control on posts, and whether a reader's choice is kept.
          reading_mode: {
            type: :hash,
            schema: {
              enabled: { type: :boolean },
              remember: { type: :boolean }
            }
          },
          # Bookmarks, reading progress and private highlights, kept in the reader's browser.
          reading_state: {
            type: :hash,
            schema: {
              enabled: { type: :boolean },
              bookmarks: { type: :boolean },
              progress: { type: :boolean },
              highlights: { type: :boolean },
              list_url: { type: :string }
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
      },
      "theme_options.syntax_highlighting" => {
        message: "Code is highlighted by Rouge when the site builds and the theme no longer loads Prism, " \
                 "so these settings have no effect. Remove them."
      },
      # The user guide's troubleshooting table sent readers here.
      "theme_options.math.enabled" => {
        message: "Nothing reads it: theme_options.math.render_on_load decides which pages load the math engine, " \
                 "and a page's `math` front matter overrides that. Remove it."
      }
    }.freeze

    COMMON_SUGGESTIONS = {
      %w[theme_options math engine] => {
        "latex" => "mathjax",
        "mathjax3" => "mathjax"
      }
    }.freeze

    # Pointing layouts_dir and the rest into a copy of the theme is how a site
    # used a Git submodule before the theme loaded its own plugins. Jekyll
    # cannot read the theme's assets or _data that way, so those were copied
    # into the site, and the copies fall behind the theme on every update.
    module ThemeDirectories
      module_function

      URL = "https://github.com/DiogoRibeiro7/analytics-blog-jekyll/blob/main/docs/install.md#keep-the-theme-in-a-git-submodule"
      KEYS = [%w[layouts_dir], %w[includes_dir], %w[plugins_dir], %w[sass sass_dir]].freeze

      def warnings(config)
        source = File.expand_path(config["source"] || Dir.pwd)
        keys = KEYS.select { |path| Array(config.dig(*path)).any? { |dir| theme_checkout?(dir, source) } }
        return [] if keys.empty?

        ["#{keys.map { |path| path.join('.') }.join(', ')} point into a copy of datalog-theme. Jekyll cannot " \
         "read the theme's assets and _data that way, so a site copies them in, and the copies fall behind " \
         "the theme. Use the copy as the theme instead: #{URL}"]
      end

      def theme_checkout?(dir, source)
        checkout = File.dirname(File.expand_path(dir.to_s, source))
        checkout != source && File.file?(File.join(checkout, "datalog-theme.gemspec"))
      end
    end

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
        check_math_defaults

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

      # With render_on_load: auto, only the pages with math load the math
      # engine. `math: true` or `mathjax: true` in front matter defaults loads it
      # on every page in their scope instead, and nothing in the build said so.
      def check_math_defaults
        return unless dig_value(@config, %w[theme_options math render_on_load]) == "auto"

        Array(@config["defaults"]).each do |entry|
          values = entry["values"] if entry.is_a?(Hash)
          next unless values.is_a?(Hash)

          %w[math mathjax].each do |key|
            next unless values[key] == true

            @warnings << "Front matter defaults set '#{key}: true' for #{describe_scope(entry['scope'])}, so they all " \
                         "load the math engine, whatever theme_options.math.render_on_load: auto finds. " \
                         "Remove it, and set 'math: true' on the pages that need the engine."
          end
        end
      end

      def describe_scope(scope)
        scope = {} unless scope.is_a?(Hash)
        type = scope["type"].to_s
        path = scope["path"].to_s
        return "every page" if type.empty? && path.empty?

        pages = type.empty? ? "the pages" : "the pages of type '#{type}'"
        path.empty? ? pages : "#{pages} under '#{path}'"
      end

      def validate_schema(data, schema, path = [])
        schema.each do |key, rules|
          key_path = path + [key.to_s]
          present, value = fetch_value(data, key)

          unless present
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
        # YAML never yields a Symbol, but converters rewrite the site's own
        # configuration: jekyll-sass-converter turns sass.style into one.
        value = value.to_s if value.is_a?(Symbol)

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
        return expected_type.any? { |type| type_valid?(value, type) } if expected_type.is_a?(Array)

        case expected_type
        when :string
          value.is_a?(String)
        when :integer
          value.is_a?(Integer)
        when :boolean
          [true, false].include?(value)
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
        # `url: ""` is what `jekyll new` writes, and what a site built locally keeps.
        return true if value.strip.empty?

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
          actual: "nil"
        }
      end

      def build_type_error(path, expected_type, value)
        identifier = path.join(".")
        {
          headline: "Invalid type for '#{identifier}'",
          path: path,
          expected: human_type(expected_type),
          actual: value.inspect
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
          suggestion: suggestion
        }
      end

      def build_format_error(path, expectation, value)
        identifier = path.join(".")
        {
          headline: "Invalid value for '#{identifier}'",
          path: path,
          expected: expectation,
          actual: value.inspect
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
        lines << "  Documentation: #{DOCUMENTATION_URL}"
        lines.compact!
        lines.join("\n")
      end

      def human_type(type)
        return type.map { |entry| human_type(entry) }.join(" or ") if type.is_a?(Array)

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

        # `data[head] || data[head.to_sym]` turned a `false` into nil.
        value = data.key?(head) ? data[head] : data[head.to_sym]
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

    # `jekyll serve` processes the same site again on every change, without
    # reading _config.yml again, and by then converters have rewritten parts of
    # the configuration: jekyll-sass-converter turns sass.style into a Symbol.
    # Checking on every build stopped each rebuild, so a site is checked on its
    # first build. A `:site, :after_init` hook would also run once, but Jekyll's
    # command line reports an error raised there as a backtrace, not a message.
    def generate(site)
      return if @validated

      validator = Validator.new(site.config)
      validator.run
      # The Validator class is at its length limit; the public-configuration check lives beside it.
      validator.errors.concat(PublicConfiguration.errors(site.config))

      (validator.warnings + ThemeDirectories.warnings(site.config)).each do |warning|
        logger.warn("config", warning)
      end

      @validated = validator.errors.empty?
      raise Jekyll::Errors::FatalException, validator.formatted_errors unless @validated
    end

    private

    def logger
      Jekyll.logger
    end
  end
end
