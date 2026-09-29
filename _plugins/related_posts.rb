# frozen_string_literal: true

module Datalog
  module RelatedPosts
    # Select recommendations once after Jekyll has read and normalized series.
    # Each field has an inverted index, so a post visits matching candidates
    # rather than comparing itself with every other post on the site.
    class Index
      FIELDS = %w[tags categories keywords].freeze
      DEFAULT_WEIGHTS = { "tags" => 3.0, "categories" => 0.35, "keywords" => 1.5, "text" => 0.0 }.freeze

      def initialize(site)
        @posts = site.posts.docs
        settings = site.config["related_posts"].is_a?(Hash) ? site.config["related_posts"] : {}
        @limit = Integer(settings.fetch("limit", 3))
        @min_score = Float(settings.fetch("min_score", 0.1))
        @weights = DEFAULT_WEIGHTS.merge(string_keys(settings["weights"] || {}))
        @weights.transform_values! { |value| Float(value) }
        @terms = {}
        @index = Hash.new { |hash, field| hash[field] = Hash.new { |terms, term| terms[term] = [] } }
        @lookup = Hash.new { |hash, key| hash[key] = [] }
        @excluded = @posts.to_h { |post| [post, post.data["related"] == false] }
        index_posts
      end

      def assign!
        results = @posts.to_h do |post|
          [post, post.data["related_posts"] == false ? [] : recommendations(post)]
        end
        results.each { |post, recommendations| post.data["related"] = recommendations.map { |item| summary(item) } }
      end

      def recommendations(post)
        selected = []
        used_series = {}
        manual = Array(post.data["related_posts"]).map { |pick| resolve(post, pick) }
        manual.each do |candidate|
          validate_pick!(post, candidate)
          add(selected, used_series, candidate)
        end
        return selected.first(@limit) if selected.size >= @limit

        ranked = scores(post).sort_by { |candidate, score| [-score, -candidate.date.to_i, candidate.url] }
        ranked.each do |candidate, score|
          next if score < @min_score || !eligible?(post, candidate)

          add(selected, used_series, candidate)
          break if selected.size >= @limit
        end
        selected
      end

      private

      def index_posts
        @posts.each do |post|
          @terms[post] = {}
          fields = FIELDS + (@weights["text"].positive? ? ["text"] : [])
          fields.each do |field|
            terms = field == "text" ? text_terms(post) : terms_for(post.data[field])
            @terms[post][field] = terms
            terms.each { |term| @index[field][term] << post }
          end
          [post.url, post.relative_path, post.data["title"]].compact.each do |key|
            @lookup[key.to_s.strip.downcase] << post
          end
        end
      end

      def scores(post)
        scores = Hash.new(0.0)
        @terms.fetch(post).each do |field, terms|
          weight = @weights.fetch(field)
          next if weight.zero?

          terms.each do |term|
            matches = @index[field][term]
            rarity = field == "tags" ? Math.log((@posts.size + 1.0) / (matches.size + 1)) + 1.0 : 1.0
            matches.each { |candidate| scores[candidate] += weight * rarity unless candidate.equal?(post) }
          end
        end
        scores
      end

      def resolve(post, pick)
        key = pick.to_s.strip.downcase
        matches = @lookup[key].uniq
        return matches.first if matches.one?

        problem = matches.empty? ? "matches no post" : "matches several posts; use a URL or path"
        raise Jekyll::Errors::FatalException, "#{post.relative_path} related_posts pick #{pick.inspect} #{problem}"
      end

      def validate_pick!(post, candidate)
        return if eligible?(post, candidate)

        raise Jekyll::Errors::FatalException,
              "#{post.relative_path} related_posts pick #{candidate.url.inspect} is the post itself, " \
              "excluded, or already appears in its series navigation"
      end

      def eligible?(post, candidate)
        own_series = series_id(post)
        !candidate.equal?(post) && !@excluded[candidate] && (own_series.nil? || series_id(candidate) != own_series)
      end

      def add(selected, used_series, candidate)
        id = series_id(candidate)
        return if selected.include?(candidate) || (id && used_series[id])

        selected << candidate
        used_series[id] = true if id
      end

      def series_id(post)
        value = post.data["series"]
        value["id"] if value.is_a?(Hash)
      end

      def terms_for(value)
        Array(value).map { |term| term.to_s.strip.downcase }.reject(&:empty?).uniq
      end

      def text_terms(post)
        text = "#{post.data['title']} #{post.data['excerpt']}"
        text.downcase.scan(/[[:alnum:]]{3,}/).uniq
      end

      def string_keys(value)
        value.is_a?(Hash) ? value.transform_keys(&:to_s) : {}
      end

      def summary(post)
        excerpt = post.data["excerpt"] || (post.excerpt if post.respond_to?(:excerpt))
        { "title" => post.data["title"], "url" => post.url, "teaser" => post.data["teaser"],
          "date" => post.date, "excerpt" => excerpt.to_s, "tags" => post.data["tags"] }
      end
    end
  end

  class RelatedPostsGenerator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      RelatedPosts::Index.new(site).assign!
    end
  end
end
