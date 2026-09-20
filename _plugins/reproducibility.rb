# frozen_string_literal: true

require "uri"

module Datalog
  # The computational artifacts behind an article, for the "Reproduce this
  # analysis" panel (_includes/components/reproducibility.html):
  #
  #   reproducibility:
  #     code:
  #       url: https://github.com/example/project
  #       ref: 4f2c1ab                   # the commit, tag or branch the article used
  #     data:
  #       doi: 10.5281/zenodo.1234567    # or url:
  #       version: v2
  #     environment:
  #       file: requirements.txt         # in the code repository at the ref, a site path or a URL
  #       container: ghcr.io/example/project:1.4.0
  #       archive: https://doi.org/10.5281/zenodo.7654321
  #     notebook:
  #       url: /notebooks/example/
  #     results:
  #       url: https://github.com/example/project/releases/tag/results-v1
  #       version: results-v1
  #
  # Every artifact is optional, and each may be a bare URL. The panel shows
  # what is given and claims nothing more: a link is a link, a ref is a ref.
  # A URL that is not http(s), a site path or a DOI stops the build.
  module Reproducibility
    module_function

    KINDS = %w[code data notebook environment results].freeze
    # Where a ref and a file in the repository can be linked.
    HOSTS = {
      "github.com" => { tree: "/tree/%s", blob: "/blob/%s/%s" },
      "gitlab.com" => { tree: "/-/tree/%s", blob: "/-/blob/%s/%s" }
    }.freeze
    URL = %r{\Ahttps?://[^\s"'<>]+\z}i
    PATH = %r{\A/[^\s"'<>]*\z}

    # The artifacts, in KINDS order, or nil when the page gives none.
    def resolve(page, site)
      value = Authors.value(page, "reproducibility")
      return unless value.is_a?(Hash)

      given = value.transform_keys(&:to_s)
      baseurl = Authors.value(site, "baseurl").to_s
      artifacts = KINDS.filter_map { |kind| artifact(kind, given[kind], given, page, baseurl) }
      { "artifacts" => artifacts } unless artifacts.empty?
    end

    def artifact(kind, value, all, page, baseurl)
      return if value.nil? || value == false || (value.is_a?(String) && value.strip.empty?)

      given = value.is_a?(Hash) ? Authors.present(value) : { "url" => value.to_s }
      url = link(given["url"] || doi_url(given["doi"]), page, "#{kind}.url", baseurl)
      artifact = { "kind" => kind, "url" => url, "external" => external?(url), "version" => given["version"]&.to_s,
                   "label" => given["label"] || display(url), "doi" => bare_doi(given["doi"]) }
      artifact.merge!(code(given, url)) if kind == "code"
      artifact.merge!(environment(given, all, page, baseurl)) if kind == "environment"
      artifact = artifact.compact
      artifact if artifact.values_at("url", "file", "container", "archive").any?
    end

    def code(given, url)
      ref = given["ref"].to_s.strip
      return {} if ref.empty?

      { "ref" => ref, "ref_url" => host_url(url, :tree, ref) }
    end

    # The environment file lives in the code repository at the article's ref
    # unless it is a site path or a URL of its own.
    def environment(given, all, page, baseurl)
      file = given["file"].to_s.strip
      archive = link(given["archive"], page, "environment.archive", baseurl)
      {
        "file" => (file unless file.empty?),
        "file_url" => (file_url(file, all["code"], page, baseurl) unless file.empty?),
        "container" => given["container"]&.to_s,
        "archive" => archive, "archive_label" => display(archive)
      }
    end

    def file_url(file, code, page, baseurl)
      own = file.match?(URL) || file.match?(PATH) || file.match?(/\Adoi:/i)
      return link(file, page, "environment.file", baseurl) if own

      code = code.is_a?(Hash) ? Authors.present(code) : { "url" => code.to_s }
      code_url = link(code["url"], page, "code.url", baseurl)
      ref = code["ref"].to_s.strip
      host_url(code_url, :blob, ref.empty? ? "HEAD" : ref, file)
    end

    # A page of a known host under the repository URL, such as a tree or a blob.
    def host_url(url, kind, *parts)
      return unless url

      uri = URI.parse(url)
      host = uri.host.to_s.downcase.sub(/\Awww\./, "")
      pattern = HOSTS.dig(host, kind)
      return unless pattern

      root = if host == "github.com"
               uri.path.split("/").reject(&:empty?).first(2).join("/")
             else
               uri.path.sub(%r{/-/.*}, "").delete_prefix("/")
             end
      root = root.chomp("/").delete_suffix(".git")
      # A ref is one route argument; a file retains its directory separators.
      encoded = parts.each_with_index.map do |part, index|
        index.zero? ? URI.encode_www_form_component(part).gsub("+", "%20") : encode_path(part)
      end
      "#{uri.scheme}://#{host}/#{root}#{format(pattern, *encoded)}"
    rescue URI::InvalidURIError
      nil
    end

    # An http(s) URL as given, a site path with the baseurl, or a DOI as its
    # URL; anything else, such as a javascript: URL or an address without its
    # scheme, stops the build.
    def link(value, page, field, baseurl)
      text = value.to_s.strip
      return if text.empty?
      return doi_url(text) if text.match?(/\Adoi:/i)
      return text if text.match?(URL)
      return "#{baseurl}#{text}" if text.match?(PATH)

      raise Jekyll::Errors::FatalException,
            "#{Authors.value(page, 'path')} reproducibility.#{field} is #{text.inspect}, which is not an http(s) " \
            "URL, a site path starting with / or a doi:; give the whole address, such as https://github.com/example/project"
    end

    def bare_doi(doi)
      text = doi.to_s.strip.sub(%r{\Ahttps?://(dx\.)?doi\.org/}i, "").sub(/\Adoi:\s*/i, "")
      text unless text.empty?
    end

    def doi_url(doi)
      bare = bare_doi(doi)
      "https://doi.org/#{encode_path(bare)}" if bare
    end

    def encode_path(value)
      value.to_s.split("/", -1).map { |part| URI.encode_www_form_component(part).gsub("+", "%20") }.join("/")
    end

    # What a link reads: the address without its scheme, or the site path.
    def display(url)
      return url unless external?(url)

      url.sub(%r{\Ahttps?://(www\.)?}i, "").chomp("/")
    end

    def external?(url)
      url.to_s.match?(URL)
    end
  end

  module ReproducibilityFilters
    def page_reproducibility(page)
      Reproducibility.resolve(page, @context["site"])
    end
  end
end

Liquid::Template.register_filter(Datalog::ReproducibilityFilters)
