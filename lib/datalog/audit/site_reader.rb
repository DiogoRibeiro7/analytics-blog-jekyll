# frozen_string_literal: true

require "open3"
require "time"
require "tmpdir"

module Datalog
  class Audit
    # What Jekyll would build, found without building it: the site's own
    # content files and every URL the build has, read with Jekyll's reader and
    # the generators that only add pages in memory. Nothing is rendered or
    # written; the destination is a directory that never exists.
    class SiteReader
      # The generators that add pages (feeds, the sitemap, pagination pages,
      # redirects, the search page, notebook pages) and write nothing until the
      # site is written. The others are left out: they fetch data, encode
      # images or fill caches.
      PAGE_GENERATORS = %w[
        JekyllFeed::Generator Jekyll::JekyllSitemap Jekyll::Paginate::Pagination
        JekyllRedirectFrom::Generator Datalog::SearchPages Jekyll::NotebookConverter
      ].freeze
      CONTENT = /\.(md|markdown|html?)\z/i

      attr_reader :root, :site

      def initialize(root)
        @root = File.expand_path(root)
      end

      def read
        require "jekyll"
        Jekyll.logger.log_level = :error
        config = Jekyll.configuration(
          "source" => root, "destination" => File.join(Dir.tmpdir, "datalog-audit-#{Process.pid}", "_site"),
          "quiet" => true, "disable_disk_cache" => true
        )
        @site = Jekyll::Site.new(config)
        @site.reset
        @site.read
        @site.generators.each do |generator|
          generator.generate(@site) if PAGE_GENERATORS.include?(generator.class.name)
        end
        self
      end

      def config
        site.config
      end

      # [absolute path, path from the site root] of every page and document the
      # site's own sources hold, in a stable order.
      def content_files
        documents = site.collections.values.flat_map(&:docs)
        pages = site.pages.select { |page| page.instance_of?(Jekyll::Page) }
        files = (documents + pages).filter_map do |item|
          path = File.expand_path(item.relative_path, root)
          next unless path.start_with?("#{root}/") && File.file?(path) && path.match?(CONTENT)

          [path, path.delete_prefix("#{root}/")]
        end
        files.uniq.sort_by(&:last)
      end

      # Every URL the build writes, normalised: pages, documents, generated
      # pages and static files.
      def urls
        @urls ||= begin
          items = site.pages + site.static_files + site.collections.values.flat_map(&:docs).select(&:write?)
          items.to_set { |item| normalize(item.url) }
        end
      end

      def normalize(url)
        path = url.to_s.split(/[?#]/, 2).first.to_s
        path = "/#{path}" unless path.start_with?("/")
        path = path.sub(%r{/index\.html?\z}, "/")
        path.end_with?("/") || path.length == 1 ? path : path.sub(/\.html?\z/, "")
      end

      def built?(url)
        path = normalize(url)
        [path, "#{path}/", path.delete_suffix("/")].any? { |candidate| urls.include?(candidate) }
      end

      # A commit that touches more files than this is a sweeping change (a
      # reformat, a migration, a rename), not an edit of any one article.
      SWEEPING_COMMIT = 10

      # The date of the last commit to edit each file, from one `git log` over
      # the site, or {} outside a repository.
      def git_dates
        @git_dates ||= begin
          output, status = Open3.capture2("git", "-C", root, "log", "--format=@@date@@%cI", "--name-only", "--relative",
                                          "--", ".", err: File::NULL)
          status.success? ? parse_log(output) : {}
        rescue SystemCallError
          {}
        end
      end

      private

      def parse_log(output)
        dates = {}
        output.split("@@date@@").each do |commit|
          stamp, *paths = commit.split("\n").map(&:strip).reject(&:empty?)
          next if stamp.nil? || paths.size > SWEEPING_COMMIT

          date = Time.iso8601(stamp)
          paths.each { |path| dates[path] ||= date }
        rescue ArgumentError
          next
        end
        dates
      end
    end
  end
end
