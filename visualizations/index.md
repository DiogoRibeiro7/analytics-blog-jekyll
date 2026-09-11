---
layout: page
title: Visualizations
permalink: /visualizations/
subtitle: Interactive dashboards, notebooks, and embeddable charts
---

{% assign visualizations = site.data.visualizations %}
{% assign techs = visualizations | map: 'tech' | uniq | sort %}

## Gallery

Browse interactive projects built with Plotly, D3, Observable, Bokeh, R Shiny, and Jupyter widgets.

<div class="viz-filters" role="region" aria-label="Visualization filters">
  <div class="research-profiles">
    <button class="btn btn-primary viz-filter-btn is-active" data-viz-filter-btn="all">All</button>
    {% for tech in techs %}
    <button class="btn btn-secondary viz-filter-btn" data-viz-filter-btn="{{ tech }}">{{ tech | capitalize }}</button>
    {% endfor %}
  </div>
</div>

<div class="card-grid" data-viz-gallery>
{% for visualization in visualizations %}
  {% include components/visualization-card.html visualization=visualization %}
{% endfor %}
</div>

## Embed Examples

The following live examples demonstrate how DataLog renders interactive visualizations inline. Libraries are lazy-loaded when they scroll into view.

### Plotly — Model Performance Drift

<div class="viz-block" data-viz-type="plotly" data-viz-slug="plotly-line-example">
  <div class="viz-canvas" data-viz-canvas>
    <script nonce="{{ page.csp_nonce }}" type="application/json">
{
  "data": [
    {"type": "scatter", "mode": "lines+markers", "name": "Production", "x": ["Jan", "Feb", "Mar", "Apr"], "y": [0.82, 0.8, 0.78, 0.81]},
    {"type": "scatter", "mode": "lines+markers", "name": "Shadow", "x": ["Jan", "Feb", "Mar", "Apr"], "y": [0.8, 0.82, 0.79, 0.83]}
  ],
  "layout": {
    "title": {"text": "F1 score drift"},
    "yaxis": {"tickformat": ".2f", "title": "F1 Score"},
    "margin": {"t": 50, "r": 30, "b": 50, "l": 60}
  }
}
    </script>
  </div>
</div>

### D3 — Feature Contribution Snapshot

<div class="viz-block" data-viz-type="d3" data-viz-slug="d3-bar-example">
  <div class="viz-canvas" data-viz-canvas>
    <script nonce="{{ page.csp_nonce }}" type="text/plain" data-d3-script>
const width = element.clientWidth;
const height = 280;
const margin = { top: 16, right: 24, bottom: 40, left: 64 };
const svg = d3
  .select(element)
  .append('svg')
  .attr('viewBox', `0 0 ${width} ${height}`)
  .attr('role', 'img')
  .attr('aria-label', 'Bar chart comparing feature contributions');

const data = [
  { feature: 'tenure', value: 0.34 },
  { feature: 'monthly_charges', value: 0.28 },
  { feature: 'contract_length', value: 0.22 },
  { feature: 'support_tickets', value: 0.16 }
];

const x = d3.scaleBand().domain(data.map(d => d.feature)).range([margin.left, width - margin.right]).padding(0.2);
const y = d3.scaleLinear().domain([0, d3.max(data, d => d.value)]).nice().range([height - margin.bottom, margin.top]);

svg.append('g').attr('fill', '#0d9488').selectAll('rect').data(data).enter().append('rect')
  .attr('x', d => x(d.feature)).attr('y', d => y(d.value))
  .attr('height', d => y(0) - y(d.value)).attr('width', x.bandwidth()).attr('rx', 6);

svg.append('g').attr('transform', `translate(0, ${height - margin.bottom})`).call(d3.axisBottom(x));
svg.append('g').attr('transform', `translate(${margin.left}, 0)`).call(d3.axisLeft(y).tickFormat(d3.format('.0%')));
    </script>
  </div>
</div>

### Observable — Topic Model

<div class="viz-block" data-viz-type="observable" data-viz-slug="observable-topic-model"
     data-observable-src="https://observablehq.com/embed/@observablehq/plot-airports?cells=viewof+chart">
  <div class="viz-canvas" data-viz-canvas></div>
</div>

### Bokeh — Pipeline Latency

<div class="viz-block" data-viz-type="bokeh" data-viz-slug="bokeh-latency-example">
  <div class="viz-canvas" data-viz-canvas>
    <script nonce="{{ page.csp_nonce }}" type="text/plain" data-bokeh-script>
const plot = Bokeh.Plotting.figure({
  title: 'Ingest latency percentiles',
  height: 280,
  sizing_mode: 'stretch_width',
  x_axis_label: 'Batch',
  y_axis_label: 'Milliseconds'
});

plot.line([1, 2, 3, 4, 5, 6], [128, 135, 129, 142, 131, 126], {
  legend_label: 'p95',
  line_width: 2,
  line_color: '#0d9488'
});

plot.line([1, 2, 3, 4, 5, 6], [86, 91, 88, 94, 89, 85], {
  legend_label: 'p50',
  line_width: 2,
  line_color: '#6366f1'
});

Bokeh.Plotting.show(plot, element);
    </script>
  </div>
</div>

### R Shiny — Retail Demand Forecaster

<div class="viz-block" data-viz-type="shiny" data-viz-slug="shiny-demand-example"
     data-viz-title="Retail demand forecaster"
     data-shiny-src="https://shiny.posit.co/r/gallery/">
  <div class="viz-canvas" data-viz-canvas></div>
</div>

### Jupyter Widgets — Feature Importance Inspector

<div class="viz-block" data-viz-type="ipywidgets" data-viz-slug="ipywidgets-slider-example">
  <div class="viz-canvas" data-viz-canvas>
    <script nonce="{{ page.csp_nonce }}" type="application/vnd.jupyter.widget-state+json">
{
  "version_major": 2,
  "version_minor": 0,
  "state": {
    "datalog-feature-slider": {
      "model_name": "IntSliderModel",
      "model_module": "@jupyter-widgets/controls",
      "model_module_version": "2.0.0",
      "state": {"value": 12, "min": 1, "max": 40, "description": "Top features"}
    }
  }
}
    </script>
    <script nonce="{{ page.csp_nonce }}" type="application/vnd.jupyter.widget-view+json">
{"version_major": 2, "version_minor": 0, "model_id": "datalog-feature-slider"}
    </script>
  </div>
</div>

## Integration Guide

Every visualization block stores version and update metadata for change tracking. Libraries are lazy-loaded only when they enter the viewport, keeping long pages performant.

Supported integrations:

<div class="card-grid">
  <div class="card">
    <h3>Plotly.js</h3>
    <p>JSON-defined charts with export controls and responsive sizing.</p>
  </div>
  <div class="card">
    <h3>D3.js</h3>
    <p>Custom SVG visualizations with inline scripts and data binding.</p>
  </div>
  <div class="card">
    <h3>Observable</h3>
    <p>Notebook embeds with live parameter tuning and reactive cells.</p>
  </div>
  <div class="card">
    <h3>Bokeh</h3>
    <p>Python-generated interactive plots with server-side rendering.</p>
  </div>
  <div class="card">
    <h3>R Shiny</h3>
    <p>Full R applications embedded via iframe with responsive height.</p>
  </div>
  <div class="card">
    <h3>Jupyter Widgets</h3>
    <p>ipywidgets state rendered client-side for interactive controls.</p>
  </div>
</div>
