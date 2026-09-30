# frozen_string_literal: true

require "nokogiri"
require_relative "test_helper"

# How display equations look and which of them are numbered (#318). Each was a
# framed card, 106px tall around a 16px formula, and MathJax numbered every
# one. By default an equation is now set plain on its line, and MathJax numbers
# only those the text can refer to; `display_style: card` and `numbering: all`
# bring the old page back.
class MathDisplayTest < Minitest::Test
  POST = <<~'MARKDOWN'
    An equation nothing refers to:

    $$
    x = 1
    $$

    and one the text does:

    $$
    y = 2 \label{eq:y}
    $$

    See \eqref{eq:y}.
  MARKDOWN

  CARD_SHADOW = /box-shadow:\s*0 12px 30px/

  # One build per settings: each compiles the whole stylesheet.
  def self.site(math)
    @sites ||= {}
    @sites[math] ||= TestSite.build(title: "Equations", permalink: "/:title/",
                                    theme_options: { "math" => math }) do |source|
      source.theme("_layouts", "_includes", "_data", "_sass", "assets/css/main.scss")
      source.post("2026-01-01-equations", POST, "layout: post\ntitle: Equations\n")
      source.write("assets/css/whole.scss", "---\n---\n@use \"theme\";\n")
    end
  end

  def site(math = {})
    self.class.site(math)
  end

  def post(math = {})
    site(math).document("equations/index.html")
  end

  def mathjax_config(math = {})
    post(math).css("head script").map(&:text).find { |script| script.include?("window.MathJax = {") }
  end

  # The selectors of the rules that draw the card's shadow round an equation.
  def card_selectors(css)
    css.scan(/([^{}]+)\{[^{}]*#{CARD_SHADOW.source}[^{}]*\}/).flatten.map(&:strip).grep(/math-expression/)
  end

  def test_by_default_mathjax_numbers_as_amsmath_does_and_a_labelled_display_too
    config = mathjax_config

    assert_includes config, "tags: 'ams'"
    # MathJax's own `ams` leaves `$$ y \label{eq:y} $$` unnumbered, and the
    # \eqref to it reads (???); the head numbers a display with a \label.
    assert_includes config, "AmsTags.prototype.finalize"
    assert_includes config, "window.DatalogMath.init(MJ, { numbering: 'ams' })"
  end

  def test_all_and_none_reach_mathjax_without_the_label_rule
    %w[all none].each do |numbering|
      config = mathjax_config("numbering" => numbering)

      assert_includes config, "tags: '#{numbering}'"
      assert_includes config, "{ numbering: '#{numbering}' }"
      refute_includes config, "AmsTags", "only `ams` needs the label rule"
    end
  end

  # The validator stops a build with any other value, but it is one of the
  # theme's plugins, and a build that runs none of them (GitHub Pages' safe
  # mode) still renders the include; what it writes into the script stays one
  # of the three.
  def test_a_value_the_theme_does_not_know_becomes_ams_and_plain
    source = File.read(File.join(TestSite.root, "_includes", "meta", "math-config.html"))
    template = Liquid::Template.parse("#{source}{{ math_numbering }}|{{ math_display_style }}")
    math = { "numbering" => "all'; alert(1); '", "display_style" => "card'" }
    rendered = template.render("site" => { "theme_options" => { "math" => math } }, "include" => { "page" => {} })

    assert_equal "ams|plain", rendered.strip
  end

  def test_a_plain_site_has_no_card_in_its_page_or_its_stylesheet
    refute_includes post.at_css("body")["class"].split, "math-card"

    css = site.read("assets/css/main.css")

    assert_empty card_selectors(css)
    refute_includes css, ".math-card"
    # The tools are out of sight until the pointer or the focus reaches them.
    assert_match(/\.math-expression__toolbar\{[^}]*opacity:\s*0/, css.gsub(/\s+(?=[{}])/, ""))
    assert_match(/\.math-expression:is\(:hover,\s*:focus-within\) \.math-expression__toolbar/, css)
  end

  def test_a_card_site_marks_the_body_and_compiles_the_card
    assert_includes post("display_style" => "card").at_css("body")["class"].split, "math-card"

    selectors = card_selectors(site("display_style" => "card").read("assets/css/main.css"))

    refute_empty selectors
    assert(selectors.all? { |selector| selector.start_with?(".math-card") }, selectors.inspect)
  end

  def test_the_whole_stylesheet_keeps_the_card_behind_its_class
    # A site whose main.scss is a bare `@use "theme"` compiles every optional
    # style, the card included; a plain site's equations must stay plain.
    selectors = card_selectors(site.read("assets/css/whole.css"))

    refute_empty selectors
    assert(selectors.all? { |selector| selector.start_with?(".math-card") }, selectors.inspect)
  end

  def test_the_validator_takes_only_the_listed_values
    validate = lambda do |math|
      config = { "title" => "T", "url" => "https://example.org", "author" => "A",
                 "theme_options" => { "math" => math } }
      Datalog::ConfigValidator.new.generate(Struct.new(:config).new(config))
    end

    %w[plain card].each { |style| assert_nil validate.call("display_style" => style) }
    %w[ams all none].each { |numbering| assert_nil validate.call("numbering" => numbering) }

    error = assert_raises(Jekyll::Errors::FatalException) { validate.call("display_style" => "boxed") }
    assert_includes error.message, "Invalid value for 'theme_options.math.display_style'"
    error = assert_raises(Jekyll::Errors::FatalException) { validate.call("numbering" => "labelled") }
    assert_includes error.message, "Invalid value for 'theme_options.math.numbering'"
  end
end
