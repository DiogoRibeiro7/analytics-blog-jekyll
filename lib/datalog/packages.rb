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

    # A PEP 440 pre-release (1.0a1, 2.0rc1, 1.0.dev3), a RubyGems one (2.0.0.pre1)
    # or a semver one (1.0.0-beta.2).
    PRERELEASE = /\A\d+(?:\.\d+)*(?:[._]?(?:a|b|c|rc|alpha|beta|pre|preview|dev)\.?\d*(?![a-z])|-[0-9A-Za-z.-]+)/i

    module_function

    # The registries a page names, in the order it names them: {"pypi" => "name"}.
    # `pypi_url` and `cran_url` still count, for pages written before `registry:`.
    def registries(data)
      named = data["registry"].is_a?(Hash) ? data["registry"].transform_keys(&:to_s) : {}
      named = named.select { |key, name| REGISTRIES.key?(key) && !name.to_s.strip.empty? }
      { "pypi" => data["pypi_url"], "cran" => data["cran_url"] }.each do |key, url|
        name = legacy_name(key, url)
        named[key] ||= name if name
      end
      named.transform_values { |name| name.to_s.strip }
    end

    def legacy_name(key, url)
      return nil if url.to_s.empty?

      case key
      when "pypi" then url[%r{pypi\.org/project/([^/?#]+)}, 1]
      when "cran" then url[/package=([\w.]+)/, 1] || url[%r{/web/packages/([\w.]+)}, 1]
      end
    end

    # The registry pages, and docs.rs for a crate: [{"label", "url"}].
    def links(data)
      registries(data).flat_map do |key, name|
        spec = REGISTRIES.fetch(key)
        page = key == "pypi" && data["pypi_url"] ? data["pypi_url"] : nil
        page ||= key == "cran" && data["cran_url"] ? data["cran_url"] : nil
        found = [{ "registry" => key, "label" => spec[:label], "url" => page || format(spec[:url], name) }]
        found << { "registry" => "docs_rs", "label" => "docs.rs", "url" => format(spec[:docs], name) } if spec[:docs]
        found
      end
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

    def prerelease?(version)
      version.to_s.match?(PRERELEASE)
    end
  end
end
