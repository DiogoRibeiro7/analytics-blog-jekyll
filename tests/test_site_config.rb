# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../lib/datalog/site_config"
require_relative "../lib/datalog/cli"

# The CLI's commands read _config.yml the way Jekyll does: a date, a time or
# an alias that Jekyll builds with must not stop them. `datalog update`'s
# loader permitted no dates and failed after moving the theme checkout; all
# three commands failed on an alias.
class SiteConfigTest < Minitest::Test
  CONFIG = <<~YAML
    title: Notes
    launched: 2024-01-01
    stamp: 2024-01-01 10:00:00 +0000
    defaults_shared: &post
      layout: post
    defaults:
      - scope: { path: "" }
        values: *post
  YAML

  def with_config(text)
    Dir.mktmpdir("datalog-site-config") do |dir|
      File.write(File.join(dir, "_config.yml"), text) if text
      yield dir, File.join(dir, "_config.yml")
    end
  end

  def test_reads_dates_times_and_aliases_as_jekyll_does
    with_config(CONFIG) do |_dir, path|
      config = Datalog::SiteConfig.load(path)

      assert_equal Date.new(2024, 1, 1), config["launched"]
      assert_kind_of Time, config["stamp"]
      assert_equal({ "layout" => "post" }, config["defaults"].first["values"])
    end
  end

  def test_a_missing_or_empty_file_is_no_settings_and_a_broken_one_still_says_so
    with_config(nil) { |_dir, path| assert_equal({}, Datalog::SiteConfig.load(path)) }
    with_config("") { |_dir, path| assert_equal({}, Datalog::SiteConfig.load(path)) }
    with_config("title: [unclosed\n") do |_dir, path|
      assert_raises(Psych::SyntaxError) { Datalog::SiteConfig.load(path) }
    end
  end

  def test_datalog_check_reads_such_a_configuration
    with_config(CONFIG) do |dir, _path|
      assert_equal %i[collections url], Datalog::CLI.new.send(:configuration_warnings, dir)
    end
  end
end
