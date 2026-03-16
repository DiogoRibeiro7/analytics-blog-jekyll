---
title: Research
permalink: /research/
layout: page
subtitle: Research interests, methodology, and publications
---

{% assign author_config = site.data.config.author %}

## Research Interests

<div class="card-grid">
{% for area in author_config.research_areas %}
  <div class="card">
    <h3><a href="{{ area.url | relative_url }}">{{ area.title }}</a></h3>
  </div>
{% endfor %}
</div>

## Methodology
{: #methodology}

Research projects follow a reproducible pipeline: version-controlled code,
containerised environments, and open datasets where permitted. Statistical
analyses use pre-registered hypotheses and power calculations to ensure
rigour.

<div class="card-grid">
{% for method in author_config.methodologies %}
  <div class="card">
    <h3><a href="{{ method.url | relative_url }}">{{ method.title }}</a></h3>
  </div>
{% endfor %}
</div>

## Recent Research Posts

<div class="card-grid">
{% assign research_posts = site.posts | where_exp: "post", "post.tags contains 'research' or post.tags contains 'statistics' or post.tags contains 'experimental-design'" %}
{% for post in research_posts limit: 6 %}
  <article class="card">
    <p class="card-meta">
      <time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: '%B %-d, %Y' }}</time>
    </p>
    <h3><a href="{{ post.url | relative_url }}">{{ post.title }}</a></h3>
    <p>{{ post.excerpt | strip_html | truncate: 140 }}</p>
    <a class="card-link" href="{{ post.url | relative_url }}">Read article</a>
  </article>
{% endfor %}
</div>

{% assign academic_profiles = site.data.social.academic %}
{% if academic_profiles %}
## Academic Profiles

<ul class="post-list-item__tags" style="margin: 0; padding: 0;">
{% for profile in academic_profiles %}
  <li><a href="{{ profile.url }}" target="_blank" rel="noopener" style="color: inherit; text-decoration: none;">{{ profile.label }}</a></li>
{% endfor %}
</ul>
{% endif %}
