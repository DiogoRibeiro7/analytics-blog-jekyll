# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/test_site"
require "fastimage"
require "nokogiri"
require "rbconfig"
require "tmpdir"

# Share cards drawn at build time for pages without an image of their own
# (#297): every post without an og_image was shared with the same picture,
# and a link to an article looked like a link to the about page.
class SocialCardTextTest < Minitest::Test
  PlainText = Datalog::SocialCards::PlainText
  Typesetter = Datalog::SocialCards::Typesetter

  # The default template's title box.
  TITLE_BOX = Typesetter::Box.new(width: 1040, height: 262, font_size: 66, min_font_size: 40, max_lines: 4,
                                  line_height: 1.15)

  def test_tex_in_a_title_reads_as_text
    {
      '$\alpha$-stable laws for $X_t^2$' => "α-stable laws for X_t²",
      'Estimating $\beta_0$ and $\beta_{12}$' => "Estimating β₀ and β₁₂",
      'When $\mathbb{E}[X] \leq \infty$' => "When 𝔼[X] ≤ ∞",
      'Why $\frac{1}{n}\sum x_i$ converges' => "Why 1/n∑x_i converges",
      '\(\sqrt{n}\)-consistency of \(\hat\sigma^2\)' => "√n-consistency of σ̂²",
      "The $L^p$ norm of $e^{-x^2}$" => "The L^p norm of e^(−x²)",
      'Matrix $\mathbf{A}^{\top}$ and $\operatorname{tr}(A)$' => "Matrix A^T and tr(A)"
    }.each { |title, text| assert_equal text, PlainText.from_tex(title), title }
  end

  def test_a_dollar_sign_is_money_unless_it_opens_maths
    assert_equal "Saving $5 and $10 a day", PlainText.from_tex("Saving $5 and $10 a day")
    assert_equal "Pay $5 now", PlainText.from_tex('Pay \$5 now')
    assert_equal "An unclosed $x", PlainText.from_tex("An unclosed $x")
  end

  def test_a_140_character_title_fits_whole
    title = "A practical guide to estimating heavy-tailed distributions from censored survival data, " \
            "with bootstrap intervals and model diagnostics in Go"
    assert_equal 140, title.length

    size, lines = Typesetter.new("serif").fit(title, TITLE_BOX)
    assert_operator size, :>=, TITLE_BOX.min_font_size
    assert_operator lines.size, :<=, 4
    assert_equal title, lines.map(&:text).join(" "), "every word is on the card"
    assert(lines.all? { |line| line.width <= TITLE_BOX.width })
    assert_operator lines.size * size * TITLE_BOX.line_height, :<=, TITLE_BOX.height
  end

  def test_a_title_too_long_for_the_card_ends_in_an_ellipsis
    _size, lines = Typesetter.new("serif").fit("word " * 120, TITLE_BOX)

    assert_equal 4, lines.size
    assert lines.last.text.end_with?("…")
    assert(lines.all? { |line| line.width <= TITLE_BOX.width })
  end

  # Neither font has ℝ or ∈: the card writes R and "in", never a box.
  def test_a_character_no_font_has_is_decomposed_or_spelled_out
    setter = Typesetter.new("serif")

    assert_equal "R", setter.runs("ℝ").map(&:first).join
    assert_equal " in ", setter.runs("∈").map(&:first).join
    assert(setter.runs("α β ≤ é ç").all? { |char, font| font.glyph?(char) })
  end

  def test_the_font_reader_draws_simple_and_composite_glyphs
    font = Typesetter.fonts.fetch("serif")

    assert_equal 2, font.outline(font.glyph_id("o")).size, "an o is two contours"
    assert_operator font.outline(font.glyph_id("é")).size, :>=, 2, "é is an e and an accent"
    assert_match(/\AM [\d.]+ [\d.]+ (?:[LQ] [\d. ]+ )+Z/, font.path("o", 0, 100, 72))
    assert_in_delta 406.1, font.width("Hello world", 72), 0.1
  end
end

# The template, drawn as MVG.
class SocialCardTemplateTest < Minitest::Test
  Template = Datalog::SocialCards::Template
  SCHEMES = Datalog::SocialCards::SCHEMES
  FIELDS = { "site" => "DataLog", "kicker" => "Part 3 of 4 · Missing data", "title" => "Multiple imputation",
             "byline" => "Ada Lovelace · March 2, 2026", "detail" => "Journal of Data · DOI 10.1/xyz" }.freeze

  def test_every_text_colour_meets_aa_in_both_schemes
    SCHEMES.each do |scheme, colors|
      Datalog::SocialCards::TEXT_COLORS.each do |name|
        ratio = Datalog::SocialCards.contrast(colors[name], colors["background"])
        assert_operator ratio, :>=, 4.5, "#{scheme} #{name} is #{ratio.round(2)}:1"
      end
    end
  end

  def test_the_default_template_draws_every_field_and_the_mark
    mvg = default_template.to_mvg(FIELDS, logo: Datalog::SocialCards::MARK)

    assert mvg.start_with?("viewbox 0 0 1200 630\n")
    assert_includes mvg, "fill '#{SCHEMES['dark']['background']}'"
    # One graphic context per drawn thing: two rectangles, the mark's two
    # paths and five text slots.
    assert_equal 9, mvg.scan("push graphic-context").size
    assert_equal mvg.scan("push graphic-context").size, mvg.scan("pop graphic-context").size
    refute_match(/^text /, mvg, "text is drawn as outlines, not set by ImageMagick")
  end

  # ImageMagick 7 reads `stroke-opacity 1` after `stroke none` as an opaque
  # black stroke, which thinned every light glyph on a dark card.
  def test_no_opacity_is_written_for_an_unpainted_colour
    mvg = default_template.to_mvg(FIELDS, logo: Datalog::SocialCards::MARK)

    mvg.split("push graphic-context").each do |context|
      refute_match(/stroke-opacity/, context) if context.include?("stroke none")
      refute_match(/fill-opacity/, context) if context.include?("fill none")
    end
    assert_includes mvg, "fill-opacity 0.25", "the mark's tinted disc keeps its opacity"
  end

  def test_an_empty_field_draws_nothing
    with = default_template.to_mvg(FIELDS)
    without = default_template.to_mvg(FIELDS.merge("detail" => "", "kicker" => nil))

    assert_equal with.scan("push graphic-context").size - 2, without.scan("push graphic-context").size
  end

  def test_a_template_of_its_own_with_transforms_images_and_styles
    svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 315">
        <g transform="translate(10 20) scale(2)" style="fill: {{accent}}; opacity: 0.5">
          <circle cx="5" cy="5" r="5"/>
          <rect x="0" y="0" width="10" height="10" rx="2" stroke="{{ink}}" stroke-width="3"/>
        </g>
        <image href="/assets/img/mark.png" x="0" y="0" width="10" height="10"/>
        <text data-field="title" x="20" y="100" width="560" font-size="40" data-font="serif" fill="{{ink}}"/>
        <linearGradient id="g"/>
      </svg>
    SVG
    resolve = ->(href) { "/site#{href}" if href == "/assets/img/mark.png" }
    template = Template.new(svg, colors: SCHEMES["light"], resolve: resolve)
    mvg = template.to_mvg({ "title" => "Own template" })

    assert_includes mvg, "affine 4,0,0,4,20,40", "the view box's scale, then the group's"
    assert_includes mvg, "fill-opacity 0.5"
    assert_includes mvg, "roundrectangle 0,0 10,10 2,2"
    assert_includes mvg, "stroke '#{SCHEMES['light']['ink']}'"
    assert_includes mvg, "image over 0,0 10,10 '/site/assets/img/mark.png'"
    assert_equal ["linearGradient"], template.ignored
  end

  def test_a_template_that_is_not_svg_or_holds_no_colour_stops_the_build
    assert_raises(Template::Error) { Template.new("<svg><rect", colors: {}).to_mvg({}) }
    assert_raises(Template::Error) do
      Template.new('<svg xmlns="http://www.w3.org/2000/svg"><rect width="1" height="1" fill="red\'; x"/></svg>',
                   colors: {}).to_mvg({})
    end
    assert_raises(Template::Error) do
      Template.new('<svg xmlns="http://www.w3.org/2000/svg"><path d="M 0 0\' image over"/></svg>', colors: {}).to_mvg({})
    end
  end

  private

  def default_template
    Template.new(File.read(Template::DEFAULT), colors: SCHEMES["dark"])
  end
end

# Whole sites, built with a stand-in for ImageMagick that copies a 1200×630
# PNG to its output and logs each call; and once with the real one.
class SocialCardSiteTest < Minitest::Test
  PNG = File.join(SiteBuilder.root, "assets/img/social-card.png")
  ENCODER = <<~RUBY.freeze
    require "fileutils"
    File.open(ENV.fetch("CARD_LOG"), "a") { |log| log.puts(ARGV.join(" ")) }
    FileUtils.cp(#{PNG.inspect}, ARGV.last.delete_prefix("png:"))
  RUBY

  def setup
    @scripts = Dir.mktmpdir
    @log = File.join(@scripts, "calls.log")
    ENV["CARD_LOG"] = @log
    File.write(File.join(@scripts, "encoder.rb"), ENCODER)
    Datalog::SocialCards.instance_variable_set(:@warned, nil)
  end

  def teardown
    FileUtils.rm_rf(@scripts)
  end

  def test_a_post_without_an_image_is_shared_with_its_own_card
    site = build
    head = site.document("2026/01/02/part-one/index.html")
    url = head.at_css('meta[property="og:image"]')["content"]

    assert_match %r{\Ahttps://example\.org/blog/assets/social/2026-01-02-part-one-\h{12}\.png\z}, url
    assert_equal url, head.at_css('meta[name="twitter:image"]')["content"]
    assert_equal(%w[1200 630], %w[width height].map do |name|
      head.at_css(%(meta[property="og:image:#{name}"]))["content"]
    end)
    assert_equal "Estimating β₀ in part one", head.at_css('meta[property="og:image:alt"]')["content"]
    assert_equal [1200, 630], FastImage.size(site.path(url.delete_prefix("https://example.org/blog/")))
  end

  def test_the_card_says_what_the_page_is
    site = build
    page = site.jekyll.posts.docs.find { |post| post.data["title"].start_with?("Estimating") }
    fields = Datalog::SocialCards.fields(site.jekyll, page)

    assert_equal "Cards", fields["site"]
    assert_equal "Part 1 of 2 · Missing data", fields["kicker"]
    assert_equal "Estimating β₀ in part one", fields["title"]
    assert_equal "Ada Lovelace · January 2, 2026", fields["byline"]
    assert_equal "Journal of Data · DOI 10.1000/xyz", fields["detail"]
  end

  def test_a_page_with_its_own_image_or_that_declines_a_card_keeps_its_image
    site = build
    own = site.document("2026/01/03/with-image/index.html")
    declined = site.document("2026/01/04/declined/index.html")

    assert_equal "https://example.org/blog/assets/img/own.png", own.at_css('meta[property="og:image"]')["content"]
    assert_nil own.at_css('meta[property="og:image:alt"]')
    assert_equal "https://example.org/blog/assets/img/social-card.png",
                 declined.at_css('meta[property="og:image"]')["content"]
    assert_equal 1, Dir[site.path("assets/social/*.png")].size, "only the one post that wants a card gets one"
  end

  def test_the_json_ld_image_is_the_card
    site = build
    json = site.document("2026/01/02/part-one/index.html").css('script[type="application/ld+json"]')
               .map { |node| JSON.parse(node.text) }.find { |block| block["image"] }

    assert_match %r{/blog/assets/social/2026-01-02-part-one-\h{12}\.png\z}, json.dig("image", "url")
    assert_equal 1200, json.dig("image", "width")
  end

  def test_a_second_build_with_nothing_changed_draws_no_card
    first = build
    calls = File.readlines(@log).size
    second = build(again: first)

    assert_equal 1, calls
    assert_equal calls, File.readlines(@log).size, "the second build drew nothing"
    assert_equal(Dir[first.path("assets/social/*.png")].map { |file| File.basename(file) },
                 Dir[second.path("assets/social/*.png")].map { |file| File.basename(file) })
  end

  def test_a_changed_title_draws_a_card_at_a_new_address
    first = build
    before = Dir[first.path("assets/social/*.png")]
    File.write(File.join(first.dir, "_posts/2026-01-02-part-one.md"),
               File.read(File.join(first.dir, "_posts/2026-01-02-part-one.md")).sub("part one", "part 1"))
    second = build(again: first)

    assert_equal 2, File.readlines(@log).size
    refute_equal before, Dir[second.path("assets/social/*.png")]
  end

  def test_without_imagemagick_it_warns_once_and_pages_keep_the_default_image
    warnings = capture_warnings do
      build(tools: { "imagemagick" => nil, "writable" => [] })
      build(tools: { "imagemagick" => nil, "writable" => [] })
    end
    site = build(tools: { "imagemagick" => nil, "writable" => [] })

    assert_equal(1, warnings.count { |message| message.include?("ImageMagick") })
    assert_equal "https://example.org/blog/assets/img/social-card.png",
                 site.document("2026/01/02/part-one/index.html").at_css('meta[property="og:image"]')["content"]
    assert_empty Dir[site.path("assets/social/*")], "no page points at a card that was not drawn"
  end

  def test_a_failed_card_leaves_its_page_on_the_default_image
    File.write(File.join(@scripts, "encoder.rb"), "exit 3\n")
    warnings = capture_warnings { @site = build }

    assert(warnings.any? { |message| message.include?("could not draw the card for _posts/2026-01-02-part-one.md") })
    assert_equal "https://example.org/blog/assets/img/social-card.png",
                 @site.document("2026/01/02/part-one/index.html").at_css('meta[property="og:image"]')["content"]
  end

  def test_pages_get_cards_when_the_site_asks
    site = build(cards: { "collections" => %w[posts pages] })

    assert_match %r{/assets/social/about-\h{12}\.png\z},
                 site.document("about/index.html").at_css('meta[property="og:image"]')["content"]
  end

  def test_off_by_default
    site = build(cards: { "enabled" => false })

    assert_empty Dir[site.path("assets/social/*")]
    assert_nil File.exist?(@log) ? File.read(@log) : nil
  end

  # The real ImageMagick, which the Tests workflow installs.
  def test_imagemagick_draws_a_1200_by_630_card
    tools = Jekyll::ImageOptimizer.detect_tools
    unless Datalog::SocialCards.renderable?(tools)
      flunk "ImageMagick with MVG and PNG not found: #{tools.inspect}" if ENV["DATALOG_IMAGE_TOOLS"] == "required"
      skip "ImageMagick is not installed"
    end

    site = build(tools: tools)
    url = site.document("2026/01/02/part-one/index.html").at_css('meta[property="og:image"]')["content"]
    card = site.path(url.delete_prefix("https://example.org/blog/"))

    assert_equal :png, FastImage.type(card)
    assert_equal [1200, 630], FastImage.size(card)
  end

  private

  def build(tools: nil, cards: {}, again: nil)
    tools ||= { "imagemagick" => [RbConfig.ruby, File.join(@scripts, "encoder.rb")], "writable" => %w[MVG PNG] }
    config = {
      baseurl: "/blog", title: "Cards", url: "https://example.org", dir: again&.dir,
      permalink: "/:year/:month/:day/:title/",
      defaults: [{ "scope" => { "path" => "" }, "values" => { "layout" => "default" } }],
      author: { "name" => "Ada Lovelace" }, social: { "default_image" => "/assets/img/social-card.png" },
      # The image optimizer would call the stand-in encoder too.
      theme_options: { "social_cards" => { "enabled" => true }.merge(cards), "images" => { "variants" => false } }
    }
    replacing_tools(tools) do
      TestSite.build(config) { |source| again ? source : write_site(source) }
    end
  end

  def write_site(source)
    source.theme("_layouts", "_includes", "_data")
    source.copy("assets/img/social-card.png", "assets/img/social-card.png")
    source.data("series.yml", { "missing-data" => { "title" => "Missing data" } })
    source.post("2026-01-02-part-one", "Text.",
                "title: Estimating $\\beta_0$ in part one\nseries: missing-data\nseries_order: 1\n" \
                "journal: Journal of Data\ndoi: 10.1000/xyz\n")
    source.post("2026-01-03-with-image", "Text.", "title: With image\nog_image: /assets/img/own.png\n" \
                                                  "series: missing-data\nseries_order: 2\n")
    source.post("2026-01-04-declined", "Text.", "title: Declined\nsocial_card: false\n")
    source.page("about.md", "About.", "title: About\nlayout: default\npermalink: /about/\n")
  end

  def replacing_tools(tools)
    original = Jekyll::ImageOptimizer.method(:tools)
    Jekyll::ImageOptimizer.define_singleton_method(:tools) { tools }
    yield
  ensure
    Jekyll::ImageOptimizer.define_singleton_method(:tools, original)
  end

  def capture_warnings
    warnings = []
    logger = Jekyll.logger
    original = logger.method(:warn)
    logger.define_singleton_method(:warn) { |topic, message = nil| warnings << "#{topic} #{message}" }
    yield
    warnings
  ensure
    logger.define_singleton_method(:warn, original)
  end
end

# theme_options.social_cards in the configuration validator.
class SocialCardSettingsTest < Minitest::Test
  def test_a_scheme_the_cards_lack_or_a_logo_that_is_no_path_stops_the_build
    error = assert_raises(Jekyll::Errors::FatalException) { validate("enabled" => true, "scheme" => "blue") }
    assert_includes error.message, "Invalid value for 'theme_options.social_cards.scheme'"

    error = assert_raises(Jekyll::Errors::FatalException) { validate("enabled" => true, "logo" => 3) }
    assert_includes error.message, "theme_options.social_cards.logo"

    validate("enabled" => true, "scheme" => "light", "logo" => false, "collections" => %w[posts pages])
  end

  private

  def validate(cards)
    config = { "title" => "Cards", "url" => "https://example.org", "author" => { "name" => "Ada Lovelace" },
               "theme_options" => { "social_cards" => cards } }
    Datalog::ConfigValidator.new.generate(Struct.new(:config).new(config))
  end
end
