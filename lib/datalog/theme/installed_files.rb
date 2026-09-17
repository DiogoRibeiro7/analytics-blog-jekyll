# frozen_string_literal: true

require "digest"
require "fileutils"
require "jekyll"
require "json"
require_relative "package"
require_relative "repository_checkout"

module Datalog
  module Theme
    # Stops a build that would serve a mix of theme versions. A site that uses
    # the theme from a Git submodule or another checkout reads every theme file
    # from it, but the script bundles are build output and have to be built
    # again whenever the checkout moves. Any site can also hold copies of files
    # the theme provides, left from copying the theme in by hand; a site's file
    # takes the place of the theme's, and the copies fall behind on the next
    # update.
    module InstalledFiles
      module_function

      BUNDLE_SOURCES = "assets/js/dist/sources.json"
      # Theme data a site has no reason to replace: the script manifest names
      # the bundles this version of the theme ships, and the integrity hashes
      # belong to the CDN files its layouts load. Translations are left out,
      # since a site may change them.
      DATA_FILES = %w[_data/js_manifest.json _data/cdn-integrity.yml].freeze

      # Jekyll prints an error on one line, so the messages are written as
      # sentences rather than laid out in lines.
      def check_bundles(site)
        return unless RepositoryCheckout.applies_to?(site)

        root = site.theme.root
        reasons = stale_bundle_reasons(root)
        return if reasons.empty?

        listed = reasons.first(5).join("; ")
        listed += "; and #{reasons.size - 5} more" if reasons.size > 5
        raise Jekyll::Errors::FatalException,
              "The script bundles in #{File.join(root, 'assets', 'js', 'dist')} were not built from the theme " \
              "files beside them (#{listed}). Pages would run scripts from another version of the theme. Build " \
              "them again by running `npm ci && npm run build:js` in #{root}."
      end

      # scripts/build_js.mjs records a SHA-256 of each file it builds from.
      def stale_bundle_reasons(root)
        record = File.join(root, BUNDLE_SOURCES)
        unless File.file?(record)
          return ["#{BUNDLE_SOURCES} is missing: the bundles were never built, or built before it was recorded"]
        end

        JSON.parse(File.read(record)).fetch("sources").filter_map do |path, digest|
          file = File.join(root, path)
          if !File.file?(file)
            "#{path} is gone"
          elsif Digest::SHA256.file(file).hexdigest != digest
            "#{path} has changed"
          end
        end
      end

      def check_site_copies(site)
        theme = site.theme
        return unless theme && theme.name == "datalog-theme"

        copies = stale_asset_copies(site, theme.root) + stale_data_copies(site, theme.root)
        return if copies.empty?

        raise Jekyll::Errors::FatalException,
              "Your site has its own copies of files datalog-theme provides, and they differ from the theme's: " \
              "#{copies.join(', ')}. A site's file takes the place of the theme's, so pages would load scripts, " \
              "or check their integrity, for another version of the theme. Delete these files: the theme " \
              "provides them."
      end

      # The site's static files that stand in for theme files pages load. Jekyll
      # leaves the theme's file out when the site has one at the same path.
      def stale_asset_copies(site, root)
        source = File.join(site.source, "")
        site.static_files.filter_map do |file|
          next unless file.path.start_with?(source)

          relative = file.relative_path.delete_prefix("/")
          next unless Package::SCRIPTS_PAGES_LOAD.any? { |entry| Package.inside?(relative, entry) }

          theme_file = File.join(root, relative)
          relative if File.file?(theme_file) && !FileUtils.identical?(file.path, theme_file)
        end
      end

      def stale_data_copies(site, root)
        reader = Jekyll::DataReader.new(site)
        own = reader.read(site.config["data_dir"])
        DATA_FILES.filter_map do |entry|
          key = File.basename(entry, ".*")
          theme_file = File.join(root, entry)
          next unless own.key?(key) && File.file?(theme_file)
          next if own[key] == reader.read_data_file(theme_file)

          Dir.glob("#{key}.*", base: site.in_source_dir(site.config["data_dir"])).map do |name|
            File.join(site.config["data_dir"], name)
          end.first
        end
      end
    end
  end
end

Jekyll::Hooks.register :site, :post_read do |site|
  Datalog::Theme::InstalledFiles.check_bundles(site)
  Datalog::Theme::InstalledFiles.check_site_copies(site)
end
