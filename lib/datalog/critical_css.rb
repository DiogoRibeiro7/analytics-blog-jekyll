# frozen_string_literal: true

require "date"
require "fileutils"
require "jekyll"
require "json"
require "nokogiri"
require "open3"
require "tmpdir"
require "yaml"
require_relative "site_config"

module Datalog
  # Writes the critical CSS a production build inlines. head.html inlines
  # _includes/critical-css/<target>.html for a page's layout (home, post, or
  # default for every other layout) and then loads main.css without blocking
  # rendering. Critical CSS depends on a site's own pages and styles, so the
  # theme ships those files empty and each site writes its own with
  # `datalog critical-css`.
  #
  # It runs critical 9, which has two engines. `render`, the default, opens
  # the page in Playwright's Chromium at each viewport in `dimensions` and
  # keeps the rules for what is painted there: the first screen, as critical 8
  # measured it. `static` needs no browser: it keeps every rule the page's
  # markup uses, which is more CSS but takes a second rather than a browser.
  class CriticalCss
    TARGETS = %w[home post default].freeze
    ENGINES = %w[render static].freeze
    DEFAULT_DIMENSIONS = [{ "width" => 1920, "height" => 1080 }, { "width" => 375, "height" => 667 }].freeze
    PACKAGE = "critical@9"
    # The render engine's browser. critical 9 leaves Playwright to the site, as
    # an optional peer, so npx is asked for both.
    PLAYWRIGHT = "playwright@1"
    MAJOR = 9
    # critical 9 needs it, as critical 8 did.
    NODE = Gem::Version.new("22.13.0")
    STYLESHEET = "assets/css/main.css"

    class Error < StandardError; end

    attr_reader :root, :settings

    # `datalog critical-css`. status reports a line as the command's shell
    # does; an error ends the command with exit status 1.
    def self.command(root, critical, status)
      config = SiteConfig.load(File.join(root, "_config.yml"))
      log = ->(message) { status.call(:critical, message, :blue) }
      written = new(root, config["critical_css"], critical: critical, log: log).run
      written.each_value { |path| status.call(:write, path, :green) }
    rescue Error, Jekyll::Errors::FatalException, SystemCallError => e
      status.call(:error, e.message, :red)
      exit 1
    end

    # critical: the command that runs critical, as a list of words. By default
    # the site's own node_modules/.bin/critical, or `npx --yes critical@9`
    # (with Playwright for the render engine).
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
      unless ENGINES.include?(engine)
        raise Error, "critical_css.engine is #{engine.inspect}; it is render (the default) or static"
      end

      if settings["penthouse_options"]
        @log.call("critical 9 has no penthouse options, so critical_css.penthouse_options is ignored")
      end
      command = critical_command
      install_browser if command == npx_command && engine == "render"

      Dir.mktmpdir("datalog-critical") do |site_dir|
        @log.call("Building the site for production into a temporary directory")
        build(site_dir)
        pages_for(site_dir).each_with_object({}) do |(target, page), written|
          if page.nil?
            @log.call("No page uses the #{target} layout; _includes/critical-css/#{target}.html is left as it is")
            next
          end

          @log.call("Extracting critical CSS for #{target} from #{page} (#{engine} engine)")
          written[target] = write(target, extract(site_dir, page, command))
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

    # The page goes to critical on its standard input, from the built site's
    # root, so the stylesheet resolves there whatever the page's folder or
    # the site's baseurl.
    def extract(site_dir, page, command = critical_command)
      html = page_for_critical(File.read(File.join(site_dir, page), encoding: "utf-8"))
      output, errors, status = Open3.capture3(*command, *arguments, stdin_data: html, chdir: site_dir)
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

    # The page as critical should read it: linking the site's stylesheet and
    # nothing else, as critical 8's --css did. The Google Fonts stylesheet
    # would bring @font-face rules for the font files a headless browser is
    # served, and fetching it made each page take over a minute. The Content
    # Security Policy goes too: it would refuse the stylesheet the render
    # engine adds to the page to measure it.
    def page_for_critical(html)
      document = Nokogiri::HTML5(html)
      document.css('link[rel~="stylesheet"], style, noscript').each(&:remove)
      document.css("meta[http-equiv]").each do |meta|
        meta.remove if meta["http-equiv"].casecmp?("content-security-policy")
      end
      head = document.at_css("head") || document.root.prepend_child(document.create_element("head"))
      head.add_child(document.create_element("link", rel: "stylesheet", href: STYLESHEET))
      document.to_html
    end

    # The arguments critical 9's command line takes: the engine, and for the
    # render engine the viewports, as one list ("1920x1080,375x667").
    def arguments
      return ["--engine", "static"] if engine == "static"

      dimensions = Array(settings["dimensions"]).grep(Hash)
      dimensions = DEFAULT_DIMENSIONS if dimensions.empty?
      viewports = dimensions.map { |entry| "#{entry['width']}x#{entry['height']}" }
      ["--engine", "render", "--dimensions", viewports.join(",")]
    end

    def engine
      settings.fetch("engine", "render").to_s
    end

    # The command that runs critical: the one given, else the site's own,
    # else npx's. The site's own must be critical 9: critical 8 takes other
    # arguments, and every option this passes would be refused.
    def critical_command
      return @critical if @critical

      check_node
      local = File.join(root, "node_modules", ".bin", Gem.win_platform? ? "critical.cmd" : "critical")
      return npx_command unless File.file?(local)

      version = installed_version
      if version && version.segments.first < MAJOR
        raise Error, "This site's node_modules has critical #{version}, and `datalog critical-css` runs critical " \
                     "#{MAJOR}, whose command line differs. Update it: npm install --save-dev critical@#{MAJOR}" \
                     "#{' playwright' if engine == 'render'}"
      end
      [local]
    end

    # npx brings Playwright but not the browser it drives, which critical 8's
    # Puppeteer downloaded as it installed. Playwright fetches it once; a later
    # run finds it in place.
    def install_browser
      @log.call("Making sure Playwright's Chromium is installed for the render engine")
      output, status = Open3.capture2e("npx", "--yes", PLAYWRIGHT, "install", "chromium")
      return if status.success?

      raise Error, "Playwright could not install Chromium: #{output.strip.lines.last(5).join.strip}"
    end

    def npx_command
      return ["npx", "--yes", PACKAGE] if engine == "static"

      ["npx", "--yes", "--package", PACKAGE, "--package", PLAYWRIGHT, "critical"]
    end

    def installed_version
      manifest = File.join(root, "node_modules", "critical", "package.json")
      return unless File.file?(manifest)

      Gem::Version.new(JSON.parse(File.read(manifest))["version"].to_s)
    rescue JSON::ParserError, ArgumentError
      nil
    end

    # critical 9 needs Node.js 22.13; an older one fails on an import, with a
    # message that does not say so.
    def check_node
      version = node_version
      raise Error, "Node.js was not found; critical needs Node.js #{NODE} or later" unless version
      return if Gem::Version.new(version) >= NODE

      raise Error, "critical needs Node.js #{NODE} or later, and this is Node.js #{version}"
    end

    # "22.13.0", or nil when there is no node to ask.
    def node_version
      output, status = Open3.capture2e("node", "--version")
      status.success? ? output[/\d+\.\d+\.\d+/] : nil
    rescue SystemCallError
      nil
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
