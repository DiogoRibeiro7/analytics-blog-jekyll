# frozen_string_literal: true

module Datalog
  class Audit
    # The front matter keys something reads, found in the sources that read
    # them rather than kept as a list: the theme's layouts, includes, plugins
    # and library, and the site's own layouts, includes and plugins. A key
    # none of them names is a typo (`descripton`) or a leftover of another
    # theme, which nothing will ever show.
    module KnownKeys
      module_function

      # Keys that Jekyll and the plugins the theme depends on read, which the
      # theme's own sources do not name.
      JEKYLL = %w[
        layout permalink published date categories category tags tag title excerpt excerpt_separator slug
        lang render_with_liquid collection output path url id ext draft hidden
        sitemap redirect_from redirect_to last_modified_at image seo canonical_url locale author description
        paginate pagination feed
      ].freeze

      TEMPLATE_DIRS = %w[_layouts _includes].freeze
      CODE_DIRS = %w[_plugins lib].freeze
      # page.title, include.page.summary, post.series and every other property
      # a template reads, and quoted names in filters (where: "layout").
      TEMPLATE_KEY = /[\w\]]\.([a-z_][a-z0-9_]*)|["']([a-z_][a-z0-9_]*)["']/
      # data["reproducibility"], fetch("title"), Authors.value(page, "series").
      CODE_KEY = /["']([a-z_][a-z0-9_]*)["']/

      def build(theme_root:, site_root:, extra: [])
        keys = Set.new(JEKYLL)
        [theme_root, site_root].uniq.each do |root|
          scan(root, TEMPLATE_DIRS, "**/*.{html,liquid,xml,json,md}", TEMPLATE_KEY, keys)
          scan(root, CODE_DIRS, "**/*.rb", CODE_KEY, keys)
        end
        keys.merge(Array(extra).map(&:to_s))
      end

      def scan(root, dirs, glob, pattern, keys)
        dirs.each do |dir|
          Dir.glob(File.join(root, dir, glob)).each do |file|
            File.read(file, encoding: "utf-8").scan(pattern) { |match| keys.merge(Array(match).compact) }
          end
        end
      end

      # Liquid output and tags; neither holds a brace, so a scan from one {{
      # stops at the next brace and the file is read in linear time.
      LIQUID = /\{\{[^{}]*\}\}|\{%(?:[^{}%]|%(?!\}))*%\}/

      # The properties a page's own Liquid reads, such as a showcase page that
      # passes `page.academic_demo` to an include, or a listing that shows
      # `post.subtitle`: read by the site's content rather than its templates.
      def from_content(text)
        text.scan(LIQUID).each_with_object(Set.new) do |liquid, keys|
          liquid.scan(TEMPLATE_KEY) { |match| keys.merge(Array(match).compact) }
        end
      end
    end
  end
end
