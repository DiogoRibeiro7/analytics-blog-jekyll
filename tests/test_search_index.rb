# frozen_string_literal: true

require_relative "test_helper"

class SearchIndexTest < Minitest::Test
  CONTENT_TYPES_WITH_BODY = %w[post dataset].freeze

  def setup
    @index = SiteBuilder.json("search.json")
  end

  def test_documents_present
    assert @index.key?("documents"), "Search index should expose a documents array"
    assert_kind_of Array, @index["documents"], "documents should be an array"
    assert_operator @index["documents"].size, :>, 0, "documents should not be empty"
  end

  # A `split: ''` in the index template turned each tag array into its string
  # form and then into single characters, so every tagged document shipped tags
  # like ["[", "\"", "m", "i", ...]. The array assertion below still passed,
  # which is why this checks the contents.
  def test_tags_are_whole_tags
    tagged = 0

    @index["documents"].each do |doc|
      tags = doc["tags"]
      assert_kind_of Array, tags, "tags facet should be an array"
      tagged += 1 unless tags.empty?

      tags.each do |tag|
        assert_kind_of String, tag, "each tag should be a string"
        refute_empty tag.strip, "tags should not contain blank entries"
        assert_match(/\A[[:alnum:]][[:alnum:]\-_. +]*\z/, tag,
                     "#{doc['url']} has #{tag.inspect}, which looks like a fragment of a serialized array rather than a tag")
      end

      assert_equal tags.size, tags.uniq.size, "tags should already be unique"
    end

    assert_operator tagged, :>, 0, "expected at least one document to carry tags"
  end

  def test_document_schema
    required_fields = %w[title url summary content type]
    always_present = %w[title url type]

    @index["documents"].each do |doc|
      required_fields.each do |field|
        value = doc[field]
        assert value, "#{field} should exist on every document"
        if always_present.include?(field)
          assert(value.is_a?(String) ? !value.strip.empty? : true,
                 "#{field} should not be blank when present")
        elsif field == "content" && CONTENT_TYPES_WITH_BODY.include?(doc["type"])
          assert(value.is_a?(String) ? !value.strip.empty? : true,
                 "#{doc['type']} entries should expose searchable content")
        end
      end
      assert_kind_of Array, doc["tags"], "tags facet should be an array"
      assert_kind_of Array, doc["math"], "math facet should be an array"
      assert_kind_of Array, doc["code"], "code facet should be an array"

      normalized = doc["normalized"]
      assert_kind_of Hash, normalized, "documents should expose precomputed normalization payload"
      %w[title summary content difficulty].each do |field|
        value = normalized[field]
        assert(value.is_a?(String), "normalized #{field} should be a string")
      end
      assert_kind_of Array, normalized["tags"], "normalized tags should be an array"
      assert_kind_of Array, normalized["languages"], "normalized languages should be an array"
    end
  end

  def test_index_captures_notebook_content
    # Require a path segment after /notebooks/ so this selects a converted
    # notebook rather than the collection listing page at /notebooks/.
    notebook_entry = @index["documents"].find { |doc| doc["url"].match?(%r{/notebooks/.+}) }
    refute_nil notebook_entry, "Search index should include converted notebooks"
    assert_match(/Exploratory Data Snapshot/, notebook_entry["title"])
    assert_includes notebook_entry["content"], "DataLog renders .ipynb files",
                    "Notebook narrative should be searchable"
  end
end
