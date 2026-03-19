# frozen_string_literal: true

begin
  require "unicode_normalize"
  UNICODE_NORMALIZE_SUPPORTED = true
rescue LoadError
  UNICODE_NORMALIZE_SUPPORTED = false
  warn "[search_normalizer] unicode_normalize gem not available; falling back to basic normalization"
end

module Datalog
  module SearchFilters
    module_function

    def normalize_search(input)
      value = input.to_s
      return "" if value.empty?

      normalized = if UNICODE_NORMALIZE_SUPPORTED && value.respond_to?(:unicode_normalize)
                     value.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "")
                   else
                     transliterate(value)
                   end

      normalized.downcase.strip
    rescue StandardError
      input.to_s.downcase
    end

    def transliterate(value)
      value.encode("ASCII", fallback: lambda { |char|
        approximate_character(char)
      }, invalid: :replace, undef: :replace, replace: "")
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      value
    end

    def approximate_character(char)
      @transliteration_map ||= build_transliteration_map
      @transliteration_map.fetch(char, "")
    end

    def build_transliteration_map
      basic_map = {}

      accents = {
        "ÀÁÂÃÄÅàáâãäå" => "a",
        "ÈÉÊËèéêë" => "e",
        "ÌÍÎÏìíîï" => "i",
        "ÒÓÔÕÖØòóôõöø" => "o",
        "ÙÚÛÜùúûü" => "u",
        "Çç" => "c",
        "Ññ" => "n",
        "Ýýÿ" => "y",
        "Ææ" => "ae",
        "Œœ" => "oe"
      }

      accents.each do |chars, replacement|
        chars.each_char { |char| basic_map[char] = replacement }
      end

      basic_map
    end

    def normalize_search_array(values)
      Array(values)
        .map { |value| normalize_search(value) }
        .reject(&:empty?)
    end
  end
end

Liquid::Template.register_filter(Datalog::SearchFilters)
