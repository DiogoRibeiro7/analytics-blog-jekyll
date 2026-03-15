---
title: Showcase gallery
description: Real-world sites using the DataLog theme for analytics storytelling.
permalink: /showcase/
---

<section class="section">
  <div class="container">
    <p>The organisations below generously shared their DataLog deployments. Submit a PR to add your own site and inspire the
    community.</p>
    <div class="card-grid">
      {% for site in site.data.showcase %}
      <article class="card">
        <h3><a href="{{ site.url }}" target="_blank" rel="noopener">{{ site.name }}</a></h3>
        <p>{{ site.description }}</p>
        <p class="card-meta">{{ site.location }} · {{ site.sector }}</p>
      </article>
      {% endfor %}
    </div>
  </div>
</section>

<section class="section section-alt">
  <div class="container">
    <h2>Submit your project</h2>
    <ol>
      <li>Open an issue or PR with your site name, link, and one-line summary.</li>
      <li>Include screenshots or animated GIFs if you would like to highlight interactive features.</li>
      <li>We review submissions weekly and deploy accepted entries via GitHub Actions.</li>
    </ol>
  </div>
</section>
