---
layout: page
title: Dataset catalog
permalink: /datasets/
description: Curated datasets referenced throughout the DataLog documentation site.
---

<section class="section">
  <div class="container">
    <div class="card-grid">
      {% for dataset in site.datasets %}
      <article class="card">
        <h2><a href="{{ dataset.url | relative_url }}">{{ dataset.title }}</a></h2>
        <p>{{ dataset.summary }}</p>
        <p class="card-meta">Updated {{ dataset.updated | date: '%B %Y' }}</p>
      </article>
      {% endfor %}
    </div>
  </div>
</section>
