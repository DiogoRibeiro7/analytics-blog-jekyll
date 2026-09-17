# frozen_string_literal: true

require "cgi"

module Datalog
  # Numbered figures and tables, and references to them, within a page:
  #
  #   {% figure id="fig-power" src="/assets/img/power.png" alt="Power curve" %}
  #   Power as a function of effect size $\delta$.
  #   {% endfigure %}
  #
  #   {% table id="tab-runs" %}
  #   Simulation runs by sample size.
  #
  #   | n | runs |
  #   |---|------|
  #   {% endtable %}
  #
  #   As {% ref fig-power %} shows, ...
  #
  # The tags write placeholders. Once the page's Markdown is converted, every
  # target gets its number in the order it appears, so a reference may come
  # before its figure, and each reference becomes a link reading "Figure 2".
  # A duplicate id or a reference to nothing stops the build. Equations are
  # numbered and referenced by MathJax (\label and \eqref) instead.
  #
  # A caption is the body of the tag, not an attribute, so math in it goes
  # through the math preprocessor like the rest of the page.
  module References
    module_function

    # Each kind counts separately; the label comes from _data/i18n.
    KINDS = {
      "figure" => { "key" => "references.figure", "label" => "Figure" },
      "table" => { "key" => "references.table", "label" => "Table" }
    }.freeze
    ID = /\A[A-Za-z][\w.:-]*\z/
    TARGET = /data-ref-target="([^"]+)" data-ref-kind="([a-z]+)"/
    LABEL = %r{<span class="datalog-ref-label" data-ref-for="([^"]+)"></span>}
    LINK = %r{<a class="datalog-ref" href="#([^"]+)" data-ref="\1">[^<]*</a>}

    SOURCE_TARGET = /\{%-?\s*(figure|table)\b[^%]*?\bid=["']([^"']+)["']/

    def number(document)
      content = document.content
      return unless content&.include?("data-ref")

      targets = targets(content.scan(TARGET), document)
      content = content.gsub(LABEL) do
        id = Regexp.last_match(1)
        %(<span class="datalog-ref-label" data-ref-for="#{id}">#{targets.fetch(id)}.</span>)
      end
      document.content = link_references(content, targets, document)
    end

    # Jekyll runs no hooks for an excerpt, and renders it when a template first
    # asks for it, which on a listing page can be before its post is converted.
    # Its references take their numbers from the post: from the converted
    # content when there is one, and otherwise from the tags in the source,
    # which are in the same order. A missing target is the post's error to report.
    def number_excerpt(excerpt, html)
      return html unless html&.include?("data-ref")

      post = excerpt.doc
      found = post.content.to_s.scan(TARGET)
      found = post.content.to_s.scan(SOURCE_TARGET).map(&:reverse) if found.empty?
      targets = targets(found.uniq(&:first), post)
      html.gsub(LINK) do
        id = Regexp.last_match(1)
        text = targets[id] ? CGI.escapeHTML(targets[id]) : id
        %(<a class="datalog-ref" href="#{post.site.baseurl}#{post.url}##{id}" data-ref="#{id}">#{text}</a>)
      end
    end

    # The id => "Figure 2" of every [id, kind] target, numbered per kind in page order.
    def targets(found, document)
      counts = Hash.new(0)
      found.each_with_object({}) do |(id, kind), targets|
        if targets.key?(id)
          raise Jekyll::Errors::FatalException,
                "#{document.relative_path} numbers two figures or tables with the id \"#{id}\"; " \
                "each id has to be unique"
        end

        counts[kind] += 1
        targets[id] = "#{label(document, kind)} #{counts[kind]}"
      end
    end

    def link_references(content, targets, document)
      missing = content.scan(LINK).flatten.uniq - targets.keys
      unless missing.empty?
        raise Jekyll::Errors::FatalException,
              "#{document.relative_path} refers to #{missing.map { |id| "\"#{id}\"" }.join(', ')}, which no figure " \
              "or table on the page has as its id"
      end

      content.gsub(LINK) do
        id = Regexp.last_match(1)
        %(<a class="datalog-ref" href="##{id}" data-ref="#{id}">#{CGI.escapeHTML(targets[id])}</a>)
      end
    end

    def label(document, kind)
      site = document.site
      locale = I18n.locale_code(site, document.data["lang"])
      I18n.lookup(site, locale, KINDS.fetch(kind)["key"]) || KINDS.fetch(kind)["label"]
    end

    def validate_id(id, tag)
      return id if id.to_s.match?(ID)

      raise Liquid::ArgumentError,
            "{% #{tag} %} needs an id that starts with a letter and holds only letters, digits, " \
            "\"-\", \"_\", \".\" or \":\", such as id=\"fig-power\"; got #{id.inspect}"
    end

    # key="value", key='value' or key=variable.
    def attributes(markup, context)
      markup.scan(/(\w+)=(?:"([^"]*)"|'([^']*)'|([\w.\[\]-]+))/).to_h do |key, double, single, variable|
        [key, double || single || context[variable].to_s]
      end
    end

    def markdown(context, text)
      site = context.registers[:site]
      site.find_converter_instance(Jekyll::Converters::Markdown).convert(text.to_s.strip)
    end

    # A caption of one paragraph loses its <p>, which a <figcaption> or <caption> does not need.
    def inline(html)
      html = html.strip
      paragraph = html.match(%r{\A<p>(.*)</p>\z}m)
      paragraph && !paragraph[1].include?("<p>") ? paragraph[1] : html
    end
  end

  class FigureTag < Liquid::Block
    def initialize(tag_name, markup, options)
      super
      @markup = markup
    end

    def render(context)
      attributes = References.attributes(@markup, context)
      id = References.validate_id(attributes["id"], "figure")
      src = attributes["src"].to_s
      raise Liquid::ArgumentError, "{% figure id=\"#{id}\" %} needs a src, the image it shows" if src.empty?
      if attributes["alt"].to_s.strip.empty?
        raise Liquid::ArgumentError, "{% figure id=\"#{id}\" %} needs alt text for its image"
      end

      src = "#{context.registers[:site].config['baseurl'].to_s.chomp('/')}#{src}" if src.start_with?("/")
      caption = References.inline(References.markdown(context, super))
      classes = ["datalog-figure", attributes["class"]].compact.join(" ")

      alt = CGI.escapeHTML(attributes["alt"])
      %(<figure class="#{CGI.escapeHTML(classes)}" id="#{id}" data-ref-target="#{id}" data-ref-kind="figure">) +
        %(<img src="#{CGI.escapeHTML(src)}" alt="#{alt}" loading="lazy" decoding="async">) +
        %(<figcaption><span class="datalog-ref-label" data-ref-for="#{id}"></span> #{caption}</figcaption></figure>\n)
    end
  end

  class TableTag < Liquid::Block
    def initialize(tag_name, markup, options)
      super
      @markup = markup
    end

    # The body holds the caption and then a Markdown table.
    def render(context)
      id = References.validate_id(References.attributes(@markup, context)["id"], "table")
      html = References.markdown(context, super)
      tables = html.scan(/<table\b/).size
      unless tables == 1
        raise Liquid::ArgumentError, "{% table id=\"#{id}\" %} holds #{tables} tables; it needs one, after its caption"
      end

      caption, table = html.split(/(?=<table\b)/, 2)
      caption = References.inline(caption)
      numbered = table.sub(/<table\b([^>]*)>/) do
        %(<table#{Regexp.last_match(1)} id="#{id}" data-ref-target="#{id}" data-ref-kind="table">) +
          %(<caption><span class="datalog-ref-label" data-ref-for="#{id}"></span> #{caption}</caption>)
      end
      "#{numbered.strip}\n"
    end
  end

  class ReferenceTag < Liquid::Tag
    def initialize(tag_name, markup, options)
      super
      @id = References.validate_id(markup.strip, "ref")
    end

    def render(_context)
      %(<a class="datalog-ref" href="##{@id}" data-ref="#{@id}">#{@id}</a>)
    end
  end
end

Liquid::Template.register_tag("figure", Datalog::FigureTag)
Liquid::Template.register_tag("table", Datalog::TableTag)
Liquid::Template.register_tag("ref", Datalog::ReferenceTag)

Jekyll::Hooks.register %i[pages documents], :post_convert do |document|
  Datalog::References.number(document)
end

Jekyll::Excerpt.prepend(Module.new do
  # Excerpt#output renders once and keeps the result; numbering it is a quick gsub.
  def output
    Datalog::References.number_excerpt(self, super)
  end
end)
