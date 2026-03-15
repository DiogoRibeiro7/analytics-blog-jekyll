---
layout: page
title: Data Science Projects
permalink: /portfolio/
hero: true
intro: Explore research-backed data science initiatives with live demos, GitHub repositories, and reproducible assets.
---

<section class="portfolio-hero">
  <div class="container">
    <h1>Interactive Project Portfolio</h1>
    <p>Browse predictive models, exploratory studies, and experimentation platforms built by Diogo Ribeiro. Each case study features live demos, GitHub integration, and reproducible documentation.</p>
  </div>
</section>

{% assign configured_projects = site.data.projects.showcase %}
{% if configured_projects %}
<section class="portfolio-configured" aria-label="Configured project showcases">
  <div class="container portfolio-grid__container">
    <h2>DataLog configuration showcases</h2>
    <p class="portfolio-configured__intro">The following highlights are driven by the <code>_data/projects.yml</code> configuration file so you can manage feature projects without editing templates.</p>
    <div class="portfolio-configured__grid">
      {% for project in configured_projects %}
      <article class="portfolio-card" data-github-owner="{{ project.github.owner }}" data-github-repo="{{ project.github.repo }}">
        <header class="portfolio-card__header">
          <h3>{{ project.title }}</h3>
          <p class="portfolio-card__description">{{ project.summary }}</p>
        </header>
        <ul class="portfolio-card__meta">
          {% if project.tags %}
          <li>
            <strong>Focus:</strong>
            {{ project.tags | join: ', ' }}
          </li>
          {% endif %}
          <li>
            <strong>Repository:</strong>
            <a href="https://github.com/{{ project.github.owner }}/{{ project.github.repo }}" target="_blank" rel="noopener">{{ project.github.owner }}/{{ project.github.repo }}</a>
          </li>
          {% if project.demo_url %}
          <li>
            <strong>Demo:</strong>
            <a href="{{ project.demo_url }}" target="_blank" rel="noopener">Launch interactive demo</a>
          </li>
          {% endif %}
        </ul>
        <dl class="portfolio-card__github-stats" aria-label="GitHub repository metrics">
          <div>
            <dt>Stars</dt>
            <dd data-github-stat="stargazers_count">—</dd>
          </div>
          <div>
            <dt>Forks</dt>
            <dd data-github-stat="forks_count">—</dd>
          </div>
          <div>
            <dt>Issues</dt>
            <dd data-github-stat="open_issues_count">—</dd>
          </div>
        </dl>
        {% if project.featured_metrics %}
        <dl class="portfolio-card__metrics" aria-label="Key performance metrics">
          {% for metric in project.featured_metrics %}
          <div>
            <dt>{{ metric.label }}</dt>
            <dd>{{ metric.value }}</dd>
          </div>
          {% endfor %}
        </dl>
        {% endif %}
        <footer class="portfolio-card__footer">
          {% if project.demo_url %}
          <a class="button" href="{{ project.demo_url }}" target="_blank" rel="noopener">View live experience</a>
          {% else %}
          <a class="button" href="https://github.com/{{ project.github.owner }}/{{ project.github.repo }}" target="_blank" rel="noopener">View repository</a>
          {% endif %}
        </footer>
      </article>
      {% endfor %}
    </div>
  </div>
</section>
{% endif %}

<section class="portfolio-grid" aria-label="Project gallery">
  <div class="container portfolio-grid__container">
    {% assign sorted_projects = site.portfolio | sort: 'title' %}
    {% for item in sorted_projects %}
      <article class="portfolio-card" data-tech="{{ item.key_technologies | map: 'name' | join: ' ' | downcase }}">
        <header class="portfolio-card__header">
          <h2><a href="{{ item.url | relative_url }}">{{ item.title }}</a></h2>
          {% if item.description %}<p class="portfolio-card__description">{{ item.description }}</p>{% endif %}
        </header>
        {% if item.visualization_embed %}
          <div class="portfolio-card__embed">
            {{ item.visualization_embed }}
          </div>
        {% endif %}
        <ul class="portfolio-card__meta">
          {% if item.key_technologies %}
            <li>
              <strong>Stack:</strong>
              {{ item.key_technologies | map: 'name' | join: ', ' }}
            </li>
          {% endif %}
          {% if item.github %}
            <li>
              <strong>GitHub:</strong>
              <a href="https://github.com/{{ item.github.owner }}/{{ item.github.repo }}">{{ item.github.owner }}/{{ item.github.repo }}</a>
            </li>
          {% endif %}
          {% if item.demo_url %}
            <li>
              <strong>Demo:</strong>
              <a href="{{ item.demo_url }}" rel="noopener" target="_blank">Launch interactive experience</a>
            </li>
          {% endif %}
        </ul>
        <footer class="portfolio-card__footer">
          <a class="button" href="{{ item.url | relative_url }}">Read the full case study</a>
        </footer>
      </article>
    {% endfor %}
  </div>
</section>
