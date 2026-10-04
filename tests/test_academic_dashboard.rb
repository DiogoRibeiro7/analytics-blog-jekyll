# frozen_string_literal: true

require "nokogiri"
require_relative "test_helper"

# The academic dashboard (components/academic-dashboard.html), which nothing
# rendered until #355 put it on the demo's /academic/ page. Unrendered, it had
# rotted: its profiles never appeared (a filter on a for loop's collection), it
# carried a second h1, metric terms sat outside any <dl>, and the bibliography
# was joined with a literal "\n\n".
class AcademicDashboardTest < Minitest::Test
  def demo
    @demo ||= Nokogiri::HTML(SiteBuilder.read("academic/index.html"))
  end

  def render(front_matter)
    site = TestSite.build(title: "Academic") do |source|
      source.theme("_includes", "_data/i18n")
      source.page("index.html", "{% include components/academic-dashboard.html academic=page.academic %}",
                  { "layout" => nil }.merge(front_matter))
    end
    site.html("index.html")
  end

  def test_the_demo_page_renders_every_section_under_its_own_heading
    dashboard = demo.at_css(".academic-dashboard")

    assert dashboard, "/academic/ renders the component"
    assert_equal 1, demo.css("h1").size, "the page gives the only h1"
    sections = dashboard.css("> section").map do |section|
      section["class"].split.first.delete_prefix("academic-dashboard__")
    end
    assert_equal %w[profiles citations submissions workflow calendar funding opportunities mentorship
                    open-science-badges networking], sections
  end

  def test_the_profiles_render_with_their_names_and_rel_me
    profiles = demo.css(".academic-profile")

    assert_equal(%w[google_scholar orcid researchgate academia], profiles.map { |profile| profile["data-profile"] })
    assert_equal(["Google Scholar", "ORCID", "ResearchGate", "Academia.edu"], profiles.map { |p| p.at_css("h3").text })
    profiles.css("a.academic-profile__link").each do |link|
      assert_equal %w[me noopener noreferrer], link["rel"].split, "the site owner's profile"
    end
  end

  def test_terms_and_definitions_sit_in_definition_lists
    orphans = demo.css(".academic-dashboard dt, .academic-dashboard dd").reject do |node|
      node.ancestors("dl").any?
    end

    assert_empty orphans.map(&:to_html)
    assert_equal 3, demo.css("dl.citation-metrics__totals > div > dd[data-citation-metric]").size
  end

  def test_no_label_is_left_untranslated
    refute_match(/academic_dashboard\./, demo.at_css(".academic-dashboard").text)
  end

  def test_the_filters_list_each_status_and_type_once
    statuses = demo.css("[data-submission-filter] option").map { |option| option["value"] }
    types = demo.css("[data-calendar-filter] option").map { |option| option["value"] }

    assert_equal "", statuses.first
    assert_equal statuses, statuses.uniq
    assert_equal demo.css(".submission-card").size, statuses.size - 1
    assert_equal types, types.uniq
    assert(demo.css("[data-academic-calendar] li").all? { |item| types.include?(item["data-event-type"]) })
  end

  def test_a_calendar_date_without_a_time_shows_no_time
    dates = demo.css(".calendar-event__meta dd").map(&:text)

    refute_empty dates
    dates.each { |date| refute_includes date, "00:00" }
  end

  def test_a_map_passed_as_academic_renders_only_what_it_has
    html = render({ "academic" => {
                    "citations" => { "metrics" => { "total" => 1248, "h_index" => 23, "i10_index" => 41 } },
                    "submissions" => [{ "title" => "A paper", "venue" => "A journal", "status" => "Drafting" }]
                  } })

    assert_equal(%w[academic-dashboard__citations academic-dashboard__submissions],
                 html.css(".academic-dashboard > section").map { |section| section["class"] })
    assert_equal "1248", html.at_css("dd[data-citation-metric='total']").text
    assert_nil html.at_css("h1")
  end

  def test_without_data_the_dashboard_has_no_empty_sections
    html = render({})

    assert html.at_css(".academic-dashboard")
    assert_empty html.css(".academic-dashboard h2")
  end

  def test_the_bibliography_export_is_labelled_and_keeps_a_blank_line_between_entries
    site = TestSite.build(title: "Academic") do |source|
      source.theme("_includes", "_data/i18n")
      source.data("publications.yml", { "bibliography" => ["@article{a, title={A}}", "@article{b, title={B}}"] })
      source.page("index.html", "{% include components/academic-dashboard.html %}")
    end
    textarea = site.html("index.html").at_css("textarea#bibliography-export")

    assert_equal "bibliography-heading", textarea["aria-labelledby"]
    assert_equal "@article{a, title={A}}\n\n@article{b, title={B}}", textarea.text
  end
end
