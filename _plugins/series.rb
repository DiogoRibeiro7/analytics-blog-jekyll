# frozen_string_literal: true

module Datalog
  # Article series: multi-part writing a reader follows in order, whatever
  # was published in between.
  #
  #   series:                       # front matter, as a map
  #     id: missing-data
  #     title: Missing Data and Statistical Inference
  #     order: 3
  #
  #   series: missing-data          # or flat
  #   series_title: Missing Data and Statistical Inference
  #   series_order: 3
  #
  #   missing-data:                 # _data/series.yml, so the title lives once
  #     title: Missing Data and Statistical Inference
  #     description: Four parts, from the missing-data mechanisms to sensitivity analysis.
  #
  # Before the site renders, every part is checked (an order that is missing,
  # not a whole number or taken by another part stops the build), the parts
  # are put in order, and each page's `series` becomes one shape: id, title,
  # description, order, position, count, parts (title, url, order, position,
  # current), previous and next. _includes/components/series-nav.html reads it.
  module Series
    module_function

    def normalize!(site)
      documents = site.documents + site.pages
      registry = site.data["series"].is_a?(Hash) ? site.data["series"] : {}
      documents.filter_map { |document| part(document) }.group_by { |part| part[:id] }.each do |id, parts|
        check_orders!(id, parts)
        meta = registry[id].is_a?(Hash) ? registry[id] : {}
        resolve!(id, parts.sort_by { |part| part[:order] }, meta)
      end
    end

    # The document's part of a series, as {doc, id, order, title}, or nil.
    def part(document)
      data = document.data
      value = data["series"]
      return if value.nil? || value == false || (value.is_a?(String) && value.strip.empty?)

      given = case value
              when Hash then value.transform_keys(&:to_s)
              when String, Symbol then { "id" => value.to_s }
              else stop(document, "has a series that is neither a name nor a map with an id and an order")
              end
      id = given["id"].to_s.strip
      stop(document, "has a series without an id, such as series: missing-data") if id.empty?

      order = given["order"] || data["series_order"]
      unless whole_number?(order)
        stop(document, "is part of the series \"#{id}\" without an order; give the part a whole number from 1, " \
                       "such as order: 2")
      end

      { doc: document, id: id, order: order.to_i, title: given["title"] || data["series_title"] }
    end

    def whole_number?(value)
      (value.is_a?(Integer) && value >= 1) || (value.is_a?(String) && value.match?(/\A[1-9]\d*\z/))
    end

    def check_orders!(id, parts)
      parts.group_by { |part| part[:order] }.each_value do |same|
        next if same.size == 1

        paths = same.map { |part| part[:doc].relative_path }.sort.join(" and ")
        raise Jekyll::Errors::FatalException,
              "#{paths} are both part #{same.first[:order]} of the series \"#{id}\"; each part needs its own order"
      end
    end

    # Writes each part's `series` from the ordered parts and the data file's entry.
    def resolve!(id, ordered, meta)
      title = meta["title"] || ordered.filter_map { |part| part[:title] }.first || titleize(id)
      summaries = ordered.each_with_index.map do |part, index|
        { "title" => part[:doc].data["title"], "url" => part[:doc].url, "order" => part[:order],
          "position" => index + 1 }
      end
      ordered.each_with_index do |part, index|
        part[:doc].data["series"] = {
          "id" => id, "title" => title, "description" => meta["description"],
          "order" => part[:order], "position" => index + 1, "count" => ordered.size,
          "parts" => summaries.map { |summary| summary.merge("current" => summary["url"] == part[:doc].url) },
          "previous" => (summaries[index - 1] if index.positive?), "next" => summaries[index + 1]
        }.compact
      end
    end

    def titleize(id)
      id.tr("-_", "  ").split.map(&:capitalize).join(" ")
    end

    def stop(document, problem)
      raise Jekyll::Errors::FatalException, "#{document.relative_path} #{problem}"
    end
  end
end

Jekyll::Hooks.register :site, :post_read do |site|
  Datalog::Series.normalize!(site)
end
