---
layout: post
title: Plotly Visualization Showcase for Executive Dashboards
date: 2024-04-07
tags: [visualization, plotly, dashboard]
difficulty: beginner
summary: Embed interactive Plotly charts, annotate export controls, and provide accessible descriptions for decision makers.
hero: /assets/images/posts/plotly-dashboard.jpg
slides:
  src: https://slides.datalog-theme.dev/plotly-story.html
  title: Plotly Showcase Slides
  theme: datalog
comments:
  provider: giscus
  mapping: pathname
  theme: dark_dimmed
---

Interactive dashboards help executives interrogate results without leaving the page. The **DataLog** theme ships with a `viz-block` component that wraps Plotly embeds with metadata, status messaging, and export buttons.

## Revenue trends

<div
  class="viz-block"
  data-viz-type="plotly"
  data-viz-slug="plotly-revenue-trends"
  data-viz-version="1.0"
  data-viz-updated="2024-04-07"
>
  <div class="viz-header">
    <h3 class="viz-title">Quarterly revenue growth</h3>
    <p class="viz-meta" data-viz-meta>ARR segmented by region and channel</p>
    <span class="viz-status" data-viz-status aria-live="polite">Loading…</span>
  </div>
  <div class="viz-toolbar" aria-label="Plotly controls">
    <div data-viz-export></div>
    <a class="viz-toolbar__button" href="https://plotly.com/javascript/">Plotly docs</a>
  </div>
  <div class="viz-canvas" data-viz-canvas>
    <script nonce="{{ page.csp_nonce }}" type="application/json">
{
  "data": [
    {"type": "bar", "name": "North America", "x": ["Q1", "Q2", "Q3", "Q4"], "y": [4.2, 4.6, 5.1, 5.7]},
    {"type": "bar", "name": "EMEA", "x": ["Q1", "Q2", "Q3", "Q4"], "y": [3.1, 3.4, 3.9, 4.3]},
    {"type": "bar", "name": "APAC", "x": ["Q1", "Q2", "Q3", "Q4"], "y": [2.5, 2.9, 3.3, 3.6]}
  ],
  "layout": {
    "barmode": "group",
    "title": {"text": "Revenue by region (in millions USD)"},
    "yaxis": {"title": "Revenue"},
    "legend": {"orientation": "h", "x": 0.5, "xanchor": "center"},
    "margin": {"t": 64, "r": 32, "b": 64, "l": 56}
  }
}
    </script>
  </div>
</div>

## Why it matters

- Keyboard users gain export controls via the toolbar.
- Metadata automatically exposes the chart title and version in screen reader-friendly text.
- Embedding raw JSON keeps version diffs tight during code review.

Pair this Plotly block with D3, Observable, and Shiny embeds to demonstrate the full visualization gallery offered by the theme.
