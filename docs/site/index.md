---
layout: home
permalink: /
hero_title: DataLog documentation
hero_tagline: Build research sites with articles, notebooks, datasets, and interactive visualizations.
hero_cta_url: /guides/installation/
hero_cta_label: Get started
hero_secondary_cta_url: /features/
hero_secondary_cta_label: Explore features
home_features_heading: Start exploring
home_features:
  - title: Layout reference
    description: Compare posts, projects, research pages, and other layouts.
    url: /features/layouts/
  - title: Interactive visualizations
    description: Adapt live charts and dashboards for your own analytics work.
    url: /visualizations/
  - title: Migration guides
    description: Move from an existing theme with practical checklists.
    url: /guides/migration/
---

<section class="section section-intro">
  <div class="container">
    <h2>Learn DataLog by using it</h2>
    <div class="split-grid">
      <div>
        <p>This documentation site runs on the DataLog Jekyll theme. The guides explain installation and configuration;
        the feature pages show the same layouts, components, and visualizations in use.</p>
        <p>Start with a working site, then explore example articles, notebooks, datasets, and projects below. Each example
        is rendered by the theme and keeps its own documentation URL.</p>
      </div>
      <div class="card card--accent">
        <h3>Documentation quick stats</h3>
        <ul>
          <li><strong>{{ site.posts | size }}</strong> example posts</li>
          <li><strong>{{ site.portfolio | size }}</strong> portfolio case studies</li>
          <li><strong>{{ site.datasets | size }}</strong> dataset catalog entries</li>
          <li><strong>{{ site.notebooks | size }}</strong> interactive notebook walk-throughs</li>
        </ul>
      </div>
    </div>
  </div>
</section>
