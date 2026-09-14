# frozen_string_literal: true

require_relative "test_helper"

class ContentSecurityPolicyTest < Minitest::Test
  def setup
    @site = SiteBuilder.site
    @destination = @site.dest
  end

  def test_nonces_are_unique_per_document
    nonces = html_documents.map { |doc| doc.data["csp_nonce"] }.compact
    refute_empty nonces, "Expected CSP generator to assign nonces"
    assert_equal nonces.length, Set.new(nonces).length, "Expected each document to receive a unique nonce"
  end

  def test_policy_excludes_unsafe_inline
    homepage = SiteBuilder.read("index.html")
    refute_includes homepage, "'unsafe-inline'", "CSP policy should not rely on unsafe-inline allowances"
  end

  # Embeds from any host but Observable were refused; sites list their hosts
  # under csp.frame_src, and the demo lists its Shiny host.
  def test_frame_src_includes_configured_hosts
    policy = SiteBuilder.read("index.html")[/<meta http-equiv="Content-Security-Policy" content="([^"]*)"/, 1].to_s
    frame_hosts = policy[/frame-src ([^;]*);/, 1].to_s.split

    assert_includes frame_hosts, "https://observablehq.com"
    assert_includes frame_hosts, "https://shiny.posit.co"
  end

  # Plotly inserts its rules into a <style> element it creates, and the Jupyter
  # widget manager adds <style> elements and compiles schemas with new Function.
  # Only the pages that run them get a looser policy.
  def test_pages_without_plotly_or_widgets_keep_the_strict_policy
    %w[index.html 2024/04/05/sql-optimization-guide/index.html].each do |page|
      directives = policy_directives(SiteBuilder.read(page))

      assert(directives["style-src"].any? { |source| source.start_with?("'nonce-") },
             "#{page} should authorise styles by nonce")
      refute_includes directives["style-src"], "'unsafe-inline'", "#{page} should not allow inline styles"
      refute_includes directives["script-src"], "'unsafe-eval'", "#{page} should not allow eval"
    end
  end

  def test_plotly_pages_allow_inline_styles_but_not_eval
    directives = policy_directives(SiteBuilder.read("2024/04/07/data-visualization-plotly-showcase/index.html"))

    assert_includes directives["style-src"], "'unsafe-inline'"
    refute(directives["style-src"].any? { |source| source.start_with?("'nonce-") },
           "A nonce in style-src would make browsers ignore 'unsafe-inline'")
    refute_includes directives["script-src"], "'unsafe-eval'"
  end

  def test_widget_pages_allow_inline_styles_and_eval
    directives = policy_directives(SiteBuilder.read("visualizations/index.html"))

    assert_includes directives["style-src"], "'unsafe-inline'"
    assert_includes directives["script-src"], "'unsafe-eval'"
    assert(directives["script-src"].any? { |source| source.start_with?("'nonce-") },
           "Scripts should still need the nonce")
    assert_includes directives["font-src"], "https://cdn.jsdelivr.net", "The widget manager loads its icon fonts from jsDelivr"
    refute_includes policy_directives(SiteBuilder.read("index.html"))["font-src"], "https://cdn.jsdelivr.net"
  end

  def test_front_matter_can_loosen_the_policy_for_other_embeds
    template = Liquid::Template.parse("{% include csp-meta.html %}")
    context = {
      "site" => SiteBuilder.payload["site"],
      "page" => { "csp_nonce" => "abc", "csp" => { "unsafe_inline_styles" => true, "unsafe_eval" => true } },
      "content" => "<p>No chart markup</p>"
    }
    directives = policy_directives(template.render!(context, registers: { site: SiteBuilder.site }))

    assert_includes directives["style-src"], "'unsafe-inline'"
    assert_includes directives["script-src"], "'unsafe-eval'"
  end

  def test_inline_scripts_all_have_nonces
    html_documents.each do |doc|
      output = read_output(doc)
      next unless output

      output.scan(/<script(?![^>]*\bsrc=)([^>]*)>/mi).each do |match|
        attributes = match.first
        assert_includes attributes, "nonce=", "Missing nonce for inline script in #{document_identifier(doc)}"
      end
    end
  end

  def test_external_scripts_use_sri
    cdn_scripts = 0
    html_documents.each do |doc|
      output = read_output(doc)
      next unless output

      output.scan(/<script[^>]+\bsrc="https:\/\/cdn\.jsdelivr\.net[^"]*"[^>]*>/i).each do |tag|
        cdn_scripts += 1
        assert_match(/integrity="sha384-[^"]+"/, tag,
                     "CDN script without an integrity hash in #{document_identifier(doc)}: #{tag}")
        assert_match(/crossorigin="anonymous"/, tag,
                     "CDN script without crossorigin in #{document_identifier(doc)}: #{tag}")
      end
    end
    assert cdn_scripts.positive?, "Expected at least one CDN script in the built site"

    mathjax_page = mathjax_document
    return unless mathjax_page

    output = read_output(mathjax_page)
    # Match the tag first, then its attributes, so the assertion does not depend
    # on the order the renderer happens to emit them in.
    mathjax_tag = output[/<script[^>]*\bid="mathjax-script"[^>]*>/]
    assert mathjax_tag, "MathJax script tag should be present"
    assert_match(/integrity="sha384-[^"]+"/, mathjax_tag,
                 "MathJax script should include an integrity hash")
  end

  def test_katex_scripts_have_integrity
    page = katex_document
    skip "KaTeX demo page missing" unless page

    output = read_output(page)
    assert_match(/<script[^>]+katex\.min\.js[^>]+integrity="sha384-[^"]+"/, output,
                 "KaTeX core script should include an integrity hash")
    assert_match(/<script[^>]+auto-render\.min\.js[^>]+integrity="sha384-[^"]+"/, output,
                 "KaTeX auto-render script should include an integrity hash")
  end

  def test_disqus_embed_includes_nonce
    page = disqus_document
    skip "Disqus verification post missing" unless page

    output = read_output(page)
    assert_match(/<script nonce="[^"]+">\s*var disqus_config = function/, output,
                 "Disqus bootstrap script should be annotated with the CSP nonce")
  end

  def test_every_document_has_a_nonce
    html_documents.each do |doc|
      assert doc.data["csp_nonce"], "Expected nonce to be stored in page data for #{document_identifier(doc)}"
    end
  end

  # object-src, base-uri and form-action do not fall back to default-src, so the
  # policy left them open.
  def test_policy_sets_the_directives_default_src_does_not_cover
    directives = policy_directives(SiteBuilder.read("index.html"))

    assert_equal ["'none'"], directives["object-src"]
    assert_equal ["'self'"], directives["base-uri"]
    assert_equal ["'self'"], directives["form-action"]
  end

  # The demo sets no google_analytics, and only a page with a widget loads
  # require.js from cdnjs.
  def test_policy_leaves_out_hosts_the_page_does_not_use
    home_sources = policy_directives(SiteBuilder.read("index.html")).values.flatten
    %w[www.googletagmanager.com www.google-analytics.com cdnjs.cloudflare.com cdn.jsdelivr.net].each do |host|
      refute(home_sources.any? { |source| allows_host?(source, host) }, "The home page should not allow #{host}")
    end

    assert_includes policy_directives(SiteBuilder.read("visualizations/index.html"))["script-src"],
                    "https://cdnjs.cloudflare.com/ajax/libs/require.js/2.3.6/"
  end

  def test_policy_allows_google_hosts_when_analytics_is_configured
    directives = render_policy("site" => { "google_analytics" => "G-TEST123" })

    assert_includes directives["script-src"], "https://*.googletagmanager.com"
    assert_includes directives["connect-src"], "https://*.google-analytics.com"
  end

  def test_site_configuration_can_add_sources
    csp = { "script_src" => ["https://widgets.example.org/"], "connect_src" => ["https://api.example.org"] }
    directives = render_policy("site" => { "csp" => csp })

    assert_includes directives["script-src"], "https://widgets.example.org/"
    assert_includes directives["connect-src"], "https://api.example.org"
  end

  # jsDelivr serves any npm package, so each page names the packages it loads.
  def test_pages_allow_only_the_jsdelivr_packages_they_load
    {
      "index.html" => [],
      "2024/01/01/introducing-datalog/index.html" => ["https://cdn.jsdelivr.net/npm/mathjax@3/es5/"],
      "katex-demo/index.html" => ["https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/"],
      "2024/04/07/data-visualization-plotly-showcase/index.html" => ["https://cdn.jsdelivr.net/npm/plotly.js-dist-min@2.27.0/"],
      "admin/analytics/index.html" => ["https://cdn.jsdelivr.net/npm/chart.js@4.4.0/"]
    }.each do |page, packages|
      scripts = policy_directives(SiteBuilder.read(page))["script-src"]
      assert_equal packages, scripts.select { |source| source_host(source) == "cdn.jsdelivr.net" },
                   "#{page} should allow exactly these jsDelivr packages"
    end
  end

  # KaTeX's stylesheet loads its fonts from jsDelivr, which the policy refused;
  # MathJax fetches its components and fonts from its own directory.
  def test_math_pages_allow_the_engine_its_stylesheet_fonts_and_components
    katex = policy_directives(SiteBuilder.read("katex-demo/index.html"))
    %w[style-src font-src].each do |directive|
      assert_includes katex[directive], "https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/"
    end

    mathjax = policy_directives(SiteBuilder.read("2024/01/01/introducing-datalog/index.html"))
    %w[font-src connect-src].each do |directive|
      assert_includes mathjax[directive], "https://cdn.jsdelivr.net/npm/mathjax@3/es5/"
    end
  end

  def test_policy_template_covers_every_jsdelivr_package_the_chart_scripts_load
    root = File.expand_path("..", __dir__)
    sources = File.read(File.join(root, "_includes/csp-meta.html")).scan(%r{https://cdn\.jsdelivr\.net/npm/[^\s'"]+}).uniq
    urls = %w[assets/js/visualizations.js assets/js/notebook.js _includes/analytics/dashboard.html].flat_map do |file|
      File.read(File.join(root, file)).scan(%r{https://cdn\.jsdelivr\.net/npm/[^\s'"`)]+})
    end
    # Widget pages allow all of jsDelivr, since widget packages come from notebooks.
    urls = urls.uniq.grep_v(%r{/npm/@(jupyter-widgets|lumino)/})

    refute_empty urls
    urls.each do |url|
      covered = sources.any? { |source| source.end_with?("/") ? url.start_with?(source) : url == source }
      assert covered, "#{url} is loaded by the theme but not allowed in _includes/csp-meta.html"
    end
  end

  private

  # The host a policy source names, such as "cdn.jsdelivr.net" for
  # "https://cdn.jsdelivr.net/npm/d3@7/", or nil for a keyword such as 'self'.
  def source_host(source)
    source[%r{\Ahttps?://([^/]+)}, 1]
  end

  # Whether a policy source allows requests to host, counting a wildcard
  # source such as "https://*.googletagmanager.com".
  def allows_host?(source, host)
    named = source_host(source)
    return false unless named
    return host == named unless named.start_with?("*.")

    host.end_with?(named.delete_prefix("*"))
  end

  # Renders csp-meta.html outside the site build, for settings the demo lacks.
  def render_policy(overrides)
    context = { "site" => {}, "page" => { "csp_nonce" => "abc" }, "content" => "" }.merge(overrides)
    template = Liquid::Template.parse("{% include csp-meta.html %}")
    policy_directives(template.render!(context, registers: { site: SiteBuilder.site }))
  end

  # The page's Content-Security-Policy meta tag as a map of directive to sources.
  def policy_directives(html)
    policy = html[/<meta http-equiv="Content-Security-Policy" content="([^"]*)"/, 1].to_s
    policy.split(";").each_with_object({}) do |directive, directives|
      name, *sources = directive.split
      directives[name] = sources if name
    end
  end

  def html_documents
    @html_documents ||= begin
      docs = @site.pages + @site.collections.values.flat_map(&:docs)
      docs.uniq.select do |doc|
        destination = doc_destination(doc)
        destination&.end_with?(".html")
      end
    end
  end

  def doc_destination(doc)
    return unless doc.respond_to?(:destination)

    doc.destination(@destination)
  end

  def read_output(doc)
    path = doc_destination(doc)
    return unless path && File.exist?(path)

    File.read(path)
  end

  def document_identifier(doc)
    if doc.respond_to?(:relative_path) && doc.relative_path
      doc.relative_path
    else
      doc.path
    end
  end

  def mathjax_document
    html_documents.find do |doc|
      effective_math_engine(doc) == "mathjax" && read_output(doc)&.include?('id="mathjax-script"')
    end
  end

  def katex_document
    html_documents.find do |doc|
      effective_math_engine(doc) == "katex"
    end
  end

  def disqus_document
    html_documents.find do |doc|
      comments = doc.data.fetch("datalog_comments", nil)
      comments && comments["provider"] == "disqus"
    end
  end

  def effective_math_engine(doc)
    data_engine = doc.data.fetch("math_engine", nil)
    return data_engine if data_engine

    site_engine = doc.site.config.dig("theme_options", "math", "engine")
    site_engine || "mathjax"
  end
end
