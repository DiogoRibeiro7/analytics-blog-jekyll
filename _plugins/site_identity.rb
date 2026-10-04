# frozen_string_literal: true

module Datalog
  # The site as an entity of its own, for the `WebSite` node that
  # meta/schema.html writes on the homepage. Search engines read that node as
  # the strongest statement of a site's name, and its `alternateName` as the
  # other names people know it by, such as a handle (#322).
  #
  # Off unless `site_identity` in _config.yml asks for it, so a site that wrote
  # its own WebSite JSON-LD does not end up with two that disagree:
  #
  #   site_identity: true               # the site's title is its name
  #   site_identity:
  #     name: Jane Doe                  # default: title
  #     alternate_names: [janedoe]      # or alternate_name: janedoe
  module SiteIdentity
    module_function

    # Nil when the site has not asked for it, else its name and other names.
    def resolve(site)
      config = Authors.value(site, "site_identity")
      config = {} if config == true
      return unless config.is_a?(Hash) && config["enabled"] != false

      name = config["name"].to_s.strip
      name = Authors.value(site, "title").to_s.strip if name.empty?
      return if name.empty?

      others = Authors.list(config, "alternate_names", "alternate_name")
      { "name" => name, "alternate_names" => (others - [name]).uniq }
    end
  end

  module SiteIdentityFilters
    # `{% assign identity = site | site_identity %}`, nil when it is off.
    def site_identity(_input = nil)
      SiteIdentity.resolve(@context["site"])
    end
  end
end

Liquid::Template.register_filter(Datalog::SiteIdentityFilters)
