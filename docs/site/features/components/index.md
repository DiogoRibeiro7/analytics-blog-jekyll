---
title: Component showcase
description: Practical examples of the hero, academic dashboard, citation tooling, and badge components bundled with the theme.
permalink: /features/components/
hero_title: Components in action
hero_tagline: Each section below renders a live include shipped with the theme so you can copy the markup into your own site.
hero_cta_url: /visualizations/
hero_cta_label: Explore visualization embeds
# The academic dashboard's data, in the shape of _data/academic.yml.
academic_demo:
  citations:
    metrics:
      total: 1248
      h_index: 23
      i10_index: 41
      since_2020:
        total: 812
        h_index: 17
        i10_index: 26
  submissions:
    - title: Reproducible dashboards for public health surveillance
      venue: Journal of Open Source Software
      type: journal
      status: Under review
      deadline: 2026-11-15
    - title: Accessible charts for screen-reader users
      venue: IEEE VIS
      type: conference
      status: Drafting
      deadline: 2027-03-31
  calendar:
    events:
      - name: Open Science Workshop
        type: workshop
        location: Porto
        start_date: 2026-11-20 09:00
        end_date: 2026-11-20 17:00
      - name: Data Visualization Summit
        type: conference
        location: Online
        start_date: 2027-02-10 14:00
        end_date: 2027-02-12 18:00
citation_entry:
  title: DataLog Theme
  authors: Ribeiro, D.
  year: 2024
  publisher: ESMAD
  doi: 10.1234/datalog.2024
open_science_badges:
  - label: Open Data
    description: Source data sets and SQL transformations
  - label: Open Materials
    description: Slide decks, interview guides, and analysis notebooks
  - label: Preregistered
    description: Registered report DOI 10.1234/prereg
---

{% include components/hero.html %}

<section class="section">
  <div class="container">
    <h2>Academic dashboard</h2>
    <p>The <code>academic-dashboard</code> include assembles citation metrics, submissions, the academic calendar and
    collaboration links from <code>_data/academic.yml</code>. Pass a map of the same shape as <code>academic</code>
    to render other data, as this page does from its front matter.</p>
    {% include components/academic-dashboard.html academic=page.academic_demo %}
  </div>
</section>

<section class="section section-alt">
  <div class="container">
    <h2>Citation tools</h2>
    <p>Help readers cite your work by embedding BibTeX, APA, and MLA snippets with the
    <code>citation-tools</code> include.</p>
    {% include components/citation-tools.html citation=page.citation_entry %}
  </div>
</section>

<section class="section">
  <div class="container">
    <h2>Open science badges</h2>
    <p>Combine preregistration, data availability, and replication badges to spotlight reproducibility.
    The markup below renders all three with descriptive tooltips.</p>
    {% include components/open-science-badges.html badges=page.open_science_badges %}
  </div>
</section>
