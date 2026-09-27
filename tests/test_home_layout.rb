# frozen_string_literal: true

require_relative "test_helper"
require "nokogiri"

class HomeLayoutTest < Minitest::Test
  def test_demo_has_both_actions_and_three_feature_cards_before_latest_posts
    doc = Nokogiri::HTML5(SiteBuilder.read("index.html"))

    action_urls = doc.css(".hero-actions a").map { |link| link["href"] }
    assert_equal %w[/blog/ /portfolio/], action_urls
    assert_equal 3, doc.css(".home-feature-card").size
    assert doc.at_css(".section-highlight .card"), "latest posts should follow the features"
    assert doc.at_css(".section-portfolio .card"), "featured projects should follow the posts"
    assert_equal doc.at_css(".section-highlight"), doc.at_css(".home-features").next_element
  end

  def test_empty_consumer_site_and_custom_one_card_page
    built = TestSite.build(baseurl: "/sample", description: "A research home page") do |source|
      source.theme("_layouts/home.html", "_includes/components/hero.html", "_data/i18n")
      source.theme("assets/img/hero-detail.webp", "assets/img/hero-detail-640.webp")
      source.layout("default", "{{ content }}")
      source.page("index.md", "", { "layout" => "home" })
      source.page("guide/index.md", "Guide")
      custom_front_matter = {
        "layout" => "home", "hero_title" => "Custom research",
        "hero_cta_url" => "/guide/", "hero_cta_label" => "Read guide",
        "hero_secondary_cta_url" => "/", "hero_secondary_cta_label" => "Home",
        "hero_image" => "/assets/img/hero-detail.webp",
        "hero_image_small" => "/assets/img/hero-detail-640.webp",
        "home_features" => [{ "title" => "One card", "description" => "Only the selected feature" }]
      }
      source.page("custom/index.md", "", custom_front_matter)
    end

    empty = built.html("index.html")
    assert_equal "Test site", empty.at_css(".hero h1").text
    assert_equal "A research home page", empty.at_css(".hero-tagline").text
    assert_empty empty.css(".hero-actions, .home-features, .section-highlight, .section-portfolio")
    assert_empty empty.css('link[rel="preload"][as="image"]')

    custom = built.html("custom/index.html")
    action_urls = custom.css(".hero-actions a").map { |link| link["href"] }
    assert_equal ["/sample/guide/", "/sample/"], action_urls
    card_titles = custom.css(".home-feature-card h3").map { |heading| heading.text.strip }
    assert_equal ["One card"], card_titles
    assert_empty custom.css(".home-feature-card a"), "a card without a URL should not become a broken link"
    preloads = custom.css('link[rel="preload"][as="image"]').map { |link| link["href"] }
    assert_equal ["/sample/assets/img/hero-detail-640.webp", "/sample/assets/img/hero-detail.webp"], preloads
    assert custom.at_css(".hero--image"), "an explicitly configured image should be used behind the gradient"
  end
end
