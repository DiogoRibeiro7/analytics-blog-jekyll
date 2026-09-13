# frozen_string_literal: true

module Datalog
  module SearchFilters
    module_function

    # Lower-cases text and strips combining marks, so "Café" and "cafe" match
    # while letters outside ASCII ("ß", "ł", Cyrillic, CJK) are kept. The
    # browser normalizes queries the same way (assets/js/search/utils.js), so
    # the index and the query agree. String#unicode_normalize is part of Ruby:
    # this file used to require it as if it were a gem, fail, and fall back to
    # dropping every character outside ASCII.
    def normalize_search(input)
      value = input.to_s
      return "" if value.empty?

      value.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase.strip
    rescue ArgumentError, Encoding::CompatibilityError
      value.downcase.strip
    end

    def normalize_search_array(values)
      Array(values)
        .map { |value| normalize_search(value) }
        .reject(&:empty?)
    end
  end
end

Liquid::Template.register_filter(Datalog::SearchFilters)
