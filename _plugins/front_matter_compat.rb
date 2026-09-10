# frozen_string_literal: true

# Minimal Mistakes front-matter compatibility.
#
# Sites migrating from the Minimal Mistakes theme carry front matter such as
#
#   header:
#     image: /assets/images/hero.jpg
#     overlay_image: /assets/images/hero.jpg
#     teaser: /assets/images/hero.jpg
#     og_image: /assets/images/hero.jpg
#   seo_title: Short title for search engines
#   seo_description: Meta description
#   classes: wide
#
# DataLog's layouts read `image`, `og_image`, `twitter_image`, `teaser`,
# `description` and an array of `classes`; the post hero is read from a
# `post_hero` hash. This hook fills those fields from the Minimal Mistakes
# ones when they are absent, so a migrated site keeps its hero images,
# teasers, titles and descriptions without every post being edited. Explicit
# DataLog fields always win: the mapping only fills gaps and never overwrites
# a value the author set.
#
# The hero is deliberately kept under its own key rather than `hero_image`,
# which DataLog's page and portfolio layouts already use for their own hero
# rendering.
#
# See docs/migrating-from-minimal-mistakes.md for the full field table.
module Datalog
  module FrontMatterCompat
    SOCIAL_IMAGE_KEYS = %w[og_image image overlay_image teaser].freeze
    HERO_IMAGE_KEYS = %w[overlay_image image].freeze
    TEASER_IMAGE_KEYS = %w[teaser image og_image overlay_image].freeze

    module_function

    # Normalises one document's front matter in place and returns it.
    def normalize!(data)
      return data unless data.is_a?(Hash)

      header = data["header"].is_a?(Hash) ? data["header"] : {}

      assign_missing(data, "og_image", header["og_image"])
      assign_missing(data, "image", first_present(header, SOCIAL_IMAGE_KEYS))
      assign_missing(data, "twitter_image", header["twitter_image"])
      assign_missing(data, "teaser", first_present(header, TEASER_IMAGE_KEYS))

      hero = first_present(header, HERO_IMAGE_KEYS)
      data["post_hero"] = post_hero_from(header, hero) if hero && !data["post_hero"].is_a?(Hash)

      assign_missing(data, "description", data["seo_description"])
      data["classes"] = normalize_classes(data["classes"]) if data.key?("classes")
      data
    end

    def post_hero_from(header, image)
      {
        "image" => image,
        "overlay" => overlay?(header),
        "alt" => header["image_description"],
        "caption" => header["caption"],
        "overlay_filter" => header["overlay_filter"],
        "overlay_color" => header["overlay_color"]
      }.reject { |_key, value| !present?(value) && value != false }
    end

    # Minimal Mistakes renders the title over the image when either an overlay
    # image or an overlay colour is given; a plain `header.image` is a figure.
    def overlay?(header)
      present?(header["overlay_image"]) || present?(header["overlay_color"])
    end

    def first_present(hash, keys)
      keys.map { |key| hash[key] }.find { |value| present?(value) }
    end

    def assign_missing(data, key, value)
      return unless present?(value)
      return if present?(data[key])

      data[key] = value
    end

    # `classes: wide` (a string) and `classes: [wide]` (a list) both become a
    # list, which is what the default layout joins into the body class.
    def normalize_classes(value)
      case value
      when Array then value.flatten.compact.map(&:to_s).flat_map(&:split)
      when String then value.split
      else []
      end
    end

    def present?(value)
      case value
      when nil, false then false
      when String then !value.strip.empty?
      else true
      end
    end
  end
end

Jekyll::Hooks.register :site, :post_read do |site|
  site.collections.each_value do |collection|
    collection.docs.each { |doc| Datalog::FrontMatterCompat.normalize!(doc.data) }
  end
  site.pages.each { |page| Datalog::FrontMatterCompat.normalize!(page.data) }
end
