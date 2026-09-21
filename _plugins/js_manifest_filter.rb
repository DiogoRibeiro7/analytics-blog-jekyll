# frozen_string_literal: true

module Jekyll
  # `_data/js_manifest.json` records each bundle at a site-root path, so that
  # every template can put it through `relative_url` and a site served from a
  # subdirectory gets the right address. The loader is the one reader that
  # cannot: `_includes/scripts.html` hands it the manifest as JSON, and no
  # Liquid filter reaches inside that. Its copy is prefixed here instead.
  #
  # Without this a site with a `baseurl` imports /assets/js/dist/core.js, the
  # import 404s, and `bootstrapFeatures` returns before it loads a single
  # feature: no dark mode, no navigation, no search, no math (#328).
  module JsManifestFilter
    # The manifest with the site's baseurl in front of every path it holds.
    # Nested, since the bundles are grouped under `features` and `entrypoints`.
    def relative_manifest(manifest)
      relativize_manifest_value(manifest)
    end

    private

    def relativize_manifest_value(value)
      case value
      when Hash then value.transform_values { |entry| relativize_manifest_value(entry) }
      when Array then value.map { |entry| relativize_manifest_value(entry) }
      # `relative_url` leaves an absolute URL alone, so a manifest pointing at
      # a CDN survives this untouched.
      when String then relative_url(value)
      else value
      end
    end
  end
end

Liquid::Template.register_filter(Jekyll::JsManifestFilter)
