---
title: Component showcase
description: Practical examples of the hero, academic dashboard, citation tooling, and badge components bundled with the theme.
permalink: /features/components/
hero_title: Components in action
hero_tagline: Each section below renders a live include shipped with the theme so you can copy the markup into your own site.
hero_cta_url: /visualizations/
hero_cta_label: Explore visualization embeds
academic_stats:
  citations: "1,248"
  h_index: 23
  i10_index: 41
  datasets: 12
  notebooks: 18
  dashboards: 9
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
    <p>The <code>academic-dashboard</code> include assembles publication stats, citation metrics, and collaboration links.
    Pass your own data via front matter or liquid assigns.</p>
    {% include components/academic-dashboard.html stats=page.academic_stats %}
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
