# frozen_string_literal: true

require "digest"
require "etc"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "social_cards/plain_text"
require_relative "social_cards/template"

module Datalog
  # A share card for each page that names no image of its own: its title,
  # series or subtitle, author and date, and the site's name and logo, drawn
  # on the theme's colours as a 1200×630 PNG (#297). Without one, every post
  # was shared with `social.default_image`, and a link to an article looked
  # like a link to the about page.
  #
  # The template is filled in Ruby, its text set in the IBM Plex fonts the
  # gem ships, and drawn by ImageMagick, which the image optimizer already
  # finds. Each card is kept in .jekyll-cache, keyed by everything drawn on
  # it, so a build renders only the cards whose pages changed.
  #
  #   theme_options:
  #     social_cards:
  #       enabled: true             # off by default: it needs ImageMagick
  #       scheme: dark              # or light
  #       background: "#0b1d3d"     # over the scheme's background
  #       logo: /assets/img/logo.svg  # an SVG or an image; false for none
  #       template: _social/card.svg  # a site's own SVG template
  #       collections: [posts]      # and "pages" for the site's pages
  #
  # Front matter: `og_image` or `image` wins over the card, and
  # `social_card: false` asks for none.
  module SocialCards
    # The scheme's colours, all at least 4.5:1 against its background.
    SCHEMES = {
      "dark" => { "background" => "#111b31", "ink" => "#e7edf9", "muted" => "#cbd5e1", "accent" => "#67e8f9" },
      "light" => { "background" => "#f8fafc", "ink" => "#172033", "muted" => "#334155", "accent" => "#3730a3" }
    }.freeze
    TEXT_COLORS = %w[ink muted accent].freeze
    # The theme's mark, as the header draws it; currentColor is the accent.
    MARK = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
        <path d="M8 48c12-24 24-32 32-32 8 0 12 4 16 8" fill="none" stroke="currentColor" stroke-width="4" stroke-linecap="round"/>
        <path d="M44 16c0 4-4 8-8 8s-8-4-8-8 4-8 8-8 8 4 8 8z" fill="currentColor" opacity="0.25"/>
      </svg>
    SVG
    WIDTH = Template::WIDTH
    HEIGHT = Template::HEIGHT
    CACHE_DIR = "datalog-social-cards"
    OUTPUT_DIR = "assets/social"
    # Bumped when the drawing changes for the same inputs, so cached cards
    # drawn the old way are drawn again.
    REVISION = 1
    MAX_AUTHORS = 3

    Job = Struct.new(:page, :fields, :mvg, :key, :cached)

    module_function

    # Draws the cards the site's pages need and tells each page where its
    # card is. Returns { rendered:, reused: } or nil when the cards are off.
    def generate(site, tools: nil)
      config = settings(site)
      return unless config

      pages = pages_for(site, config)
      return { rendered: 0, reused: 0 } if pages.empty?

      tools ||= Jekyll::ImageOptimizer.tools
      unless renderable?(tools)
        warn_once("ImageMagick, which draws them, was not found (magick, or convert outside Windows), " \
                  "so pages are shared with social.default_image")
        return { rendered: 0, reused: 0 }
      end

      template = Template.new(config[:template], colors: config[:colors], resolve: resolver(site))
      jobs = pages.map { |page| job(site, page, template, config) }
      warn_once("the card template's #{template.ignored.uniq.join(', ')} are not drawn") unless template.ignored.empty?

      pending = jobs.reject { |item| File.exist?(item.cached) }
      failed = render_all(pending, tools)
      jobs.each { |item| publish(site, item) if File.exist?(item.cached) }
      report(failed, pending.size - failed.size, jobs.size - pending.size)
    end

    def settings(site)
      options = site.config.dig("theme_options", "social_cards")
      return unless options.is_a?(Hash) && options["enabled"] == true

      scheme = SCHEMES.key?(options["scheme"].to_s) ? options["scheme"].to_s : "dark"
      colors = SCHEMES[scheme].dup
      colors["background"] = options["background"].to_s.strip if options["background"].is_a?(String)
      check_contrast(colors)
      { colors: colors, template: template(site, options), logo: logo(site, options),
        collections: Array(options.fetch("collections", ["posts"])).map(&:to_s) }
    end

    # The pages that get a card: those in the configured collections (and
    # the site's own pages, for "pages") that are written, have a title, and
    # name no image of their own.
    def pages_for(site, config)
      candidates = config[:collections].flat_map do |label|
        next site.pages.select { |page| page.output_ext == ".html" } if label == "pages"

        site.collections[label]&.docs || []
      end
      candidates.select { |page| wants_card?(page) }
    end

    def wants_card?(page)
      data = page.data
      return false if data["social_card"] == false || data["title"].to_s.strip.empty?
      return false if %w[og_image image].any? { |key| data[key].is_a?(String) && !data[key].strip.empty? }

      !page.respond_to?(:write?) || page.write?
    end

    # What the card says about a page.
    def fields(site, page)
      data = page.data
      locale = I18n.locale_code(site, data["lang"])
      {
        "site" => site_name(site),
        "kicker" => kicker(site, locale, data),
        "title" => PlainText.from_tex(data["title"]),
        "byline" => [authors(site, page), date(site, page, locale)].compact.join(" · "),
        "detail" => detail(data)
      }
    end

    # The name beside the logo, as the header shows it: the name
    # `site_identity` gives, else `name`, else `title`.
    def site_name(site)
      identity = site.config["site_identity"]
      named = identity["name"].to_s.strip if identity.is_a?(Hash)
      [named, site.config["name"], site.config["title"]].map(&:to_s).map(&:strip).find { |name| !name.empty? }
    end

    # "Part 3 of 4 · Missing data" for a part of a series, else the subtitle.
    def kicker(site, locale, data)
      series = data["series"]
      if series.is_a?(Hash) && series["count"]
        part = I18n.interpolate(I18n.lookup(site, locale, "series.part_of") || "Part {{part}} of {{total}}",
                                "part" => series["position"], "total" => series["count"])
        return [part, PlainText.from_tex(series["title"])].reject(&:empty?).join(" · ")
      end
      PlainText.from_tex(data["subtitle"]) unless data["subtitle"].to_s.strip.empty?
    end

    def authors(site, page)
      page_hash = page.data.merge("path" => page.relative_path)
      names = Authors.authors(page_hash, site.config.merge("data" => site.data)).filter_map { |author| author["name"] }
      return if names.empty?

      names.size > MAX_AUTHORS ? "#{names.first} et al." : names.join(", ")
    end

    # A post's date. Any other document has one too, the time of the build
    # when it names none, so only one given in front matter counts.
    def date(site, page, locale)
      given = page.data["date"]
      post = page.respond_to?(:collection) && page.collection&.label == "posts"
      return unless given && (post || given != site.time)

      context = Liquid::Context.new([{ "page" => { "lang" => locale } }], {}, { site: site })
      I18n.localized_format(context, given, "long")
    end

    # A research article's venue and DOI.
    def detail(data)
      venue = data["publication"] || data["journal"] || data["conference"]
      venue = nil unless venue.is_a?(String)
      doi = data["doi"].to_s.strip
      [venue, (doi.empty? ? nil : "DOI #{doi}")].compact.join(" · ")
    end

    def job(site, page, template, config)
      fields = fields(site, page)
      mvg = template.to_mvg(fields, logo: config[:logo])
      key = Digest::SHA256.hexdigest([REVISION, mvg, *image_digests(mvg)].join("\0"))
      Job.new(page, fields, mvg, key, File.join(cache_root(site), "#{key}.png"))
    end

    # The drawing names an image by its path; its content goes into the key
    # too, so a logo or a template's image replaced under the same name draws
    # the card again.
    def image_digests(mvg)
      mvg.scan(/^image over \S+ \S+ '([^']+)'$/).flatten.uniq.map do |file|
        File.file?(file) ? Digest::SHA256.file(file).hexdigest : file
      end
    end

    # Draws each card into the cache, a few at a time. Returns the failures.
    def render_all(jobs, tools)
      queue = Queue.new
      jobs.each { |item| queue << item }
      queue.close
      failed = Queue.new
      workers = [Etc.nprocessors, 4, jobs.size].min
      Array.new(workers) do
        Thread.new do
          while (item = queue.pop)
            begin
              render(item, tools)
            rescue StandardError => e
              failed << [item, e.message]
            end
          end
        end
      end.each(&:join)
      Array.new(failed.size) { failed.pop }
    end

    # Writes beside the cache entry and renames it into place, so an
    # interrupted render never leaves a card a later build takes for done.
    def render(item, tools)
      FileUtils.mkdir_p(File.dirname(item.cached))
      drawing = "#{item.cached}.mvg"
      partial = item.cached.sub(/\.png\z/, ".partial.png")
      File.write(drawing, item.mvg)
      command = [*tools["imagemagick"], "mvg:#{drawing}", "-depth", "8", "-strip",
                 "-define", "png:exclude-chunks=date,time", "png:#{partial}"]
      output, status = Open3.capture2e(*command)
      unless status.success?
        tail = output.strip.lines.last(3).join.strip
        raise "#{File.basename(command.first)} exited with #{status.exitstatus}: #{tail}"
      end

      File.rename(partial, item.cached)
    ensure
      FileUtils.rm_f([drawing, partial].compact)
    end

    def publish(site, item)
      name = "#{slug(item.page.url)}-#{item.key[0, 12]}.png"
      file = CardFile.new(site, OUTPUT_DIR, name, item.cached)
      site.static_files << file
      item.page.data["datalog_social_card"] = {
        "url" => file.url, "width" => WIDTH, "height" => HEIGHT, "alt" => item.fields["title"]
      }
    end

    def slug(url)
      name = url.to_s.delete_prefix("/").delete_suffix("/").sub(/\.html\z/, "").tr("/", "-")
      name = name.gsub(/[^\w.-]+/, "-")
      name.empty? ? "index" : name
    end

    def report(failed, rendered, reused)
      failed.first(5).each do |item, message|
        Jekyll.logger.warn "Social cards:", "could not draw the card for #{item.page.relative_path}: #{message}"
      end
      Jekyll.logger.warn "Social cards:", "#{failed.size - 5} more could not be drawn" if failed.size > 5
      if (rendered + reused).positive?
        Jekyll.logger.info "Social cards:",
                           "#{rendered} drawn, #{reused} reused from the cache"
      end
      { rendered: rendered, reused: reused, failed: failed.size }
    end

    def renderable?(tools)
      tools && tools["imagemagick"] && %w[MVG PNG].all? { |format| Array(tools["writable"]).include?(format) }
    end

    def template(site, options)
      return File.read(Template::DEFAULT) unless options["template"]

      path = site_file(site, options["template"], "theme_options.social_cards.template")
      File.read(path)
    end

    # The theme's mark unless `logo` names a file (or `true`, the mark too);
    # an SVG's text, or an image's path; nil for `false`.
    def logo(site, options)
      value = options.fetch("logo", true)
      return MARK if value == true
      return if value == false || value.to_s.strip.empty?

      path = site_file(site, value, "theme_options.social_cards.logo")
      File.extname(path).casecmp?(".svg") ? File.read(path) : path
    end

    def site_file(site, value, setting)
      path = inside_site(site, value)
      return path if path

      raise Jekyll::Errors::FatalException, "#{setting} names #{value}, which is not a file in the site"
    end

    # An image a template names, from the site's source.
    def resolver(site)
      lambda do |href|
        inside_site(site, href) unless href.to_s.strip.empty? || href.to_s.match?(/\A[a-z]+:/i)
      end
    end

    # The file a site path names, when it is one and inside the site: a
    # sibling directory whose name starts with the site's does not count.
    def inside_site(site, value)
      root = File.expand_path(site.source)
      path = File.expand_path(value.to_s.delete_prefix("/"), root)
      path if File.file?(path) && path.start_with?("#{root}/")
    end

    def cache_root(site)
      return site.in_cache_dir(CACHE_DIR) unless site.config["disable_disk_cache"]

      @cache_root ||= Dir.mktmpdir(CACHE_DIR).tap { |dir| at_exit { FileUtils.rm_rf(dir) } }
    end

    # WCAG's contrast ratio between two #rgb or #rrggbb colours, or nil.
    def contrast(first, second)
      lighter, darker = [luminance(first), luminance(second)].then do |values|
        return nil if values.any?(&:nil?)

        values.sort.reverse
      end
      (lighter + 0.05) / (darker + 0.05)
    end

    def luminance(color)
      hex = color.to_s.delete_prefix("#")
      hex = hex.chars.map { |char| char * 2 }.join if hex.length == 3
      return unless hex.match?(/\A\h{6}\z/)

      channels = hex.scan(/../).map do |pair|
        value = pair.to_i(16) / 255.0
        value <= 0.039_28 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
      end
      (0.2126 * channels[0]) + (0.7152 * channels[1]) + (0.0722 * channels[2])
    end

    def check_contrast(colors)
      TEXT_COLORS.each do |name|
        ratio = contrast(colors[name], colors["background"])
        next if ratio.nil? || ratio >= 4.5

        warn_once(format("the %<name>s colour %<color>s on the background %<background>s is %<ratio>.2f:1, " \
                         "below the 4.5:1 WCAG AA asks for text", name: name, color: colors[name],
                                                                  background: colors["background"], ratio: ratio))
      end
    end

    def warn_once(message)
      @warned ||= {}
      return if @warned[message]

      @warned[message] = true
      Jekyll.logger.warn "Social cards:", message
    end

    # A card kept in the cache, which Jekyll copies into the site from there.
    class CardFile < Jekyll::StaticFile
      def initialize(site, dir, name, cached)
        @cached = cached
        super(site, site.source, "/#{dir}", name)
      end

      def path
        @cached
      end
    end
  end
end
