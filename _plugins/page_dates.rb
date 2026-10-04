# frozen_string_literal: true

require "time"

module Datalog
  # The date a page was published, when it has one. Jekyll gives a collection
  # document without a `date:` the time of the build, so `page.date` cannot
  # tell a dated page from an undated one, and an undated package, dataset or
  # notebook was "published" again by every build (#411). A post's date, from
  # its file name, and any `date:` in front matter are real.
  module PageDates
    module_function

    # The page's date, or nil when it has none or its date is the build's.
    def published(page, build_time)
      date = page.respond_to?(:[]) && !page.is_a?(String) ? page["date"] : nil
      return if date.nil? || date.to_s.strip.empty?

      time = date.respond_to?(:to_time) ? date.to_time : Time.parse(date.to_s)
      return if build_time && time.to_i == build_time.to_i

      date
    rescue ArgumentError
      nil
    end
  end

  module PageDateFilters
    # `{{ page | published_date | localize_date }}`, nil for an undated page.
    def published_date(page)
      site = @context.registers[:site]
      PageDates.published(page, site&.time)
    end
  end
end

Liquid::Template.register_filter(Datalog::PageDateFilters)
