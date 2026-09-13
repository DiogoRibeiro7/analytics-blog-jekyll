# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "pathname"
require "rbconfig"
require "tmpdir"
require "yaml"

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

  # Without JEKYLL_ENV the published site left out the analytics tag and
  # shipped the development CSP logger.
  def test_publish_builds_for_production
    cli = Datalog::CLI.new
    calls = []
    cli.define_singleton_method(:system) do |*args, **_options|
      calls << args
      args.include?("rev-parse")
    end

    assert_raises(SystemExit) { capture_io { cli.publish } }

    build = calls.find { |args| args.last == "bundle exec jekyll build" }
    refute_nil build, "publish should run the Jekyll build"
    assert_equal "production", build.first["JEKYLL_ENV"]
  end

  # The exit status of commit and push used to be ignored, so a rejected push
  # still ended as a successful publish.
  def test_publish_does_not_count_a_failed_push_as_published
    Dir.mktmpdir do |dir|
      with_env(git_identity) do
        capture_subprocess_io do
          system("git", "init", "-q", dir)
          File.write(File.join(dir, "index.html"), "<p>site</p>")
          refute Datalog::CLI.new.send(:commit_and_push, dir, "gh-pages", "Publish"),
                 "a push to a remote that does not exist should not count as published"
        end
      end
    end
  end

  # A title with a double quote, or a tag with a colon, used to produce front
  # matter that did not parse.
  def test_new_post_front_matter_survives_quotes_and_colons
    Dir.mktmpdir do |dir|
      cli = Datalog::CLI::New.new([], { root: dir, title: 'Say "hello": a guide', date: "2024-01-02",
                                        tags: ["theme: dark"], difficulty: "easy" })
      cli.define_singleton_method(:ask) { |*_args| "" }
      capture_io { cli.post }

      post = Dir[File.join(dir, "_posts", "*.md")].first
      refute_nil post, "expected the scaffolded post"
      front_matter = YAML.safe_load(File.read(post)[/\A---\n(.*?)\n---\n/m, 1], permitted_classes: [Date])
      assert_equal 'Say "hello": a guide', front_matter["title"]
      assert_equal ["theme: dark"], front_matter["tags"]
    end
  end

  private

  def env
    { "BUNDLE_GEMFILE" => ROOT.join("Gemfile").to_s }
  end

  def git_identity
    {
      "GIT_AUTHOR_NAME" => "DataLog Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
      "GIT_COMMITTER_NAME" => "DataLog Test", "GIT_COMMITTER_EMAIL" => "test@example.com"
    }
  end

  def with_env(values)
    saved = values.keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    begin
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      saved.each { |key, value| ENV[key] = value }
    end
  end
end
