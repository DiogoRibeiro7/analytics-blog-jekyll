# frozen_string_literal: true

module Datalog
  module Theme
    # The repository is both the theme and the theme's demo site, and the demo
    # keeps some of its files in directories a theme also uses. These lists say
    # which of those files belong to the theme. The gemspec packages only those,
    # and RepositoryCheckout applies the same split to sites that install the
    # theme from a Git checkout or a local path, which see the whole repository.
    module Package
      # The _data files the layouts need in order to render. The rest of _data
      # (navigation, social profiles, publications, the author profile) is the
      # demo site's own; a site using the theme supplies its own versions.
      DATA_FILES = %w[
        _data/i18n
        _data/js_manifest.json
        _data/cdn-integrity.yml
      ].freeze

      # Downloads the demo site links to from assets/: the maintainer's CV
      # templates and publication exports.
      DEMO_ASSETS = %w[
        assets/publications
        assets/templates
      ].freeze

      module_function

      # Whether a repository-relative path is part of the theme rather than
      # demo content that happens to live in a theme directory.
      def theme_file?(path)
        return DATA_FILES.any? { |entry| inside?(path, entry) } if inside?(path, "_data")

        DEMO_ASSETS.none? { |entry| inside?(path, entry) }
      end

      # The site.data keys the theme's own data files are read into.
      def data_keys
        DATA_FILES.map { |entry| File.basename(entry, ".*") }
      end

      def inside?(path, entry)
        path == entry || path.start_with?("#{entry}/")
      end
    end
  end
end
