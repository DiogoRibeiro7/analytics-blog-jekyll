#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "time"
require "optparse"
require "fileutils"
require "yaml"
require_relative "script_support"

ScriptSupport.handle_errors do
  options = {
    input: "medium-export.json",
    output: "_posts",
    author: nil,
    dry_run: false
  }

  OptionParser.new do |opts|
    opts.banner = "Usage: ruby scripts/import_medium.rb [options]"

    opts.on("-i", "--input PATH", "Path to medium-export.json (required)") do |path|
      options[:input] = path
    end

    opts.on("-o", "--output DIR", "Destination directory (default: _posts)") do |dir|
      options[:output] = dir
    end

    opts.on("-a", "--author NAME", "Override author name for imported posts") do |author|
      options[:author] = author
    end

    opts.on("--dry-run", "Parse files without writing to disk") do
      options[:dry_run] = true
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  input_path = options[:input]
  raise ArgumentError, "Medium export not found at #{input_path}" unless File.file?(input_path)

  export = JSON.parse(File.read(input_path))
  posts = Array(export["posts"]).reject { |post| post["draft"] }
  raise "No posts found in the Medium export payload." if posts.empty?

  progress = ScriptSupport::ProgressBar.new(total: posts.length, label: "Medium import")
  created = 0

  posts.each do |post|
    title = post["title"] || "Untitled Medium Post"
    slug_source = post["uniqueSlug"] || post["slug"] || title
    slug = ScriptSupport.sanitize_filename(slug_source)
    created_at = post["createdAt"] || post["updatedAt"] || Time.now.iso8601
    date = Time.parse(created_at)
    tags = Array(post["tags"]).map { |t| t.to_s.downcase } + Array(post["topics"]).map(&:to_s)
    canonical_url = post["canonicalUrl"] || post["url"]

    front_matter = {
      "layout" => "post",
      "title" => title,
      "date" => date.iso8601,
      "tags" => tags.uniq.compact,
      "canonical_url" => canonical_url,
      "medium_id" => post["id"],
      "author" => options[:author] || post.dig("creator", "name")
    }.compact.reject { |_, value| value.respond_to?(:empty?) && value.empty? }

    content = post["content"] || post["content:encoded"] || post["body"] || ""
    content = content.strip

    filename = File.join(options[:output], format("%<date>s-%<slug>s.md", date: date.strftime("%Y-%m-%d"), slug: slug))

    unless options[:dry_run]
      yaml = front_matter.to_yaml.sub(/\A---\s*\n?/, "").strip
      ScriptSupport.write_file(filename, <<~MARKDOWN)
        ---
        #{yaml}
        ---

        #{content}
      MARKDOWN
    end

    created += 1
    progress.advance(message: "#{created} imported")
  end

  puts "\nImported #{created} Medium posts into #{options[:output]}" unless options[:dry_run]
  puts '\nDry run complete. No files were written.' if options[:dry_run]
end
