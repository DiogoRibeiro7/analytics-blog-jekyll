# frozen_string_literal: true

# What the Minitest suite reaches in the theme's Ruby: the plugins Jekyll loads
# for a site and the library the gem and the CLI are built from. Loaded by
# `tests/test_helper.rb` when COVERAGE is set, so an ordinary `rake test` stays
# as quick as it was (#368).
require "simplecov_json_formatter"

SimpleCov.start do
  enable_coverage :branch

  # The HTML report to read, and the JSON one Codecov reads. The JSON
  # formatter ships with simplecov, so neither costs another dependency.
  formatter SimpleCov::Formatter::MultiFormatter.new(
    [SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::JSONFormatter]
  )

  # Everything, not only what a test happened to load: a plugin with no test at
  # all should read 0%, not be missing from the report.
  track_files "{lib,_plugins}/**/*.rb"

  add_filter "/tests/"
  add_filter "/tmp/"
  add_filter "/vendor/"
  add_filter "/docs/"
  add_filter "/node_modules/"

  # `bundle exec` puts -rbundler/setup in RUBYOPT, so Bundler evaluates
  # datalog-theme.gemspec at interpreter startup — before any of this runs. The
  # gemspec requires both of these, and Ruby's Coverage cannot see a file
  # loaded before it starts, so they would read 0% however well they are
  # exercised. They are, end to end: tests/test_gem_package.rb asserts what the
  # gemspec's file list produces, which is all `theme_file?` does.
  add_filter "lib/datalog/theme/package.rb"
  add_filter "lib/datalog/theme/version.rb"

  add_group "Plugins", "_plugins"
  add_group "Library", "lib"
  add_group "CLI", "lib/datalog/cli"

  # Measured on 2026-09-23 at 84.5% lines and 62.7% branches, over 581 tests,
  # with the consumer build's own results merged in. A few points below that,
  # as vitest.config.js sets its own: enough to catch a regression, not so
  # tight that an ordinary change trips it.
  #
  # They are written for the whole suite, so `COVERAGE=1` on a single file
  # fails them by design. `bundle exec rake coverage` is the way in.
  minimum_coverage line: 81, branch: 59
end
