# frozen_string_literal: true

require_relative "test_helper"

class TestI18n < Minitest::Test
  def test_language_switcher_and_hreflang_links
    html = SiteBuilder.read("index.html")

    assert_includes html, "data-language-switcher", "expected language switcher select"
    assert_includes html, 'hreflang="pt"'
    assert_includes html, 'hreflang="es"'
    assert_includes html, 'hreflang="ar"'
  end

  def test_portuguese_homepage_strings
    html = SiteBuilder.read("pt/index.html")

    assert_includes html, "lang=\"pt\""
    assert_includes html, "Progresso de leitura"
    assert_includes html, "Pesquisar código, equações e insights"
  end

  def test_spanish_homepage_strings
    html = SiteBuilder.read("es/index.html")

    assert_includes html, "lang=\"es\""
    assert_includes html, "Progreso de lectura"
    assert_includes html, "Buscar código, ecuaciones e insights"
  end

  def test_rtl_layout_applied
    html = SiteBuilder.read("ar/index.html")

    assert_includes html, "dir=\"rtl\""
    assert_match(/class=\"[^\"]*rtl[^\"]*\"/, html)
  end
end
