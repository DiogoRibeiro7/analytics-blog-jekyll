#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'rexml/document'
require 'time'
require 'yaml'
require_relative 'script_support'

ScriptSupport.handle_errors do
  options = {
    input: 'wordpress.xml',
    output: '_posts',
    categories_as_tags: true,
    status: 'publish',
    dry_run: false
  }

  OptionParser.new do |opts|
    opts.banner = 'Usage: ruby scripts/import_wordpress.rb [options]'

    opts.on('-i', '--input PATH', 'Path to WordPress WXR export (required)') do |path|
      options[:input] = path
    end

    opts.on('-o', '--output DIR', 'Destination directory (default: _posts)') do |dir|
      options[:output] = dir
    end

    opts.on('--[no-]categories-as-tags', 'Convert categories to tags (default: true)') do |value|
      options[:categories_as_tags] = value
    end

    opts.on('--status STATUS', 'Only import posts with matching status (default: publish)') do |status|
      options[:status] = status
    end

    opts.on('--dry-run', 'Parse files without writing to disk') do
      options[:dry_run] = true
    end

    opts.on('-h', '--help', 'Show this help message') do
      puts opts
      exit
    end
  end.parse!

  input_path = options[:input]
  raise ArgumentError, "WordPress export not found at #{input_path}" unless File.file?(input_path)

  xml = File.read(input_path)
  document = REXML::Document.new(xml)
  items = []

  document.elements.each('rss/channel/item') do |item|
    post_type = item.get_text('wp:post_type')&.value
    next unless post_type == 'post'

    status = item.get_text('wp:status')&.value
    next if options[:status] && status != options[:status]

    title = item.get_text('title')&.value || 'Untitled WordPress Post'
    slug_source = item.get_text('wp:post_name')&.value || title
    slug = ScriptSupport.sanitize_filename(slug_source)
    created_at = item.get_text('wp:post_date_gmt')&.value || item.get_text('wp:post_date')&.value
    date = Time.parse(created_at.to_s.empty? ? Time.now.iso8601 : created_at)

    categories = []
    tags = []

    item.elements.each('category') do |category|
      domain = category.attributes['domain']
      value = category.texts.join.strip
      next if value.empty?

      case domain
      when 'category'
        if options[:categories_as_tags]
          tags << value
        else
          categories << value
        end
      when 'post_tag'
        tags << value
      end
    end

    content = item.get_text('content:encoded')&.value.to_s.strip

    front_matter = {
      'layout' => 'post',
      'title' => title,
      'date' => date.iso8601,
      'tags' => tags.uniq,
      'categories' => categories.uniq,
      'wordpress_id' => item.get_text('wp:post_id')&.value,
      'status' => status
    }.delete_if { |_, v| Array(v).empty? }

    filename = File.join(options[:output], format('%<date>s-%<slug>s.md', date: date.strftime('%Y-%m-%d'), slug: slug))

    items << [filename, front_matter, content]
  end

  raise 'No WordPress posts matched the provided filters.' if items.empty?

  progress = ScriptSupport::ProgressBar.new(total: items.length, label: 'WordPress import')

  items.each_with_index do |(filename, front_matter, content), index|
    unless options[:dry_run]
      yaml = front_matter.to_yaml.sub(/\A---\s*\n?/, '').strip
      ScriptSupport.write_file(filename, <<~MARKDOWN)
        ---
        #{yaml}
        ---

        #{content}
      MARKDOWN
    end

    progress.advance(message: "#{index + 1} imported")
  end

  puts "\nImported #{items.length} WordPress posts into #{options[:output]}" unless options[:dry_run]
  puts '\nDry run complete. No files were written.' if options[:dry_run]
end
