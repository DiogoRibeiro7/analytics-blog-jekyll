# frozen_string_literal: true

require "digest"
require "fastimage"
require "fileutils"
require "json"
require "nokogiri"
require "open3"
require "tmpdir"
require "tempfile"
require "uri"

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
    SOURCE_FORMATS = %w[avif webp].freeze
    # ImageMagick's names for the formats it writes itself, as `-list format` prints them.
    CODERS = { "jpeg" => "JPEG", "png" => "PNG", "webp" => "WEBP" }.freeze
    CACHE_DIR = "datalog-images"

    # The file-name suffix that marks a dark twin, and the query the markup
    # asks the browser. The site's script narrows this when a reader has used
    # the theme toggle, whose choice the operating system does not know about.
    DEFAULT_DARK_SUFFIX = "-dark"
    DARK_MEDIA = "(prefers-color-scheme: dark)"

    # The one image a page fetches early: the first in its post or page content,
    # unless the author made it lazy or the page already preloads an image, as
    # the hero does. The first <img> anywhere used to be marked both lazy and
    # high priority; on the home page that was a post card below the hero, and
    # on tutorials the thumbnail of a related post at the bottom.
    def priority_image(fragment)
      return if fragment.at_css('link[rel="preload"][as="image"]')

      image = fragment.css(".post-content img, .page-content img").find { |img| img["data-no-optimize"] != "true" }
      image unless image.nil? || image["loading"] == "lazy"
    end

    def process(document)
      return unless document.output_ext == ".html"
      return if document.output.nil? || document.output.empty?

      full_document = document.output.lstrip.match?(/\A(?:<!DOCTYPE|<html)/i)
      # Fragments use the HTML5 parser too: the HTML4 serializer writes a
      # </source> end tag after each void <source> that offer_variants adds.
      fragment = if full_document
                   Nokogiri::HTML5::Document.parse(document.output)
                 else
                   Nokogiri::HTML5::DocumentFragment.parse(document.output)
                 end
      return if fragment.nil?

      site = document.respond_to?(:site) ? document.site : nil
      manifest = site&.data&.fetch("datalog_responsive_images", {}) || {}
      image_config = site&.config&.fetch("datalog_image_config", {}) || {}
      baseurl = site.respond_to?(:baseurl) ? site.baseurl.to_s : ""
      optimized = false
      priority = priority_image(fragment)

      fragment.css("img").each do |img|
        next if img["data-no-optimize"] == "true"

        if img == priority
          img["fetchpriority"] ||= "high"
        else
          img["loading"] ||= "lazy"
        end
        img["decoding"] ||= "async"
        normalized_src = normalize_src(img["src"], site)
        picture_entry = manifest[normalized_src]

        dark = dark_twin(img, picture_entry, manifest, site)
        offer_variants(img, picture_entry, dark, image_config, baseurl) if picture_entry || dark

        if picture_entry
          if !img["width"] && !img["height"] && picture_entry["width"] && picture_entry["height"]
            img["width"] = picture_entry["width"].to_s
            img["height"] = picture_entry["height"].to_s
          end
        elsif (size = unlisted_size(img, site, normalized_src))
          img["width"], img["height"] = size.map(&:to_s)
        elsif dark.nil?
          next
        end
        optimized = true
      rescue StandardError => e
        Jekyll.logger.debug "ImageOptimizer", "Skipping #{img['src']}: #{e.message}"
      end

      return unless optimized

      document.output = fragment.to_html
    end

    # Offers an image's generated variants: the resized copies as the <img>'s
    # srcset, and each modern format as a <source> in a <picture> around it.
    # An image with a dark companion is wrapped for that alone, even when the
    # pipeline generated nothing else for it. Markup the author chose, a srcset
    # of their own or a <picture>, is left alone, and so is an image with
    # nothing generated besides the original.
    def offer_variants(img, entry, dark, image_config, baseurl)
      return if img["srcset"] || img.parent&.name == "picture"

      fallback = entry&.dig("fallback", "variants") || []
      sources = (entry || {}).fetch("sources", []).select { |source| source["type"] && source["variants"]&.any? }
      return if fallback.size < 2 && sources.empty? && dark.nil?

      sizes = img["sizes"] || image_config.fetch("default_sizes", "100vw")
      # `sizes` without a `srcset` on the <img> says nothing; the <source>
      # elements carry their own.
      if fallback.size > 1
        img["srcset"] = build_srcset(fallback, baseurl)
        img["sizes"] = sizes
      end
      dark_first = dark_elements(img, dark, sizes, baseurl)
      return if sources.empty? && dark_first.empty?

      picture = Nokogiri::XML::Node.new("picture", img.document)
      # A <picture> takes the first source whose media and type both match, so
      # the dark ones come first or they would never be reached.
      dark_first.each { |element| picture.add_child(element) }
      sources.each do |source|
        element = Nokogiri::XML::Node.new("source", img.document)
        element["type"] = source["type"]
        element["srcset"] = build_srcset(source["variants"], baseurl)
        element["sizes"] = sizes
        picture.add_child(element)
      end
      img.add_previous_sibling(picture)
      picture.add_child(img)
    end

    # The dark companion of an image: the one the author named with `dark_src`,
    # or the twin the build found beside it. A named companion is looked up in
    # the manifest, so it is served with the same responsive variants as any
    # other image; one the pipeline never saw, an SVG or an image on another
    # host, is carried as the single file it is.
    def dark_twin(img, entry, manifest, site)
      named = img["data-dark-src"]
      return entry && entry["dark"] unless named

      img.remove_attribute("data-dark-src")
      manifest[normalize_src(named, site)] || { "url" => named }
    end

    # The companion's <source> elements: its modern formats, then its own, so a
    # browser that supports neither AVIF nor WebP still gets the dark image
    # rather than the light one.
    def dark_elements(img, dark, sizes, baseurl)
      return [] unless dark
      return [dark_element(img, nil, dark["url"], sizes)] if dark["url"]

      sources = dark.fetch("sources", []).select { |source| source["type"] && source["variants"]&.any? }
      fallback = dark["fallback"]
      sources += [fallback] if fallback && fallback["variants"]&.any?
      sources.map do |source|
        dark_element(img, source["type"], build_srcset(source["variants"], baseurl), sizes)
      end
    end

    # `data-dark-source` marks it for the toggle: a reader whose system is
    # light and who has switched the site to dark needs the media query
    # overruled, and the script has to know which sources to overrule.
    def dark_element(img, type, srcset, sizes)
      element = Nokogiri::XML::Node.new("source", img.document)
      element["media"] = DARK_MEDIA
      element["type"] = type if type
      element["srcset"] = srcset
      element["sizes"] = sizes
      element["data-dark-source"] = ""
      element
    end

    # The real size of an image the variant pipeline did not touch, read from
    # the file, so the page does not shift while it loads. An image the author
    # gave a width or a height has a deliberate aspect ratio and keeps it.
    def unlisted_size(img, site, src)
      return if img["width"] || img["height"]

      source = image_source_path(site, src)
      return unless source && File.exist?(source)

      FastImage.size(source)
    end

    def prepare_site(site)
      config = image_config(site)
      encoders = config["variants"] ? tools : {}
      counts = Hash.new(0)
      manifest = {}

      responsive_candidates(site).each do |static_file|
        entry = manifest_entry_for(site, static_file, config, encoders, counts)
        next unless entry

        manifest[entry.delete("source")] = entry
      end

      link_dark_variants(manifest, config)
      site.data["datalog_responsive_images"] = manifest
      site.config["datalog_image_config"] = config
      report(encoders, counts)
    end

    # A plot exported for a white page is unreadable on a dark one. An author
    # exports a second file beside the first — power.png and power-dark.png —
    # and every image that has such a twin carries it in the manifest, so the
    # markup can offer both and the browser can choose.
    #
    # The twin is an image in its own right, so it already has its own entry
    # with its own variants; this only records which entry belongs to which.
    def link_dark_variants(manifest, config)
      suffix = config.fetch("dark_suffix", DEFAULT_DARK_SUFFIX).to_s
      return if suffix.empty?

      manifest.each do |src, entry|
        extension = File.extname(src)
        next if extension.empty?
        # The twin of a twin is not a thing.
        next if File.basename(src, extension).end_with?(suffix)

        twin = "#{src.delete_suffix(extension)}#{suffix}#{extension}"
        dark = manifest[twin]
        next unless dark

        entry["dark"] = { "source" => twin, "sources" => dark["sources"], "fallback" => dark["fallback"] }
      end
    end

    def report(encoders, counts)
      if counts[:created].positive? || counts[:cached].positive?
        Jekyll.logger.info "Images:", "#{counts[:created]} variants created, #{counts[:cached]} reused from the cache"
      elsif encoders.any? && encoders["imagemagick"].nil?
        Jekyll.logger.debug "ImageOptimizer", "ImageMagick was not found, so no image variants were created"
      end
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

    def manifest_entry_for(site, static_file, config, encoders, counts)
      source_path = static_file.path
      width, height = FastImage.size(source_path)
      return unless width && height

      normalized_src = normalize_src(static_file.relative_path, site)
      fallback_format = normalize_format(File.extname(source_path))
      fallback_variants = []
      source_variants = Hash.new { |hash, key| hash[key] = [] }
      image = { site: site, file: static_file, width: width, height: height, config: config,
                encoders: encoders, counts: counts }

      normalized_sizes(config["sizes"], width).each do |target_width|
        if fallback_format && target_width < width
          variant = build_variant(image, target_width, fallback_format)
          fallback_variants << variant if variant
        end

        SOURCE_FORMATS.each do |format|
          variant = build_variant(image, target_width, format)
          source_variants[format] << variant if variant
        end
      end

      fallback_variants.sort_by! { |variant| variant["width"] }
      fallback_variants << original_variant(normalized_src, width, height)

      sources = SOURCE_FORMATS.filter_map do |format|
        variants = source_variants[format].sort_by { |variant| variant["width"] }
        next if variants.empty?

        { "type" => MIME_TYPES[format], "format" => format, "variants" => variants }
      end

      {
        "source" => normalized_src,
        "width" => width,
        "height" => height,
        "sources" => sources,
        "fallback" => {
          "type" => MIME_TYPES[fallback_format] || "image/jpeg",
          "format" => fallback_format,
          "variants" => fallback_variants
        }
      }
    end

    # Encodes one variant into the cache, unless an earlier build already did,
    # and adds it to the files the site writes. Returns nil when this machine
    # cannot encode the format or the encoder fails, so the manifest only names
    # files that exist.
    def build_variant(image, target_width, format)
      return unless can_encode?(format, image[:encoders])

      static_file = image[:file]

      quality = image[:config]["quality"][format]
      cached = cached_variant_path(image, target_width, format, quality)
      if File.exist?(cached)
        image[:counts][:cached] += 1
      else
        encode_into_cache(static_file.path, cached, target_width, format, quality, image[:encoders])
        image[:counts][:created] += 1
      end

      variant_file = variant_static_file(image[:site], static_file, target_width, format, cached)
      image[:site].static_files << variant_file

      {
        "url" => variant_file.url,
        "width" => target_width,
        "height" => scaled_height(image[:width], image[:height], target_width),
        "format" => format
      }
    rescue StandardError => e
      Jekyll.logger.warn "ImageOptimizer:",
                         "Could not create a #{target_width}px #{format} of #{image[:file].relative_path}: #{e.message}"
      nil
    end

    # Published next to the original, in a responsive/ folder:
    # /assets/img/plot.png gives /assets/img/responsive/plot-640w.webp.
    def variant_static_file(site, static_file, target_width, format, cached)
      relative_path = static_file.relative_path.sub(%r{^/}, "")
      dir = File.dirname(relative_path)
      responsive_dir = dir == "." ? "responsive" : File.join(dir, "responsive")
      base = File.basename(relative_path)
      Jekyll::ResponsiveImageStaticFile.new(site, responsive_dir, "#{base}-#{target_width}w.#{extension_for(format)}",
                                            cached)
    end

    # Keyed by the image's content rather than its file time, which a fresh
    # checkout resets.
    def cached_variant_path(image, target_width, format, quality)
      image[:digest] ||= Digest::SHA256.file(image[:file].path).hexdigest
      key = Digest::SHA256.hexdigest([image[:digest], target_width, format, quality].join("|"))
      File.join(cache_root(image[:site]), "#{key}.#{extension_for(format)}")
    end

    # Jekyll's cache directory. A site that sets disable_disk_cache gets a
    # temporary directory instead, which `jekyll serve` reuses between builds
    # and which is removed when Jekyll exits.
    def cache_root(site)
      return site.in_cache_dir(CACHE_DIR) unless site.config["disable_disk_cache"]

      @cache_root ||= Dir.mktmpdir(CACHE_DIR).tap { |dir| at_exit { FileUtils.rm_rf(dir) } }
    end

    # Encodes beside the cache entry and renames it into place, so a failed or
    # interrupted encode never leaves a file that a later build takes for done.
    def encode_into_cache(source, cached, target_width, format, quality, encoders)
      partial = cached.sub(/(\.\w+)\z/, '.partial\1')
      FileUtils.mkdir_p(File.dirname(cached))
      if format == "avif"
        Tempfile.create(["datalog-image", ".png"]) do |png|
          png.close
          resize(source, png.path, target_width, nil, encoders)
          run!(*encoders["avifenc"], "-q", avif_quality(quality).to_s, "-s", "6", png.path, partial)
        end
      else
        resize(source, partial, target_width, quality, encoders)
      end
      File.rename(partial, cached)
    ensure
      FileUtils.rm_f(partial)
    end

    def resize(source, destination, target_width, quality, encoders)
      command = [*encoders["imagemagick"], source, "-auto-orient", "-resize", "#{target_width}x>", "-strip"]
      command += ["-quality", quality.to_s] if quality
      run!(*command, destination)
    end

    def run!(*command)
      output, status = Open3.capture2e(*command)
      return if status.success?

      raise "#{File.basename(command.first)} exited with #{status.exitstatus}: #{output.strip.lines.last(3).join.strip}"
    end

    def avif_quality(quality)
      value = quality.to_i
      value.positive? ? value.clamp(1, 100) : 50
    end

    def can_encode?(format, encoders)
      return false unless encoders["imagemagick"]
      return encoders["writable"].include?("PNG") && !encoders["avifenc"].nil? if format == "avif"

      encoders["writable"].include?(CODERS.fetch(format, format.upcase))
    end

    # The encoders on this machine, looked up once per process. ImageMagick 7
    # is `magick`. ImageMagick 6 is `convert`, looked for only off Windows,
    # where C:\Windows\System32\convert.exe converts file systems. AVIF also
    # needs avifenc, from libavif.
    def tools
      @tools ||= detect_tools
    end

    def detect_tools(windows: Gem.win_platform?)
      magick = which("magick")
      convert = which("convert") unless magick || windows
      imagemagick = [magick || convert].compact
      imagemagick = nil if imagemagick.empty?

      avifenc = which("avifenc")

      {
        "imagemagick" => imagemagick,
        "writable" => imagemagick ? writable_formats(imagemagick) : [],
        "avifenc" => avifenc && [avifenc]
      }
    end

    def writable_formats(command)
      output, status = Open3.capture2e(*command, "-list", "format")
      status.success? ? parse_writable_formats(output) : []
    rescue SystemCallError
      []
    end

    # A line of `-list format` reads "     WEBP* rw+   WebP Image Format" in
    # ImageMagick 7. ImageMagick 6 adds the module: "     WEBP* WEBP      rw+".
    def parse_writable_formats(listing)
      listing.each_line.filter_map { |line| line[/\A\s*([A-Z0-9-]+)\*?\s+(?:[A-Z0-9-]+\s+)?[r-]w[+-]\s/, 1] }
    end

    def which(command)
      extensions = ENV["PATHEXT"] ? ENV["PATHEXT"].split(";") : [""]
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
        extensions.each do |extension|
          path = File.join(dir, "#{command}#{extension}")
          return path if File.file?(path) && File.executable?(path)
        end
      end
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
      format == "jpeg" ? "jpg" : format
    end

    def original_variant(src, width, height)
      {
        "url" => encode_image_path(src),
        "width" => width,
        "height" => height,
        "format" => normalize_format(File.extname(src))
      }
    end

    # These are filesystem paths, not already escaped URLs. Encode them once
    # when creating the manifest so both Markdown and the include use valid srcsets.
    def encode_image_path(path)
      path.split("/", -1).map { |part| URI.encode_www_form_component(part).gsub("+", "%20") }.join("/")
    end

    # Variant URLs are site paths. A site served below a baseurl needs it in
    # front of them, as relative_url adds it in templates.
    def build_srcset(variants, baseurl = "")
      variants.map do |variant|
        next unless variant["url"] && variant["width"]

        url = variant["url"]
        url = "#{baseurl}#{url}" if url.start_with?("/") && !url.start_with?("//")
        "#{url} #{variant['width']}w"
      end.compact.join(", ")
    end

    def normalize_src(src, site)
      # Relative image URLs belong to the page, not to the source root. Leave
      # them alone rather than offer another image's dimensions or variants.
      return unless src&.start_with?("/") && !src.start_with?("//")

      baseurl = site&.baseurl.to_s
      normalized = URI::DEFAULT_PARSER.unescape(src.split(/[?#]/, 2).first)
      if !baseurl.empty? && (normalized == baseurl || normalized.start_with?("#{baseurl.chomp('/')}/"))
        normalized = normalized.delete_prefix(baseurl.chomp("/"))
      end
      normalized
    end

    def image_config(site)
      options = site.config.dig("theme_options", "images") || {}
      qualities = DEFAULT_QUALITY.merge((options["quality"] || {}).transform_keys { |key| key.to_s.downcase })

      {
        "variants" => options.fetch("variants", true) != false,
        "sizes" => options["sizes"] || options["breakpoints"] || DEFAULT_SIZES,
        "quality" => qualities,
        "lazy_loading" => options["lazy_loading"] || "lazy",
        "default_sizes" => options["default_sizes"] || "100vw",
        # An empty suffix turns the convention off, for a site whose file names
        # end in "-dark" for some other reason.
        "dark_suffix" => options.fetch("dark_suffix", DEFAULT_DARK_SUFFIX).to_s
      }
    end
  end
end

# A variant kept in the image cache. Jekyll copies it into the site from there,
# as it copies any static file from the source.
class Jekyll::ResponsiveImageStaticFile < Jekyll::StaticFile
  attr_reader :url

  def initialize(site, relative_dir, name, cached_path)
    @cached_path = cached_path
    super(site, site.source, "/#{relative_dir}", name)
    @url = Jekyll::ImageOptimizer.encode_image_path("/#{relative_dir}/#{name}")
  end

  def path
    @cached_path
  end
end

# The srcset of a list of manifest variants, for markup built in Liquid.
# `responsive-image.html` wrote its own, three times over, and it had to keep
# in step with the one the optimizer writes for every other image.
module Jekyll
  module ImageSrcsetFilter
    def image_srcset(variants)
      site = @context.registers[:site]
      Jekyll::ImageOptimizer.build_srcset(Array(variants), site&.config&.fetch("baseurl", "").to_s)
    end
  end
end

Liquid::Template.register_filter(Jekyll::ImageSrcsetFilter)

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
