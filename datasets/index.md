---
layout: page
title: Datasets
permalink: /datasets/
subtitle: Open data to power reproducible research and technical storytelling
---

## Original Datasets

Documented, versioned, and published with reproducible notebooks.

<div class="card-grid">
{% for dataset in site.datasets %}
  <article class="card">
    <p class="card-meta">
      {% if dataset.license %}<span class="post-meta__badge">{{ dataset.license }}</span>{% endif %}
      {% if dataset.updated %}<time datetime="{{ dataset.updated | date_to_xmlschema }}">Updated {{ dataset.updated | date: '%B %Y' }}</time>{% endif %}
    </p>
    <h3><a href="{{ dataset.url | relative_url }}">{{ dataset.title }}</a></h3>
    <p>{{ dataset.summary | default: dataset.excerpt | strip_html | truncate: 140 }}</p>
    {% if dataset.schema %}
    <p class="card-meta">{{ dataset.schema.size }} fields</p>
    {% endif %}
    <div class="project-links">
      <a class="btn btn-primary" href="{{ dataset.url | relative_url }}">View schema</a>
      {% if dataset.download_url %}
        <a class="btn btn-secondary" href="{{ dataset.download_url }}" target="_blank" rel="noopener">Download</a>
      {% endif %}
    </div>
  </article>
{% endfor %}
</div>

{% assign catalog = site.data.datasets.collections %}
{% if catalog and catalog.size > 0 %}

## Dataset Catalog

{{ site.data.datasets.preferences.availability_statement }}

<div class="card-grid">
{% for dataset in catalog %}
  <article class="card">
    <p class="card-meta">
      <span class="post-meta__badge">{{ dataset.license }}</span>
      {% if dataset.update_frequency %}
        <span>{{ dataset.update_frequency | capitalize }}</span>
      {% endif %}
    </p>
    <h3>{{ dataset.title }}</h3>
    <p>{{ dataset.description }}</p>
    {% if dataset.tags %}
    <ul class="post-list-item__tags">
      {% for tag in dataset.tags %}
        <li>{{ tag }}</li>
      {% endfor %}
    </ul>
    {% endif %}
    <div class="project-links">
      {% if dataset.source_url %}
        <a class="btn btn-primary" href="{{ dataset.source_url }}" target="_blank" rel="noopener">Source</a>
      {% endif %}
      {% if dataset.documentation %}
        <a class="btn btn-secondary" href="{{ dataset.documentation | relative_url }}">Docs</a>
      {% endif %}
    </div>
  </article>
{% endfor %}
</div>
{% endif %}

## External Resources

<div class="card-grid">
  <a href="https://data.gov.pt" target="_blank" rel="noopener" class="card research-area-card">
    <h3>Portuguese Open Data Portal</h3>
    <p>National statistics, energy, and transportation datasets.</p>
  </a>
  <a href="https://registry.opendata.aws/" target="_blank" rel="noopener" class="card research-area-card">
    <h3>AWS Open Data Registry</h3>
    <p>Petabyte-scale climate and satellite imagery.</p>
  </a>
  <a href="https://zenodo.org/communities/openscience/" target="_blank" rel="noopener" class="card research-area-card">
    <h3>Zenodo Open Science</h3>
    <p>Curated research datasets with DOIs.</p>
  </a>
  <a href="https://ourworldindata.org/" target="_blank" rel="noopener" class="card research-area-card">
    <h3>Our World in Data</h3>
    <p>Global socio-economic indicators with reproducible charts.</p>
  </a>
</div>

## Contribute

Have a dataset to share? Email [dfr@esmad.ipp.pt](mailto:dfr@esmad.ipp.pt) with context and licensing details.
