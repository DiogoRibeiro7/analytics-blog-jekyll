# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "nokogiri"
require "yaml"

# schema.org/Dataset for the datasets collection. Google Dataset Search indexes
# `Dataset` and nothing else, so a dataset page described only as a `WebPage`
# could not be found there (#334).
class DatasetSchemaTest < Minitest::Test
  def test_a_dataset_page_describes_the_dataset
    dataset = dataset_schema_from(SiteBuilder.read("datasets/sample-dataset/index.html"))
    refute_nil dataset, "a dataset page should carry a Dataset block"

    assert_equal "Urban Mobility Sensor Dataset", dataset["name"]
    assert_includes dataset["description"], "multimodal transit sensor readings"
    assert_equal "https://diogoribeiro7.github.io/datasets/sample-dataset/", dataset["url"]
  end

  # The front matter names an SPDX-ish id; structured data wants the licence's
  # own address, which `page_license` already resolves for the page's footer.
  def test_the_licence_is_a_url_rather_than_an_identifier
    dataset = dataset_schema_from(SiteBuilder.read("datasets/sample-dataset/index.html"))

    assert_equal "https://creativecommons.org/licenses/by/4.0/", dataset["license"]
  end

  def test_the_field_schema_becomes_the_variables_measured
    dataset = dataset_schema_from(SiteBuilder.read("datasets/sample-dataset/index.html"))
    variables = dataset["variableMeasured"]

    assert_equal 4, variables.size
    names = variables.map { |v| v["name"] }
    assert_equal %w[timestamp station_id bike_count bus_passengers], names
    assert(variables.all? { |v| v["@type"] == "PropertyValue" })
    assert_equal "UTC timestamp of the observation", variables.first["description"]
  end

  def test_the_download_becomes_a_distribution_with_its_media_type
    dataset = dataset_schema_from(SiteBuilder.read("datasets/sample-dataset/index.html"))
    download = dataset["distribution"].first

    assert_equal "DataDownload", download["@type"]
    assert_equal "https://example.com/data/urban-mobility.zip", download["contentUrl"]
    assert_equal "application/zip", download["encodingFormat"]
  end

  # Jekyll gives a collection document without a `date:` the build time. Writing
  # that out would claim a publication date the dataset does not have, and would
  # change the page on every build.
  def test_no_publication_date_is_invented
    dataset = dataset_schema_from(SiteBuilder.read("datasets/sample-dataset/index.html"))

    refute dataset.key?("datePublished"), "a dataset with no date in its front matter should claim none"
    assert_equal "2024-05-01", dataset["dateModified"][0, 10]
  end

  # `"license": ""` is not valid structured data; an empty value is worse than
  # an absent one.
  def test_nothing_is_emitted_empty
    dataset = dataset_schema_from(SiteBuilder.read("datasets/sample-dataset/index.html"))

    assert_empty empty_paths(dataset), "every key should carry a value or be left out"
  end

  def test_pages_that_are_not_datasets_carry_no_dataset_block
    %w[index.html blog/index.html].each do |path|
      assert_nil dataset_schema_from(SiteBuilder.read(path)), "#{path} should carry no Dataset block"
    end
  end

  # The optional front matter, none of which the demo dataset uses.
  def test_the_richer_front_matter_reaches_the_output
    dataset = rich_dataset

    assert_equal "10.5281/zenodo.1234567", dataset["identifier"]["value"]
    assert_equal "https://doi.org/10.5281/zenodo.1234567", dataset["identifier"]["url"]
    assert_equal %w[mobility sensors porto], dataset["keywords"]
    assert_equal "2019-01-01/2021-12-31", dataset["temporalCoverage"]
    assert_equal "Porto, Portugal", dataset["spatialCoverage"]
    assert_equal "Inductive loop counters", dataset["measurementTechnique"]
    assert_equal false, dataset["isAccessibleForFree"]
    assert_equal "2021-06-01", dataset["datePublished"][0, 10]
  end

  def test_several_downloads_each_get_their_media_type
    downloads = rich_dataset["distribution"]

    assert_equal 3, downloads.size
    formats = downloads.map { |d| d["encodingFormat"] }
    assert_equal %w[text/csv application/vnd.apache.parquet application/x-netcdf], formats
    assert_equal "Tabular export", downloads.first["name"]
    # A relative path is made absolute, as a contentUrl has to be.
    assert_equal "https://example.test/data/readings.nc", downloads.last["contentUrl"]
  end

  def test_each_dataset_names_the_catalogue_it_belongs_to
    catalog = rich_dataset["includedInDataCatalog"]

    assert_equal "DataCatalog", catalog["@type"]
    assert_equal "https://example.test/datasets/", catalog["url"]
  end

  private

  def dataset_schema_from(html)
    Nokogiri::HTML(html)
            .css('script[type="application/ld+json"]')
            .map { |node| JSON.parse(node.text) }
            .find { |block| block["@type"] == "Dataset" }
  end

  # Every key whose value is an empty string, hash or array, as a path.
  def empty_paths(value, prefix = "")
    case value
    when Hash
      value.flat_map do |key, nested|
        path = prefix.empty? ? key : "#{prefix}.#{key}"
        nested.respond_to?(:empty?) && nested.empty? ? [path] : empty_paths(nested, path)
      end
    when Array
      value.each_with_index.flat_map { |entry, index| empty_paths(entry, "#{prefix}[#{index}]") }
    else []
    end
  end

  def rich_dataset
    self.class.rich_dataset ||= build_rich_dataset
  end

  class << self
    attr_accessor :rich_dataset
  end

  def build_rich_dataset
    front = {
      "title" => "Urban readings", "summary" => "Counts from the loop detectors.",
      "date" => "2021-06-01", "updated" => "2024-05-01", "license" => "CC-BY-4.0",
      "doi" => "10.5281/zenodo.1234567", "keywords" => %w[mobility sensors porto],
      "temporal_coverage" => "2019-01-01/2021-12-31", "spatial_coverage" => "Porto, Portugal",
      "measurement_technique" => "Inductive loop counters", "is_accessible_for_free" => false,
      "distributions" => [
        { "url" => "https://example.test/data/readings.csv", "name" => "Tabular export" },
        { "url" => "https://example.test/data/readings.parquet" },
        { "url" => "/data/readings.nc" }
      ]
    }
    site = TestSite.build(
      url: "https://example.test", title: "Example",
      collections: { "datasets" => { "output" => true, "permalink" => "/datasets/:name/" } },
      defaults: [{ "scope" => { "path" => "", "type" => "datasets" }, "values" => { "layout" => "dataset" } }]
    ) do |source|
      source.theme("_layouts", "_includes", "_data")
      source.document("datasets", "readings", "Body.", front)
    end
    dataset_schema_from(site.jekyll.collections["datasets"].docs.first.output)
  end
end
