# frozen_string_literal: true

require_relative "test_helper"

# The header navigation is rendered with include_cached, which keys its cache on
# the include's parameters and never on the page. Each page has to mark its own
# section as current, not whichever page happened to render the list first.
class NavigationCacheTest < Minitest::Test
  def test_each_section_marks_only_its_own_navigation_link
    {
      "index.html" => [],
      "blog/index.html" => ["/blog/"],
      "about/index.html" => ["/about/"],
      "datasets/index.html" => ["/datasets/"],
      "portfolio/index.html" => ["/portfolio/"]
    }.each do |page, expected|
      assert_equal expected, current_links(page), "#{page} should mark #{expected.inspect} as the current section"
    end
  end

  def test_only_the_current_link_carries_aria_current
    navigation = SiteBuilder.read("about/index.html")[%r{<nav id="site-nav".*?</nav>}m]

    refute_nil navigation, "the page should have the site navigation"
    assert_equal 1, navigation.scan('aria-current="page"').size
  end

  private

  def current_links(page)
    navigation = SiteBuilder.read(page)[%r{<nav id="site-nav".*?</nav>}m].to_s
    navigation.scan(/class="nav-link is-active" href="([^"]*)"/).flatten
  end
end
