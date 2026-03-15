---
title: Programming Language Archive
permalink: /archives/languages/
layout: page
description: Filter tutorials and research artefacts by primary programming language.
---

<section class="archive-section" aria-label="Programming languages">
  <div class="container">
    <h1>Programming languages</h1>
    <p>Jump straight to content focused on Python, R, SQL, Julia, and JavaScript.</p>
    {% assign languages = "Python,R,SQL,Julia,JavaScript" | split: ',' %}
    <div class="archive-grid">
      {% for language in languages %}
        {% assign language_lower = language | downcase %}
        {% assign posts = site.posts | where_exp: "item", "item.tags contains language_lower" %}
        <article class="archive-card">
          <h2 id="lang-{{ language_lower }}">{{ language }}</h2>
          {% if posts.size == 0 %}
            <p>No articles published yet. Check back soon.</p>
          {% else %}
            <ul>
              {% for post in posts %}
                <li><a href="{{ post.url | relative_url }}">{{ post.title }}</a> <span class="archive-meta">{{ post.date | date: "%B %-d, %Y" }}</span></li>
              {% endfor %}
            </ul>
          {% endif %}
        </article>
      {% endfor %}
    </div>
  </div>
</section>
