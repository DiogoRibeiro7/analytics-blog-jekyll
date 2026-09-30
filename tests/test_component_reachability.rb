# frozen_string_literal: true

require_relative "test_helper"

# Every file in _includes/components/ is included by something a build
# renders: a layout, a page, a post, the documentation site, a test page, the
# theme's own Ruby, or another include that one of those reaches. Six were
# included by nothing (#341, #355). They shipped in the gem with no page
# rendering them and no test reading them, so nothing noticed them rot: one
# threw on load for as long as it existed.
class ComponentReachabilityTest < Minitest::Test
  INCLUDE = /\{%-?\s*include(?:_cached)?\s+([^\s%{]+\.html)/
  SOURCES = "**/*.{html,md,markdown,xml,liquid,rb}"
  # Build output, dependencies, and the files that only describe includes.
  IGNORED = %r{\A(?:node_modules|vendor|tmp|coverage|pkg|tests|docs/history|\.[^/]+)/|(?:\A|/)_site/}

  def self.graph
    @graph ||= begin
      edges = Hash.new { |hash, key| hash[key] = [] }
      Dir.glob(SOURCES, base: TestSite.root).grep_v(IGNORED).each do |file|
        File.read(File.join(TestSite.root, file), encoding: "utf-8").scan(INCLUDE).flatten.each do |name|
          edges[file] << "_includes/#{name}"
        end
      end
      edges
    end
  end

  # The includes reached from every file that is not an include itself.
  def self.reached
    @reached ||= begin
      seen = {}
      queue = graph.keys.reject { |file| file.start_with?("_includes/") }
      until queue.empty?
        graph[queue.shift].each do |target|
          next if seen[target]

          seen[target] = true
          queue << target
        end
      end
      seen
    end
  end

  def components
    Dir.glob("_includes/components/**/*.html", base: TestSite.root).sort
  end

  def test_every_component_is_included_by_something_the_build_renders
    unreached = components.reject { |component| self.class.reached[component] }

    assert_empty unreached,
                 "Included by no layout, page, post, docs-site page, test page or plugin. Render each one where " \
                 "the suite builds it (a demo page or _test_pages/), or remove it: #{unreached.join(', ')}"
  end

  # The scan has to see the includes a plugin writes in Ruby and those one
  # include makes of another, or it would call live components unreached.
  def test_the_scan_follows_plugins_and_nested_includes
    assert self.class.reached["_includes/components/comments-thread.html"], "lib/datalog/plugins/comments.rb"
    assert self.class.reached["_includes/components/open-science-badges.html"], "academic-dashboard.html"
    assert self.class.reached["_includes/components/visualization-card.html"], "visualizations/index.md"
  end
end
