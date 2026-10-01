# frozen_string_literal: true

require_relative "../lib/datalog/packages"

module Datalog
  # Liquid's view of a package page: the registries its front matter names
  # (lib/datalog/packages.rb), and its latest release as
  # `datalog packages refresh` wrote it to _data/package_releases.yml, which
  # wins over the `version` and `license` typed in front matter.
  module PackageFilters
    # What each registry's language requirement is called on the page.
    REQUIREMENTS = {
      "requires_python" => "Python", "rust_version" => "Rust", "required_ruby_version" => "Ruby",
      "r_version" => "R", "node_version" => "Node.js"
    }.freeze

    # [{"registry", "label", "url"}]: the registry pages, docs.rs for a crate.
    def package_links(page)
      Packages.links(PackageFilters.data(page))
    end

    # The install panel's tabs. The options are the include's parameters,
    # which win over the front matter: language, name, git_url, and pip,
    # conda and cran to replace that tab's command.
    def package_install_tabs(page, options = {})
      data = PackageFilters.data(page)
      options = options.is_a?(Hash) ? options.transform_keys(&:to_s) : {}
      Packages.install_tabs(data, language: options["language"] || data["language"],
                                  git_url: options["git_url"] || data["github_url"],
                                  name: options["name"] || data["title"],
                                  overrides: options.slice("pip", "conda", "cran"))
    end

    # {"version", "released", "license", "requirement", "prerelease", "yanked",
    # "registry", "status"}: from the data file, for the first of the page's
    # registries it has, else from the front matter.
    def package_release(page)
      data = PackageFilters.data(page)
      releases = @context["site"]["data"]["package_releases"]
      releases = {} unless releases.is_a?(Hash)
      registry, name = Packages.registries(data).find do |key, value|
        releases[key].is_a?(Hash) && releases[key][value].is_a?(Hash)
      end
      release = registry ? releases[registry][name].dup : {}
      release["registry"] = registry if registry
      release["version"] ||= data["version"]&.to_s
      release["license"] ||= data["license"]&.to_s
      release["prerelease"] = true if Packages.prerelease?(release["version"])
      release["requirement"] = requirement(release)
      release["status"] = data["status"]&.to_s
      release.compact
    end

    def self.data(page)
      page.respond_to?(:[]) && !page.is_a?(String) ? page : {}
    end

    private

    def requirement(release)
      key = REQUIREMENTS.keys.find { |name| release[name] }
      return nil unless key

      value = release[key].to_s
      value = ">= #{value}" if value.match?(/\A\d/)
      "#{REQUIREMENTS[key]} #{value}"
    end
  end
end

Liquid::Template.register_filter(Datalog::PackageFilters)
