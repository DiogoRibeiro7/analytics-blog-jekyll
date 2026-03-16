# frozen_string_literal: true

module Datalog
  module WarningFilter
    FILTERS = [
      /literal string will be frozen/,
      /already initialized constant Datalog::Theme::VERSION/
    ].freeze

    def warn(message)
      return if FILTERS.any? { |pattern| pattern.match?(message) }

      super
    end
  end
end

Warning.singleton_class.prepend(Datalog::WarningFilter) if defined?(Warning)

module Kernel
  alias __datalog_warn warn

  def warn(message = nil, *args)
    return if message && Datalog::WarningFilter::FILTERS.any? { |pattern| pattern.match?(message) }

    __datalog_warn(message, *args)
  end
end
