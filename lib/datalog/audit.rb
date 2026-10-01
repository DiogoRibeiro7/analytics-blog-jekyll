# frozen_string_literal: true

require "json"
require_relative "audit/source_file"
require_relative "audit/site_reader"
require_relative "audit/known_keys"
require_relative "audit/checks"

module Datalog
  # `datalog audit`: which of a site's pages would gain from the theme's newer
  # authoring features, and which have problems no build reports, each with
  # its file and line. It reads the site and writes nothing.
  class Audit
    class Error < StandardError; end

    Finding = Struct.new(:kind, :check, :file, :line, :message) do
      def to_h
        { "kind" => kind, "check" => check, "file" => file, "line" => line, "message" => message }
      end
    end

    # Check id => [kind, heading]. Opportunities are advice; problems fail --strict.
    CHECKS = {
      "statements" => [:opportunity, "Statements typed by hand"],
      "figures" => [:opportunity, "Figure and table numbers typed by hand"],
      "series" => [:opportunity, "Series"],
      "reproducibility" => [:opportunity, "Reproducibility"],
      "revisions" => [:opportunity, "Revisions"],
      "references" => [:opportunity, "References written by hand"],
      "front-matter" => [:problem, "Front matter no one reads"],
      "images" => [:problem, "Images without alt text"],
      "links" => [:problem, "Links to pages the site does not build"],
      "math" => [:problem, "Math switched against the content"]
    }.freeze

    THEME_ROOT = File.expand_path("../..", __dir__)

    attr_reader :root, :findings, :files

    def initialize(root:, only: nil, path: nil)
      @root = File.expand_path(root)
      @only = only ? Array(only).flat_map { |id| id.to_s.split(",") }.map(&:strip).reject(&:empty?) : CHECKS.keys
      unknown = @only - CHECKS.keys
      raise Error, "unknown check #{unknown.join(', ')}; the checks are #{CHECKS.keys.join(', ')}" unless unknown.empty?

      @path = path&.delete_prefix("./")&.chomp("/")
      raise Error, "#{@root} has no _config.yml: run the audit from a Jekyll site, or pass --root" unless
        File.file?(File.join(@root, "_config.yml"))
    end

    def run
      reader = SiteReader.new(root).read
      settings = reader.config["audit"].is_a?(Hash) ? reader.config["audit"] : {}
      keys = KnownKeys.build(theme_root: THEME_ROOT, site_root: root, extra: settings["known_keys"])
      # Every file's Liquid, audited or not, may read another page's front matter.
      sources = reader.content_files.map { |path, relative| SourceFile.new(path, relative) }
      sources.each { |source| keys.merge(KnownKeys.from_content(source.body)) }
      checks = Checks.new(reader: reader, known_keys: keys, settings: settings)
      audited = sources.select { |source| within_path?(source.relative) }
      @files = audited.map { |source| [source.path, source.relative] }
      @findings = audited.flat_map do |file|
        relative = file.relative
        @only.flat_map do |check|
          checks.public_send(check.tr("-", "_"), file).map do |line, message|
            Finding.new(CHECKS[check].first, check, relative, line, message)
          end
        end
      end
      self
    end

    def problems
      findings.select { |finding| finding.kind == :problem }
    end

    def opportunities
      findings.select { |finding| finding.kind == :opportunity }
    end

    # --------------------------------------------------------------- reports

    def to_json(*_args)
      JSON.pretty_generate(
        "root" => root, "files" => files.size,
        "summary" => { "problems" => problems.size, "opportunities" => opportunities.size },
        "problems" => problems.map(&:to_h), "opportunities" => opportunities.map(&:to_h)
      )
    end

    def to_text
      out = ["DataLog audit of #{root}: #{files.size} #{files.size == 1 ? 'file' : 'files'}", ""]
      [[:problem, "Problems"], [:opportunity, "Opportunities"]].each do |kind, title|
        group = findings.select { |finding| finding.kind == kind }
        out << "#{title} (#{group.size})"
        by_check(group).each do |check, items|
          out << "  #{CHECKS[check].last} (#{items.size})"
          items.each { |item| out << "    #{item.file}:#{item.line}  #{item.message}" }
        end
        out << ""
      end
      out << summary
      out.join("\n")
    end

    def to_markdown
      out = ["## DataLog audit", "", "#{summary.chomp('.')} in #{files.size} files.", ""]
      [[:problem, "Problems"], [:opportunity, "Opportunities"]].each do |kind, title|
        group = findings.select { |finding| finding.kind == kind }
        next if group.empty?

        out << "### #{title}" << ""
        by_check(group).each do |check, items|
          out << "#### #{CHECKS[check].last}" << ""
          items.each { |item| out << "- `#{item.file}:#{item.line}` #{markdown_text(item.message)}" }
          out << ""
        end
      end
      out.join("\n")
    end

    def summary
      "#{problems.size} #{problems.size == 1 ? 'problem' : 'problems'}, #{opportunities.size} " \
        "#{opportunities.size == 1 ? 'opportunity' : 'opportunities'}."
    end

    private

    # A message as Markdown: Liquid tags as code, and the characters Markdown
    # would read as emphasis, a link or a table cell escaped, so a quoted
    # **Theorem 1.** reads as typed.
    def markdown_text(message)
      message.split(/(\{%.*?%\})/).each_with_index.map do |part, index|
        index.odd? ? "`#{part}`" : part.gsub(/([*_\[\]<>|\\])/) { "\\#{Regexp.last_match(1)}" }
      end.join
    end

    def by_check(group)
      group.group_by(&:check).sort_by { |check, _| CHECKS.keys.index(check) }
    end

    def within_path?(relative)
      @path.nil? || @path.empty? || relative == @path || relative.start_with?("#{@path}/")
    end
  end
end
