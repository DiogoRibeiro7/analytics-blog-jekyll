#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require "yaml"
require "time"
require "pathname"
require_relative "script_support"

ScriptSupport.handle_errors do
  options = {
    input: "notion-export",
    output: "_posts",
    layout: "post",
    dry_run: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/import_notion.rb [options]"

    opts.on("-i", "--input DIR", "Path to unzipped Notion Markdown export (required)") do |dir|
      options[:input] = dir
    end

    opts.on("-o", "--output DIR", "Destination directory (default: _posts)") do |dir|
      options[:output] = dir
    end

    opts.on("-l", "--layout LAYOUT", "Front matter layout (default: post)") do |layout|
      options[:layout] = layout
    end

    opts.on("--dry-run", "Parse files without writing to disk") do
      options[:dry_run] = true
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  input_dir = Pathname.new(options[:input])
  raise ArgumentError, "Notion export directory not found: #{input_dir}" unless input_dir.directory?

  markdown_files = input_dir.glob("**/*.md")
  raise "No Markdown files were found in the Notion export." if markdown_files.empty?

  progress = ScriptSupport::ProgressBar.new(total: markdown_files.length, label: "Notion import")

  markdown_files.each_with_index do |path, index|
    contents = path.read
    heading = contents.lines.find { |line| line.start_with?("#") }&.gsub("#", "")&.strip
    title = heading || path.basename.sub_ext("").to_s.tr("_", " ").split.map(&:capitalize).join(" ")
    slug = ScriptSupport.sanitize_filename(path.basename.sub_ext("").to_s)
    date = Time.at(path.mtime.to_i)

    body = contents.sub(/^#.+\n+/, "").strip

    front_matter = {
      "layout" => options[:layout],
      "title" => title,
      "date" => date.iso8601,
      "notion_source" => path.relative_path_from(input_dir).to_s
    }

    filename = File.join(options[:output], format("%<date>s-%<slug>s.md", date: date.strftime("%Y-%m-%d"), slug: slug))

    unless options[:dry_run]
      yaml = front_matter.to_yaml.sub(/\A---\s*\n?/, "").strip
      ScriptSupport.write_file(filename, <<~MARKDOWN)
        ---
        #{yaml}
        ---

        #{body}
      MARKDOWN
    end

    progress.advance(message: "#{index + 1} imported")
  end

  puts "\nImported #{markdown_files.length} Notion pages into #{options[:output]}" unless options[:dry_run]
  puts '\nDry run complete. No files were written.' if options[:dry_run]
end
