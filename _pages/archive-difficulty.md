---
title: Difficulty Archive
permalink: /archives/difficulty/
layout: page
description: Filter tutorials and research articles by estimated difficulty level.
---

<section class="archive-section" aria-label="Difficulty levels">
  <div class="container">
    <h1>Difficulty levels</h1>
    <p>Select content aligned with your current skill level—from foundational walkthroughs to advanced research briefings.</p>
    {% assign levels = "Beginner,Intermediate,Advanced" | split: ',' %}
    <div class="archive-grid">
      {% for level in levels %}
        {% assign posts = site.posts | where: "difficulty", level %}
        <article class="archive-card">
          <h2 id="difficulty-{{ level | downcase }}">{{ level }}</h2>
          {% if posts.size == 0 %}
            <p>No publications yet at this level.</p>
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
