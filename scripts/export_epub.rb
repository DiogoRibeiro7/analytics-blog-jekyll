#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "tmpdir"
require "pathname"
require "shellwords"
require_relative "script_support"

ScriptSupport.handle_errors do
  options = {
    output: "export/site.epub",
    build_dir: "_site",
    build: true,
    config: nil,
    title: "DataLog Export",
    author: "DataLog"
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/export_epub.rb [options]"

    opts.on("-o", "--output FILE", "Output EPUB path (default: export/site.epub)") do |path|
      options[:output] = path
    end

    opts.on("-d", "--build-dir DIR", "Jekyll build directory (default: _site)") do |dir|
      options[:build_dir] = dir
    end

    opts.on("--[no-]build", "Trigger `bundle exec jekyll build` before exporting (default: true)") do |value|
      options[:build] = value
    end

    opts.on("-c", "--config FILE", "Additional config file for the build step") do |config|
      options[:config] = config
    end

    opts.on("--title TITLE", "Title metadata for the EPUB (default: DataLog Export)") do |title|
      options[:title] = title
    end

    opts.on("--author NAME", "Author metadata for the EPUB (default: DataLog)") do |author|
      options[:author] = author
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  unless ScriptSupport.command_available?("pandoc")
    raise "Pandoc is required to export EPUB files. Please install pandoc."
  end

  build_dir = Pathname.new(options[:build_dir])
  total_steps = 1

  if options[:build]
    total_steps += 1
    build_command = ["bundle exec jekyll build"]
    build_command << "--destination #{build_dir}"
    build_command << "--config #{options[:config]}" if options[:config]
    ScriptSupport.run_command(build_command.join(" "), error_message: "Jekyll build failed before EPUB export.")
  end

  html_files = if build_dir.directory?
                 build_dir.glob("**/*.html").sort
               else
                 []
               end

  raise "No HTML files found in #{build_dir}. Did you build the site?" if html_files.empty?

  total_steps += html_files.length
  progress = ScriptSupport::ProgressBar.new(total: total_steps, label: "EPUB export")

  progress.advance(message: "Site built") if options[:build]

  Dir.mktmpdir("datalog-epub") do |tmpdir|
    combined_path = File.join(tmpdir, "book.html")
    ScriptSupport.write_file(combined_path, html_files.map do |path|
      progress.advance(message: path.basename.to_s)
      path.read
    end.join("\n\n"))

    ScriptSupport.ensure_path(options[:output])

    command = [
      "pandoc",
      Shellwords.escape(combined_path),
      "--metadata",
      "title=#{Shellwords.escape(options[:title])}",
      "--metadata",
      "creator=#{Shellwords.escape(options[:author])}",
      "-o",
      Shellwords.escape(options[:output])
    ].join(" ")

    ScriptSupport.run_command(command, error_message: "Pandoc failed to produce the EPUB file.")
  end

  progress.advance(message: "EPUB created")
  puts "\nExported site to #{options[:output]}"
end
