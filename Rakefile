# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake"

def ruby_script(path)
  sh "bundle exec ruby #{path}"
end

def node_script(path)
  sh "node #{path}"
end

def python_script(path)
  sh "python3 #{path}"
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
