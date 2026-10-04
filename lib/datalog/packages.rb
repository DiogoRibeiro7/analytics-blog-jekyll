# frozen_string_literal: true

require "date"
require "time"

module Datalog
  # Package pages that know their registries: where each registry lists a
  # package, how to install it from there, and how to read its latest release
  # from the registry's API. The layout and the install panel read the first
  # two through _plugins/packages.rb; `datalog packages refresh` the third.
  module Packages
    # key => label, page, install commands as [console, template], and docs.
    REGISTRIES = {
      "pypi" => { label: "PyPI", tab: "pip", url: "https://pypi.org/project/%s/",
                  install: [["terminal", "pip install %s"]] },
      "conda_forge" => { label: "conda-forge", tab: "conda", url: "https://anaconda.org/conda-forge/%s",
                         install: [["terminal", "conda install -c conda-forge %s"]] },
      "cran" => { label: "CRAN", tab: "cran", url: "https://cran.r-project.org/package=%s",
                  install: [["r_console", "install.packages('%s')"]] },
      "crates" => { label: "crates.io", tab: "cargo", url: "https://crates.io/crates/%s",
                    install: [["terminal", "cargo add %s"]], docs: "https://docs.rs/%s" },
      "rubygems" => { label: "RubyGems", tab: "gem", url: "https://rubygems.org/gems/%s",
                      install: [["terminal", "gem install %s"], ["gemfile", "gem \"%s\""]] },
      "npm" => { label: "npm", tab: "npm", url: "https://www.npmjs.com/package/%s",
                 install: [["terminal", "npm install %s"]] },
      "julia" => { label: "JuliaHub", tab: "julia", url: "https://juliahub.com/ui/Packages/General/%s",
                   install: [["julia_repl", "using Pkg; Pkg.add(\"%s\")"]] }
    }.freeze

    # A tab is named for the tool that installs from the registry.
    TAB_LABELS = { "pip" => "pip", "conda" => "conda", "cran" => "CRAN", "cargo" => "cargo", "gem" => "gem",
                   "npm" => "npm", "julia" => "Pkg" }.freeze

    # The registries `datalog packages refresh` reads, and the address of a
    # package's latest release in each.
    ENDPOINTS = {
      "pypi" => "https://pypi.org/pypi/%s/json",
      "crates" => "https://crates.io/api/v1/crates/%s",
      "rubygems" => "https://rubygems.org/api/v1/versions/%s.json",
      "cran" => "https://crandb.r-pkg.org/%s",
      "npm" => "https://registry.npmjs.org/%s"
    }.freeze

    # A PEP 440 version, read leniently: an epoch, the release, then a
    # pre-release, a post-release and a development release, each optional,
    # then a local label. A pre-release or a development release makes it a
    # pre-release (1.0a1, 2.0rc1, 1!1.0rc1, 1.0.post1.dev2); a post-release
    # alone does not (1.0.post1).
    PEP440 = /\A(?:\d+!)?\d+(?:\.\d+)*
              (?<pre>[-_.]?(?:a|b|c|rc|alpha|beta|pre|preview)[-_.]?\d*)?
              (?:[-_.]?(?:post|rev|r)[-_.]?\d*|-\d+)?
              (?<dev>[-_.]?dev[-_.]?\d*)?
              (?:\+[a-z0-9]+(?:[-_.][a-z0-9]+)*)?\z/ix

    # Registries whose versions are semver, where a hyphen marks a pre-release
    # (1.0.0-beta.2) and a plus only build metadata (1.0.0+build.5).
    SEMVER = %w[crates npm julia].freeze

    # The two addresses pages gave before `registry:`.
    LEGACY = { "pypi" => "pypi_url", "cran" => "cran_url" }.freeze

    module_function

    # The registries a page names, in the order it names them: {"pypi" => "name"}.
    # `pypi_url` and `cran_url` still count, for pages written before `registry:`.
    def registries(data)
      named = data["registry"].is_a?(Hash) ? data["registry"].transform_keys(&:to_s) : {}
      named = named.select { |key, name| REGISTRIES.key?(key) && !name.to_s.strip.empty? }
      LEGACY.each_key do |key|
        name = legacy_name(key, legacy_url(data, key))
        named[key] ||= name if name
      end
      named.transform_values { |name| name.to_s.strip }
    end

    def legacy_url(data, key)
      url = data[LEGACY.fetch(key)].to_s.strip
      url.empty? ? nil : url
    end

    def legacy_name(key, url)
      return nil unless url

      case key
      when "pypi" then url[%r{pypi\.(?:python\.)?org/(?:project|pypi)/([^/?#]+)}, 1]
      when "cran" then url[/package=([\w.]+)/, 1] || url[%r{/web/packages/([\w.]+)}, 1]
      end
    end

    # The registry pages, and docs.rs for a crate: [{"registry", "label", "url"}].
    # A `pypi_url` or `cran_url` is the link when it names the same package as
    # the registry's entry, and still a link when it names none this can read.
    def links(data)
      named = registries(data)
      found = named.flat_map do |key, name|
        spec = REGISTRIES.fetch(key)
        legacy = LEGACY.key?(key) ? legacy_url(data, key) : nil
        legacy = nil unless legacy && legacy_name(key, legacy).to_s.casecmp?(name)
        [{ "registry" => key, "label" => spec[:label], "url" => legacy || format(spec[:url], name) },
         spec[:docs] && { "registry" => "docs_rs", "label" => "docs.rs", "url" => format(spec[:docs], name) }].compact
      end
      LEGACY.each_key do |key|
        url = legacy_url(data, key)
        found << { "registry" => key, "label" => REGISTRIES.dig(key, :label), "url" => url } if url && !named.key?(key)
      end
      found
    end

    # The install panel's tabs: one per registry, then Git. Each is
    # {"id", "label", "commands" => [{"console", "command"}]}. A page that
    # names no registry keeps the tabs its language always had: pip, conda
    # and Git for Python, CRAN and GitHub for R. `overrides` replaces the
    # command of a tab by its id, as the include's pip_command and siblings do.
    def install_tabs(data, language: nil, git_url: nil, name: nil, overrides: {})
      named = registries(data)
      tabs = named.empty? ? language_tabs(language.to_s.downcase, name) : named.map { |key, package| tab(key, package) }
      git = git_tab(language.to_s.downcase, git_url)
      tabs << git if git
      tabs.each do |item|
        override = overrides[item["id"]].to_s.strip
        item["commands"][0]["command"] = override unless override.empty?
      end
    end

    def tab(key, package)
      spec = REGISTRIES.fetch(key)
      commands = spec[:install].map do |console, template|
        { "console" => console, "command" => format(template, package) }
      end
      { "id" => spec[:tab], "label" => TAB_LABELS.fetch(spec[:tab]), "commands" => commands }
    end

    def language_tabs(language, name)
      case language
      when "python" then [terminal_tab("pip", "pip install #{name}"), terminal_tab("conda", "conda install #{name}")]
      when "r" then [tab("cran", name)]
      else []
      end
    end

    def terminal_tab(id, command, console: "terminal", label: TAB_LABELS.fetch(id, id))
      { "id" => id, "label" => label, "commands" => [{ "console" => console, "command" => command }] }
    end

    def git_tab(language, git_url)
      return nil if git_url.to_s.empty?

      if language == "r"
        repository = git_url.sub(%r{\Ahttps?://github\.com/}, "").sub(/\.git\z/, "")
        return terminal_tab("github", "devtools::install_github(\"#{repository}\")", console: "r_console",
                                                                                     label: "GitHub")
      end

      # The clone's directory is the repository's name, which need not be the package's.
      lines = ["git clone #{git_url}", "cd #{File.basename(git_url.to_s.chomp('/'), '.git')}"]
      lines << "pip install -e ." if language == "python"
      terminal_tab("git", lines.join("\n"), label: "Git")
    end

    # Whether a version is a pre-release by the rules of its registry: any
    # letter for RubyGems, a hyphen for semver, PEP 440 otherwise (and semver
    # for a version PEP 440 cannot read). CRAN has no pre-releases.
    def prerelease?(version, registry = nil)
      text = version.to_s.strip
      return false if text.empty? || registry == "cran"
      return text.match?(/[a-z]/i) if registry == "rubygems"
      return semver_prerelease?(text) if SEMVER.include?(registry)

      match = PEP440.match(text)
      match ? !(match[:pre] || match[:dev]).nil? : semver_prerelease?(text)
    end

    def semver_prerelease?(text)
      text.split("+", 2).first.include?("-")
    end
  end
end
