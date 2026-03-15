# frozen_string_literal: true

module Datalog
  module Plugins
    class Comments < Datalog::PluginSystem::Plugin
      id "datalog-comments"
      depends_on "datalog-search"
      priority :low

      class CommentsTag < Liquid::Tag
        def render(context)
          plugin = Datalog::PluginSystem.plugin("datalog-comments")
          return "" unless plugin

          plugin.render_comments(context)
        end
      end

      REQUIRED_FIELDS = {
        "giscus" => %w[repo repo_id category category_id],
        "utterances" => %w[repo],
        "disqus" => %w[shortname]
      }.freeze

      def initialize(site, config = {})
        super
        @defaults = {
          "provider" => "giscus",
          "mapping" => "pathname",
          "theme" => "light",
          "enabled_by_default" => false
        }.merge(@config)
        @memo = {}
      end

      def before_render(document, _payload = nil)
        return unless comments_enabled?(document)

        settings = resolve_settings(document)
        embed = build_embed(document, settings)

        document.data["datalog_comments"] = settings.merge("embed" => embed)
        document.data["datalog_comments_state"] = storage_key(document)
        @memo[storage_key(document)] = settings.merge("embed" => embed)
      end

      def custom_liquid_tags
        { "datalog_comments" => CommentsTag }
      end

      def search_indexing(document)
        key = storage_key(document)
        settings = @memo[key]
        return {} unless settings

        {
          "comments" => {
            "provider" => settings["provider"],
            "mapping" => settings["mapping"]
          }
        }
      end

      def render_comments(context)
        page = context.registers[:page] || {}
        key = page["datalog_comments_state"]
        settings = @memo[key]
        return "" unless settings

        <<~HTML
          <div class="datalog-comments" aria-label="Comments">
            #{settings['embed']}
          </div>
        HTML
      end

      private

      def comments_enabled?(document)
        front_matter = document.data.fetch("comments", nil)
        if front_matter.nil?
          @defaults["enabled_by_default"]
        else
          front_matter != false
        end
      end

      def resolve_settings(document)
        front_matter = document.data.fetch("comments", {})
        front_settings = front_matter.is_a?(Hash) ? front_matter.transform_keys(&:to_s) : {}
        @defaults.merge(front_settings)
      end

      def build_embed(document, settings)
        provider = settings["provider"]
        missing = missing_required_fields(provider, settings)
        unless missing.empty?
          logger.warn(
            "datalog comments",
            %(Missing required settings for #{provider.inspect}: #{missing.join(", ")})
          )
          return %(<p class="datalog-comments-missing">Comments provider "#{provider}" missing required settings: #{missing.join(", ")}. Check your front matter or datalog configuration.</p>)
        end

        case provider
        when "giscus"
          render_giscus(settings)
        when "utterances"
          render_utterances(settings)
        when "disqus"
          render_disqus(document, settings)
        else
          %(<p class="datalog-comments-unsupported">Comments provider "#{settings['provider']}" is not supported.</p>)
        end
      end

      def render_giscus(settings)
        %(<script src="https://giscus.app/client.js"
          data-repo="#{settings['repo']}"
          data-repo-id="#{settings['repo_id']}"
          data-category="#{settings['category']}"
          data-category-id="#{settings['category_id']}"
          data-mapping="#{settings['mapping']}"
          data-strict="0"
          data-reactions-enabled="1"
          data-emit-metadata="0"
          data-input-position="bottom"
          data-theme="#{settings['theme']}"
          data-lang="#{settings['lang'] || 'en'}"
          crossorigin="anonymous"
          async></script>)
      end

      def render_utterances(settings)
        %(<script src="https://utteranc.es/client.js"
          repo="#{settings['repo']}"
          issue-term="#{settings['mapping']}"
          theme="#{settings['theme']}"
          crossorigin="anonymous"
          async></script>)
      end

      def render_disqus(document, settings)
        shortname = settings["shortname"] || ""
        nonce = nonce_attribute(document)
        <<~HTML
          <div id="disqus_thread"></div>
          <script#{nonce}>
            var disqus_config = function () {
              this.page.url = window.location.href;
              this.page.identifier = '#{settings['mapping']}';
            };
            (function() {
              var d = document, s = d.createElement('script');
              s.src = 'https://#{shortname}.disqus.com/embed.js';
              s.setAttribute('data-timestamp', +new Date());
              (d.head || d.body).appendChild(s);
            })();
          </script>
          <noscript>Please enable JavaScript to view the comments powered by Disqus.</noscript>
        HTML
      end

      def nonce_attribute(document)
        nonce = document.data.fetch("csp_nonce", nil)
        nonce ? %( nonce="#{nonce}") : ""
      end

      def storage_key(document)
        document.relative_path || document.path
      end

      def missing_required_fields(provider, settings)
        required = REQUIRED_FIELDS.fetch(provider.to_s, [])
        required.select { |key| settings[key].to_s.strip.empty? }
      end

      def logger
        Jekyll.logger
      end
    end
  end
end

