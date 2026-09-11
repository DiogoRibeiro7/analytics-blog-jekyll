---
title: Categories
permalink: /categories/
layout: page
description: Browse every post by category.
---

<section class="archive-section" aria-label="Categories">
  <div class="container">
    <h1>Categories</h1>
    <p>Every category used across the site, with the posts filed under it. Post pages and breadcrumbs link here by category.</p>
    <ul class="archive-list">
      {% assign groups = site.categories | sort %}
      {% for group in groups %}
        {% assign group_name = group[0] %}
        <li>
          <h2 id="{{ group_name | slugify }}">{{ group_name }}</h2>
          <ul>
            {% for post in group[1] %}
              <li><a href="{{ post.url | relative_url }}">{{ post.title }}</a> <span class="archive-meta">{{ post.date | date: "%B %-d, %Y" }}</span></li>
            {% endfor %}
          </ul>
        </li>
      {% endfor %}
    </ul>
  </div>
</section>
