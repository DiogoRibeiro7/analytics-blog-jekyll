# frozen_string_literal: true

require_relative "test_helper"
require "nokogiri"
require "yaml"

# The header, the navigation, the breadcrumbs, the sharing buttons and the
# footer, on a site that is not in English. The theme ships translations for
# all of it in three languages; what it did not do was ask for them, so a
# Spanish or Portuguese site got Portuguese post metadata inside an English
# chrome (#331).
class LocalizedChromeTest < Minitest::Test
  LOCALES = %w[en es pt].freeze

  def test_the_chrome_of_a_portuguese_site_is_in_portuguese
    doc = portuguese_post
    header = doc.at_css(".site-header")

    assert_equal "Pesquisar código, equações e insights", header.at_css("#site-search-input")["placeholder"]
    assert_equal "Pesquisar", header.at_css(".site-search button").text.strip
    assert_equal "Alternar modo escuro para melhor leitura", header.at_css("[data-toggle-dark-mode]")["aria-label"]
    assert_equal "Abrir ou fechar navegação", header.at_css(".nav-toggle")["aria-label"]
    assert_equal "Navegação principal", header.at_css("#site-nav")["aria-label"]
    assert_includes header.at_css(".site-brand")["aria-label"], "Página inicial de"
  end

  def test_the_navigation_takes_the_key_each_entry_names
    titles = portuguese_post.css(".site-nav .nav-title").map(&:text)

    # _data/navigation.yml carries `title: Research` and
    # `title_key: navigation.header.research.title` for the same entry. The
    # key is the one a site in another language needs.
    assert_includes titles, "Investigação"
    assert_includes titles, "Conjuntos de dados"
    refute_includes titles, "Research"

    descriptions = portuguese_post.css(".site-nav .nav-description").map(&:text)
    assert_includes descriptions, "Artigos, estudos de replicação e documentação"
  end

  def test_the_article_chrome_is_translated_too
    doc = portuguese_post

    assert_equal "Caminho de navegação", doc.at_css(".breadcrumbs")["aria-label"]
    assert_equal "Início", doc.at_css(".breadcrumbs .breadcrumbs__link span[itemprop='name']").text.strip
    assert_equal "Partilhar este artigo", doc.at_css(".social-share")["aria-label"]
    assert_equal "Partilhar no LinkedIn", doc.at_css(".social-share__button--linkedin")["aria-label"]
    assert_equal "Nesta página", doc.at_css(".enhanced-toc__heading").text.strip
  end

  def test_the_footer_headings_are_translated
    headings = portuguese_post.css(".site-footer h2").map { |node| node.text.strip }

    assert_includes headings, "Explorar"
    assert_includes headings, "Contacto"
    assert_includes headings, "Fique a par"
  end

  # A key that does not exist renders as the key itself, which would put
  # "navigation.header.blog.title" in the menu of every site.
  def test_every_key_the_navigation_data_names_exists_in_every_locale
    data = YAML.load_file(File.join(SiteBuilder.root, "_data", "navigation.yml"))
    named = collect_keys(data)
    refute_empty named

    LOCALES.each do |locale|
      translations = YAML.load_file(File.join(SiteBuilder.root, "_data", "i18n", "#{locale}.yml"))
      missing = named.reject { |key| translated?(translations, key) }
      assert_empty missing, "#{locale}.yml has no translation for #{missing.join(', ')}"
    end
  end

  private

  def collect_keys(value)
    case value
    when Hash
      value.flat_map do |key, nested|
        key.to_s.end_with?("_key") && nested.is_a?(String) ? [nested] : collect_keys(nested)
      end
    when Array then value.flat_map { |entry| collect_keys(entry) }
    else []
    end
  end

  def translated?(translations, key)
    key.split(".").reduce(translations) do |scope, segment|
      break nil unless scope.is_a?(Hash)

      scope[segment]
    end.is_a?(String)
  end

  # The demo site's own posts, built with the site language set to Portuguese.
  def portuguese_post
    self.class.portuguese_post ||= build_portuguese_post
  end

  class << self
    attr_accessor :portuguese_post
  end

  # The theme's own layouts, includes and data over one post, with the site
  # language set to Portuguese. Built from a copy rather than from the demo
  # source so that this build compiles no stylesheet: the Sass compiler the
  # suite's first build leaves behind cannot serve a second one.
  def build_portuguese_post
    front = { "layout" => "post", "title" => "Um artigo", "tags" => ["estatística"],
              "categories" => ["investigação"] }
    site = TestSite.build(url: "https://example.test", title: "Sítio", author: { "name" => "Autora" },
                          features: { "search" => true, "dark_mode_toggle" => true },
                          theme_options: { "localization" => { "default_locale" => "pt" } }) do |source|
      # No _sass: the Sass compiler the suite's first build leaves behind
      # cannot serve a second one.
      source.theme("_layouts", "_includes", "_data")
      source.post("2026-01-01-post", "## Primeira secção\n\nCorpo.\n\n## Segunda secção\n\nCorpo.", front)
    end
    Nokogiri::HTML5(site.jekyll.posts.docs.first.output)
  end
end
