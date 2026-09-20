# frozen_string_literal: true

require "time"

module Datalog
  # The licence of a page's text and figures, and of its code samples, for
  # the reuse notice, the JSON-LD and the head's rel="license" link:
  #
  #   content_license: CC-BY-4.0     # _config.yml: the default for every article
  #
  #   license: CC-BY-SA-4.0          # front matter: this page's own
  #   license: false                 # front matter: none for this page
  #   license:                       # front matter: a licence the theme does not know
  #     name: Open Government Licence v3.0
  #     url: https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/
  #     holder: The Lab
  #     year: 2026
  #   code_license: MIT              # the code samples, when their licence differs
  #
  # The repository's LICENSE covers the theme's software; these settings are
  # for what a site publishes. Datasets and packages carry their own
  # `license` and never take the site's default.
  module Licenses
    module_function

    # SPDX identifiers, with the name readers see and the licence text.
    KNOWN = {
      "CC-BY-4.0" => ["CC BY 4.0", "https://creativecommons.org/licenses/by/4.0/"],
      "CC-BY-SA-4.0" => ["CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0/"],
      "CC-BY-ND-4.0" => ["CC BY-ND 4.0", "https://creativecommons.org/licenses/by-nd/4.0/"],
      "CC-BY-NC-4.0" => ["CC BY-NC 4.0", "https://creativecommons.org/licenses/by-nc/4.0/"],
      "CC-BY-NC-SA-4.0" => ["CC BY-NC-SA 4.0", "https://creativecommons.org/licenses/by-nc-sa/4.0/"],
      "CC-BY-NC-ND-4.0" => ["CC BY-NC-ND 4.0", "https://creativecommons.org/licenses/by-nc-nd/4.0/"],
      "CC0-1.0" => ["CC0 1.0", "https://creativecommons.org/publicdomain/zero/1.0/"],
      "MIT" => ["MIT", "https://spdx.org/licenses/MIT.html"],
      "Apache-2.0" => ["Apache 2.0", "https://spdx.org/licenses/Apache-2.0.html"],
      "BSD-2-Clause" => ["BSD 2-Clause", "https://spdx.org/licenses/BSD-2-Clause.html"],
      "BSD-3-Clause" => ["BSD 3-Clause", "https://spdx.org/licenses/BSD-3-Clause.html"],
      "GPL-3.0-only" => ["GPL 3.0", "https://spdx.org/licenses/GPL-3.0-only.html"],
      "GPL-3.0-or-later" => ["GPL 3.0 or later", "https://spdx.org/licenses/GPL-3.0-or-later.html"],
      "LGPL-3.0-only" => ["LGPL 3.0", "https://spdx.org/licenses/LGPL-3.0-only.html"],
      "AGPL-3.0-only" => ["AGPL 3.0", "https://spdx.org/licenses/AGPL-3.0-only.html"],
      "MPL-2.0" => ["MPL 2.0", "https://spdx.org/licenses/MPL-2.0.html"],
      "ISC" => ["ISC", "https://spdx.org/licenses/ISC.html"],
      "Unlicense" => ["The Unlicense", "https://spdx.org/licenses/Unlicense.html"],
      "all-rights-reserved" => ["All rights reserved", nil]
    }.freeze

    # Other spellings: "CC BY" and "cc0" take the current version; the GPL
    # family without a suffix means "only", as SPDX reads it.
    ALIASES = {
      "CC-BY" => "CC-BY-4.0", "CC-BY-SA" => "CC-BY-SA-4.0", "CC-BY-ND" => "CC-BY-ND-4.0",
      "CC-BY-NC" => "CC-BY-NC-4.0", "CC-BY-NC-SA" => "CC-BY-NC-SA-4.0", "CC-BY-NC-ND" => "CC-BY-NC-ND-4.0",
      "CC0" => "CC0-1.0", "GPL-3.0" => "GPL-3.0-only", "LGPL-3.0" => "LGPL-3.0-only", "AGPL-3.0" => "AGPL-3.0-only"
    }.freeze

    # Collections whose pages carry their own licence and never the site's.
    OWN_LICENSE = %w[datasets packages].freeze

    def key(value)
      value.to_s.strip.upcase.gsub(/[\s_]+/, "-")
    end

    LOOKUP = KNOWN.keys.to_h { |id| [key(id), id] }.merge(ALIASES.to_h { |from, to| [key(from), to] }).freeze

    # The licence of the page's text and figures, or nil.
    def content(page, site)
      resolve(setting(page, "license", site, "content_license"), page, site)
    end

    # The licence of the page's code samples, or nil.
    def code(page, site)
      resolve(setting(page, "code_license", site, "code_license"), page, site)
    end

    # The page's own value, else the site's; `false` declines the site's.
    def setting(page, page_key, site, site_key)
      value = Authors.value(page, page_key)
      own_only = OWN_LICENSE.include?(Authors.value(page, "collection").to_s)
      fallback = Authors.value(site, site_key) unless own_only
      return fallback if value.nil? || value == true

      if value.is_a?(Hash) && !Authors.present(value).keys.intersect?(%w[id name url])
        defaults = fallback.is_a?(Hash) ? Authors.present(fallback) : { "name" => fallback }
        return defaults.merge(Authors.present(value))
      end

      value
    end

    def resolve(value, page, site)
      return if value.nil? || value == false || (value.is_a?(String) && value.strip.empty?)
      unless value.is_a?(String) || value.is_a?(Hash)
        raise Jekyll::Errors::FatalException, "#{Authors.value(page, 'path')} license must be a name, a map or false"
      end

      given = value.is_a?(Hash) ? Authors.present(value) : { "name" => value.to_s.strip }
      return unless given.keys.intersect?(%w[id name url])

      id = LOOKUP[key(given["id"] || given["name"])]
      name, url = KNOWN[id] if id
      # A name that is not itself an identifier is the label the page chose.
      name = given["name"] if given["name"] && LOOKUP[key(given["name"])].nil?
      licence = { "id" => id, "name" => name, "url" => given["url"] || url, "reserved" => id == "all-rights-reserved" }
      licence.merge(holder(given, page, site)).compact
    end

    # The copyright holder and year: the page's, else the site default's,
    # else the page's authors and its date.
    def holder(given, page, site)
      site_given = Authors.value(site, "content_license")
      site_given = site_given.is_a?(Hash) ? Authors.present(site_given) : {}
      names = Array(given["holder"] || site_given["holder"]).map(&:to_s).reject(&:empty?)
      authors = Authors.authors(page, site).map { |author| author["name"] }
      people = names.empty? || (names - authors).empty?
      names = authors if names.empty?
      year = year(given["year"] || site_given["year"] || Authors.value(page, "date"))
      { "holders" => names, "holder" => (names.join(", ") unless names.empty?), "people" => people, "year" => year }
    end

    # A year, a date or a string naming either.
    def year(value)
      return value if value.is_a?(Integer)
      return value.year if value.respond_to?(:year)

      text = value.to_s.strip
      return text.to_i if text.match?(/\A\d{4}\z/)
      return text if text.match?(/\A\d{4}[-–]\d{4}\z/)

      Time.parse(text).year unless text.empty?
    rescue ArgumentError
      nil
    end
  end

  module LicenseFilters
    def page_license(page)
      Licenses.content(page, @context["site"])
    end

    def page_code_license(page)
      Licenses.code(page, @context["site"])
    end
  end
end

Liquid::Template.register_filter(Datalog::LicenseFilters)
