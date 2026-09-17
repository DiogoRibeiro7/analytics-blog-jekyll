# frozen_string_literal: true

require "date"
require "time"

module Datalog
  # The revision history of an article, for a post that is corrected or
  # rewritten while keeping its URL:
  #
  #   revisions:
  #     - date: 2026-09-16
  #       type: correction
  #       summary: Replaced the sample-size rules with model diagnostics.
  #       details_url: https://github.com/example/repo/pull/425
  #     - date: 2024-03-12
  #       type: update
  #       summary: Updated the code examples for the current SciPy.
  #
  # Before the site renders, each page's list is checked, its dates are
  # parsed and its entries sorted newest first, so the includes read one
  # shape. A correction or an update is substantive: the newest one becomes
  # `revision_notice`, which the post layout announces under the metadata.
  # A review or an editorial change appears in the history only.
  #
  # Every revision but a review changed the article, so the newest one sets
  # `last_modified_at` when it is later than the date the page gives, and
  # the JSON-LD, the microdata, the feed and the sitemap all carry it.
  module Revisions
    module_function

    TYPES = %w[correction update review editorial].freeze
    SUBSTANTIVE = %w[correction update].freeze
    DEFAULT_TYPE = "update"

    def normalize!(document)
      data = document.data
      return unless data.key?("revisions")

      revisions = entries(data["revisions"], document)
      data["revisions"] = revisions
      notice = revisions.find { |revision| revision["substantive"] }
      data["revision_notice"] = notice unless data["revision_notice"] == false

      changed = revisions.find { |revision| revision["type"] != "review" }
      modified = to_time(data["last_modified_at"] || data["updated"])
      data["last_modified_at"] = changed["date"] if changed && (modified.nil? || changed["date"] > modified)
    end

    # Newest first; revisions on one day keep their order.
    def entries(list, document)
      unless list.is_a?(Array)
        stop(document, "has revisions that is not a list; each revision is a map with a date, a summary and, " \
                       "if wanted, a type and a details_url")
      end

      revisions = list.each_with_index.map { |entry, index| revision(entry, index + 1, document) }
      revisions.each_with_index.sort_by { |revision, index| [-revision["date"].to_i, index] }.map(&:first)
    end

    def revision(entry, number, document)
      stop(document, "revision #{number} is not a map with a date and a summary") unless entry.is_a?(Hash)

      entry = entry.transform_keys(&:to_s)
      type = (entry["type"] || DEFAULT_TYPE).to_s.strip.downcase
      unless TYPES.include?(type)
        stop(document, "revision #{number} has the type #{entry['type'].inspect}; it takes #{TYPES.join(', ')}")
      end
      summary = entry["summary"].to_s.strip
      stop(document, "revision #{number} needs a summary saying what changed") if summary.empty?
      date = to_time(entry["date"])
      unless date
        stop(document, "revision #{number} has the date #{entry['date'].inspect}, which is not a date such as " \
                       "2026-09-16")
      end

      details = entry["details_url"].to_s.strip
      { "date" => date, "type" => type, "summary" => summary, "details_url" => (details unless details.empty?),
        "substantive" => SUBSTANTIVE.include?(type) }.compact
    end

    def stop(document, problem)
      raise Jekyll::Errors::FatalException, "#{document.relative_path} #{problem}"
    end

    # A Date, a Time or a string naming a day, such as "2026-09-16".
    def to_time(value)
      case value
      when Time then value
      when Date then value.to_time
      when String
        parts = Date._parse(value)
        Time.parse(value) if parts[:year] && parts[:mon] && parts[:mday]
      end
    end
  end
end

Jekyll::Hooks.register :site, :post_read do |site|
  site.documents.each { |document| Datalog::Revisions.normalize!(document) }
  site.pages.each { |page| Datalog::Revisions.normalize!(page) }
end
