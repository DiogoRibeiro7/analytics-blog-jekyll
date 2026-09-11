# frozen_string_literal: true

require_relative "test_helper"
require_relative "../_plugins/front_matter_compat"

class FrontMatterCompatTest < Minitest::Test
  POST_TITLE = "Minimal Mistakes Front Matter, Rendered by DataLog"

  def test_header_images_map_to_datalog_fields
    data = Datalog::FrontMatterCompat.normalize!(
      "header" => { "image" => "/a.jpg", "overlay_image" => "/o.jpg", "teaser" => "/t.jpg",
                    "og_image" => "/og.jpg", "twitter_image" => "/tw.jpg", "overlay_filter" => 0.5 }
    )
    assert_equal "/og.jpg", data["image"]
    assert_equal "/og.jpg", data["og_image"]
    assert_equal "/tw.jpg", data["twitter_image"]
    assert_equal "/t.jpg", data["teaser"]
    assert_equal({ "image" => "/o.jpg", "overlay" => true, "overlay_filter" => 0.5 }, data["post_hero"])
  end

  def test_plain_header_image_is_a_figure_not_an_overlay
    data = Datalog::FrontMatterCompat.normalize!("header" => { "image" => "/a.jpg", "caption" => "Cap" })
    assert_equal({ "image" => "/a.jpg", "overlay" => false, "caption" => "Cap" }, data["post_hero"])
    assert_equal "/a.jpg", data["teaser"]
    assert_equal "/a.jpg", data["image"]
  end

  def test_overlay_colour_alone_makes_an_overlay_hero
    data = Datalog::FrontMatterCompat.normalize!("header" => { "image" => "/a.jpg", "overlay_color" => "#333" })
    assert_equal true, data["post_hero"]["overlay"]
    assert_equal "#333", data["post_hero"]["overlay_color"]
  end

  def test_datalog_hero_image_is_left_alone
    data = Datalog::FrontMatterCompat.normalize!("hero_image" => "/datalog.jpg", "title" => "Page")
    assert_equal "/datalog.jpg", data["hero_image"]
    refute data.key?("post_hero")
  end

  def test_explicit_datalog_fields_win
    data = Datalog::FrontMatterCompat.normalize!(
      "image" => "/explicit.jpg", "description" => "explicit",
      "post_hero" => { "image" => "/mine.jpg", "overlay" => false },
      "header" => { "image" => "/a.jpg", "overlay_image" => "/o.jpg" }, "seo_description" => "from seo"
    )
    assert_equal "/explicit.jpg", data["image"]
    assert_equal "explicit", data["description"]
    assert_equal({ "image" => "/mine.jpg", "overlay" => false }, data["post_hero"])
  end

  def test_seo_description_fills_description
    data = Datalog::FrontMatterCompat.normalize!("seo_description" => "meta text")
    assert_equal "meta text", data["description"]
  end

  def test_classes_string_becomes_a_list
    assert_equal ["wide"], Datalog::FrontMatterCompat.normalize!("classes" => "wide")["classes"]
    assert_equal %w[wide dark], Datalog::FrontMatterCompat.normalize!("classes" => "wide dark")["classes"]
    assert_equal %w[wide], Datalog::FrontMatterCompat.normalize!("classes" => ["wide"])["classes"]
  end

  def test_data_without_minimal_mistakes_fields_is_untouched
    data = { "title" => "Plain", "image" => "/x.jpg" }
    assert_equal data, Datalog::FrontMatterCompat.normalize!(data.dup)
  end

  def test_non_hash_input_is_returned_as_is
    assert_nil Datalog::FrontMatterCompat.normalize!(nil)
  end

  # --- rendered demo site ---

  def test_demo_post_renders_the_overlay_hero_with_the_title_inside
    html = demo_post_html
    assert_includes html, 'class="post-hero post-hero--overlay"'
    assert_match(%r!<style nonce="[^"]*">\s*#post-hero-\S+ \{[^}]*20220607123041_detail\.001\.png!, html,
                 "the hero background must come from a nonce-carrying style element, since the CSP blocks style attributes")
    refute_match(/post-hero--overlay" style=/, html)
    assert_match(%r{post-hero__title[^>]*>#{Regexp.escape(POST_TITLE)}<}, html)
    refute_match(/<h1 class="article-title" itemprop/, html, "the article header must not repeat the title")
    assert_includes html, "The compatibility layer in action"
  end

  def test_demo_post_uses_the_seo_title_and_description
    html = demo_post_html
    assert_includes html, "<title>Migrating Minimal Mistakes Front Matter to DataLog | "
    assert_includes html, 'name="description" content="How DataLog reads Minimal Mistakes'
    assert_includes html, 'property="og:image" content="https://diogoribeiro7.github.io/assets/img/20220607123041_detail.001.png"'
  end

  def test_demo_post_body_carries_the_wide_class
    assert_match(/<body class="[^"]*\bwide\b/, demo_post_html)
  end

  def test_demo_post_renders_the_provenance_note
    html = demo_post_html
    assert_includes html, 'class="content-provenance"'
    assert_includes html, "Why this exists"
  end

  def test_redirect_from_generates_a_redirect_page
    redirect = SiteBuilder.read("legacy/minimal-mistakes-post/index.html")
    assert_includes redirect, demo_post.url
  end

  def test_home_cards_show_teaser_thumbnails
    assert_includes SiteBuilder.read("index.html"), 'class="card-media"'
  end

  def test_pages_with_local_images_keep_their_document_structure
    %w[index.html portfolio/sample-project/index.html].each do |path|
      html = SiteBuilder.read(path)
      assert_match(/\A\s*<!DOCTYPE html>/i, html, "#{path} should start with a doctype")
      assert_includes html, 'lang="en"', "#{path} should keep its html element"
      assert_includes html, "<head>", "#{path} should keep its head element"
    end
  end

  def test_portfolio_pages_render_their_own_hero_only_once
    html = SiteBuilder.read("portfolio/sample-project/index.html")
    refute_includes html, "post-hero", "DataLog's hero_image pages must not gain a second hero"
  end

  private

  def demo_post
    @demo_post ||= SiteBuilder.site.posts.docs.find { |doc| doc.data["title"] == POST_TITLE }
  end

  def demo_post_html
    refute_nil demo_post, "expected the compatibility demo post to exist"
    SiteBuilder.read(File.join(demo_post.url, "index.html"))
  end
end
