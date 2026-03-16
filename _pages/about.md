---
title: About
permalink: /about/
layout: page
subtitle: Data science researcher focused on reproducible analytics
---

{% assign author = site.data.config.author %}
{% assign academic = site.data.academic %}
{% assign citations = academic.citations %}

<div class="about-header">
  <div class="about-header__info">
    <h2 class="about-header__name">{{ author.name }}</h2>
    <p class="about-header__affiliation">{{ author.affiliation }}</p>
    <p class="about-header__bio">{{ author.biography }}</p>
    <div class="research-profiles">
      <a href="https://github.com/{{ author.profiles.github }}" target="_blank" rel="noopener" class="btn btn-secondary">GitHub</a>
      <a href="{{ author.profiles.orcid }}" target="_blank" rel="noopener" class="btn btn-secondary">ORCID</a>
      <a href="mailto:{{ author.email }}" class="btn btn-primary">Contact</a>
    </div>
  </div>
  {% if citations.metrics %}
  <div class="research-metrics research-metrics--compact">
    <div class="card">
      <span class="stat__value">{{ citations.metrics.total }}</span>
      <span class="stat__label">Citations</span>
    </div>
    <div class="card">
      <span class="stat__value">{{ citations.metrics.h_index }}</span>
      <span class="stat__label">h-index</span>
    </div>
    <div class="card">
      <span class="stat__value">{{ citations.metrics.i10_index }}</span>
      <span class="stat__label">i10-index</span>
    </div>
  </div>
  {% endif %}
</div>

## Research Interests

<div class="card-grid">
{% for area in author.research_areas %}
  <a href="{{ area.url | relative_url }}" class="card research-area-card">
    <h3>{{ area.title }}</h3>
  </a>
{% endfor %}
</div>

- Probabilistic forecasting for critical infrastructure and climate resilience
- Reproducible machine learning and MLOps for regulated industries
- Statistical methodology for experimental design and causal inference
- Interactive storytelling that bridges quantitative insights with decision making

## Academic Credentials

- **MSc in Data Science**, ESMAD - Instituto Politécnico do Porto (2020)
- **BSc in Multimedia Technology**, ESMAD - Instituto Politécnico do Porto (2018)
- Visiting researcher, Centre for Applied AI, 2022 -- present

## Publications

<div class="card-grid">
  <article class="card">
    <p class="card-meta"><time>2023</time></p>
    <h3>Energy Demand Forecasting with Hierarchical Ensembles</h3>
    <p>Journal of Sustainable Analytics</p>
  </article>
  <article class="card">
    <p class="card-meta"><time>2022</time></p>
    <h3>Designing Accessible Visualization Systems for Smart Cities</h3>
    <p>Proceedings of VIS4GOOD · with R. Almeida</p>
  </article>
  <article class="card">
    <p class="card-meta"><time>2021</time></p>
    <h3>Open Science Playbook for Applied Analytics Teams</h3>
    <p>Data Science Practice</p>
  </article>
</div>

Full list on [Google Scholar](https://scholar.google.com/citations?user=example) and [ResearchGate](https://www.researchgate.net/profile/Diogo-Ribeiro).

## Community & Teaching

<div class="card-grid">
  <div class="card">
    <h3>DataLog Academy</h3>
    <p>Instructor for Python and R bootcamps focused on reproducible data workflows.</p>
  </div>
  <div class="card">
    <h3>Porto Data Viz Meetup</h3>
    <p>Co-organizer of the local data visualization community with monthly events.</p>
  </div>
  <div class="card">
    <h3>Open Source</h3>
    <p>Contributor to DuckDB extensions, Jupyter widgets, and the DataLog Jekyll theme.</p>
  </div>
</div>

## Get in Touch

I welcome collaborations on research, consulting, and teaching initiatives.

<div class="research-profiles">
  <a href="mailto:{{ author.email }}" class="btn btn-primary">Email</a>
  <a href="https://github.com/{{ author.profiles.github }}" target="_blank" rel="noopener" class="btn btn-secondary">GitHub</a>
  <a href="https://www.linkedin.com/in/{{ author.profiles.linkedin }}" target="_blank" rel="noopener" class="btn btn-secondary">LinkedIn</a>
  <a href="{{ author.profiles.orcid }}" target="_blank" rel="noopener" class="btn btn-secondary">ORCID</a>
  <a href="{{ author.profiles.researchgate }}" target="_blank" rel="noopener" class="btn btn-secondary">ResearchGate</a>
</div>
