# frozen_string_literal: true

require_relative "test_helper"

class SearchNormalizerIntegrationTest < Minitest::Test
  SEARCH_PATTERNS = %w[_plugins/**/*.rb lib/**/*.rb scripts/**/*.rb tests/**/*.rb].freeze
  TARGET_SNIPPETS = ["require 'search_normalizer'", 'require "search_normalizer"'].freeze

  def test_search_normalizer_not_manually_required
    offenders = SEARCH_PATTERNS.flat_map do |pattern|
      Dir.glob(File.join(SiteBuilder.root, pattern))
         .select { |path| File.file?(path) }
         .select { |path| contains_disallowed_require?(path) }
    end

    assert offenders.empty?, <<~MSG
      The following files manually require search_normalizer and should be updated:\n      #{offenders.join("\n  ")}
    MSG
  end

  private

  def contains_disallowed_require?(path)
    content = File.read(path)
    TARGET_SNIPPETS.any? { |snippet| content.include?(snippet) }
  end
end
