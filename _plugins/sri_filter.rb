# frozen_string_literal: true

module Jekyll
  module SriFilter
    def add_sri(url)
      site = @context.registers[:site]
      integrity_map = site.data["cdn-integrity"] || {}
      entry = integrity_map[url]
      return url unless entry

      attributes = "#{url}\" integrity=\"#{entry['integrity']}"
      attributes += "\" crossorigin=\"#{entry['crossorigin']}" if entry["crossorigin"]
      attributes
    end
  end
end

Liquid::Template.register_filter(Jekyll::SriFilter)
