# frozen_string_literal: true

require "securerandom"

module Datalog
  module Security
    class CspGenerator < Jekyll::Generator
      priority :highest

      DEFAULT_NONCE_BYTES = 16

      def initialize(config = {})
        super
        @nonce_bytes = config.fetch("nonce_bytes", DEFAULT_NONCE_BYTES)
      end

      def generate(site)
        site.data["csp"] ||= {}
        site.data["csp"]["nonces"] ||= {}

        assign_nonces(site, site.pages)
        site.collections.each_value do |collection|
          assign_nonces(site, collection.docs)
        end
      end

      def assign_nonces(site, documents)
        Array(documents).each do |doc|
          self.class.assign_nonce(site, doc, @nonce_bytes)
        end
      end

      def self.assign_nonce(site, document, nonce_bytes = DEFAULT_NONCE_BYTES)
        return unless document.respond_to?(:data)

        existing = document.data["csp_nonce"]
        return existing if existing

        nonce = SecureRandom.base64(nonce_bytes)
        document.data["csp_nonce"] = nonce

        registry_site = site || (document.respond_to?(:site) ? document.site : nil)
        if registry_site.respond_to?(:data)
          registry_site.data["csp"] ||= {}
          registry_site.data["csp"]["nonces"] ||= {}
          key = document_key(document)
          registry_site.data["csp"]["nonces"][key] = nonce if key
        end

        nonce
      end

      def self.document_key(doc)
        if doc.respond_to?(:relative_path) && doc.relative_path
          doc.relative_path
        elsif doc.respond_to?(:path)
          doc.path
        end
      end

      # Gives every inline script in the rendered page the page's nonce. The
      # generator also took a SHA-256 of each inline script, but the policy is
      # written into the head while the page renders, so the hashes of the
      # finished page never reached it; with every script nonced they are not
      # needed.
      def self.add_nonces(document)
        return unless document.respond_to?(:output)

        output = document.output
        return if output.nil? || output.empty?

        site = document.respond_to?(:site) ? document.site : nil
        nonce = assign_nonce(site, document)

        # Case-insensitive: HTML tag names are, so <SCRIPT> in author content
        # must be matched too. Without /i such a tag received no nonce and was
        # then blocked by the policy, which fails closed but silently.
        document.output = output.gsub(/<script(?![^>]*\bsrc=)(?![^>]*\bnonce=)([^>]*)>/i) do
          attributes = Regexp.last_match(1)
          "<script nonce=\"#{nonce}\"#{attributes}>"
        end
      end
    end
  end
end

%i[pages documents].each do |target|
  Jekyll::Hooks.register target, :pre_render do |document|
    Datalog::Security::CspGenerator.assign_nonce(document.respond_to?(:site) ? document.site : nil, document)
  end

  Jekyll::Hooks.register target, :post_render do |document|
    Datalog::Security::CspGenerator.add_nonces(document)
  end
end
