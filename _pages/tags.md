---
title: Tags
permalink: /tags/
layout: page
description: Browse every post by tag.
---

<section class="archive-section" aria-label="Tags">
  <div class="container">
    <h1>Tags</h1>
    <p>Every tag used across the site, with the posts filed under it. Post pages link here by tag.</p>
    <ul class="archive-list">
      {% assign groups = site.tags | sort %}
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
