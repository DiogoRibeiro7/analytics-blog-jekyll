# frozen_string_literal: true

require "cgi"
require "json"
require_relative "../citations/entry"
require_relative "../citations/markup"

module Datalog
  module Plugins
    # In-text citations and the bibliography they build, on a par with the
    # figure, table and statement references of _plugins/references.rb:
    #
    #   bibliography: _bibliography/missing-data.bib    # or .json (CSL-JSON), or a list
    #
    #   Multiple imputation {% cite rubin1987 %} and its critics {% cite allison2001 vanbuuren2018 p="12" %}.
    #
    # The tags write placeholders. Once the page's Markdown is converted, every
    # citation gets its number in the order it appears (numeric) or its author
    # and year (author-year), each linked to its entry, and the bibliography
    # lists the cited works with links back to where each was cited. A key the
    # page's sources do not have, or a key two entries share, stops the build.
    #
    # Entries come from the page's `bibliography` files (else the site's
    # `citations.bibliography`), its `citations:` list, a `references:` list of
    # maps, and `citation_group` in _data/citations.yml. `nocite: [key]` or
    # `nocite: all` lists works the text does not cite.
    class Citations < Datalog::PluginSystem::Plugin
      id "datalog-citations"
      priority :high

      Markup = Datalog::Citations::Markup
      STYLES = %w[numeric author-year].freeze
      LOCATORS = %w[p pp chap sec loc].freeze
      KEY = /\A[^\s"'<>&{}%]+\z/
      MARKER = %r{<span class="datalog-cite" data-cite="([^"]*)"(?: data-cite-locator="([^"]*)")?></span>}
      SOURCE_TAG = /\{%-?\s*(?:cite|datalog_cite)\s+([^%]*?)-?%\}/

      # {% cite key %}, {% cite key1 key2 %}, {% cite key p="12" %}.
      class CiteTag < Liquid::Tag
        def initialize(tag_name, markup, options)
          super
          @keys, @locator = Citations.parse_markup(markup, tag_name)
        end

        def render(context)
          unless Datalog::PluginSystem.plugin("datalog-citations")
            page = context.registers[:page] || {}
            raise Liquid::ArgumentError,
                  "#{page['path']} uses {% #{tag_name} %}, which needs the datalog-citations plugin: " \
                  "add it to datalog_plugins.enabled in _config.yml"
          end

          locator = @locator ? %( data-cite-locator="#{CGI.escapeHTML(@locator)}") : ""
          %(<span class="datalog-cite" data-cite="#{CGI.escapeHTML(@keys.join(' '))}"#{locator}></span>)
        end
      end

      # The page's bibliography, where a layout puts it.
      class BibliographyTag < Liquid::Tag
        def render(context)
          page = context.registers[:page] || {}
          plugin = Datalog::PluginSystem.plugin("datalog-citations")
          return plugin.bibliography_html(page) if plugin

          if page["datalog_bibliography"]
            Jekyll.logger.warn("datalog-citations", "#{page['path']} sets datalog_bibliography, but " \
                                                    "datalog_plugins.enabled does not list datalog-citations")
          end
          ""
        end
      end

      # [keys, "p|12"] from `key1 key2 p="12"`.
      def self.parse_markup(markup, tag_name = "cite")
        keys = []
        locator = nil
        tokens(markup).each do |token|
          name, value = token.split("=", 2)
          if value.nil?
            keys << check_key(token, tag_name)
          else
            unless LOCATORS.include?(name)
              raise Liquid::ArgumentError, "{% #{tag_name} %} takes a locator as p=, pp=, chap=, sec= or loc=; " \
                                           "got #{name}="
            end

            locator = "#{name}|#{unquote(value)}"
          end
        end
        raise Liquid::ArgumentError, "{% #{tag_name} %} needs at least one citation key" if keys.empty?

        [keys.uniq, locator]
      end

      # The markup split at spaces outside quotes, character by character: a
      # regular expression over it could take quadratic time on a long word.
      def self.tokens(markup)
        tokens = []
        current = +""
        quote = nil
        markup.to_s.each_char do |char|
          if quote
            quote = nil if char == quote
          elsif ['"', "'"].include?(char)
            quote = char
          elsif char.strip.empty?
            tokens << current unless current.empty?
            current = +""
            next
          end
          current << char
        end
        tokens << current unless current.empty?
        tokens
      end

      def self.unquote(value)
        quoted = value.length >= 2 && ['"', "'"].include?(value[0]) && value[-1] == value[0]
        quoted ? value[1..-2] : value
      end

      def self.check_key(key, tag_name)
        return key if key.match?(KEY)

        raise Liquid::ArgumentError, "{% #{tag_name} %} takes citation keys without spaces, quotes, <, >, " \
                                     "&, braces or %; got #{key.inspect}"
      end

      def initialize(site, config = {})
        super
        @state = {}
        @files = {}
      end

      def custom_liquid_tags
        {
          "cite" => CiteTag,
          "datalog_cite" => CiteTag,
          "datalog_bibliography" => BibliographyTag
        }
      end

      # ------------------------------------------------------------- sources

      def before_render(document, payload = nil)
        state = load_state(document)
        # A page's `page` in Liquid is a copy of its data taken before it
        # renders (a document's reads its data live), so what numbering finds
        # has to reach that copy too.
        state[:page] = payload["page"] if payload.respond_to?(:[]) && payload["page"].is_a?(Hash)
        publish(document, state, "datalog_citation_state" => state[:id])
        title = config["bibliography_title"]
        return unless title && !document.data["datalog_bibliography_title"]

        publish(document, state, "datalog_bibliography_title" => title)
      end

      def publish(document, state, values)
        document.data.merge!(values)
        state[:page]&.merge!(values)
      end

      def load_state(document)
        id = document.relative_path || document.path
        return @state[id] if @state.key?(id)

        entries = {}
        sources(document).each do |label, items|
          items.each do |entry|
            next if entry.key.empty?

            if entries.key?(entry.key)
              raise Jekyll::Errors::FatalException,
                    "#{document.relative_path} has two bibliography entries with the key \"#{entry.key}\" " \
                    "(in #{entries[entry.key][:source]} and #{label}); each key has to be unique"
            end

            entries[entry.key] = { entry: entry, source: label }
          end
        end
        @state[id] = { id: id, entries: entries.transform_values { |value| value[:entry] },
                       sources: sources_label(document) }
      end

      # [label, [Entry, ...]] for each place the page's entries come from.
      def sources(document)
        data = document.data
        found = bibliography_files(document).map { |path| [path, read_file(document, path)] }
        found << ["citations:", front_matter_entries(data["citations"])]
        # The research layout's `references:` is a hand-written list of strings;
        # only a list of maps is a list of entries.
        found << ["references:", front_matter_entries(Array(data["references"]).grep(Hash))]
        group = data["citation_group"]
        if group
          found << ["_data/citations.yml (#{group})", front_matter_entries(site.data.dig("citations", group.to_s))]
        end
        found
      end

      def front_matter_entries(items)
        Array(items).map { |item| Datalog::Citations::Entry.from_front_matter(item) }
      end

      def sources_label(document)
        labels = bibliography_files(document)
        labels << "citations:" if document.data["citations"]
        labels.empty? ? "it has none" : labels.join(", ")
      end

      def bibliography_files(document)
        own = document.data["bibliography"]
        value = own.nil? ? site_setting("bibliography") : own
        return [] if value == false

        Array(value).map(&:to_s).reject(&:empty?)
      end

      def read_file(document, path)
        file = resolve(document, path)
        stamp = [File.mtime(file), File.size(file)]
        @files.delete(file) unless @files.dig(file, :stamp) == stamp
        @files[file] ||= { stamp: stamp, entries: parse_file(document, file, path) }
        @files[file][:entries]
      end

      # A path in the site: from its source directory, or from the page's own.
      def resolve(document, path)
        source = File.expand_path(site.source)
        base = File.dirname(File.expand_path(document.path.to_s, source))
        candidates = [File.expand_path(path, source), File.expand_path(path, base)]
        file = candidates.find { |candidate| candidate.start_with?("#{source}/") && File.file?(candidate) }
        return file if file

        raise Jekyll::Errors::FatalException,
              "#{document.relative_path} names the bibliography #{path}, which is not a file in the site"
      end

      def parse_file(document, file, path)
        text = File.read(file, encoding: "bom|utf-8")
        case File.extname(file).downcase
        when ".bib", ".bibtex"
          Datalog::Citations::BibTeX.parse(text).map { |record| Datalog::Citations::Entry.from_bibtex(record) }
        when ".json"
          Array(JSON.parse(text)).map { |item| Datalog::Citations::Entry.from_csl(item) }
        else
          raise Jekyll::Errors::FatalException, "#{document.relative_path} names the bibliography #{path}, " \
                                                "which is neither BibTeX (.bib) nor CSL-JSON (.json)"
        end
      rescue Datalog::Citations::BibTeX::ParseError, JSON::ParserError => e
        raise Jekyll::Errors::FatalException, "#{path}, the bibliography of #{document.relative_path}: #{e.message}"
      end

      def site_setting(name)
        settings = site.config["citations"]
        settings.is_a?(Hash) ? settings[name] : nil
      end

      # ----------------------------------------------------------- numbering

      # After conversion: resolve every placeholder, in the order the page shows them.
      def number(document)
        content = document.content.to_s
        nocite = document.data["nocite"]
        return unless content.include?('class="datalog-cite"') || nocite

        state = load_state(document)
        style = style(document)
        words = words(document)
        entries = listed_entries(document, state, content, nocite, style)
        labels = Markup.labels(entries, style, words)
        anchors = Markup.anchors(entries)
        backlinks = Hash.new { |hash, key| hash[key] = [] }
        document.content = content.gsub(MARKER) do
          links = Regexp.last_match(1).split.map do |key|
            ref = "cite-ref-#{anchors[key]}-#{backlinks[key].size + 1}"
            backlinks[key] << ref
            %(<a href="#cite-#{anchors[key]}" id="#{ref}">#{CGI.escapeHTML(labels[key])}</a>)
          end
          Markup.marker(links, Markup.locator_text(Regexp.last_match(2), words), style)
        end

        state[:html] = Markup.list_html(entries, labels, anchors, backlinks, style, words)
        publish(document, state,
                "datalog_bibliography" => entries.map(&:key),
                "datalog_cited_works" => entries.map { |entry| { "reference" => entry.highwire, "json_ld" => entry.json_ld } })
      end

      # The cited entries in citation order, then the nocite ones; sorted by
      # author and year in the author-year style.
      def listed_entries(document, state, content, nocite, style)
        cited = content.scan(MARKER).flat_map { |keys, _| keys.split }.uniq
        check_keys(document, state, cited)
        extra = [nocite].flatten.map(&:to_s) == ["all"] ? state[:entries].keys : Array(nocite).map(&:to_s)
        check_keys(document, state, extra, "nocite")
        entries = (cited + (extra - cited)).map { |key| state[:entries][key] }
        style == "author-year" ? entries.sort_by(&:sort_key) : entries
      end

      def check_keys(document, state, keys, tag = "cite")
        missing = keys - state[:entries].keys
        return if missing.empty?

        verb = tag == "nocite" ? "lists in nocite" : "cites"
        raise Jekyll::Errors::FatalException,
              "#{document.relative_path} #{verb} #{missing.map { |key| "\"#{key}\"" }.join(', ')}, which " \
              "#{missing.size == 1 ? 'is' : 'are'} not in its bibliography (#{state[:sources]})"
      end

      def bibliography_html(page)
        state = @state[page["datalog_citation_state"]]
        state && state[:html] ? state[:html] : ""
      end

      # --------------------------------------------------------------- excerpts

      # Jekyll renders an excerpt apart from its post, and on a listing page
      # before the post itself may be converted. Its citations read as they do
      # in the post, linked to the post's bibliography.
      def number_excerpt(excerpt, html)
        return html unless html&.include?('class="datalog-cite"')

        post = excerpt.doc
        state = load_state(post)
        style = style(post)
        words = words(post)
        cited = post.content.to_s.scan(MARKER).flat_map { |keys, _| keys.split }
        cited = source_keys(post) if cited.empty?
        entries = cited.uniq.filter_map { |key| state[:entries][key] }
        entries = entries.sort_by(&:sort_key) if style == "author-year"
        labels = Markup.labels(entries, style, words)
        anchors = Markup.anchors(entries)
        url = "#{post.site.baseurl}#{post.url}"
        html.gsub(MARKER) do
          links = Regexp.last_match(1).split.map do |key|
            next CGI.escapeHTML(key) unless labels[key]

            %(<a href="#{url}#cite-#{anchors[key]}">#{CGI.escapeHTML(labels[key])}</a>)
          end
          Markup.marker(links, Markup.locator_text(Regexp.last_match(2), words), style)
        end
      end

      def source_keys(post)
        source = File.file?(post.path.to_s) ? File.read(post.path, encoding: "bom|utf-8") : ""
        source.scan(SOURCE_TAG).flat_map { |(markup)| Citations.parse_markup(markup).first }
      rescue Liquid::ArgumentError
        []
      end

      # ----------------------------------------------------------- settings

      def style(document)
        value = (document.data["citation_style"] || site_setting("style") || "numeric").to_s
        STYLES.include?(value) ? value : "numeric"
      end

      def words(document)
        locale = Datalog::I18n.locale_code(site, document.data["lang"])
        lookup = ->(key, fallback) { Datalog::I18n.lookup(site, locale, "citations.#{key}") || fallback }
        {
          and: lookup.call("and", "and"), et_al: lookup.call("et_al", "et al."),
          no_date: lookup.call("no_date", "n.d."), back: lookup.call("back", "Back to citation {{n}}"),
          locators: LOCATORS.to_h { |kind| [kind, lookup.call("locators.#{kind}", "#{kind}.")] }
        }
      end

      # --------------------------------------------------------------- search

      # The keys a page cites, for the search index, when the site has search.
      def search_indexing(document)
        return {} unless Datalog::PluginSystem.plugin("datalog-search")

        keys = Array(document.data["datalog_bibliography"])
        return {} if keys.empty?

        { "citations" => { "count" => keys.size, "keys" => keys.sort } }
      end
    end
  end
end

# The tags exist whether or not the plugin is on, so a page that cites on a
# site without it stops with a message saying what to enable, not with
# "Unknown tag 'cite'". The plugin registers them again when it loads.
Liquid::Template.register_tag("cite", Datalog::Plugins::Citations::CiteTag)
Liquid::Template.register_tag("datalog_cite", Datalog::Plugins::Citations::CiteTag)
Liquid::Template.register_tag("datalog_bibliography", Datalog::Plugins::Citations::BibliographyTag)

Jekyll::Hooks.register %i[pages documents], :post_convert do |document|
  Datalog::PluginSystem.plugin("datalog-citations")&.number(document)
end

Jekyll::Excerpt.prepend(Module.new do
  def output
    plugin = Datalog::PluginSystem.plugin("datalog-citations")
    plugin ? plugin.number_excerpt(self, super) : super
  end
end)
