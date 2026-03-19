---
layout: page
title: Projects
permalink: /portfolio/
subtitle: Research-backed data science projects with reproducible code and live demos
---

{% assign showcase = site.data.projects.showcase %}
{% assign portfolio_items = site.portfolio | sort: 'title' %}

{% if showcase and showcase.size > 0 %}
## Featured Projects

<div class="card-grid">
{% for project in showcase %}
  <article class="card project-card">
    <p class="card-meta">
      {% for tag in project.tags limit: 3 %}
        <span class="post-meta__badge">{{ tag }}</span>
      {% endfor %}
    </p>
    <h3>{{ project.title }}</h3>
    <p>{{ project.summary }}</p>
    {% if project.featured_metrics %}
    <div class="project-metrics">
      {% for metric in project.featured_metrics %}
      <div class="project-metric">
        <span class="project-metric__value">{{ metric.value }}</span>
        <span class="project-metric__label">{{ metric.label }}</span>
      </div>
      {% endfor %}
    </div>
    {% endif %}
    <div class="project-links">
      <a class="btn btn-primary" href="https://github.com/{{ project.github.owner }}/{{ project.github.repo }}" target="_blank" rel="noopener">GitHub</a>
      {% if project.demo_url %}
        <a class="btn btn-secondary" href="{{ project.demo_url }}" target="_blank" rel="noopener">Live demo</a>
      {% endif %}
    </div>
  </article>
{% endfor %}
</div>
{% endif %}

{% if portfolio_items and portfolio_items.size > 0 %}
## Case Studies

<div class="card-grid">
{% for item in portfolio_items %}
  <article class="card project-card">
    <p class="card-meta">
      {% if item.key_technologies %}
        {% for tech in item.key_technologies limit: 3 %}
          <span class="post-meta__badge">{{ tech.name }}</span>
        {% endfor %}
      {% endif %}
    </p>
    <h3><a href="{{ item.url | relative_url }}">{{ item.title }}</a></h3>
    <p>{{ item.description }}</p>
    {% if item.github %}
    <p class="card-meta">
      <a href="https://github.com/{{ item.github.owner }}/{{ item.github.repo }}" target="_blank" rel="noopener">{{ item.github.owner }}/{{ item.github.repo }}</a>
    </p>
    {% endif %}
    <a class="card-link" href="{{ item.url | relative_url }}">Read case study</a>
  </article>
{% endfor %}
</div>
{% endif %}
