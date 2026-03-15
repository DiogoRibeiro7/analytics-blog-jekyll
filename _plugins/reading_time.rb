# frozen_string_literal: true

module Jekyll
  module ReadingTimeFilter
    WORDS_PER_MINUTE = 180.0

    def reading_time(input)
      words = input.to_s.split.size
      minutes = (words / WORDS_PER_MINUTE).ceil
      minutes.positive? ? minutes : 1
    end
  end
end

Liquid::Template.register_filter(Jekyll::ReadingTimeFilter)
