# frozen_string_literal: true

require "nokogiri"
require "tmpdir"
require_relative "test_helper"

# Reading mode and print (_includes/components/reading-mode-toggle.html and
# _sass/_print.scss): the control on posts, its settings, the address line
# on paper, and the print rules in the stylesheet (#248).
class ReadingModeTest < Minitest::Test
  POST = "2024/04/05/sql-optimization-guide/index.html"

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def test_a_post_offers_the_control_and_its_address_on_paper
    html = SiteBuilder.read(POST)
    doc = Nokogiri::HTML5.fragment(html)
    toggle = doc.at_css("button[data-reading-mode-toggle]")

    assert_equal "false", toggle["aria-pressed"]
    assert_equal ["Reading mode", "Exit reading mode"], [toggle["data-label-enter"], toggle["data-label-exit"]]
    assert_nil toggle["data-reading-mode-remember"], "the choice is not remembered unless the site asks"
    assert doc.at_css("##{toggle['aria-describedby']}"), "the hint the button is described by exists"
    assert_match(%r{<script nonce="[^"]+">\s*// Reading mode}, html, "the script carries the page's CSP nonce")
    assert_equal 1, doc.css(".post-content").size, "reading mode reuses the article; nothing is duplicated"

    source = doc.at_css(".post-print-source")

    assert_includes source["class"], "print-only"
    assert_equal "Online at https://diogoribeiro7.github.io/2024/04/05/sql-optimization-guide/", source.text.strip
  end

  def test_the_control_follows_the_site_settings
    assert_nil render("enabled" => false).at_css("[data-reading-mode-toggle]")
    assert render("remember" => true).at_css("[data-reading-mode-toggle][data-reading-mode-remember]")
    assert render({}).at_css("[data-reading-mode-toggle]"), "on by default"
  end

  def test_the_control_follows_the_page_language
    assert_equal "Modo de leitura", render({}, "pt").at_css("[data-reading-mode-label]").text
  end

  def test_the_stylesheet_hides_the_chrome_in_reading_mode_and_in_print
    css = SiteBuilder.read("assets/css/main.css")

    assert_match(/body\.reading-mode \.site-header,[^{]*\{display:none !important\}/, css)
    assert_match(/body\.reading-mode \.reading-mode-bar\{position:sticky/, css)
    assert_includes css, ".print-only{display:none}"

    print = css[/@media print\{@page\{margin:2cm\}.*?\.viz-table-wrapper\[hidden\]\{display:block !important\}\}/m]

    refute_nil print, "the print block starts at @page and ends with the visualization table fallback"
    assert_match(/\.site-header,\.site-footer,[^{]*\{display:none !important\}/, print)
    assert_includes print, "body.dark-mode .highlight span{color:#000 !important;background:none !important}"
    assert_includes print, ".post-content a[href^=http]::after{content:\" (\" attr(href) \")\""
    assert_match(/mjx-container\[display=true\],\.katex-display\{break-inside:avoid/, print)
  end

  private

  # A page holding the control, under the given reading_mode settings. The
  # parameters are positional: a bare `"key" => value` argument would be read
  # as keywords otherwise.
  def render(settings, lang = nil)
    FileUtils.mkdir_p(File.join(@dir, "_includes", "components"))
    FileUtils.mkdir_p(File.join(@dir, "_data"))
    FileUtils.cp(File.join(SiteBuilder.root, "_includes", "components", "reading-mode-toggle.html"),
                 File.join(@dir, "_includes", "components", "reading-mode-toggle.html"))
    FileUtils.cp_r(File.join(SiteBuilder.root, "_data", "i18n"), File.join(@dir, "_data"))
    front_matter = { "layout" => nil, "title" => "Paper", "lang" => lang }.compact.to_yaml
    File.write(File.join(@dir, "index.html"),
               "#{front_matter}---\n\n{% include components/reading-mode-toggle.html %}\n")
    config = Jekyll.configuration(
      "source" => @dir, "destination" => File.join(@dir, "_site"), "quiet" => true, "title" => "Reading",
      "url" => "https://example.org", "author" => { "name" => "Test" },
      "theme_options" => { "reading_mode" => settings }
    )
    Jekyll::Site.new(config).process
    Nokogiri::HTML5.fragment(File.read(File.join(@dir, "_site", "index.html")))
  end
end
