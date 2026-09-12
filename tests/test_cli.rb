# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "pathname"
require "rbconfig"

require_relative "../lib/datalog/cli"

class CLITest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("..").expand_path
  BIN = ROOT.join("bin/datalog").to_s
  # The binstub relies on its shebang, which Windows does not honour, so name
  # the interpreter explicitly: `bundle exec bin/datalog` fails there with
  # "command not found".
  RUBY = RbConfig.ruby

  def test_help_lists_primary_commands
    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", RUBY, BIN, "--help")

    assert status.success?, stderr
    assert_includes stdout, "datalog new post"
    assert_includes stdout, "datalog publish"
  end

  def test_version_reports_theme_version
    stdout, stderr, status = Open3.capture3(env, "bundle", "exec", RUBY, BIN, "version")

    assert status.success?, stderr
    assert_match(/DataLog theme version/, stdout)
  end

  def test_dependency_probe_finds_the_running_interpreter
    cli = Datalog::CLI.new

    assert cli.send(:command_available?, "ruby"),
           "Expected the dependency check to find ruby on PATH"
    refute cli.send(:command_available?, "datalog-no-such-command"),
           "Expected the dependency check to reject a command that does not exist"
  end

  private

  def env
    { "BUNDLE_GEMFILE" => ROOT.join("Gemfile").to_s }
  end
end
