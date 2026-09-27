---
layout: home
permalink: /
hero_title: DataLog Theme Documentation
hero_tagline: Explore the analytics storytelling toolkit powering notebooks, datasets, dashboards, and research hubs.
hero_cta_url: /features/
hero_cta_label: Browse theme features
hero_secondary_cta_url: /guides/
hero_secondary_cta_label: Read the guides
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
    <h2>Why ship your docs with DataLog?</h2>
    <div class="split-grid">
      <div>
        <p>The documentation site is rendered with the DataLog theme itself, so every heading, callout, and interactive
        widget you see here ships with the gem. Clone the repository, wire up your datasets and notebooks, and you are
        ready to publish analytics stories across your organisation.</p>
        <p>Use the navigation above to deep-dive into feature walkthroughs, interactive visualization recipes, migration
        guidance, and a gallery of teams already building with DataLog.</p>
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
