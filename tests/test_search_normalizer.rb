# frozen_string_literal: true

require_relative "test_helper"

class SearchNormalizerIntegrationTest < Minitest::Test
  SEARCH_PATTERNS = %w[_plugins/**/*.rb lib/**/*.rb scripts/**/*.rb tests/**/*.rb].freeze
  # These snippets appear verbatim below, so this file always matches its own
  # scan and is skipped explicitly.
  TARGET_SNIPPETS = ["require 'search_normalizer'", 'require "search_normalizer"'].freeze

  def test_search_normalizer_not_manually_required
    offenders = SEARCH_PATTERNS.flat_map do |pattern|
      Dir.glob(File.join(SiteBuilder.root, pattern))
         .select { |path| File.file?(path) }
         .reject { |path| File.identical?(path, __FILE__) }
         .select { |path| contains_disallowed_require?(path) }
    end

    assert offenders.empty?, <<~MSG
      The following files manually require search_normalizer and should be updated:\n      #{offenders.join("\n  ")}
    MSG
  end

  # The index used to keep only ASCII: the plugin required unicode_normalize
  # as if it were a gem, failed, and dropped every other character.
  def test_keeps_letters_outside_ascii_and_strips_accents
    assert_equal "cafe straße łodz naive привет",
                 Datalog::SearchFilters.normalize_search("Café Straße Łódź naïve Привет")
  end

  def test_drops_invalid_bytes_instead_of_failing
    assert_equal "caf x", Datalog::SearchFilters.normalize_search("Caf\xC3 X".dup.force_encoding("UTF-8"))
  end

  def test_indexes_text_in_other_encodings_as_it_is
    assert_equal "cafe", Datalog::SearchFilters.normalize_search("CAFE".encode("ISO-8859-1"))
  end

  private

  def contains_disallowed_require?(path)
    content = File.read(path)
    TARGET_SNIPPETS.any? { |snippet| content.include?(snippet) }
  end
end
