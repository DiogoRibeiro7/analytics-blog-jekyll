# frozen_string_literal: true

require "bundler"
require "fileutils"
require "json"
require "open3"
require "pathname"
require "shellwords"
require "tmpdir"
require "yaml"
require_relative "../site_config"

module Datalog
  module Theme
    # Runs an upgrade from either a published gem or a path-installed checkout.
    # A checkout is moved only after its worktree and target tag are checked.
    class Updater
      class Error < StandardError; end

      COPY_FILES = %w[assets/js/loader.js _data/js_manifest.json _data/cdn-integrity.yml].freeze
      CONFIG_DIRS = %w[layouts_dir includes_dir plugins_dir].freeze

      def initialize(root:, options:, report:, execute:, available:)
        @root = File.expand_path(root)
        @options = options
        @report = report
        @execute = execute
        @available = available
      end

      def run
        theme = checkout_path
        return update_gem unless theme

        update_checkout(theme)
      end

      private

      def report(message)
        @report.call(message)
      end

      def checkout_path
        gemfile = File.join(@root, "Gemfile")
        return unless File.file?(gemfile)

        definition = Bundler::Dsl.evaluate(gemfile, File.join(@root, "Gemfile.lock"), {})
        dependency = definition.dependencies.find { |item| item.name == "datalog-theme" }
        source = dependency&.source
        return unless source.is_a?(Bundler::Source::Path)

        path = File.expand_path(source.path.to_s, @root)
        return path if File.exist?(File.join(path, ".git")) && git("rev-parse", "--show-toplevel", dir: path) == path

        nil
      rescue Bundler::BundlerError => e
        raise Error, "Cannot read the site's Gemfile: #{e.message}"
      end

      def update_checkout(theme)
        current = current_tag(theme)
        raise Error, "Theme checkout is not at a release tag; check out one before updating" unless current
        unless git("status", "--porcelain", dir: theme).empty?
          raise Error, "Theme checkout has local changes; commit or discard them first"
        end

        tags = available_tags(theme)
        target = choose_tag(tags, current)
        newer = tags.select { |tag| version(tag) > version(current) }.sort_by { |tag| version(tag) }
        report("Releases after #{current}: #{newer.join(', ')}") unless newer.empty?
        if target == current && !submodule_needs_stage?(theme)
          report("DataLog theme is already at #{current}.")
          return check_current(theme)
        end

        report("Update #{theme} from #{current} to #{target}.")
        if @options[:dry_run]
          report("Dry run: fetch tags, check out #{target}, build bundles, install gems, " \
                 "check the site and stage the submodule.")
          return 0
        end

        raise Error, "npm is required to build a path-installed theme" unless @available.call("npm")

        git("fetch", "--tags", "origin", dir: theme) if remote?(theme)
        git("checkout", "--detach", target, dir: theme)
        run!("npm ci", theme)
        run!("npm run build:js", theme)
        run!("bundle install", @root)
        changelog(File.join(theme, "CHANGELOG.md"), current, target)
        check_site!(theme)
        build_site if @options[:build]
        stage_submodule(theme, target)
        report("Theme updated to #{target}. Review the changes before committing; nothing was committed or pushed.")
        2
      end

      # Already at the release asked for, the checkout still has to be one a
      # site can build from: its bundles are rebuilt when they were never built
      # or were built from other sources, the site gets the same checks as after
      # an update, and --build builds it. Nothing changes the release, so the
      # answer stays 0, "already current".
      def check_current(theme)
        require_relative "installed_files"
        stale = InstalledFiles.stale_bundle_reasons(theme)
        if @options[:dry_run]
          report("Dry run: rebuild the theme bundles (#{stale.first}).") unless stale.empty?
          report("Dry run: check the site#{' and build it' if @options[:build]}.")
          return 0
        end

        unless stale.empty?
          raise Error, "npm is required to build a path-installed theme" unless @available.call("npm")

          report("The theme's bundles need building: #{stale.first}.")
          run!("npm ci", theme)
          run!("npm run build:js", theme)
        end
        check_site!(theme)
        build_site if @options[:build]
        0
      end

      def check_site!(theme)
        issues = preflight(theme)
        return if issues.empty?

        issues.each { |issue| report("Check: #{issue}") }
        raise Error, "Resolve the #{issues.size} site check(s) above before building"
      end

      def update_gem
        if @options[:to] && @options[:to] != "latest"
          raise Error, "--to with a version requires a path-installed Git checkout"
        end

        gemfile = File.join(@root, "Gemfile")
        before = locked_version
        if File.file?(gemfile)
          run!("bundle update datalog-theme", @root, "Bundler could not update datalog-theme.")
        else
          report("No Gemfile detected—skipping Bundler update")
        end
        update_site_npm
        return 0 if @options[:dry_run]

        after = locked_version
        changelog(gem_changelog, "v#{before}", "v#{after}") if before && after && before != after
        build_site if @options[:build]
        report("Theme dependencies are up to date!")
        before && after && before != after ? 2 : 0
      end

      def update_site_npm
        return unless File.file?(File.join(@root, "package.json"))

        if @available.call("npm")
          run!("npm install", @root, "npm could not install the site's packages.")
        else
          report("Node.js tooling not available—skipping npm install")
        end
      end

      def run!(command, dir, error = "#{command} failed")
        report(@options[:dry_run] ? "Would run #{command} in #{dir}" : "Running #{command} in #{dir}")
        return if @options[:dry_run]

        env = command.start_with?("bundle ") ? { "BUNDLE_GEMFILE" => File.join(@root, "Gemfile") } : {}
        return if @execute.call(env, command, dir)

        raise Error, error
      end

      def build_site
        Dir.mktmpdir("datalog-update-build") do |destination|
          command = "bundle exec jekyll build --disable-disk-cache --destination #{Shellwords.escape(destination)}"
          run!(command, @root, "The site build failed after updating the theme")
        end
      end

      def available_tags(theme)
        local = git("tag", "--list", dir: theme).lines.map(&:strip)
        remote = if remote?(theme)
                   git("ls-remote", "--refs", "--tags", "origin", dir: theme).lines.map do |line|
                     line.split("refs/tags/").last&.strip
                   end
                 else
                   []
                 end
        (local + remote).compact.uniq.select { |tag| version(tag) }
      end

      def choose_tag(tags, current)
        requested = @options[:to] || "latest"
        stable = tags.reject { |tag| version(tag).prerelease? }
        target = requested == "latest" ? stable.max_by { |tag| version(tag) } : requested
        raise Error, "Release tag #{requested.inspect} was not found" unless target && tags.include?(target)
        if version(target) < version(current)
          raise Error, "#{target} is older than #{current}; an update cannot downgrade the theme"
        end

        target
      end

      def current_tag(theme)
        tags = git("tag", "--points-at", "HEAD", dir: theme).lines.map(&:strip)
        tags.select { |tag| version(tag) }.max_by { |tag| version(tag) }
      end

      def version(tag)
        value = tag.to_s.delete_prefix("v")
        Gem::Version.new(value) if tag.to_s.start_with?("v") && Gem::Version.correct?(value)
      end

      def remote?(theme)
        !git("remote", "get-url", "origin", dir: theme, optional: true).nil?
      end

      def git(*args, dir:, optional: false)
        output, error, status = Open3.capture3("git", "-C", dir, *args)
        return output.strip if status.success?
        return if optional

        raise Error, "git #{args.join(' ')} failed in #{dir}: #{error.strip}"
      end

      def stage_submodule(theme, target)
        relative = Pathname.new(theme).relative_path_from(Pathname.new(@root)).to_s
        tracked = git("ls-files", "--stage", "--", relative, dir: @root, optional: true).to_s
        if tracked.start_with?("160000 ")
          git("add", "--", relative, dir: @root)
          report("Staged submodule #{relative}. Commit it when ready: " \
                 "git commit -m \"Update the DataLog theme to #{target}\"")
        else
          report("Theme checkout is not a tracked submodule; stage its pointer in your site repository yourself.")
        end
      end

      def submodule_needs_stage?(theme)
        relative = Pathname.new(theme).relative_path_from(Pathname.new(@root)).to_s
        tracked = git("ls-files", "--stage", "--", relative, dir: @root, optional: true).to_s
        tracked.start_with?("160000 ") && tracked.split[1] != git("rev-parse", "HEAD", dir: theme)
      end

      def locked_version
        file = File.join(@root, "Gemfile.lock")
        return unless File.file?(file)

        Bundler::LockfileParser.new(Bundler.read_file(file)).specs.find { |spec| spec.name == "datalog-theme" }&.version
      end

      def gem_changelog
        output, = Open3.capture2({ "BUNDLE_GEMFILE" => File.join(@root, "Gemfile") },
                                 "bundle", "info", "--path", "datalog-theme", chdir: @root)
        File.join(output.strip, "CHANGELOG.md")
      rescue Errno::ENOENT
        nil
      end

      def changelog(file, from, to)
        return unless file && File.file?(file)

        File.read(file).scan(/^## \[([^\]]+)\][^\n]*\n(.*?)(?=^## \[|\z)/m).reverse_each do |name, body|
          next unless version("v#{name}") && version("v#{name}") > version(from) && version("v#{name}") <= version(to)

          body.scan(/^### (Removed|Changed|Deprecated)\s*\n(.*?)(?=^### |\z)/m) do |heading, contents|
            report("#{name} — #{heading}\n#{contents.strip}")
          end
        end
      end

      def preflight(theme)
        require_relative "installed_files"
        config = SiteConfig.load(File.join(@root, "_config.yml"))
        issues = InstalledFiles.stale_bundle_reasons(theme)
        issues.concat(stale_copies(theme))
        CONFIG_DIRS.each do |key|
          issues << "#{key} points into the theme checkout" if points_into_theme?(config[key], theme)
        end
        sass = config["sass"].is_a?(Hash) ? config["sass"]["sass_dir"] : nil
        issues << "sass.sass_dir points into the theme checkout" if points_into_theme?(sass, theme)
        issues
      end

      def points_into_theme?(value, theme)
        return false unless value.is_a?(String) && !value.empty?

        path = File.expand_path(value, @root)
        path == theme || path.start_with?("#{theme}#{File::SEPARATOR}")
      end

      def stale_copies(theme)
        files = COPY_FILES + Dir.glob("assets/js/dist/**/*", base: theme).select do |path|
          File.file?(File.join(theme, path))
        end
        files.filter_map do |relative|
          own = File.join(@root, relative)
          source = File.join(theme, relative)
          next unless File.file?(source) && File.file?(own)

          "#{relative} differs from the theme's file" unless FileUtils.compare_file(own, source)
        end
      end
    end
  end
end
