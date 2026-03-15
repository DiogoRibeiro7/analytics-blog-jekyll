# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "fileutils"
require "json"
require_relative "../lib/datalog/warning_filter"
require "jekyll"
require "jekyll/commands/build"

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
      File.join(root, "_config.yml"),
      File.join(root, "_config.performance.yml")
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

  def destination_path(path)
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

SiteBuilder.build
