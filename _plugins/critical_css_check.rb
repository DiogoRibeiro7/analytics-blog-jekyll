# frozen_string_literal: true

module Datalog
  # The theme ships _includes/critical-css/*.html empty, since critical CSS
  # depends on a site's own pages. A production build with critical_css.enabled
  # and no critical CSS written inlined nothing and kept main.css blocking
  # rendering, and nothing said so.
  module CriticalCssCheck
    module_function

    TARGETS = %w[home post default].freeze

    def warning(site)
      return unless Jekyll.env == "production"

      settings = site.config["critical_css"]
      return unless settings.is_a?(Hash) && settings["enabled"] == true

      empty = TARGETS.select { |target| fragment(site, target).strip.empty? }
      return if empty.empty?

      files = empty.map { |target| "_includes/critical-css/#{target}.html" }.join(", ")
      "critical_css.enabled is true, but #{files} #{empty.size == 1 ? 'is' : 'are'} empty, so pages with " \
        "#{empty.size == 1 ? 'that layout' : 'those layouts'} inline no critical CSS and main.css blocks rendering. " \
        "Run `bundle exec datalog critical-css` before building."
    end

    # The site's file, or the theme's when the site has none.
    def fragment(site, target)
      name = File.join("critical-css", "#{target}.html")
      directories = [site.in_source_dir(site.config["includes_dir"].to_s)]
      directories << site.theme.includes_path if site.theme&.includes_path
      path = directories.map { |directory| File.join(directory, name) }.find { |candidate| File.file?(candidate) }
      path ? File.read(path) : ""
    end
  end
end

Jekyll::Hooks.register :site, :post_read do |site|
  warning = Datalog::CriticalCssCheck.warning(site)
  Jekyll.logger.warn("Critical CSS:", warning) if warning
end
