# frozen_string_literal: true

require "jekyll"
require_relative "package"

module Datalog
  module Theme
    # A site that installs the theme from a Git checkout or a local path
    # (`gem "datalog-theme", github: ...` or `path: ...`) gets the whole
    # repository as its theme, and the repository is also the demo site. Jekyll
    # merges the demo's _config.yml into the site's configuration, reads the
    # demo's _data as theme data and copies the demo's downloads from assets/.
    # The site then inherits the maintainer's name, contact addresses and social
    # profiles, and jekyll-feed stops the build on a datasets feed for a
    # collection the site does not have. The packaged gem contains none of those
    # files; these hooks give a checkout the same contents.
    module RepositoryCheckout
      module_function

      # The packaged gem ships no _config.yml, so one at the theme root means
      # the theme is a copy of the repository.
      def applies_to?(site)
        theme = site.theme
        !theme.nil? && theme.name == "datalog-theme" && File.file?(File.join(theme.root, "_config.yml"))
      end

      # Jekyll merges the theme configuration before any theme code runs, so it
      # cannot be taken back out here: Jekyll's own `ignore_theme_config` switch
      # is the only way to keep it out. A site that sets the switch to false has
      # chosen to inherit the demo configuration.
      def check_configuration(site)
        return unless applies_to?(site)
        return if site.config.key?("ignore_theme_config")

        raise Jekyll::Errors::FatalException, <<~MESSAGE
          datalog-theme is installed from a copy of its repository (#{site.theme.root}),
          which is also the theme's demo site. Jekyll merges the demo's _config.yml into
          your configuration, so your site would carry the demo's author, contact
          addresses, social profiles and feeds.

          Add this line to your _config.yml:

            ignore_theme_config: true

          The theme then also leaves out the demo's _data files and downloads. Set it to
          false instead only if you mean to inherit the demo configuration.
        MESSAGE
      end

      def remove_demo_content(site)
        return unless applies_to?(site) && site.config["ignore_theme_config"] == true

        remove_demo_assets(site)
        remove_demo_data(site)
      end

      def remove_demo_assets(site)
        demo_dirs = Package::DEMO_ASSETS.map { |entry| File.join(site.theme.root, entry, "") }
        site.static_files.reject! { |file| demo_dirs.any? { |dir| file.path.start_with?(dir) } }
      end

      # site.data holds the theme's data with the site's merged over it. Each key
      # the demo contributed goes back to the site's own value, or away.
      def remove_demo_data(site)
        theme_data_dir = File.join(site.theme.root, "_data")
        return unless File.directory?(theme_data_dir)

        demo_keys = Dir.children(theme_data_dir).map { |name| File.basename(name, ".*") } - Package.data_keys
        return if demo_keys.empty?

        own = Jekyll::DataReader.new(site).read(site.config["data_dir"])
        demo_keys.each do |key|
          if own.key?(key)
            site.data[key] = own[key]
          else
            site.data.delete(key)
          end
        end
      end
    end
  end
end

Jekyll::Hooks.register :site, :after_init do |site|
  Datalog::Theme::RepositoryCheckout.check_configuration(site)
end

Jekyll::Hooks.register :site, :post_read do |site|
  Datalog::Theme::RepositoryCheckout.remove_demo_content(site)
end
