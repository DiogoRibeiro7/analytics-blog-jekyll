#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "open3"
require "shellwords"
require "time"
require_relative "script_support"

ScriptSupport.handle_errors do
  options = {
    remote: "origin",
    branch: nil,
    message: "Automated backup: #{Time.now.utc.iso8601}",
    force: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/backup_to_git.rb [options]"

    opts.on("-r", "--remote NAME", "Remote name to push to (default: origin)") do |remote|
      options[:remote] = remote
    end

    opts.on("-b", "--branch NAME", "Target branch (default: current branch)") do |branch|
      options[:branch] = branch
    end

    opts.on("-m", "--message MSG", "Commit message (default includes timestamp)") do |message|
      options[:message] = message
    end

    opts.on("--force", "Force push the backup (use with caution)") do
      options[:force] = true
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  def run_git(command, error_message: nil)
    stdout, stderr, status = Open3.capture3(command)
    return stdout if status.success?

    raise(error_message || "Git command failed: #{command}\n#{stderr}")
  end

  run_git("git rev-parse --is-inside-work-tree", error_message: "This directory is not a Git repository.")

  current_branch = options[:branch] || run_git("git rev-parse --abbrev-ref HEAD").strip
  raise "Could not determine the target branch." if current_branch.empty?

  status_output = run_git("git status --porcelain")
  steps = 1 # push step
  steps += 1 unless status_output.strip.empty?

  progress = ScriptSupport::ProgressBar.new(total: steps, label: "Git backup")

  unless status_output.strip.empty?
    run_git("git add -A", error_message: "Failed to stage changes for backup.")
    run_git("git commit -m #{Shellwords.escape(options[:message])}", error_message: "Commit failed for backup run.")
    progress.advance(message: "Changes committed")
  end

  push_command = ["git", "push", options[:remote], current_branch]
  push_command << "--force" if options[:force]
  run_git(push_command.join(" "), error_message: "Push failed during backup.")
  progress.advance(message: "Pushed to remote")

  puts "\nBackup complete on #{options[:remote]}/#{current_branch}"
end
