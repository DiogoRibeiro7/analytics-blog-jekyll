# frozen_string_literal: true

module Datalog
  # One list of a page's authors, and one of its contributors, which the
  # byline, the author cards, the JSON-LD, the citation meta tags and the
  # citation exports all read. Each used to work the author out on its own: a
  # post named one author, `author: john_doe` put "john_doe" in the byline while
  # the card looked the key up in _data/authors.yml, the research layout gave
  # every author the site author's ORCID and affiliation, and the JSON-LD listed
  # the site author's profiles only when an ORCID was set.
  #
  # An entry is a name, a key of _data/authors.yml, or a map with `name` (or
  # `id`, a key of _data/authors.yml). The data record and, for the site's own
  # author, `author` in _config.yml fill in what the entry leaves out.
  module Authors
    module_function

    PROFILE_URLS = {
      "github" => "https://github.com/%s",
      "twitter" => "https://twitter.com/%s",
      "linkedin" => "https://linkedin.com/in/%s"
    }.freeze
    PROFILE_LINKS = %w[researchgate google_scholar].freeze
    ORCID_ID = /\A\d{4}-\d{4}-\d{4}-\d{3}[\dX]\z/

    # `authors:`, else `author:`, else the site's author.
    def authors(page, site)
      entries = entries(value(page, "authors"))
      entries = entries(value(page, "author")) if entries.empty?
      records = entries.filter_map { |entry| resolve(entry, site) }
      records = [site_author(site)].compact if records.empty?
      apply_page_affiliation(records, page)
    end

    def contributors(page, site)
      entries(value(page, "contributors")).filter_map { |entry| resolve(entry, site) }
    end

    # A list, one entry, or names in a string separated by semicolons.
    def entries(value)
      list = if value.is_a?(String) then value.split(";")
             elsif value.is_a?(Hash) then [value]
             else Array(value)
             end
      list.reject { |entry| entry.nil? || (entry.is_a?(String) && entry.strip.empty?) }
    end

    # A plain entry is a key or a name; a map's own fields win over the record's.
    def resolve(entry, site)
      own = entry.is_a?(Hash) ? present(entry) : {}
      key = own["id"] || own["name"] || entry.to_s.strip
      record = known(key, site).merge(own)
      record["name"] ||= key
      return if record["name"].to_s.strip.empty?

      finish(record, site)
    end

    # The _data/authors.yml record for a key, or the site author's profile
    # when the key is the site author's name.
    def known(key, site)
      data = value(value(site, "data"), "authors")
      record = value(data, key.to_s)
      return present(record) if record.is_a?(Hash)

      author = site_author_profile(site)
      author && author["name"] == key ? author : {}
    end

    def site_author(site)
      profile = site_author_profile(site)
      profile && finish(profile, site)
    end

    def site_author_profile(site)
      author = value(site, "author")
      return { "name" => author.strip } if author.is_a?(String) && !author.strip.empty?

      present(author) if author.is_a?(Hash) && author["name"]
    end

    def finish(record, site)
      record["affiliation"] ||= record["institution"]
      record["bio"] ||= record["biography"]
      record["image"] ||= record["avatar"] || record["photo"]
      record["orcid"] = "https://orcid.org/#{record['orcid']}" if record["orcid"].to_s.match?(ORCID_ID)
      record["site_author"] = record["name"] == site_author_profile(site)&.fetch("name")
      record["same_as"] = profiles(record)
      record
    end

    def profiles(record)
      urls = [record["orcid"]]
      urls += PROFILE_URLS.map { |key, template| format(template, record[key]) if record[key] }
      urls += PROFILE_LINKS.map { |key| record[key] }
      urls.compact.map(&:to_s).reject(&:empty?).uniq
    end

    # `author_affiliation` in front matter names the affiliation of a page's
    # only author; an empty one removes it.
    def apply_page_affiliation(records, page)
      affiliation = value(page, "author_affiliation")
      return records if affiliation.nil? || records.size != 1

      affiliation.to_s.strip.empty? ? records.first.delete("affiliation") : records.first["affiliation"] = affiliation
      records
    end

    # String keys, without the blank values an entry leaves for its record to fill.
    def present(hash)
      hash.to_h.each_with_object({}) do |(key, entry), result|
        result[key.to_s] = entry unless entry.nil? || (entry.is_a?(String) && entry.strip.empty?)
      end
    end

    # Pages are hashes in Liquid, documents and the site are drops; both answer [].
    def value(object, key)
      object[key] if object.respond_to?(:[]) && !object.is_a?(String) && !object.is_a?(Array)
    end
  end

  module AuthorFilters
    def page_authors(page)
      Authors.authors(page, @context["site"])
    end

    def page_contributors(page)
      Authors.contributors(page, @context["site"])
    end
  end
end

Liquid::Template.register_filter(Datalog::AuthorFilters)
