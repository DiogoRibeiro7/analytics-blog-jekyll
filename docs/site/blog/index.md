---
layout: page
title: Documentation updates
permalink: /blog/
description: Release notes, implementation tips, and behind-the-scenes updates for the DataLog theme documentation site.
---

<section class="section">
  <div class="container">
    <div class="stack">
      {% for post in site.posts %}
      <article class="card">
        <h2><a href="{{ post.url | relative_url }}">{{ post.title }}</a></h2>
        <p class="card-meta">{{ post.date | date: '%B %-d, %Y' }} · {{ post.reading_time | default: post.content | number_of_words | divided_by: 180 | ceil }} min read</p>
        <p>{{ post.summary | default: post.excerpt | strip_html | truncate: 180 }}</p>
        <a class="card-link" href="{{ post.url | relative_url }}">Read the update</a>
      </article>
      {% endfor %}
    </div>
  </div>
</section>
