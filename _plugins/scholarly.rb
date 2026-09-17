# frozen_string_literal: true

module Datalog
  # Which pages get scholarly discovery metadata (_includes/meta/scholarly.html):
  # the Highwire meta tags Google Scholar and reference managers read, and
  # their Dublin Core equivalents. Not every post is a paper, so the tags are
  # opt-in:
  #
  #   scholarly: true        # front matter: this page is a research article
  #   scholarly: false       # front matter: this one is not, whatever the site says
  #
  #   scholarly: true        # _config.yml: every post and research article
  #   scholarly: [notebooks] # _config.yml: these collections or layouts as well
  #
  # A page with the research layout, or in a research collection, is
  # scholarly unless it says otherwise.
  module Scholarly
    module_function

    ALWAYS = %w[research].freeze
    POSTS = %w[posts post].freeze

    def scholarly?(page, site)
      own = Authors.value(page, "scholarly")
      return own == true unless own.nil?

      kinds = kinds(Authors.value(site, "scholarly"))
      [Authors.value(page, "layout"), Authors.value(page, "collection")].any? { |kind| kinds.include?(kind.to_s) }
    end

    # The layouts and collections the site's setting covers, besides research.
    def kinds(setting)
      case setting
      when true then ALWAYS + POSTS
      when Array then ALWAYS + setting.map(&:to_s)
      when String then ALWAYS + setting.split(/[\s,]+/)
      else ALWAYS
      end
    end
  end

  module ScholarlyFilters
    # A Liquid filter's name cannot end with "?".
    def scholarly(page) # rubocop:disable Naming/PredicateMethod
      Scholarly.scholarly?(page, @context["site"])
    end
  end
end

Liquid::Template.register_filter(Datalog::ScholarlyFilters)
