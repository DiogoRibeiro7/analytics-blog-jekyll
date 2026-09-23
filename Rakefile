# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake"

# The Minitest suite builds the demo site once and checks what it produced. It
# replaces `rake ci:verify`, whose scripts mostly checked that source files
# contained particular strings.
desc "Build the demo site and run the Minitest suite, as the Tests workflow does"
task :test do
  ruby "-Itests", "-e", "Dir['tests/test_*.rb'].sort.each { |file| require_relative file }"
end

# Roughly three times the runtime of `rake test`, which is why it is a task of
# its own rather than the default. See .simplecov for what it measures and the
# thresholds it holds the suite to.
desc "Run the Minitest suite under SimpleCov and enforce the coverage thresholds"
task :coverage do
  ENV["COVERAGE"] = "1"
  Rake::Task[:test].invoke
end

task default: :test
