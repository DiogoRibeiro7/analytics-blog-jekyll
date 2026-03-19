---
title: Research
permalink: /research/
layout: page
subtitle: Exploring data science, statistical modeling, and reproducible analytics
---

{% assign author = site.data.config.author %}
{% assign academic = site.data.academic %}
{% assign citations = academic.citations %}

<div class="research-intro">
  <p class="research-bio">{{ author.biography }}</p>
  <p><strong>{{ author.name }}</strong> · {{ author.affiliation }}</p>
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

## Research Areas

<div class="card-grid">
{% for area in author.research_areas %}
  <a href="{{ area.url | relative_url }}" class="card research-area-card">
    <h3>{{ area.title }}</h3>
    {% assign area_posts = site.tags[area.id] | default: site.posts %}
    <p>{{ area_posts.size }} posts</p>
  </a>
{% endfor %}
</div>

## Methodology
{: #methodology}

<div class="card-grid">
{% for method in author.methodologies %}
  <a href="{{ method.url | relative_url }}" class="card research-area-card">
    <h3>{{ method.title }}</h3>
  </a>
{% endfor %}
</div>

Research projects follow a reproducible pipeline: version-controlled code,
containerised environments, and open datasets where permitted. Statistical
analyses use pre-registered hypotheses and power calculations to ensure rigour.

{% if academic.submissions and academic.submissions.size > 0 %}
## Current Work

<div class="card-grid">
{% for sub in academic.submissions %}
  <article class="card">
    <p class="card-meta">
      <span class="post-meta__badge">{{ sub.status }}</span>
      <span>{{ sub.type | capitalize }}</span>
    </p>
    <h3>{{ sub.title }}</h3>
    <p>{{ sub.venue }}</p>
    {% if sub.collaborators and sub.collaborators.size > 0 %}
      <p class="card-meta">with {{ sub.collaborators | join: ', ' }}</p>
    {% endif %}
  </article>
{% endfor %}
</div>
{% endif %}

## Recent Research Posts

<div class="card-grid">
{% for post in site.posts limit: 6 %}
  <article class="card">
    <p class="card-meta">
      <time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: '%B %-d, %Y' }}</time>
      {% if post.difficulty %}
        <span class="post-meta__badge">{{ post.difficulty }}</span>
      {% endif %}
    </p>
    <h3><a href="{{ post.url | relative_url }}">{{ post.title }}</a></h3>
    <p>{{ post.excerpt | strip_html | truncate: 120 }}</p>
    <a class="card-link" href="{{ post.url | relative_url }}">Read article</a>
  </article>
{% endfor %}
</div>

{% assign academic_profiles = site.data.social.academic %}
{% if academic_profiles and academic_profiles.size > 0 %}
## Academic Profiles

<div class="research-profiles">
{% for profile in academic_profiles %}
  <a href="{{ profile.url }}" target="_blank" rel="{{ profile.rel | default: 'noopener' }}" class="btn btn-secondary">{{ profile.label }}</a>
{% endfor %}
</div>
{% endif %}
