# frozen_string_literal: true

require "fastimage"
require "nokogiri"
require "tempfile"
require "English"
require "fileutils"
require "json"

begin
  require "mini_magick"
rescue LoadError
  MiniMagick = nil
end

module Jekyll
  module ImageOptimizer
    module_function

    DEFAULT_SIZES = [320, 640, 960, 1_280, 1_920].freeze
    DEFAULT_QUALITY = {
      "avif" => 45,
      "webp" => 75,
      "jpeg" => 85,
      "jpg" => 85,
      "png" => 85
    }.freeze
    MIME_TYPES = {
      "avif" => "image/avif",
      "webp" => "image/webp",
      "jpeg" => "image/jpeg",
      "jpg" => "image/jpeg",
      "png" => "image/png"
    }.freeze
    RASTER_EXTENSIONS = %w[.jpg .jpeg .png].freeze

    def process(document)
      return unless document.output_ext == ".html"
      return if document.output.nil? || document.output.empty?

      full_document = document.output.lstrip.match?(/\A(?:<!DOCTYPE|<html)/i)
      fragment = full_document ? Nokogiri::HTML5::Document.parse(document.output) : Nokogiri::HTML::DocumentFragment.parse(document.output)
      return if fragment.nil?

      site = document.respond_to?(:site) ? document.site : nil
      manifest = site&.data&.fetch("datalog_responsive_images", {}) || {}
      image_config = site&.config&.fetch("datalog_image_config", {}) || {}
      optimized = false
      first_priority_assigned = false

      fragment.css("img").each do |img|
        next if img["data-no-optimize"] == "true"

        img["loading"] ||= "lazy"
        img["decoding"] ||= "async"

        unless first_priority_assigned
          img["fetchpriority"] ||= "high"
          first_priority_assigned = true
        end

        normalized_src = normalize_src(img["src"], site)
        picture_entry = manifest[normalized_src]

        if picture_entry
          fallback_variants = picture_entry.dig("fallback", "variants") || []
          img["srcset"] = build_srcset(fallback_variants) unless img["srcset"]
          img["sizes"] ||= image_config.fetch("default_sizes", "100vw")
          img["width"] ||= picture_entry["width"].to_s if picture_entry["width"]
          img["height"] ||= picture_entry["height"].to_s if picture_entry["height"]
        else
          next if img["width"] && img["height"]

          source = image_source_path(site, img["src"])
          next unless source && File.exist?(source)

          width, height = FastImage.size(source)
          next unless width && height

          img["width"] ||= width.to_s
          img["height"] ||= height.to_s
        end
        optimized = true
      rescue StandardError => e
        Jekyll.logger.debug "ImageOptimizer", "Skipping #{img['src']}: #{e.message}"
      end

      return unless optimized

      document.output = fragment.to_html
    end

    def prepare_site(site)
      config = image_config(site)
      manifest = {}

      responsive_candidates(site).each do |static_file|
        entry = manifest_entry_for(site, static_file, config)
        next unless entry

        manifest[entry.delete("source")] = entry
      end

      site.data["datalog_responsive_images"] = manifest
      site.config["datalog_image_config"] = config
    end

    def image_source_path(site, src)
      return unless site && src

      normalized = src.gsub(%r{^/}, "")
      return if normalized.start_with?("http://", "https://", "data:")

      Jekyll.sanitized_path(site.source, normalized)
    end

    def responsive_candidates(site)
      return [] unless site.respond_to?(:static_files)

      site.static_files.select do |static_file|
        path = static_file.path
        next false unless path

        ext = File.extname(path).downcase
        next false unless RASTER_EXTENSIONS.include?(ext)

        relative_dir = File.dirname(static_file.relative_path.to_s)
        !relative_dir.to_s.split(File::SEPARATOR).include?("responsive")
      end
    end

    def manifest_entry_for(site, static_file, config)
      source_path = static_file.path
      width, height = FastImage.size(source_path)
      return unless width && height

      normalized_src = normalize_src(static_file.relative_path, site)
      sizes = normalized_sizes(config["sizes"], width)
      fallback_format = normalize_format(File.extname(source_path))
      fallback_variants = []
      source_variants = Hash.new { |hash, key| hash[key] = [] }

      sizes.each do |target_width|
        target_height = scaled_height(width, height, target_width)

        if fallback_format && target_width < width
          variant = build_variant(site, static_file, target_width, target_height, fallback_format, config,
                                  fallback_format, width)
          fallback_variants << variant if variant
        end

        %w[avif webp].each do |format|
          variant = build_variant(site, static_file, target_width, target_height, format, config, fallback_format,
                                  width)
          source_variants[format] << variant if variant
        end
      end

      fallback_variants.sort_by! { |variant| variant["width"] }
      fallback_variants << original_variant(normalized_src, width, height) unless fallback_variants.any? do |variant|
        variant["width"] >= width
      end

      sources = %w[avif webp].map do |format|
        variants = source_variants[format].compact.sort_by { |variant| variant["width"] }
        next if variants.empty?

        { "type" => MIME_TYPES[format], "format" => format, "variants" => variants }
      end.compact

      {
        "source" => normalized_src,
        "width" => width,
        "height" => height,
        "sources" => sources,
        "fallback" => {
          "type" => MIME_TYPES[fallback_format] || MIME_TYPES[normalize_format(File.extname(source_path))] || "image/jpeg",
          "format" => fallback_format,
          "variants" => fallback_variants
        }
      }
    end

    def build_variant(site, static_file, target_width, target_height, format, config, original_format, original_width)
      return unless format

      if MiniMagick.nil?
        if original_format != format
          Jekyll.logger.debug "ImageOptimizer",
                              "Skipping #{format} variant for #{static_file.relative_path} because MiniMagick is unavailable"
          return
        end

        if original_width && target_width < original_width
          Jekyll.logger.debug "ImageOptimizer",
                              "Skipping #{format} #{target_width}w variant for #{static_file.relative_path} because MiniMagick is unavailable"
          return
        end

        return
      end

      quality_map = config["quality"] || {}
      quality = quality_map[format] || quality_map[format&.downcase] || quality_map[format&.upcase]
      encoder_path = avif_encoder
      if format == "avif" && encoder_path.nil?
        Jekyll.logger.debug "ImageOptimizer",
                            "Skipping AVIF variant for #{static_file.relative_path} because avifenc is unavailable"
        return
      end

      relative_path = static_file.relative_path.sub(%r{^/}, "")
      dir = File.dirname(relative_path)
      dir = "" if dir == "."
      responsive_dir = File.join(dir, "responsive")

      base = File.basename(relative_path, File.extname(relative_path))
      ext = extension_for(format)
      filename = "#{base}-#{target_width}w.#{ext}"

      responsive_file = ResponsiveImageStaticFile.new(
        site: site,
        relative_dir: responsive_dir,
        name: filename,
        original_path: static_file.path,
        width: target_width,
        height: target_height,
        format: format,
        quality: quality,
        avif_encoder: encoder_path
      )

      site.static_files << responsive_file

      {
        "url" => responsive_file.url,
        "width" => target_width,
        "height" => target_height,
        "format" => format
      }
    rescue StandardError => e
      Jekyll.logger.debug "ImageOptimizer",
                          "Unable to generate variant for #{static_file.relative_path}: #{e.message}"
      nil
    end

    def normalized_sizes(configured_sizes, original_width)
      sizes = Array(configured_sizes || DEFAULT_SIZES).map do |value|
        Integer(value)
      rescue ArgumentError, TypeError
        nil
      end.compact

      sizes = DEFAULT_SIZES if sizes.empty?
      sizes = sizes.select { |size| size.positive? && size < original_width }
      sizes.sort.uniq.tap do |collection|
        collection << original_width
        collection.uniq!
      end
    end

    def scaled_height(original_width, original_height, target_width)
      return original_height if original_width.zero?

      scaled = (original_height.to_f * target_width.to_f / original_width.to_f).round
      scaled.positive? ? scaled : 1
    end

    def normalize_format(ext)
      return unless ext

      normalized = ext.delete(".").downcase
      return "jpeg" if normalized == "jpg"

      normalized if %w[jpeg png].include?(normalized)
    end

    def extension_for(format)
      case format
      when "jpeg"
        "jpg"
      when "jpg"
        "jpg"
      else
        format
      end
    end

    def original_variant(src, width, height)
      {
        "url" => src,
        "width" => width,
        "height" => height,
        "format" => normalize_format(File.extname(src))
      }
    end

    def build_srcset(variants)
      variants.map do |variant|
        next unless variant["url"] && variant["width"]

        "#{variant['url']} #{variant['width']}w"
      end.compact.join(", ")
    end

    def normalize_src(src, site)
      return src if src.nil? || src.empty?
      return src if src.start_with?("http://", "https://", "data:")

      baseurl = site&.baseurl.to_s
      normalized = src.dup
      normalized = normalized.delete_prefix(baseurl) if baseurl && !baseurl.empty? && normalized.start_with?(baseurl)
      site_url = site&.config&.fetch("url", "").to_s
      normalized = normalized.delete_prefix(site_url) if !site_url.empty? && normalized.start_with?(site_url)
      normalized = normalized.gsub(%r{^/+}, "")
      "/#{normalized}"
    end

    def image_config(site)
      options = site.config.dig("theme_options", "images") || {}
      qualities = DEFAULT_QUALITY.merge((options["quality"] || {}).transform_keys { |key| key.to_s.downcase })

      {
        "sizes" => options["sizes"] || options["breakpoints"] || DEFAULT_SIZES,
        "quality" => qualities,
        "lazy_loading" => options["lazy_loading"] || "lazy",
        "default_sizes" => options["default_sizes"] || "100vw"
      }
    end

    def avif_encoder
      @avif_encoder ||= (Jekyll::Utils.which("avifenc") if defined?(Jekyll::Utils))
    end
  end
end

class Jekyll::ResponsiveImageStaticFile < Jekyll::StaticFile
  attr_reader :url

  def initialize(site:, relative_dir:, name:, original_path:, width:, height:, format:, quality:, avif_encoder: nil)
    @site = site
    @original_path = original_path
    @target_width = width
    @target_height = height
    @format = format
    @quality = quality
    @avif_encoder = avif_encoder

    sanitized_dir = relative_dir.to_s.sub(%r{^/}, "")
    super(site, site.source, sanitized_dir, name)

    relative = File.join(sanitized_dir, name).gsub(File::SEPARATOR, "/")
    @url = relative.empty? ? "/#{name}" : "/#{relative}"
  end

  def write(dest)
    dest_path = destination(dest)
    return false unless needs_write?(dest_path)

    FileUtils.mkdir_p(File.dirname(dest_path))
    generate_variant(dest_path)
    true
  rescue StandardError => e
    Jekyll.logger.warn "ImageOptimizer", "Failed to generate #{relative_path}: #{e.message}"
    false
  end

  private

  def needs_write?(dest_path)
    return true unless File.exist?(dest_path)

    File.mtime(dest_path) < File.mtime(@original_path)
  rescue Errno::ENOENT
    true
  end

  def generate_variant(dest_path)
    if MiniMagick.nil?
      FileUtils.cp(@original_path, dest_path)
      return
    end

    case @format
    when "avif"
      generate_avif(dest_path)
    else
      generate_with_mini_magick(dest_path, @format)
    end
  end

  def generate_with_mini_magick(dest_path, format)
    image = MiniMagick::Image.open(@original_path)
    image.auto_orient
    image.resize "#{@target_width}x#{@target_height}>" if @target_width.positive? && @target_width < image.width
    image.strip
    image.format(format)
    image.quality(@quality.to_i) if @quality
    image.write(dest_path)
  ensure
    image&.destroy!
  end

  def generate_avif(dest_path)
    raise "avifenc encoder not available" unless @avif_encoder

    Tempfile.create(["responsive", ".png"]) do |tempfile|
      generate_with_mini_magick(tempfile.path, "png")
      args = [@avif_encoder, "-q", avif_quality.to_s, "-s", "6", tempfile.path, dest_path]
      system(*args)
      raise "avifenc failed" unless $CHILD_STATUS&.success?
    end
  end

  def avif_quality
    quality = @quality.to_i
    return 50 if quality <= 0

    [[quality, 100].min, 0].max
  end
end

class Jekyll::ImageOptimizerGenerator < Jekyll::Generator
  safe true
  priority :low

  def generate(site)
    Jekyll::ImageOptimizer.prepare_site(site)
  end
end

Jekyll::Hooks.register(%i[pages documents], :post_render) do |document|
  Jekyll::ImageOptimizer.process(document)
end

Jekyll::Hooks.register(:site, :post_write) do |site|
  manifest = site.data.fetch("datalog_responsive_images", {})
  next if manifest.empty?

  destination = File.join(site.dest, "assets", "img", "responsive")
  FileUtils.mkdir_p(destination)

  manifest_path = File.join(destination, "manifest.json")
  File.write(manifest_path, JSON.pretty_generate(manifest))
end
