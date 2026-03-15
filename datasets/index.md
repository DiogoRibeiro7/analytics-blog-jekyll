---
layout: page
title: Data Sources & Curated Datasets
permalink: /datasets/
subtitle: Open data to power reproducible research and technical storytelling.
---

<section class="dataset-hero">
  <div class="container">
    <h1>Curated datasets for data scientists</h1>
    <p>Explore open data packages maintained by Diogo Ribeiro alongside recommended external resources for machine learning, statistical analysis, and visualization projects.</p>
  </div>
</section>

<section class="dataset-curated" aria-label="Original datasets">
  <div class="container">
    <h2>Original datasets</h2>
    <p>These datasets are published with detailed documentation, version history, and reproducible notebooks.</p>
    <div class="dataset-grid">
      {% for dataset in site.datasets %}
        <article class="dataset-card">
          <header>
            <h3><a href="{{ dataset.url | relative_url }}">{{ dataset.title }}</a></h3>
            {% if dataset.updated %}<p class="dataset-meta">Updated {{ dataset.updated | date: '%B %-d, %Y' }}</p>{% endif %}
          </header>
          <p>{{ dataset.summary | default: dataset.excerpt }}</p>
          {% if dataset.license %}<p><strong>License:</strong> {{ dataset.license }}</p>{% endif %}
          {% if dataset.download_url %}
            <p><a class="button" href="{{ dataset.download_url }}">Download dataset</a></p>
          {% endif %}
        </article>
      {% endfor %}
    </div>
  </div>
</section>

{% assign configured_datasets = site.data.datasets.collections %}
{% if configured_datasets %}
<section class="dataset-config" aria-label="Configured dataset listings">
  <div class="container">
    <h2>Configured dataset catalog</h2>
    <p>{{ site.data.datasets.preferences.availability_statement | default: site.theme_options.datasets.availability_statement }}</p>
    <div class="dataset-grid">
      {% for dataset in configured_datasets %}
      <article class="dataset-card" data-license="{{ dataset.license }}">
        <header>
          <h3>{{ dataset.title }}</h3>
          {% if dataset.update_frequency %}<p class="dataset-meta">Updated {{ dataset.update_frequency | capitalize }}</p>{% endif %}
        </header>
        <p>{{ dataset.description }}</p>
        <ul class="dataset-meta-list">
          <li><strong>License:</strong> {{ dataset.license | default: site.theme_options.datasets.default_license }}</li>
          {% if dataset.tags %}
          <li><strong>Tags:</strong> {{ dataset.tags | join: ', ' }}</li>
          {% endif %}
        </ul>
        <div class="dataset-actions">
          {% if dataset.source_url %}
          <a class="button" href="{{ dataset.source_url }}" target="_blank" rel="noopener">Source</a>
          {% endif %}
          {% if dataset.documentation %}
          <a class="button button--ghost" href="{{ dataset.documentation | relative_url }}">Documentation</a>
          {% endif %}
        </div>
      </article>
      {% endfor %}
    </div>
  </div>
</section>
{% endif %}

<section class="dataset-external" aria-label="External resources">
  <div class="container">
    <h2>Recommended external sources</h2>
    <ul class="dataset-resources">
      <li><a href="https://data.gov.pt" target="_blank" rel="noopener">Portuguese Open Data Portal</a> — national statistics, energy, and transportation datasets.</li>
      <li><a href="https://registry.opendata.aws/" target="_blank" rel="noopener">AWS Open Data Registry</a> — petabyte-scale climate and satellite imagery.</li>
      <li><a href="https://zenodo.org/communities/openscience/" target="_blank" rel="noopener">Zenodo Open Science Community</a> — curated research datasets with DOIs.</li>
      <li><a href="https://ourworldindata.org/" target="_blank" rel="noopener">Our World in Data</a> — global socio-economic indicators with reproducible charts.</li>
    </ul>
  </div>
</section>

<section class="dataset-cta" aria-label="Contribute datasets">
  <div class="container">
    <h2>Share your dataset</h2>
    <p>Submit new resources or collaborate on data documentation. Email <a href="mailto:dfr@esmad.ipp.pt">dfr@esmad.ipp.pt</a> with context and licensing details.</p>
  </div>
</section>
