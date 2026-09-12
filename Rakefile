# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake"

def ruby_script(path)
  sh "bundle exec ruby #{path}"
end

def node_script(path)
  sh "node #{path}"
end

# Windows has no `python3` executable: the interpreter is `python`, and the
# `python3` name resolves to a Microsoft Store stub that only prints an error.
PYTHON_COMMANDS = %w[python3 python py].freeze

def python_command
  @python_command ||= PYTHON_COMMANDS.find { |command| python_usable?(command) } ||
                      abort("No Python interpreter found (tried #{PYTHON_COMMANDS.join(', ')}).")
end

def python_usable?(command)
  system(command, "--version", out: File::NULL, err: File::NULL)
rescue Errno::ENOENT
  false
end

def python_script(path)
  sh python_command, path
end

namespace :ci do
  desc "Run documentation-friendly verification suite"
  task :verify do
    Rake::Task["ci:cross_platform"].invoke
  end

  desc "Run comprehensive cross-platform safe checks"
  task :cross_platform do
    ruby_script "scripts/test_math_rendering.rb"
    ruby_script "scripts/test_code_syntax.rb"
    ruby_script "scripts/test_performance.rb"
    ruby_script "scripts/test_accessibility.rb"
    ruby_script "scripts/test_responsiveness.rb"
    ruby_script "scripts/test_citations.rb"
    ruby_script "scripts/test_integrations.rb"
    ruby_script "scripts/test_collaboration_workflows.rb"
    ruby_script "scripts/test_security.rb"
    node_script "scripts/test_search.js"
    node_script "scripts/verify_interactive_elements.js"
    python_script "scripts/notebook_validation.py"
  end
end

desc "Default task"
task default: "ci:verify"
