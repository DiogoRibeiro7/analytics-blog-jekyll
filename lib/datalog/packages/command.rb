# frozen_string_literal: true

require "thor"

module Datalog
  # `datalog packages`: commands about the site's package pages.
  class PackagesCommand < Thor
    class_option :root, type: :string, default: Dir.pwd, aliases: "-r",
                        desc: "Path to the Jekyll site using the DataLog theme"

    desc "refresh", "Write each package's latest release, from its registries, to _data/package_releases.yml"
    method_option :dry_run, type: :boolean, default: false, desc: "Print the file instead of writing it"
    long_desc <<~DESC
      Reads the latest release of every package in the packages collection from
      each registry its `registry:` front matter names (PyPI, crates.io, RubyGems,
      CRAN, npm): version, release date, licence, the language version it needs,
      and whether it is a pre-release or yanked. The package layout shows these
      over the front matter, and the build itself never goes to a registry.
      If a registry cannot be read, nothing is written and the command exits 1.
    DESC
    def refresh
      require_relative "refresh"
      refresher = new_refresher
      data, yaml = refresher.run(dry_run: options[:dry_run])
      file = refresher.data_file.delete_prefix("#{refresher.root}/")
      count = data.values.sum(&:size)
      if count.zero?
        say "No package names a registry this command reads (#{Packages::ENDPOINTS.keys.join(', ')}); " \
            "#{file} was left as it was."
      elsif options[:dry_run]
        say yaml
      else
        say "Wrote #{count} #{count == 1 ? 'release' : 'releases'} to #{file}"
      end
    rescue Packages::Refresh::Error => e
      say e.message, :red
      exit 1
    end

    no_commands do
      # What reads the registries; a test hands it a fetch that reads fixtures.
      def new_refresher
        Packages::Refresh.new(root: options[:root])
      end
    end

    def self.exit_on_failure?
      true
    end
  end
end
