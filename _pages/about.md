---
title: About
permalink: /about/
layout: page
subtitle: Data Scientist, Researcher, Open Science Advocate
---

{% assign author = site.data.config.author %}
{% assign academic = site.data.academic %}
{% assign citations = academic.citations %}

<section class="author-profile">
  <div class="author-profile__hero">
    <div class="author-profile__photo">
      {% if author.photo %}
        <img src="{{ author.photo | relative_url }}" alt="{{ author.name }}" class="author-profile__img" />
      {% else %}
        <div class="author-profile__placeholder">
          {{ author.name | slice: 0 }}
        </div>
      {% endif %}
    </div>
    <div class="author-profile__intro">
      <h2 class="author-profile__name">{{ author.name }}</h2>
      <p class="author-profile__title">{{ author.title }}</p>
      <p class="author-profile__affiliation">{{ author.affiliation }}{% if author.location %} · {{ author.location }}{% endif %}</p>
      <p class="author-profile__bio">{{ author.biography }}</p>
      <div class="research-profiles">
        <a href="mailto:{{ author.email }}" class="btn btn-primary">Contact</a>
        <a href="https://github.com/{{ author.profiles.github }}" target="_blank" rel="noopener" class="btn btn-secondary">GitHub</a>
        <a href="https://www.linkedin.com/in/{{ author.profiles.linkedin }}" target="_blank" rel="noopener" class="btn btn-secondary">LinkedIn</a>
        <a href="{{ author.profiles.orcid }}" target="_blank" rel="noopener" class="btn btn-secondary">ORCID</a>
      </div>
    </div>
  </div>

  {% if citations.metrics %}
  <div class="research-metrics">
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
</section>

## About Me

{{ author.bio_extended }}

## Skills & Expertise

<div class="skills-grid">
  <div class="card">
    <h3>Languages</h3>
    <div class="skills-tags">
      {% for lang in author.skills.languages %}
      <span class="skill-tag skill-tag--lang">{{ lang }}</span>
      {% endfor %}
    </div>
  </div>
  <div class="card">
    <h3>Frameworks & Libraries</h3>
    <div class="skills-tags">
      {% for fw in author.skills.frameworks %}
      <span class="skill-tag skill-tag--framework">{{ fw }}</span>
      {% endfor %}
    </div>
  </div>
  <div class="card">
    <h3>Tools & Platforms</h3>
    <div class="skills-tags">
      {% for tool in author.skills.tools %}
      <span class="skill-tag skill-tag--tool">{{ tool }}</span>
      {% endfor %}
    </div>
  </div>
  <div class="card">
    <h3>Domains</h3>
    <div class="skills-tags">
      {% for domain in author.skills.domains %}
      <span class="skill-tag skill-tag--domain">{{ domain }}</span>
      {% endfor %}
    </div>
  </div>
</div>

## Experience

<div class="timeline">
{% for job in author.experience %}
  <div class="timeline__item">
    <div class="timeline__marker"></div>
    <div class="timeline__content card">
      <p class="card-meta">{{ job.period }}</p>
      <h3>{{ job.role }}</h3>
      <p class="timeline__org">{{ job.organization }}</p>
      <p>{{ job.description }}</p>
    </div>
  </div>
{% endfor %}
</div>

## Education

<div class="card-grid">
{% for edu in author.education %}
  <div class="card">
    <p class="card-meta">{{ edu.year }}</p>
    <h3>{{ edu.degree }}</h3>
    <p>{{ edu.institution }}</p>
  </div>
{% endfor %}
</div>

## Research Areas

<div class="card-grid">
{% for area in author.research_areas %}
  <a href="{{ area.url | relative_url }}" class="card research-area-card">
    <h3>{{ area.title }}</h3>
  </a>
{% endfor %}
</div>

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

## Get in Touch

I welcome collaborations on research, consulting, and teaching. Whether you're interested in data science projects, speaking engagements, or open-source contributions, feel free to reach out.

<div class="research-profiles">
  <a href="mailto:{{ author.email }}" class="btn btn-primary">Email</a>
  <a href="https://github.com/{{ author.profiles.github }}" target="_blank" rel="noopener" class="btn btn-secondary">GitHub</a>
  <a href="https://www.linkedin.com/in/{{ author.profiles.linkedin }}" target="_blank" rel="noopener" class="btn btn-secondary">LinkedIn</a>
  <a href="{{ author.profiles.orcid }}" target="_blank" rel="noopener" class="btn btn-secondary">ORCID</a>
  <a href="{{ author.profiles.researchgate }}" target="_blank" rel="noopener" class="btn btn-secondary">ResearchGate</a>
  <a href="https://www.kaggle.com/{{ author.profiles.kaggle }}" target="_blank" rel="noopener" class="btn btn-secondary">Kaggle</a>
</div>
