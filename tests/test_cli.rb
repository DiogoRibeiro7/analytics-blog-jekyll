# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "pathname"

class CLITest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("..").expand_path
  BIN = ROOT.join("bin/datalog").to_s

  def test_help_lists_primary_commands
    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", BIN, "--help")

    assert status.success?, stderr
    assert_includes stdout, "datalog new post"
    assert_includes stdout, "datalog publish"
  end

  def test_version_reports_theme_version
    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", BIN, "version")

    assert status.success?, stderr
    assert_match(/DataLog theme version/, stdout)
  end

  private

  def env
    { "BUNDLE_GEMFILE" => ROOT.join("Gemfile").to_s }
  end
end
