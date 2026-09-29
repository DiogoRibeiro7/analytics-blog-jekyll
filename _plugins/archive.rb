# frozen_string_literal: true

module Datalog
  module Archive
    module_function

    def build(site, page)
      mode = page["archive"].to_s
      limit = (page["archive_limit"] || site.config["archive_limit"]).to_i
      limit = 20 if limit <= 0
      posts = site.posts.docs.sort_by { |post| [-post.date.to_i, post.url] }

      case mode
      when "year" then years(posts, page, limit)
      when "tag" then terms(posts, "tags", limit)
      when "category" then terms(posts, "categories", limit)
      when "facet" then facet(posts, page, limit)
      when "topic" then topic(posts, page, limit)
      else
        []
      end
    end

    def years(posts, page, limit)
      groups = grouped(posts, limit) { |post| [[post.date.year.to_s, post.date.year.to_s]] }
      groups.sort_by! { |group| -group["name"].to_i }
      return groups unless page["archive_months"]

      groups.each do |year|
        year_posts = posts.select { |post| post.date.year.to_s == year["name"] }
        months = grouped(year_posts, limit) do |post|
          [[post.date.strftime("%Y-%m"), post.date.strftime("%Y-%m")]]
        end
        year["months"] = months.sort_by { |month| month["name"] }.reverse
      end
      groups
    end

    def terms(posts, field, limit)
      groups = grouped(posts, limit) do |post|
        Array(post.data[field]).map { |term| [term.to_s, term.to_s] }
      end
      groups.sort_by { |group| group["name"].downcase }
    end

    def facet(posts, page, limit)
      field = page["archive_field"].to_s
      wanted = Array(page["archive_terms"]).map(&:to_s)
      groups = grouped(posts, limit) do |post|
        Array(post.data[field]).map { |term| [term.to_s, term.to_s] }.select do |name, _|
          wanted.any? { |given| given.casecmp?(name) }
        end
      end
      wanted.filter_map { |term| groups.find { |group| group["name"].casecmp?(term) } }
    end

    def grouped(posts, limit)
      groups = {}
      posts.each do |post|
        yield(post).each do |name, label|
          slug = Jekyll::Utils.slugify(name)
          next if slug.empty?

          group = (groups[slug] ||= { "name" => label, "slug" => slug, "posts" => [] })
          group["posts"] << post unless group["posts"].include?(post)
        end
      end
      groups.each_value do |group|
        group["count"] = group["posts"].size
        group["remaining"] = group["posts"].drop(limit)
        group["posts"] = group["posts"].first(limit)
      end
      groups.values
    end

    def topic(posts, page, limit)
      config = page["topic"] || {}
      tags = Array(config["tags"]).map { |value| value.to_s.downcase }
      categories = Array(config["categories"]).map { |value| value.to_s.downcase }
      featured = Array(config["featured"]).map(&:to_s)
      matches = posts.select { |post| topic_match?(post, tags, categories) }
      series, loose = matches.partition do |post|
        post.data["series"].is_a?(Hash) && post.data["series"]["id"]
      end
      series = topic_series(series, featured)
      loose.sort_by! { |post| [featured.include?(post.url) ? 0 : 1, -post.date.to_i, post.url] }
      { "series" => series, "posts" => loose.first(limit), "remaining" => loose.drop(limit),
        "count" => matches.size }
    end

    def topic_match?(post, tags, categories)
      Array(post.data["tags"]).map { |value| value.to_s.downcase }.intersect?(tags) ||
        Array(post.data["categories"]).map { |value| value.to_s.downcase }.intersect?(categories)
    end

    def topic_series(posts, featured)
      groups = posts.group_by { |post| post.data["series"]["id"] }
      series = groups.map do |_id, parts|
        data = parts.first.data["series"]
        { "title" => data["title"], "url" => parts.first.url,
          "count" => parts.size, "featured" => parts.any? { |post| featured.include?(post.url) } }
      end
      series.sort_by { |item| [item["featured"] ? 0 : 1, item["title"].to_s.downcase] }
    end
  end

  module ArchiveFilters
    def archive_data(page)
      Archive.build(@context.registers[:site], page)
    end
  end
end

Liquid::Template.register_filter(Datalog::ArchiveFilters)
