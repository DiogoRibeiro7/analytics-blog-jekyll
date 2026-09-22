# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "fileutils"
require "json"
require_relative "../lib/datalog/warning_filter"
require "jekyll"
require "jekyll/commands/build"

# Jekyll loads a site's `_plugins/` when it builds it, and the demo site's
# source is the theme itself, so building it used to be what registered the
# theme's tags and filters for the whole process. A test that builds a site of
# its own in a temporary directory relied on that having happened, which is a
# lot to ask of a side effect. They are loaded here instead, once, plainly.
Dir[File.expand_path("../_plugins/*.rb", __dir__)].sort.each { |plugin| require plugin }

module SiteBuilder
  module_function

  def root
    @root ||= File.expand_path("..", __dir__)
  end

  def destination
    @destination ||= File.expand_path("../tmp/site", __dir__)
  end

  def build
    return if @built

    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(destination)

    ENV["JEKYLL_ENV"] = "test"
    Jekyll.logger.log_level = :error

    config_files = [
      File.join(root, "_config.yml")
    ]

    config = Jekyll.configuration(
      "source" => root,
      "destination" => destination,
      "quiet" => true,
      "config" => config_files
    )

    site = Jekyll::Site.new(config)
    site.process

    @site = site
    @payload = nil

    @built = true
  rescue StandardError => e
    warn "Jekyll build failed: #{e.message}"
    warn e.backtrace.join("\n")
    raise
  end

  # Every reader builds first. The build is memoised, so the demo site is made
  # once per process however many of the 57 files that read it run.
  def destination_path(path)
    build
    File.join(destination, path)
  end

  def read(path)
    File.read(destination_path(path))
  end

  def json(path)
    JSON.parse(read(path))
  end

  def site
    build
    @site
  end

  def payload
    build
    @payload ||= @site.site_payload
  end
end

require_relative "support/test_site"
