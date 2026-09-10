# frozen_string_literal: true

require "json"
require "time"
require "pathname"
require "fileutils"
require "cgi"
require "loofah"
require "base64"

module Datalog
  module NotebookRenderer
    module_function

    NOTEBOOK_SANITIZE_CONFIG = {
      elements: %w[
        h1 h2 h3 h4 h5 h6 p br ul ol li
        strong em code pre blockquote
        a img table thead tbody tr td th
        div span
      ],
      attributes: {
        "a" => %w[href title],
        "img" => %w[src alt title width height],
        "code" => ["class"],
        "pre" => ["class"],
        "div" => ["class"]
      },
      protocols: {
        "a" => { "href" => %w[http https mailto] },
        "img" => { "src" => %w[http https data] }
      }
    }.freeze

    MAX_DATA_URI_BYTES = 256_000
    SAFE_IFRAME_ATTRIBUTES = %w[src title width height loading sandbox allow allowfullscreen referrerpolicy].freeze
    SAFE_DATA_ATTRIBUTE_PATTERN = /\Adata-[a-z0-9-]+\z/i
    SAFE_CLASS_TOKEN_PATTERN = /\A[a-z0-9_-]+\z/i
    MATH_DELIMITERS = ["(", ")", "[", "]", "$$"].freeze
    VIZ_DATA_ATTRIBUTE_MAX_LENGTH = 4_096

    def sanitization_metrics
      @sanitization_metrics ||= Hash.new do |hash, key|
        hash[key] = { fragments: 0, removed_nodes: 0, removed_attributes: 0 }
      end
    end

    def reset_sanitization_metrics!
      @sanitization_metrics = nil
      sanitization_metrics
    end

    def sanitization_metrics_snapshot
      sanitization_metrics.transform_values(&:dup)
    end

    def render(notebook, metadata: {}, site: nil)
      cells = Array(notebook["cells"])
      return if cells.empty?

      fragments = cells.each_with_index.filter_map do |cell, index|
        source = Array(cell["source"]).join
        next if source.strip.empty?

        case cell["cell_type"]
        when "markdown"
          render_markdown(source, site, cell_index: index, metadata: metadata)
        when "code"
          render_code(cell, source, metadata, site, index)
        end
      end

      return if fragments.empty?

      fragments.join("\n")
    end

    def render_from_raw(raw, metadata: {}, site: nil)
      notebook = JSON.parse(raw)
      render(notebook, metadata: metadata, site: site)
    rescue JSON::ParserError
      nil
    end

    def render_markdown(source, site, cell_index:, metadata: {})
      html = if (converter = markdown_converter(site))
               converter.convert(source)
             else
               %(<p>#{CGI.escapeHTML(source)}</p>)
             end

      meta = metadata.respond_to?(:merge) ? metadata.merge(kind: :markdown) : { kind: :markdown }
      sanitized = sanitize_html(html, context: :markdown, site: site,
                                      metadata: build_sanitization_metadata(meta, cell_index: cell_index))
      return if sanitized.to_s.strip.empty?

      %(<section class="notebook-cell notebook-cell--markdown">\n#{sanitized}\n</section>)
    end

    # Class names mirror the theme stylesheet (`.notebook-cell--input`,
    # `.notebook-cell__code` and `.notebook-cell__outputs` in _sass/_components.scss).
    def render_code(cell, source, metadata, site, cell_index)
      language = cell.dig("metadata", "language") || metadata[:language] || "text"
      code_html = %(<pre class="notebook-cell__code"><code class="language-#{language}">#{CGI.escapeHTML(source)}</code></pre>)
      base_metadata = metadata.respond_to?(:merge) ? metadata.merge(language: language) : { language: language }
      outputs_html = render_outputs(Array(cell["outputs"]), site: site, cell_index: cell_index, metadata: base_metadata)
      outputs_html = %(\n<div class="notebook-cell__outputs">\n#{outputs_html}\n</div>) unless outputs_html.empty?
      %(<section class="notebook-cell notebook-cell--input">\n#{code_html}#{outputs_html}\n</section>)
    end

    def render_outputs(outputs, site:, cell_index:, metadata:)
      return "" if outputs.empty?

      base_metadata = metadata.respond_to?(:merge) ? metadata.merge(kind: :output) : { kind: :output }
      rendered = outputs.each_with_index.filter_map do |output, output_index|
        render_output(output, site: site, cell_index: cell_index, output_index: output_index, metadata: base_metadata)
      end

      rendered.join("\n")
    rescue StandardError
      ""
    end

    def render_output(output, site:, cell_index:, output_index:, metadata:)
      context = build_sanitization_metadata(metadata, cell_index: cell_index, output_index: output_index)

      if (html = extract_html_output(output))
        html_metadata = context.merge(mime: "text/html")
        sanitized = sanitize_visualization_html(html, site: site, metadata: html_metadata)
        return if sanitized.to_s.strip.empty?

        return %(<div class="notebook-output notebook-output--html">#{sanitized}</div>)
      end

      if (image_data = image_output_html(output))
        image_html, image_mime = image_data
        image_metadata = context.merge(kind: :image, mime: image_mime)
        sanitized = sanitize_html(image_html, context: :output, site: site, metadata: image_metadata)
        return if sanitized.to_s.strip.empty?

        return %(<div class="notebook-output notebook-output--image">#{sanitized}</div>)
      end

      text = extract_output_text(output)
      return if text.to_s.strip.empty?

      %(<div class="notebook-output notebook-output--text"><pre>#{CGI.escapeHTML(text)}</pre></div>)
    end

    def extract_html_output(output)
      html = output.dig("data", "text/html")
      return unless html

      Array(html).join
    end

    def image_output_html(output)
      data = output["data"] || {}

      if (png = data["image/png"])
        html = %(<img src="data:image/png;base64,#{Array(png).join}" alt="Notebook output" />)
        return [html, "image/png"]
      elsif (jpeg = data["image/jpeg"])
        html = %(<img src="data:image/jpeg;base64,#{Array(jpeg).join}" alt="Notebook output" />)
        return [html, "image/jpeg"]
      elsif (svg = data["image/svg+xml"])
        encoded = Base64.strict_encode64(Array(svg).join)
        html = %(<img src="data:image/svg+xml;base64,#{encoded}" alt="Notebook output" />)
        return [html, "image/svg+xml"]
      end

      nil
    end

    def extract_output_text(output)
      if output["text"]
        Array(output["text"]).join
      elsif output.dig("data", "text/plain")
        Array(output.dig("data", "text/plain")).join
      else
        ""
      end
    end

    def sanitize_visualization_html(html, site:, metadata:)
      sanitized = sanitize_html(html, context: :visualization, site: site, metadata: metadata)
      enforce_visualization_rules(sanitized, metadata, site: site)
    end

    def sanitize_html(html, context:, site:, metadata: {})
      fragment_source = html.to_s
      protected_html, math_replacements = protect_mathjax_delimiters(fragment_source)
      fragment = Loofah.fragment(protected_html)

      removed_nodes = 0
      removed_attributes = 0

      fragment.traverse do |node|
        next unless node.element?

        unless allowed_element?(node)
          node.remove
          removed_nodes += 1
          next
        end

        removed_attributes += sanitize_node_attributes(node)

        next unless node.name == "iframe"

        unless iframe_has_valid_src?(node)
          node.remove
          removed_nodes += 1
          next
        end

        enforce_iframe_defaults(node)
      end

      sanitized = fragment.to_html
      sanitized = restore_mathjax_delimiters(sanitized, math_replacements)

      record_sanitization(context, nodes_removed: removed_nodes, attrs_removed: removed_attributes)
      log_sanitization(context, metadata, removed_nodes, removed_attributes, site)

      sanitized
    rescue StandardError => e
      log_sanitization_error(context, metadata, e)
      CGI.escapeHTML(html.to_s)
    end

    def enforce_visualization_rules(html, metadata, site: nil)
      fragment = Loofah.fragment(html)
      removed_attributes = 0
      removed_nodes = 0

      fragment.css("[class]").each do |node|
        next unless viz_element?(node)

        node.attribute_nodes.each do |attr|
          next if attr.name == "class"

          if attr.name.start_with?("data-")
            next if safe_data_attribute?(attr.name, attr.value)

            attr.remove
            removed_attributes += 1
            next
          end

          next if node.name == "iframe" && SAFE_IFRAME_ATTRIBUTES.include?(attr.name)

          attr.remove
          removed_attributes += 1
        end
      end

      fragment.css("iframe").each do |iframe|
        unless iframe_has_valid_src?(iframe)
          iframe.remove
          removed_nodes += 1
          next
        end

        enforce_iframe_defaults(iframe)
      end

      sanitized = fragment.to_html

      if removed_attributes.positive? || removed_nodes.positive?
        record_sanitization(:visualization, nodes_removed: removed_nodes, attrs_removed: removed_attributes,
                                            increment_fragment: false)
        log_sanitization(:visualization, metadata, removed_nodes, removed_attributes, site)
      end

      sanitized
    end

    def build_sanitization_metadata(metadata, cell_index:, output_index: nil)
      context = { cell_index: cell_index }
      context[:output_index] = output_index if output_index

      if metadata.respond_to?(:[])
        context[:notebook] = metadata[:slug] || metadata["slug"] if metadata[:slug] || metadata["slug"]
        context[:language] = metadata[:language] || metadata["language"] if metadata[:language] || metadata["language"]
        context[:kind] = metadata[:kind] || metadata["kind"] if metadata[:kind] || metadata["kind"]
        context[:mime] = metadata[:mime] || metadata["mime"] if metadata[:mime] || metadata["mime"]
      end

      context
    end

    def allowed_element?(node)
      NOTEBOOK_SANITIZE_CONFIG[:elements].include?(node.name) || node.name == "iframe"
    end

    def sanitize_node_attributes(node)
      removed = 0

      allowed_attrs = Array(NOTEBOOK_SANITIZE_CONFIG[:attributes][node.name]).dup
      allowed_attrs << "class" if %w[div span code pre].include?(node.name)

      if node.name == "iframe"
        allowed_attrs = SAFE_IFRAME_ATTRIBUTES.dup
        allowed_attrs << "class"
      end

      node.attribute_nodes.each do |attr|
        name = attr.name
        value = attr.value.to_s

        if name == "class"
          removed += sanitize_class_attribute(attr)
          next
        end

        if node.name == "iframe"
          unless SAFE_IFRAME_ATTRIBUTES.include?(name)
            attr.remove
            removed += 1
            next
          end

          removed += sanitize_iframe_attribute(node, attr)
          next
        end

        if allowed_attrs.include?(name)
          if %w[width height].include?(name)
            cleaned = sanitize_dimension_value(value)
            if cleaned
              attr.value = cleaned
            else
              attr.remove
              removed += 1
            end
            next
          end

          if name == "src" && node.name == "img"
            unless safe_image_src?(value)
              attr.remove
              removed += 1
            end
            next
          end

          if requires_protocol_validation?(node.name, name)
            unless safe_url?(value, NOTEBOOK_SANITIZE_CONFIG[:protocols][node.name][name])
              attr.remove
              removed += 1
            end
            next
          end

          next
        end

        next if allow_data_attribute?(node, name, value)

        attr.remove
        removed += 1
      end

      removed
    end

    def sanitize_iframe_attribute(_node, attr)
      name = attr.name
      value = attr.value.to_s

      case name
      when "src"
        return 1 unless safe_url?(value, %w[http https])
      when "sandbox"
        attr.value = sanitize_sandbox_value(value)
      when "allow"
        attr.value = sanitize_allow_value(value)
      when "allowfullscreen"
        attr.value = "true" if value.to_s.strip.casecmp("true").zero?
      when "loading"
        attr.value = sanitize_loading_value(value)
      when "referrerpolicy"
        attr.value = sanitize_referrer_policy(value)
      when "width", "height"
        cleaned = sanitize_dimension_value(value)
        if cleaned
          attr.value = cleaned
        else
          attr.remove
          return 1
        end
      end

      0
    end

    def sanitize_sandbox_value(value)
      requested = value.to_s.split(/\s+/)
      allowed = requested & %w[allow-same-origin allow-scripts allow-popups allow-forms]
      allowed = %w[allow-scripts allow-same-origin] if allowed.empty?
      allowed.join(" ")
    end

    def sanitize_allow_value(value)
      requested = value.to_s.split(/;\s*/)
      safe = requested.grep(/\A[a-z0-9:-]+\z/i)
      safe.join("; ")
    end

    def sanitize_loading_value(value)
      token = value.to_s.strip.downcase
      return "lazy" if token.empty?
      return token if %w[lazy eager auto].include?(token)

      "lazy"
    end

    def sanitize_referrer_policy(value)
      token = value.to_s.strip.downcase
      return token if %w[no-referrer origin same-origin strict-origin strict-origin-when-cross-origin
                         origin-when-cross-origin unsafe-url].include?(token)

      "no-referrer"
    end

    def sanitize_class_attribute(attr)
      tokens = attr.value.to_s.split(/\s+/).map(&:strip).reject(&:empty?)
      safe = tokens.grep(SAFE_CLASS_TOKEN_PATTERN)
      if safe.empty?
        attr.remove
        return 1
      end

      attr.value = safe.join(" ")
      0
    end

    def sanitize_dimension_value(value)
      stripped = value.to_s.strip
      return stripped if stripped.empty?
      return stripped if stripped.match?(/\A\d{1,4}\z/)
      return stripped if stripped.match?(/\A\d{1,3}%\z/)

      nil
    end

    def requires_protocol_validation?(tag, attribute)
      NOTEBOOK_SANITIZE_CONFIG[:protocols].key?(tag) && NOTEBOOK_SANITIZE_CONFIG[:protocols][tag].key?(attribute)
    end

    def safe_image_src?(value)
      return false if value.to_s.strip.empty?
      return valid_data_uri?(value) if value.start_with?("data:")
      return false if value =~ /\Ajavascript:/i

      true
    end

    def valid_data_uri?(uri)
      match = uri.match(%r{\Adata:([a-z0-9\-.+/]+);base64,(.*)\z}i)
      return false unless match

      data = match[2]
      decoded = Base64.strict_decode64(data)
      decoded.bytesize <= MAX_DATA_URI_BYTES
    rescue ArgumentError
      false
    end

    def safe_url?(value, allowed_protocols)
      uri = value.to_s.strip
      return true if uri.empty?
      return false if uri =~ /\Ajavascript:/i
      return true if uri.start_with?("#") || uri.start_with?("/")

      scheme = uri[/\A([a-z0-9.+-]+):/i, 1]

      if scheme.nil?
        true
      elsif scheme.casecmp("data").zero?
        allowed_protocols&.include?("data") && valid_data_uri?(uri)
      else
        allowed_protocols&.include?(scheme.downcase)
      end
    end

    def allow_data_attribute?(node, name, value)
      return false unless name.start_with?("data-")
      return false unless viz_element?(node)
      return false unless SAFE_DATA_ATTRIBUTE_PATTERN.match?(name)

      sanitized_value = value.to_s
      return false if sanitized_value.length > VIZ_DATA_ATTRIBUTE_MAX_LENGTH
      return false if sanitized_value =~ /javascript:/i
      return false if sanitized_value.include?("<") || sanitized_value.include?(">")

      true
    end

    def safe_data_attribute?(name, value)
      return false unless SAFE_DATA_ATTRIBUTE_PATTERN.match?(name)

      sanitized_value = value.to_s
      return false if sanitized_value.length > VIZ_DATA_ATTRIBUTE_MAX_LENGTH
      return false if sanitized_value =~ /javascript:/i
      return false if sanitized_value.include?("<") || sanitized_value.include?(">")

      true
    end

    def viz_element?(node)
      classes = node["class"].to_s.split(/\s+/)
      classes.any? { |token| token.start_with?("viz-") }
    end

    def iframe_has_valid_src?(node)
      return false unless node["src"]

      safe_url?(node["src"], %w[http https])
    end

    def enforce_iframe_defaults(node)
      node["sandbox"] = sanitize_sandbox_value(node["sandbox"]) unless node["sandbox"]
      node["loading"] = "lazy" unless node["loading"]
      node["referrerpolicy"] = "no-referrer" unless node["referrerpolicy"]
    end

    def record_sanitization(context, nodes_removed:, attrs_removed:, increment_fragment: true)
      metrics = sanitization_metrics[context.to_sym]
      metrics[:fragments] += 1 if increment_fragment
      metrics[:removed_nodes] += nodes_removed
      metrics[:removed_attributes] += attrs_removed
    end

    def log_sanitization(context, metadata, nodes_removed, attrs_removed, site)
      return if nodes_removed.zero? && attrs_removed.zero?

      logger = sanitizer_logger
      return unless logger

      message = "sanitized #{context} fragment (removed #{nodes_removed} elements, #{attrs_removed} attributes)"
      detail = format_sanitization_metadata(metadata)
      message = "#{message} #{detail}" if detail

      if current_env(site) == "development"
        logger.info("notebook sanitizer", message)
      elsif logger.respond_to?(:debug?)
        logger.debug("notebook sanitizer", message)
      end
    end

    def log_sanitization_error(context, metadata, error)
      logger = sanitizer_logger
      return unless logger

      detail = format_sanitization_metadata(metadata)
      message = "failed to sanitize #{context} fragment"
      message = "#{message} #{detail}" if detail
      logger.warn("notebook sanitizer", "#{message}: #{error.message}")
    end

    def sanitizer_logger
      return unless defined?(Jekyll)

      Jekyll.logger
    rescue StandardError
      nil
    end

    def current_env(_site = nil)
      if defined?(Jekyll) && Jekyll.respond_to?(:env)
        Jekyll.env
      else
        ENV.fetch("JEKYLL_ENV", "development")
      end
    rescue StandardError
      "development"
    end

    def format_sanitization_metadata(metadata)
      return unless metadata.respond_to?(:[])

      details = []
      details << "(cell #{metadata[:cell_index]})" if metadata[:cell_index]
      details << "(output #{metadata[:output_index]})" if metadata[:output_index]
      details << "[#{metadata[:notebook]}]" if metadata[:notebook]
      details << "{#{metadata[:language]}}" if metadata[:language]
      return if details.empty?

      details.join(" ")
    end

    def protect_mathjax_delimiters(html)
      replacements = {}
      index = 0

      protected = html.to_s.gsub(/\\(|\\)|\\[|\\]|\$\$/) do |match|
        key = "__MATH_DELIM_#{index}__"
        replacements[key] = match
        index += 1
        key
      end

      [protected, replacements]
    end

    def restore_mathjax_delimiters(html, replacements)
      restored = html.to_s
      replacements.each do |token, original|
        restored = restored.gsub(token, original)
      end
      restored
    end

    def summary_html(summary)
      text = summary.to_s.strip
      return if text.empty?

      %(<section class="notebook-cell notebook-cell--summary"><p>#{CGI.escapeHTML(text)}</p></section>)
    end

    def markdown_converter(site)
      return unless site

      @markdown_converters ||= {}
      @markdown_converters[site.object_id] ||= site.find_converter_instance(Jekyll::Converters::Markdown)
    rescue StandardError
      nil
    end

    def patch_jupyter_converter!
      return unless defined?(JekyllJupyterNotebook::Converter)
      return if @converter_fallback_applied

      fallback = Module.new do
        def convert(content)
          super
        rescue Errno::ENOENT, StandardError => e
          Jekyll.logger.warn("notebook converter", "primary conversion failed: #{e.message}; using fallback renderer")
          Datalog::NotebookRenderer.render_from_raw(content) || ""
        end
      end

      JekyllJupyterNotebook::Converter.prepend(fallback)
      @converter_fallback_applied = true
    rescue StandardError => e
      Jekyll.logger.warn("notebook converter", "failed to apply converter fallback: #{e.message}")
    end
  end
end

Jekyll::Hooks.register :site, :after_init do |_site|
  Datalog::NotebookRenderer.patch_jupyter_converter!
end

module Jekyll
  # Converts Jupyter notebooks into HTML pages and downloadable assets.
  class NotebookConverter < Generator
    safe true
    priority :low

    def generate(site)
      @site = site
      @config = build_config(site)

      Datalog::NotebookRenderer.reset_sanitization_metrics!

      unless config["enabled"]
        logger.debug("notebook converter", "disabled via configuration")
        return
      end

      ensure_dependency

      files = notebook_files
      logger.debug("notebook converter", "located #{files.size} notebooks")
      return if files.empty?

      index_entries = []

      files.each do |path|
        process_notebook(path, index_entries)
      end

      site.data["notebook_sanitization"] = Datalog::NotebookRenderer.sanitization_metrics_snapshot
      site.data["datalog_notebooks"] = index_entries if index_entries.any?
    rescue StandardError => e
      logger.error("notebook converter", "unexpected error: #{e.message}")
      debug_backtrace(e)
    end

    private

    attr_reader :site, :config

    def build_config(site)
      defaults = {
        "enabled" => true,
        "source" => "_notebooks",
        "output" => "notebooks",
        "download_dir" => "notebooks",
        "default_layout" => "notebook",
        "collection" => "notebooks",
        "permalink_base" => "/notebooks"
      }

      merged = defaults.merge(site.config.fetch("notebooks", {}))
      merged["source"] = merged["source"].to_s
      merged["output"] = merged["output"].to_s
      merged["download_dir"] = merged["download_dir"].to_s
      merged["permalink_base"] = normalized_base_path(merged["permalink_base"])
      merged["collection"] = merged["collection"].to_s
      merged["default_layout"] = merged["default_layout"].to_s
      merged
    end

    def normalized_base_path(base)
      value = base.to_s.strip
      value = "/notebooks" if value.empty?
      value = "/#{value}" unless value.start_with?("/")
      value.sub(%r{/+$}, "")
    end

    # Notebook pages do not need the gem (see #convert_notebook). When it is
    # present, its converter is given the same renderer as a fallback so the
    # gem's own `.ipynb` handling and `{% jupyter_notebook %}` tag keep working
    # on machines without a `jupyter` executable.
    def ensure_dependency
      return true if defined?(JekyllJupyterNotebook::Converter)

      require "jekyll-jupyter-notebook"
      Datalog::NotebookRenderer.patch_jupyter_converter!
      true
    rescue LoadError => e
      logger.debug("notebook converter", "jekyll-jupyter-notebook not loaded: #{e.message}")
      false
    end

    def notebook_files
      glob = File.join(site.source, config["source"], "**", "*.ipynb")
      Dir.glob(glob)
    end

    def process_notebook(path, index_entries)
      relative_path = Pathname.new(path).relative_path_from(Pathname.new(site.source)).to_s
      raw = File.binread(path)
      notebook = JSON.parse(raw)

      metadata = extract_metadata(notebook, path, relative_path)
      html = convert_notebook(notebook, metadata, relative_path)
      html ||= Datalog::NotebookRenderer.summary_html(metadata[:summary])
      return unless html

      page = build_page(metadata, html)
      site.pages << page
      attach_to_collection(page)
      register_download(path, metadata)

      search_entry = build_search_entry(metadata)
      index_entries << search_entry if search_entry
      page.data["datalog_search_extensions"] = { "notebook" => search_entry }.compact
    rescue JSON::ParserError => e
      logger.error("notebook converter", "failed to parse #{relative_path}: #{e.message}")
      debug_backtrace(e)
    rescue StandardError => e
      logger.error("notebook converter", "failed to process #{relative_path}: #{e.message}")
      debug_backtrace(e)
    end

    # Pages are rendered by Datalog::NotebookRenderer rather than by
    # `jupyter nbconvert`. Its output is sanitized (tests/test_notebook_sanitization.rb),
    # carries no inline scripts or styles for the CSP to block, uses the
    # `.notebook-cell` markup the stylesheet styles, and does not change shape
    # between nbconvert releases.
    def convert_notebook(notebook, metadata, relative_path)
      Datalog::NotebookRenderer.render(notebook, metadata: metadata, site: site)
    rescue StandardError => e
      logger.error("notebook converter", "conversion failed for #{relative_path}: #{e.message}")
      debug_backtrace(e)
      nil
    end

    def extract_metadata(notebook, absolute_path, relative_path)
      meta = notebook.fetch("metadata", {})
      cells = Array(notebook["cells"])

      title = meta["title"] || meta.dig("datalog", "title") || first_heading_from(cells)
      # An explicit slug wins so a notebook's URL can stay stable when its title
      # changes, and so it can follow the file name the collection permalink
      # (/notebooks/:name/) advertises.
      explicit_slug = meta["slug"] || meta.dig("datalog", "slug")
      slug_source = explicit_slug || title || File.basename(absolute_path, ".ipynb")
      slug = Jekyll::Utils.slugify(slug_source)
      title ||= slug_source.split(/[-_]/).map(&:capitalize).join(" ")

      summary = summary_from(cells)
      tags = Array(meta["tags"] || meta["keywords"]).map(&:to_s).reject(&:empty?).uniq
      authors = extract_authors(meta)
      kernelspec = (meta["kernelspec"] || {}).dup
      language_info = (meta["language_info"] || {}).dup
      language = kernelspec["language"] || language_info["name"]

      execution_meta = meta["execution_info"] || meta["execution"] || meta.dig("datalog", "execution") || {}
      executed_at = parse_time(execution_meta["finished_at"] || execution_meta["timestamp"] || meta["modified"])
      executed_at ||= File.mtime(absolute_path)
      duration = format_duration(execution_meta["duration"] || meta.dig("datalog", "duration"))

      counts = count_cells(cells)
      git = git_info(absolute_path)
      integrations = build_integrations(relative_path)

      download_dir = config["download_dir"].sub(%r{^/}, "")
      download_url = File.join("/", download_dir, "#{slug}.ipynb")
      permalink = File.join(config["permalink_base"], "#{slug}/")

      {
        title: title,
        slug: slug,
        summary: summary,
        tags: tags,
        authors: authors,
        kernelspec: kernelspec,
        language_info: language_info,
        language: language,
        counts: counts,
        executed_at: executed_at,
        duration: duration,
        git: git,
        integrations: integrations,
        download_url: download_url,
        permalink: permalink,
        relative_source: relative_path,
        absolute_path: absolute_path,
        date: executed_at,
        last_modified_at: git[:last_modified_at] || executed_at
      }
    end

    def extract_authors(meta)
      Array(meta["authors"]).map do |entry|
        case entry
        when String
          entry.strip
        when Hash
          entry["name"] || entry["full_name"] || entry["email"]
        end
      end.compact.reject(&:empty?)
    end

    def count_cells(cells)
      code = 0
      markdown = 0
      errors = 0

      cells.each do |cell|
        case cell["cell_type"]
        when "code"
          code += 1
          outputs = Array(cell["outputs"])
          errors += 1 if outputs.any? { |output| output["output_type"] == "error" }
        when "markdown"
          markdown += 1
        end
      end

      { code: code, markdown: markdown, errors: errors }
    end

    def summary_from(cells)
      first_markdown = cells.find { |cell| cell["cell_type"] == "markdown" }
      return unless first_markdown

      text = Array(first_markdown["source"]).join
      text = text.gsub(/^#.+$/, "").strip
      text.split(/\n\n+/).first&.strip
    end

    def first_heading_from(cells)
      cells.each do |cell|
        next unless cell["cell_type"] == "markdown"

        Array(cell["source"]).each do |line|
          next unless line.is_a?(String)

          stripped = line.strip
          next unless stripped.start_with?("#")

          heading = stripped.gsub(/^#+\s*/, "")
          return heading unless heading.empty?
        end
      end
      nil
    end

    def parse_time(value)
      return if value.nil?

      case value
      when Time
        value
      when Numeric
        Time.at(value)
      when String
        Time.parse(value)
      end
    rescue ArgumentError
      nil
    end

    def format_duration(value)
      numeric =
        case value
        when Numeric
          value.to_f
        when String
          stripped = value.strip
          if stripped =~ /\A\d+(?:\.\d+)?\z/
            stripped.to_f
          elsif stripped =~ /\A\d{2}:\d{2}:\d{2}\z/
            h, m, s = stripped.split(":").map(&:to_i)
            (h * 3600) + (m * 60) + s
          else
            return stripped
          end
        else
          return nil
        end

      hours = (numeric / 3600).floor
      minutes = ((numeric % 3600) / 60).floor
      seconds = (numeric % 60).round

      parts = []
      parts << "#{hours}h" if hours.positive?
      parts << "#{minutes}m" if minutes.positive?
      parts << "#{seconds}s" if seconds.positive? || parts.empty?
      parts.join(" ")
    end

    def git_info(path)
      return { last_commit: nil, last_modified_at: nil } unless File.exist?(path)

      command = ["git", "log", "-1", "--format=%H|%ad", "--date=iso-strict", path]
      output = IO.popen(command, &:read).to_s.strip
      return { last_commit: nil, last_modified_at: nil } if output.empty?

      commit, timestamp = output.split("|", 2)
      { last_commit: commit, last_modified_at: parse_time(timestamp) }
    rescue StandardError
      { last_commit: nil, last_modified_at: nil }
    end

    def build_integrations(relative_source)
      repo_url = config["repository"] || site.config["repository_url"] || site.config.dig("github", "repository_url") ||
                 site.config.dig("github", "url") || site.config.dig("social", "github_url")
      return {} unless repo_url

      clean_repo = repo_url.gsub(/\.git$/, "")
      repo_slug = clean_repo.split("github.com/").last
      return {} unless repo_slug

      branch = config.fetch("branch", "main")
      binder_template = config.dig("binder", "base_url") || "https://mybinder.org/v2/gh/%{slug}/%{branch}?labpath=%{path}"
      colab_template = config.dig("colab", "base_url") || "https://colab.research.google.com/github/%{slug}/blob/%{branch}/%{path}"

      {
        "binder" => format(binder_template, slug: repo_slug, branch: branch, path: relative_source),
        "colab" => format(colab_template, slug: repo_slug, branch: branch, path: relative_source),
        "repository" => clean_repo,
        "branch" => branch,
        "source" => File.join(clean_repo, "blob", branch, relative_source)
      }
    rescue KeyError, StandardError
      {}
    end

    def build_page(metadata, html)
      dir = File.join(config["output"], metadata[:slug])
      page = NotebookPage.new(site, site.source, dir, "index.html")
      page.content = html
      page.data["layout"] = config["default_layout"].empty? ? "notebook" : config["default_layout"]
      page.data["title"] = metadata[:title]
      page.data["description"] = metadata[:summary]
      page.data["summary"] = metadata[:summary]
      page.data["excerpt"] = metadata[:summary]
      page.data["tags"] = metadata[:tags]
      page.data["categories"] = Array(page.data["categories"]) | ["notebook"]
      page.data["language"] = metadata[:language]
      page.data["permalink"] = metadata[:permalink]
      page.data["date"] = metadata[:date]
      page.data["last_modified_at"] = metadata[:last_modified_at]
      page.data["collection"] = config["collection"] unless config["collection"].empty?
      page.data["author"] ||= metadata[:authors].first || site.config.dig("author", "name")
      page.data["notebook_post"] = true

      page.data["notebook"] = {
        "authors" => metadata[:authors],
        "kernelspec" => metadata[:kernelspec],
        "language_info" => metadata[:language_info],
        "language" => metadata[:language],
        "code_cells" => metadata.dig(:counts, :code),
        "markdown_cells" => metadata.dig(:counts, :markdown),
        "error_cells" => metadata.dig(:counts, :errors),
        "executed_at" => metadata[:executed_at],
        "duration" => metadata[:duration],
        "download" => metadata[:download_url],
        "source" => metadata[:relative_source],
        "git" => metadata[:git],
        "integrations" => metadata[:integrations]
      }

      page
    end

    def attach_to_collection(page)
      collection = config["collection"].empty? ? nil : site.collections[config["collection"]]
      return unless collection
      # Only attach to collection if collection output is enabled to avoid conflicts
      return unless collection.metadata["output"]

      return if collection.docs.include?(page)

      collection.docs << page
      collection.docs.sort_by! do |doc|
        (doc.respond_to?(:date) ? doc.date : doc.data["date"]) || Time.at(0)
      end
      collection.docs.reverse!
    end

    def register_download(source_path, metadata)
      dir = config["download_dir"].sub(%r{^/}, "")
      download = NotebookDownload.new(site, source_path, dir, metadata[:slug])

      unless site.static_files.any? do |static|
        static.is_a?(NotebookDownload) && static.name == download.name && static.dir == download.dir
      end
        site.static_files << download
      end
    end

    def build_search_entry(metadata)
      {
        "title" => metadata[:title],
        "summary" => metadata[:summary],
        "url" => metadata[:permalink],
        "tags" => metadata[:tags],
        "authors" => metadata[:authors],
        "download" => metadata[:download_url],
        "kernelspec" => metadata[:kernelspec],
        "language" => metadata[:language],
        "code_cells" => metadata.dig(:counts, :code),
        "markdown_cells" => metadata.dig(:counts, :markdown),
        "error_cells" => metadata.dig(:counts, :errors),
        "executed_at" => metadata[:executed_at]&.iso8601,
        "duration" => metadata[:duration],
        "git" => metadata[:git].merge("last_modified_at" => metadata[:git][:last_modified_at]&.iso8601),
        "integrations" => metadata[:integrations]
      }
    rescue StandardError => e
      logger.warn("notebook converter", "unable to build search metadata for #{metadata[:slug]}: #{e.message}")
      debug_backtrace(e)
      nil
    end

    def logger
      Jekyll.logger
    end

    def debug_backtrace(error)
      return unless logger.respond_to?(:debug?) && logger.debug?

      Array(error.backtrace).each do |line|
        logger.debug("notebook converter", line)
      end
    end
  end

  class NotebookPage < PageWithoutAFile
  end

  class NotebookDownload < StaticFile
    def initialize(site, source_path, download_dir, slug)
      @site = site
      @base = site.source
      @source_path = source_path
      relative_dir = File.dirname(source_path.sub(%r{^#{Regexp.escape(site.source)}/}, ""))
      relative_name = File.basename(source_path)
      super(site, site.source, relative_dir, relative_name)
      @dir = download_dir
      @name = "#{slug}.ipynb"
    end

    def destination(dest)
      File.join(dest, @dir, @name)
    end

    def write(dest)
      FileUtils.mkdir_p(File.dirname(destination(dest)))
      FileUtils.cp(@source_path, destination(dest))
      true
    rescue StandardError => e
      Jekyll.logger.warn("notebook converter", "failed to copy #{@source_path} to #{destination(dest)}: #{e.message}")
      false
    end
  end
end
