#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "tmpdir"
require "pathname"
require "shellwords"
require_relative "script_support"

ScriptSupport.handle_errors do
  options = {
    output: "export/site.pdf",
    build_dir: "_site",
    build: true,
    config: nil
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/export_pdf.rb [options]"

    opts.on("-o", "--output FILE", "Output PDF path (default: export/site.pdf)") do |path|
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

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  unless ScriptSupport.command_available?("pandoc") || ScriptSupport.command_available?("wkhtmltopdf")
    raise "Neither pandoc nor wkhtmltopdf is available. Please install one of them to export PDFs."
  end

  build_dir = Pathname.new(options[:build_dir])
  total_steps = 1 # for conversion step later

  if options[:build]
    total_steps += 1
    build_command = ["bundle exec jekyll build"]
    build_command << "--destination #{build_dir}"
    build_command << "--config #{options[:config]}" if options[:config]
    ScriptSupport.run_command(build_command.join(" "), error_message: "Jekyll build failed before PDF export.")
  end

  html_files = if build_dir.directory?
                 build_dir.glob("**/*.html").sort
               else
                 []
               end

  raise "No HTML files found in #{build_dir}. Did you build the site?" if html_files.empty?

  total_steps += html_files.length
  progress = ScriptSupport::ProgressBar.new(total: total_steps, label: "PDF export")

  progress.advance(message: "Site built") if options[:build]

  Dir.mktmpdir("datalog-pdf") do |tmpdir|
    combined_path = File.join(tmpdir, "book.html")
    ScriptSupport.write_file(combined_path, html_files.map do |path|
      progress.advance(message: path.basename.to_s)
      path.read
    end.join("\n\n"))

    ScriptSupport.ensure_path(options[:output])

    if ScriptSupport.command_available?("pandoc")
      command = [
        "pandoc",
        Shellwords.escape(combined_path),
        "-o",
        Shellwords.escape(options[:output])
      ].join(" ")
      ScriptSupport.run_command(command, error_message: "Pandoc failed to produce the PDF.")
    else
      command = [
        "wkhtmltopdf",
        Shellwords.escape(combined_path),
        Shellwords.escape(options[:output])
      ].join(" ")
      ScriptSupport.run_command(command, error_message: "wkhtmltopdf failed to produce the PDF.")
    end
  end

  progress.advance(message: "PDF created")
  puts "\nExported site to #{options[:output]}"
end
