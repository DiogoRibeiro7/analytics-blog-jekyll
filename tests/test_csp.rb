# frozen_string_literal: true

require_relative "test_helper"
require "set"

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

  def test_inline_scripts_all_have_nonces
    html_documents.each do |doc|
      output = read_output(doc)
      next unless output

      output.scan(/<script(?![^>]*\bsrc=)([^>]*)>/m).each do |match|
        attributes = match.first
        assert_includes attributes, "nonce=", "Missing nonce for inline script in #{document_identifier(doc)}"
      end
    end
  end

  def test_external_scripts_use_sri
    homepage = SiteBuilder.read("index.html")
    cdn_pattern = /<script[^>]+cdn\.jsdelivr[^>]+integrity="sha384-[^"]+"[^>]+crossorigin="anonymous"/
    assert cdn_pattern.match?(homepage), "Expected CDN scripts to include SRI integrity attributes"

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

  def test_page_data_records_hashes
    html_documents.each do |doc|
      assert doc.data["csp_nonce"], "Expected nonce to be stored in page data for #{document_identifier(doc)}"
      hashes = doc.data["csp_hashes"]
      assert_kind_of Array, hashes, "Expected inline script hashes to be captured for #{document_identifier(doc)}"
    end
  end

  private

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
      effective_math_engine(doc) == "mathjax"
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
