# frozen_string_literal: true

require_relative "test_helper"

class PublicationsGeneratorTest < Minitest::Test
  def setup
    @site = SiteBuilder.site
    @publications = @site.data["publications"]
    @generator = Jekyll::PublicationsGenerator.new
  end

  def test_publications_data_available
    refute_nil @publications, "site.data['publications'] should exist"
    assert_kind_of Hash, @publications
  end

  def test_entries_present
    entries = @publications["entries"]
    refute_nil entries, "publications should have entries"
    assert_kind_of Array, entries
    refute_empty entries, "entries should not be empty"
  end

  def test_entries_have_expected_keys
    entries = @publications["entries"]
    refute_empty entries

    entries.each do |entry|
      assert entry.key?("title"), "Each entry should have a title"
      assert entry.key?("year"), "Each entry should have a year"
      assert entry.key?("authors"), "Each entry should have authors"
    end
  end

  def test_imported_entries_from_bibtex
    imported = @publications["imported"]
    refute_nil imported, "publications should have imported entries"
    assert_kind_of Array, imported
    refute_empty imported, "imported entries should not be empty when bibtex source exists"
  end

  def test_imported_entry_has_expected_fields
    imported = @publications["imported"]
    refute_empty imported

    entry = imported.first
    assert entry["title"], "imported entry should have a title"
    assert entry["authors"], "imported entry should have authors"
    assert_kind_of Array, entry["authors"], "authors should be an array"
    assert entry["year"], "imported entry should have a year"
    assert entry["id"], "imported entry should have an id"
    assert entry["type"], "imported entry should have a type"
  end

  def test_parse_bibtex_entries_extracts_fields
    bibtex = <<~BIB
      @article{smith2023ml,
        title = {Machine Learning for Climate Science},
        author = {Smith, John and Doe, Jane},
        journal = {Nature Analytics},
        year = {2023},
        doi = {10.1234/test.2023.001}
      }
    BIB

    entries = @generator.send(:parse_bibtex_entries, bibtex)
    assert_equal 1, entries.size

    entry = entries.first
    assert_equal "smith2023ml", entry["id"]
    assert_equal "article", entry["type"]
    assert_equal "Machine Learning for Climate Science", entry["title"]
    assert_equal ["Smith, John", "Doe, Jane"], entry["authors"]
    assert_equal "Nature Analytics", entry["venue"]
    assert_equal "2023", entry["year"]
    assert_equal "10.1234/test.2023.001", entry["doi"]
  end

  def test_parse_bibtex_entries_handles_multiple_entries
    bibtex = <<~BIB
      @article{first2023,
        title = {First Paper},
        author = {Alpha, A.},
        journal = {Journal One},
        year = {2023}
      }

      @inproceedings{second2022,
        title = {Second Paper},
        author = {Beta, B. and Gamma, C.},
        booktitle = {Conference Two},
        year = {2022}
      }
    BIB

    entries = @generator.send(:parse_bibtex_entries, bibtex)
    assert_equal 2, entries.size
    assert_equal "first2023", entries[0]["id"]
    assert_equal "second2022", entries[1]["id"]
  end

  def test_parse_bibtex_entries_uses_booktitle_as_venue
    bibtex = <<~BIB
      @inproceedings{conf2023,
        title = {Conference Paper},
        author = {Author, A.},
        booktitle = {ICML 2023},
        year = {2023}
      }
    BIB

    entries = @generator.send(:parse_bibtex_entries, bibtex)
    assert_equal "ICML 2023", entries.first["venue"]
  end

  def test_parse_bibtex_entries_uses_institution_as_venue
    bibtex = <<~BIB
      @techreport{report2022,
        title = {Technical Report},
        author = {Author, A.},
        institution = {MIT},
        year = {2022}
      }
    BIB

    entries = @generator.send(:parse_bibtex_entries, bibtex)
    assert_equal "MIT", entries.first["venue"]
  end

  def test_normalize_entry_converts_keys_to_strings
    entry = { title: "Test", year: 2023, authors: "Alpha and Beta" }
    normalized = @generator.send(:normalize_entry, entry)

    assert_equal "Test", normalized["title"]
    assert_equal "2023", normalized["year"]
    assert_kind_of Array, normalized["authors"]
    assert_equal ["Alpha", "Beta"], normalized["authors"]
  end

  def test_normalize_entry_preserves_array_authors
    entry = { "title" => "Test", "authors" => ["A", "B"] }
    normalized = @generator.send(:normalize_entry, entry)

    assert_equal ["A", "B"], normalized["authors"]
  end

  def test_normalize_entry_converts_year_to_string
    entry = { "title" => "Test", "year" => 2024 }
    normalized = @generator.send(:normalize_entry, entry)

    assert_equal "2024", normalized["year"]
  end

  def test_sort_order_descending
    entries = @publications["entries"]
    refute_empty entries

    years = entries.map { |e| e["year"].to_i }
    # With descending sort, years should be non-increasing (allowing equal years)
    years.each_cons(2) do |a, b|
      assert_operator a, :>=, b,
                       "Entries should be sorted in descending year order, got #{a} before #{b}"
    end
  end

  def test_sort_order_ascending
    entries_asc = @publications["entries"].dup
    entries_asc.sort_by! { |e| [e["year"].to_i, e["title"].to_s.downcase] }

    years = entries_asc.map { |e| e["year"].to_i }
    years.each_cons(2) do |a, b|
      assert_operator a, :<=, b,
                       "Ascending sorted entries should have non-decreasing years"
    end
  end

  def test_grouped_data_present
    grouped = @publications["grouped"]
    refute_nil grouped, "publications should have grouped data when group_by is set"
  end

  def test_manual_entry_included_in_entries
    entries = @publications["entries"]
    manual = entries.find { |e| e["id"] == "datalog2024" }
    refute_nil manual, "manual entry 'datalog2024' should be in combined entries"
    assert_equal "Reproducible Energy Demand Forecasting", manual["title"]
    assert_includes manual["authors"], "Diogo Ribeiro"
  end

  def test_bibtex_entry_included_in_entries
    entries = @publications["entries"]
    bibtex_entry = entries.find { |e| e["id"] == "ribeiro2024interpretable" }
    refute_nil bibtex_entry, "BibTeX entry 'ribeiro2024interpretable' should be in combined entries"
    assert_equal "Interpretable Bayesian Forecasting for Distributed Energy Resources", bibtex_entry["title"]
  end

  def test_metrics_computed
    metrics = @publications["metrics"]
    refute_nil metrics, "publications should have metrics"
    assert metrics.key?("total"), "metrics should have total"
    assert metrics.key?("h_index"), "metrics should have h_index"
    assert metrics.key?("i10_index"), "metrics should have i10_index"
  end

  def test_parse_bibtex_handles_empty_input
    entries = @generator.send(:parse_bibtex_entries, "")
    assert_empty entries

    entries = @generator.send(:parse_bibtex_entries, nil)
    assert_empty entries
  end
end
