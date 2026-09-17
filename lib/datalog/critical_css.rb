# frozen_string_literal: true

require "date"
require "fileutils"
require "jekyll"
require "open3"
require "tmpdir"
require "yaml"

module Datalog
  # Writes the critical CSS a production build inlines. head.html inlines
  # _includes/critical-css/<target>.html for a page's layout (home, post, or
  # default for every other layout) and then loads main.css without blocking
  # rendering. Critical CSS depends on a site's own pages and styles, so the
  # theme ships those files empty and each site writes its own with
  # `datalog critical-css`.
  class CriticalCss
    TARGETS = %w[home post default].freeze
    DEFAULT_DIMENSIONS = [{ "width" => 1920, "height" => 1080 }, { "width" => 375, "height" => 667 }].freeze
    PACKAGE = "critical@8"

    class Error < StandardError; end

    attr_reader :root, :settings

    # `datalog critical-css`. status reports a line as the command's shell
    # does; an error ends the command with exit status 1.
    def self.command(root, critical, status)
      config = YAML.safe_load_file(File.join(root, "_config.yml"), permitted_classes: [Date, Time]) || {}
      log = ->(message) { status.call(:critical, message, :blue) }
      written = new(root, config["critical_css"], critical: critical, log: log).run
      written.each_value { |path| status.call(:write, path, :green) }
    rescue Error, Jekyll::Errors::FatalException, SystemCallError => e
      status.call(:error, e.message, :red)
      exit 1
    end

    # critical: the command that runs critical, as a list of words. By default
    # the site's own node_modules/.bin/critical, or `npx --yes critical@8`.
    def initialize(root, settings, critical: nil, log: ->(_message) {})
      @root = File.expand_path(root)
      @settings = settings || {}
      @critical = critical
      @log = log
    end

    # Returns the files written, by target. A target with no page to extract
    # from, such as post on a site without posts, is left as it is.
    def run
      unless settings["enabled"] == true
        raise Error, "critical_css.enabled is not true in _config.yml, so no page would inline critical CSS"
      end

      Dir.mktmpdir("datalog-critical") do |site_dir|
        @log.call("Building the site for production into a temporary directory")
        build(site_dir)
        pages_for(site_dir).each_with_object({}) do |(target, page), written|
          if page.nil?
            @log.call("No page uses the #{target} layout; _includes/critical-css/#{target}.html is left as it is")
            next
          end

          @log.call("Extracting critical CSS for #{target} from #{page}")
          written[target] = write(target, extract(site_dir, page))
        end
      end
    end

    # A production build, with critical CSS turned off for it: pages then link
    # main.css as usual, and CSS inlined by an earlier run cannot skew the result.
    def build(destination)
      previous = ENV.fetch("JEKYLL_ENV", nil)
      ENV["JEKYLL_ENV"] = "production"
      config = Jekyll.configuration(
        "source" => root, "destination" => destination, "quiet" => true,
        "critical_css" => settings.merge("enabled" => false)
      )
      Jekyll::Site.new(config).process
    ensure
      ENV["JEKYLL_ENV"] = previous
    end

    # The page each target extracts from: the one critical_css.pages names, or
    # the first built page with that layout, nearest the site root first.
    def pages_for(site_dir)
      configured = settings["pages"] || {}
      found = TARGETS.to_h { |target| [target, configured[target] && page_file(site_dir, configured[target])] }
      missing = TARGETS.reject { |target| found[target] }

      html_files(site_dir).each do |page|
        break if missing.empty?

        target = target_of(File.read(File.join(site_dir, page), encoding: "utf-8"))
        next unless missing.delete(target)

        found[target] = page
      end
      found
    end

    # Mirrors head.html: the home and post layouts have their own file, and
    # every other page the theme's default layout renders uses default. Pages
    # kept out of search engines, such as the search page, are not typical.
    def target_of(html)
      classes = html[/<body\b[^>]*\bclass="([^"]*)"/, 1].to_s.split
      return unless classes.include?("site-body")
      return "home" if classes.include?("layout-home")
      return "post" if classes.include?("layout-post")

      "default" unless html.match?(/<meta name="robots" content="noindex/)
    end

    # Only the site's stylesheet: the Google Fonts stylesheet would inline
    # @font-face rules for the font files headless Chrome is served (TrueType),
    # and fetching it made each page take over a minute.
    def extract(site_dir, page)
      arguments = [page, "--base", site_dir, "--css", File.join(site_dir, "assets", "css", "main.css"),
                   *dimension_arguments, *penthouse_arguments]
      output, errors, status = Open3.capture3(*critical_command, *arguments, chdir: site_dir)
      unless status.success?
        raise Error, "critical could not extract CSS from #{page}: #{errors.strip.lines.last(5).join.strip}"
      end

      css = output.strip
      raise Error, "critical found no critical CSS in #{page}" if css.empty?

      css
    end

    def write(target, css)
      path = File.join(root, "_includes", "critical-css", "#{target}.html")
      FileUtils.mkdir_p(File.dirname(path))
      # The include is rendered as Liquid; raw keeps a "{{" in CSS from being read as a tag.
      File.write(path, "{% raw %}\n#{css}\n{% endraw %}\n")
      path
    end

    def critical_command
      return @critical if @critical

      local = File.join(root, "node_modules", ".bin", Gem.win_platform? ? "critical.cmd" : "critical")
      File.file?(local) ? [local] : ["npx", "--yes", PACKAGE]
    end

    def dimension_arguments
      dimensions = Array(settings["dimensions"]).grep(Hash)
      dimensions = DEFAULT_DIMENSIONS if dimensions.empty?
      dimensions.flat_map { |entry| ["--dimensions", "#{entry['width']}x#{entry['height']}"] }
    end

    def penthouse_arguments
      options = settings["penthouse_options"]
      return [] unless options.is_a?(Hash)

      options.flat_map { |key, value| ["--penthouse-#{key}", value.to_s] }
    end

    def page_file(site_dir, url)
      path = url.to_s.sub(%r{\A/+}, "")
      path = File.join(path, "index.html") if path.empty? || path.end_with?("/")
      path if File.file?(File.join(site_dir, path))
    end

    def html_files(site_dir)
      Dir.glob("**/*.html", base: site_dir).sort_by { |page| [page.count("/"), page] }
    end
  end
end
