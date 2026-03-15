---
title: Topic Archive
permalink: /archives/topics/
layout: page
description: Browse content organized by technical topic and research theme.
---

<section class="archive-section" aria-label="Topics">
  <div class="container">
    <h1>Topics</h1>
    <p>Discover posts grouped by domain expertise, from machine learning to experimental design.</p>
    <ul class="archive-list">
      {% assign tags = site.tags | sort %}
      {% for tag in tags %}
        {% assign tag_name = tag[0] %}
        <li>
          <h2 id="tag-{{ tag_name | slugify }}">{{ tag_name | capitalize }}</h2>
          <ul>
            {% for post in tag[1] %}
              <li><a href="{{ post.url | relative_url }}">{{ post.title }}</a> <span class="archive-meta">{{ post.date | date: "%B %-d, %Y" }}</span></li>
            {% endfor %}
          </ul>
        </li>
      {% endfor %}
    </ul>
  </div>
</section>
