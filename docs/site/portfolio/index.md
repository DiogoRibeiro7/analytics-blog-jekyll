---
layout: page
title: Portfolio
permalink: /portfolio/
description: Featured analytics initiatives demonstrating the DataLog project layout.
---

<section class="section">
  <div class="container">
    <div class="card-grid">
      {% for project in site.portfolio %}
      <article class="card">
        <h2><a href="{{ project.url | relative_url }}">{{ project.title }}</a></h2>
        <p>{{ project.summary }}</p>
        <p class="card-meta">{{ project.tags | join: ', ' }}</p>
      </article>
      {% endfor %}
    </div>
  </div>
</section>
