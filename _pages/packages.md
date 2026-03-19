---
layout: page
title: Packages
permalink: /packages/
subtitle: Open-source tools for data science and statistical analysis
---

{% if site.packages.size > 0 %}

<div class="card-grid">
{% for package in site.packages %}
  <article class="card project-card">
    <p class="card-meta">
      {% if package.language %}<span class="post-meta__badge">{{ package.language }}</span>{% endif %}
      {% if package.version %}<span class="post-meta__badge">v{{ package.version }}</span>{% endif %}
      {% if package.license %}<span>{{ package.license }}</span>{% endif %}
    </p>
    <h3><a href="{{ package.url | relative_url }}">{% if package.icon %}{{ package.icon }} {% endif %}{{ package.title }}</a></h3>
    {% if package.tagline %}<p><strong>{{ package.tagline }}</strong></p>{% endif %}
    {% if package.description %}<p>{{ package.description }}</p>{% endif %}
    <div class="project-links">
      <a class="btn btn-primary" href="{{ package.url | relative_url }}">Documentation</a>
      {% if package.github_url %}
        <a class="btn btn-secondary" href="{{ package.github_url }}" target="_blank" rel="noopener">GitHub</a>
      {% endif %}
      {% if package.pypi_url %}
        <a class="btn btn-secondary" href="{{ package.pypi_url }}" target="_blank" rel="noopener">PyPI</a>
      {% endif %}
    </div>
  </article>
{% endfor %}
</div>

{% else %}

<div class="packages-empty">
  <h3>No packages yet</h3>
  <p>Package documentation will appear here once packages are added to the <code>_packages</code> collection.</p>
</div>

{% endif %}
