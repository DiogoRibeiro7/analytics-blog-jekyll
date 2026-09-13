# frozen_string_literal: true

module Datalog
  # Silences two warnings that every build repeats. Kernel#warn reports through
  # Warning.warn, so prepending here covers both. A Kernel#warn override used to
  # sit alongside it, and it printed keyword arguments such as `uplevel:` and
  # `category:` as a hash after the message instead of honouring them.
  module WarningFilter
    FILTERS = [
      /literal string will be frozen/,
      /already initialized constant Datalog::Theme::VERSION/
    ].freeze

    def warn(message, **options)
      return if FILTERS.any? { |pattern| pattern.match?(message) }

      super
    end
  end
end

Warning.singleton_class.prepend(Datalog::WarningFilter) if defined?(Warning)
