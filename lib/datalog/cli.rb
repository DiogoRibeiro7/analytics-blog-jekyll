# frozen_string_literal: true

require "bundler"
require "date"
require "fileutils"
require "json"
require "pathname"
require "tmpdir"
require "yaml"
require "thor"

require_relative "theme/version"

module Datalog
  # Command line interface for automating common theme workflows.
  class CLI < Thor
    include Thor::Actions

    class_option :root,
                 type: :string,
                 default: Dir.pwd,
                 aliases: "-r",
                 desc: "Path to the Jekyll site using the DataLog theme"

    map %w[--version -v] => :version

    desc "version", "Print the installed DataLog theme version"
    def version
      say "DataLog theme version #{Datalog::Theme::VERSION}"
    end

    desc "check", "Verify required runtimes, dependencies, and configuration"
    long_desc <<~DESC
      Runs a diagnostic pass to make sure the current site directory has all
      dependencies installed, required configuration values in _config.yml, and
      optional tooling such as Node.js and Python for notebooks and visualizations.
      The command exits with a non-zero status code when a critical check fails.
    DESC
    def check
      root = site_root
      say_status :check, "Scanning #{root}" unless options[:quiet]

      critical_failures = []
      warnings = []

      critical_failures << :ruby unless ruby_supported?
      critical_failures << :bundler unless command_available?("bundle")
      critical_failures << :jekyll unless gem_available?(root, "jekyll")
      warnings << :node unless command_available?("node")
      warnings << :python unless command_available?("python3") || command_available?("python")
      warnings << :git unless command_available?("git")

      if config_valid?(root)
        warnings.concat(configuration_warnings(root))
      else
        critical_failures << :config
      end

      summarize_checks(critical_failures, warnings)

      exit 1 unless critical_failures.empty?
    end

    desc "publish", "Build the site and deploy the _site artifacts to GitHub Pages"
    method_option :branch,
                  type: :string,
                  default: "gh-pages",
                  aliases: "-b",
                  desc: "Target branch that serves the built site"
    method_option :message,
                  type: :string,
                  aliases: "-m",
                  desc: "Custom commit message for the deployment"
    long_desc <<~DESC
      Builds the Jekyll site using the active configuration and pushes the
      generated _site folder to the chosen branch. The command uses a temporary
      git worktree to keep the deployment history isolated.
    DESC
    def publish
      ensure_inside_git_repository!

      root = site_root
      branch = options[:branch]
      message = options[:message] || "Publish DataLog site on #{Time.now.utc.strftime('%Y-%m-%d %H:%M UTC')}"

      say_status :build, "bundle exec jekyll build", :blue
      unless system({ "BUNDLE_GEMFILE" => gemfile_path(root) }, "bundle exec jekyll build", chdir: root)
        say_error "Jekyll build failed. Resolve the error above and try again."
        exit 1
      end

      Dir.mktmpdir("datalog-publish") do |tmp|
        worktree_path = File.join(tmp, "deploy")
        prepare_worktree(root, branch, worktree_path)
        copy_site_output(root, worktree_path)
        commit_and_push(worktree_path, branch, message)
        cleanup_worktree(root, worktree_path)
      end
    end

    desc "update", "Update the DataLog theme and related assets to the latest version"
    long_desc <<~DESC
      Runs Bundler to update the datalog-theme dependency to the latest compatible
      release and refreshes npm packages if a package.json file is present.
    DESC
    def update
      root = site_root
      gemfile = gemfile_path(root)

      if File.exist?(gemfile)
        say_status :bundle, "bundle update datalog-theme", :blue
        unless system({ "BUNDLE_GEMFILE" => gemfile }, "bundle update datalog-theme", chdir: root)
          say_error "Bundler could not update datalog-theme."
          exit 1
        end
      else
        say_status :skip, "No Gemfile detected—skipping Bundler update", :yellow
      end

      package_json = File.join(root, "package.json")
      if File.exist?(package_json) && command_available?("npm")
        say_status :npm, "npm install", :blue
        system("npm install", chdir: root)
      elsif File.exist?(package_json)
        say_status :warn, "Node.js tooling not available—skipping npm install", :yellow
      end

      say "Theme dependencies are up to date!"
    end

    class New < Thor
      include Thor::Actions

      class_option :root,
                   type: :string,
                   default: Dir.pwd,
                   aliases: "-r",
                   desc: "Path to the Jekyll site using the DataLog theme"

      no_commands do
        def site_root
          File.expand_path(options[:root])
        end

        def ensure_directory!(relative_path)
          absolute = File.join(site_root, relative_path)
          FileUtils.mkdir_p(absolute)
          absolute
        end

        def slugify(text)
          text.downcase.strip.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
        end

        def ask_with_default(prompt, default)
          response = ask("#{prompt} [#{default}]")
          response = response.strip
          response.empty? ? default : response
        end
      end

      desc "post", "Interactively scaffold a blog post with recommended front matter"
      method_option :title, type: :string, aliases: "-t", desc: "Title for the post"
      method_option :date, type: :string, aliases: "-d", desc: "Publication date (YYYY-MM-DD)"
      method_option :tags, type: :array, aliases: "-g", desc: "List of tags"
      method_option :difficulty, type: :string, aliases: "-l", desc: "Difficulty label"
      def post
        title = options[:title] || ask("Title?")
        date_input = options[:date] || ask_with_default("Publication date", Date.today.strftime("%Y-%m-%d"))
        date = parse_date(date_input)
        slug = slugify(title)
        summary = ask_with_default("One-sentence summary", "Describe what readers will learn.")
        tags = options[:tags] || ask("Tags (comma separated)?").split(",").map(&:strip).reject(&:empty?)
        difficulty = (options[:difficulty] || ask_with_default("Difficulty", "Intermediate")).capitalize
        author = ask_with_default("Author", ENV.fetch("GIT_AUTHOR_NAME", "DataLog Team"))

        posts_dir = ensure_directory!("_posts")
        filename = File.join(posts_dir, format("%<date>s-%<slug>s.md", date: date.strftime("%Y-%m-%d"), slug: slug))

        if File.exist?(filename)
          say_status :error, "Post already exists: #{filename}", :red
          exit 1
        end

        tags_yaml = if tags.empty?
                      "[]"
                    else
                      "\n" + tags.map { |tag| "  - #{tag}" }.join("\n")
                    end
        front_matter = <<~YAML
          ---
          layout: post
          title: "#{title}"
          description: "#{summary}"
          author: "#{author}"
          date: #{date.strftime('%Y-%m-%d')}
          tags:#{tags_yaml}
          difficulty: "#{difficulty}"
          hero:
            image: /assets/images/#{slug}.jpg
            alt: "Hero image for #{title}"
          callouts:
            - label: Key takeaway
              content: Highlight the most important insight from the post.
          ---
        YAML

        body = <<~MARKDOWN
          #{front_matter}
          ## Overview

          Introduce the topic and set expectations for the walkthrough.

          ```python
          # Drop in runnable code snippets with syntax highlighting
          import pandas as pd
          ```

          > Use alerts, figures, and inline math like $\\alpha_t$ to demonstrate the theme.

          ### Next steps

          - Summarize the insights readers gained.
          - Link to supporting datasets or notebooks.
          - Invite feedback or reproduction reports.
        MARKDOWN

        create_file(filename, body)
        say_status :create, relative_to_root(filename), :green
      end

      desc "notebook", "Generate a notebook landing page and starter .ipynb file"
      method_option :title, type: :string, aliases: "-t", desc: "Title for the notebook"
      method_option :language, type: :string, aliases: "-l", default: "python", desc: "Primary notebook language"
      def notebook
        site_root
        title = options[:title] || ask("Title?")
        language = options[:language]&.strip&.downcase || "python"
        slug = slugify(title)
        summary = ask_with_default("Summary", "Explain what the notebook demonstrates.")
        binder = ask("Binder URL (optional)?").strip
        colab = ask("Colab URL (optional)?").strip
        tags = ask("Tags (comma separated)?").split(",").map(&:strip).reject(&:empty?)

        build_started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        notebooks_dir = ensure_directory!("_notebooks")
        assets_dir = ensure_directory!("notebooks")
        download_dir = ensure_directory!("assets/notebooks")

        metadata = {
          "title" => title,
          "summary" => summary,
          "tags" => tags,
          "date" => Date.today.strftime("%Y-%m-%d"),
          "notebook" => {
            "source" => "notebooks/#{slug}.ipynb",
            "download" => "/assets/notebooks/#{slug}.ipynb",
            "executed_at" => Time.now.strftime("%Y-%m-%d %H:%M"),
            "code_cells" => 0,
            "markdown_cells" => 0,
            "error_cells" => 0,
            "kernelspec" => {
              "display_name" => language.capitalize,
              "language" => language
            }
          }
        }

        integrations = {}
        integrations["binder"] = binder unless binder.empty?
        integrations["colab"] = colab unless colab.empty?
        metadata["notebook"]["integrations"] = integrations unless integrations.empty?

        ipynb_path = File.join(assets_dir, "#{slug}.ipynb")
        create_file(ipynb_path, JSON.pretty_generate(blank_notebook(language)))

        download_path = File.join(download_dir, "#{slug}.ipynb")
        if File.exist?(download_path)
          say_status :skip, "Download already exists at #{relative_to_root(download_path)}", :yellow
        else
          FileUtils.cp(ipynb_path, download_path)
          say_status :copy, relative_to_root(download_path), :blue
        end

        elapsed_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - build_started_at
        metadata["notebook"]["duration"] = elapsed_seconds.positive? ? elapsed_seconds.round(2) : 0

        metadata_yaml = metadata.to_yaml(line_width: -1)
        markdown_path = File.join(notebooks_dir, "#{slug}.md")
        create_file(markdown_path, <<~MARKDOWN)
          ---
          #{metadata_yaml.split("---\n").last.strip}
          ---

          This notebook demonstrates how to weave executable analysis into your narrative.

          ```#{language}
          print("Hello, DataLog!")
          ```
        MARKDOWN

        say_status :create, relative_to_root(markdown_path), :green
        say_status :create, relative_to_root(ipynb_path), :green
      end

      desc "project", "Scaffold a portfolio project entry"
      method_option :title, type: :string, aliases: "-t", desc: "Title for the project"
      def project
        site_root
        title = options[:title] || ask("Title?")
        slug = slugify(title)
        summary = ask_with_default("Summary", "Explain the project's impact and results.")
        role = ask_with_default("Role", "Lead Analyst")
        client = ask("Client or stakeholder? (optional)").strip
        timeline = ask_with_default("Timeline", "#{Date.today.strftime('%b %Y')} – Present")
        tags = ask("Tags (comma separated)?").split(",").map(&:strip).reject(&:empty?)

        portfolio_dir = ensure_directory!("_portfolio")
        path = File.join(portfolio_dir, "#{slug}.md")

        metadata = {
          "layout" => "portfolio",
          "title" => title,
          "summary" => summary,
          "role" => role,
          "timeline" => timeline,
          "tags" => tags,
          "links" => [
            { "label" => "Repository", "url" => "https://github.com/#{ENV.fetch('GITHUB_USER', 'DiogoRibeiro7')}/#{slug}" }
          ]
        }
        metadata["client"] = client unless client.empty?

        create_file(path, <<~MARKDOWN)
          ---
          #{metadata.to_yaml.split("---\n").last.strip}
          ---

          ## Problem

          Describe the problem space, constraints, and success criteria.

          ## Approach

          Outline the methodology, tooling, and collaboration model you used.

          ## Outcomes

          Highlight measurable impact, visuals, and lessons learned.
        MARKDOWN

        say_status :create, relative_to_root(path), :green
      end

      private

      def parse_date(input)
        Date.parse(input)
      rescue ArgumentError
        say_status :warn, "Invalid date provided. Using today's date.", :yellow
        Date.today
      end

      def blank_notebook(language)
        {
          "cells" => [
            {
              "cell_type" => "markdown",
              "metadata" => {},
              "source" => ["# #{options[:title] || 'New Notebook'}\n", "Describe the objective of this analysis."]
            },
            {
              "cell_type" => "code",
              "execution_count" => nil,
              "metadata" => {},
              "outputs" => [],
              "source" => [example_snippet(language)]
            }
          ],
          "metadata" => {
            "kernelspec" => {
              "display_name" => language.capitalize,
              "language" => language,
              "name" => language
            },
            "language_info" => {
              "name" => language
            }
          },
          "nbformat" => 4,
          "nbformat_minor" => 5
        }
      end

      def example_snippet(language)
        case language
        when "python"
          "print('Hello, DataLog!')\n"
        when "r"
          "print('Hello, DataLog!')\n"
        when "julia"
          "println('Hello, DataLog!')\n"
        else
          "# Add your #{language} code here\n"
        end
      end

      def relative_to_root(path)
        Pathname.new(path).relative_path_from(Pathname.new(site_root)).to_s
      end
    end

    register(New, "new", "new COMMAND", "Scaffold posts, notebooks, and portfolio projects")

    private

    def site_root
      File.expand_path(options[:root])
    end

    def ensure_inside_git_repository!
      return if command_available?("git") && system("git", "rev-parse", "--is-inside-work-tree", out: File::NULL,
                                                                                                 err: File::NULL, chdir: site_root)

      say_error "The publish command must be run inside a git repository."
      exit 1
    end

    def ruby_supported?
      Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.0.0")
    end

    def gemfile_path(root)
      File.join(root, "Gemfile")
    end

    def gem_available?(root, gem_name)
      gemfile = gemfile_path(root)
      return false unless File.exist?(gemfile)

      lockfile = File.join(root, "Gemfile.lock")
      return false unless File.exist?(lockfile)

      locked = Bundler::LockfileParser.new(Bundler.read_file(lockfile))
      locked.specs.any? { |spec| spec.name == gem_name }
    rescue Bundler::BundlerError
      false
    end

    # Searches PATH directly instead of shelling out: `command -v` is a POSIX
    # shell builtin with no executable behind it, so on Windows every lookup
    # failed and `datalog check` reported all dependencies as missing.
    def command_available?(command)
      return true if File.file?(command) && File.executable?(command)

      extensions = if Gem.win_platform?
                     (ENV["PATHEXT"] || ".COM;.EXE;.BAT;.CMD").split(";")
                   else
                     [""]
                   end

      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
        next false if directory.empty?

        extensions.any? do |extension|
          candidate = File.join(directory, "#{command}#{extension}")
          File.file?(candidate) && File.executable?(candidate)
        end
      end
    end

    def config_valid?(root)
      config_path = File.join(root, "_config.yml")
      return false unless File.exist?(config_path)

      config = load_config(config_path)
      config["theme"] == "datalog" || Array(config["plugins"]).include?("datalog-theme")
    rescue Psych::SyntaxError
      false
    end

    def configuration_warnings(root)
      config_path = File.join(root, "_config.yml")
      return [] unless File.exist?(config_path)

      config = load_config(config_path)
      warnings = []
      warnings << :collections unless config.key?("collections")
      warnings << :url unless config.key?("url")
      warnings
    rescue Psych::SyntaxError
      []
    end

    def load_config(path)
      YAML.safe_load_file(path, permitted_classes: [Date, Time]) || {}
    end

    def summarize_checks(critical, warnings)
      if critical.empty?
        say_status :ok, "All critical checks passed", :green
      else
        critical.each do |item|
          say_status :fail, "Missing required dependency: #{item}", :red
        end
      end

      warnings.each do |item|
        message = case item
                  when :collections
                    "Optional configuration missing: define collections in _config.yml to enable datasets and portfolio content"
                  when :url
                    "Set site url in _config.yml for accurate SEO metadata"
                  else
                    "Optional tooling not available: #{item}"
                  end
        say_status :warn, message, :yellow
      end
    end

    def remote_branch?(root, branch)
      system("git", "ls-remote", "--exit-code", "origin", "refs/heads/#{branch}", out: File::NULL, err: File::NULL,
                                                                                  chdir: root)
    end

    def prepare_worktree(root, branch, worktree_path)
      unless system("git", "show-ref", "--verify", "--quiet", "refs/heads/#{branch}", chdir: root)
        say_status :info, "Creating #{branch} branch", :blue
        if remote_branch?(root, branch)
          system("git", "branch", branch, "origin/#{branch}", chdir: root)
        else
          system("git", "branch", branch, chdir: root)
        end
      end

      say_status :git, "git worktree add --force #{worktree_path} #{branch}", :blue
      return if system("git", "worktree", "add", "--force", worktree_path, branch, chdir: root)

      say_error "Unable to create git worktree for #{branch}."
      exit 1
    end

    def copy_site_output(root, worktree_path)
      say_status :sync, "Copying _site to #{worktree_path}", :blue
      FileUtils.rm_rf(Dir.glob(File.join(worktree_path, "*"),
                               File::FNM_DOTMATCH) - [File.join(worktree_path, "."), File.join(worktree_path, ".."),
                                                      File.join(worktree_path, ".git")])
      Dir.glob(File.join(root, "_site", "*"), File::FNM_DOTMATCH).each do |entry|
        next if [".", ".."].include?(File.basename(entry))

        FileUtils.cp_r(entry, worktree_path, preserve: true)
      end
    end

    def commit_and_push(worktree_path, branch, message)
      Dir.chdir(worktree_path) do
        system("git", "add", "--all")
        if system("git", "diff", "--cached", "--quiet")
          say_status :skip, "No changes to publish", :yellow
          return
        end

        system("git", "commit", "-m", message)
        say_status :git, "git push origin #{branch}", :blue
        system("git", "push", "origin", branch)
      end
    end

    def cleanup_worktree(root, worktree_path)
      say_status :git, "git worktree remove --force #{worktree_path}", :blue
      system("git", "worktree", "remove", "--force", worktree_path, chdir: root)
    ensure
      FileUtils.rm_rf(File.dirname(worktree_path)) if worktree_path && File.directory?(File.dirname(worktree_path))
    end

    def say_error(message)
      say message, :red
    end
  end
end
