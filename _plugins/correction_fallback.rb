# frozen_string_literal: true

require "uri"

module Datalog
  # A plain link is useful even on a static site, before JavaScript enriches
  # the report with the section and selected passage.
  module CorrectionFallback
    module_function

    MAX_BODY = 900
    MAX_TITLE = 180
    MAX_URL = 1800
    HOSTS = %w[github.com gitlab.com].freeze
    EMAIL = /\A[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+\z/

    def resolve(page, site, article_url, context)
      settings = Authors.value(site, "corrections")
      settings = {} unless settings.respond_to?(:[])
      mode = Authors.value(settings, "fallback")&.to_s
      repository = repository_url(Authors.value(site, "repository"))
      email = Authors.value(site, "contact_email")
      email = Authors.value(Authors.value(site, "author"), "email") if email.to_s.strip.empty?
      email = email.to_s.strip
      email = nil unless email&.match?(EMAIL)
      mode = repository ? "issue" : (email ? "email" : "none") if mode.nil? || mode.empty?
      return unless %w[issue email].include?(mode)
      return if mode == "issue" && !repository || mode == "email" && !email

      title = Authors.value(page, "title").to_s.strip[0, MAX_TITLE]
      subject = I18n.translate(context, "corrections.fallback.subject", "title" => title)
      body_lines = [
        "#{I18n.translate(context, 'corrections.fallback.article')}: #{title}",
        "#{I18n.translate(context, 'corrections.fallback.url')}: #{article_url}"
      ]
      minimum = body_lines.join("\n").length
      body = (body_lines + ["", I18n.translate(context, "corrections.fallback.prompt")]).join("\n")
      body = body[0, [MAX_BODY, minimum].max]

      if mode == "email"
        { "kind" => mode, "body_param" => "body",
          "href" => bounded_link("mailto:#{email}", { subject: subject, body: body }, :body, minimum) }
      else
        issue_link(repository, subject, body, minimum, settings)
      end
    end

    def issue_link(repository, subject, body, minimum, settings)
      github = URI.parse(repository).host == "github.com"
      title_key, body_key = github ? %w[title body] : ["issue[title]", "issue[description]"]
      params = { title_key => subject, body_key => body }
      labels = Authors.value(settings, "issue_labels") || ["correction"]
      labels = Array(labels).map(&:to_s).map(&:strip).reject(&:empty?)
      params[github ? "labels" : "issue[label_names]"] = labels.join(",") unless labels.empty?
      path = github ? "/issues/new" : "/-/issues/new"
      { "kind" => "issue", "body_param" => body_key,
        "href" => bounded_link("#{repository}#{path}", params, body_key, minimum) }
    end

    def bounded_link(destination, params, body_key, minimum)
      address = "#{destination}?#{URI.encode_www_form(params)}"
      while address.bytesize > MAX_URL && params[body_key].length > minimum
        params[body_key] = params[body_key][0, [params[body_key].length - 20, minimum].max]
        address = "#{destination}?#{URI.encode_www_form(params)}"
      end
      address
    end

    def repository_url(value)
      uri = URI.parse(value.to_s.strip)
      return unless uri.scheme == "https" && HOSTS.include?(uri.host&.downcase)
      return if uri.userinfo || uri.port != 443 || uri.query || uri.fragment

      parts = uri.path.to_s.sub(%r{/$}, "").split("/").reject(&:empty?)
      valid_parts = parts.all? { |part| part.match?(/\A[a-zA-Z0-9_.-]+\z/) && !%w[. ..].include?(part) }
      return unless parts.length >= 2 && valid_parts
      return unless uri.host.downcase == "gitlab.com" || parts.length == 2

      "https://#{uri.host.downcase}/#{parts.join('/').sub(/\.git\z/, '')}"
    rescue URI::InvalidURIError
      nil
    end
  end

  module CorrectionFallbackFilters
    def correction_fallback(page, article_url)
      CorrectionFallback.resolve(page, @context["site"], article_url, @context)
    end
  end
end

Liquid::Template.register_filter(Datalog::CorrectionFallbackFilters)
