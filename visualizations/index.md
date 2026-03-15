---
layout: page
title: Visualization Hub
permalink: /visualizations/
description: Interactive visualization gallery showcasing Plotly, Observable, D3.js, Bokeh, R Shiny, and Jupyter widget integrations for the DataLog theme.
---

The DataLog visualization hub centralises interactive projects, reproducible notebooks, and embeddable dashboards. Use the filters
below to discover examples aligned with specific technologies, topics, or collaboration needs.

<div class="viz-gallery" data-viz-gallery>
  {% assign techs = site.data.visualizations | map: 'tech' | uniq | sort %}
  {% assign tag_strings = site.data.visualizations | map: 'tags' | join: ',' %}
  {% assign tags = tag_strings | split: ',' | uniq | sort %}
  <div class="viz-gallery-controls" role="region" aria-label="Visualization filters">
    <label>
      Technology
      <select data-viz-filter="tech">
        <option value="all">All</option>
        {% for tech in techs %}
        <option value="{{ tech }}">{{ tech | capitalize }}</option>
        {% endfor %}
      </select>
    </label>
    <label>
      Topic tag
      <select data-viz-filter="tag">
        <option value="all">All</option>
        {% for tag in tags %}
        <option value="{{ tag }}">{{ tag | capitalize }}</option>
        {% endfor %}
      </select>
    </label>
  </div>
  <div class="viz-gallery-grid">
    {% for visualization in site.data.visualizations %}
    {% include components/visualization-card.html visualization=visualization %}
    {% endfor %}
  </div>
</div>

## Embed examples

### Plotly.js line chart
<div
  class="viz-block"
  data-viz-type="plotly"
  data-viz-slug="plotly-line-example"
  data-viz-version="1.0"
  data-viz-updated="2024-03-01"
>
  <div class="viz-header">
    <h3 class="viz-title">Model performance drift</h3>
    <p class="viz-meta" data-viz-meta></p>
    <span class="viz-status" data-viz-status aria-live="polite">Loading…</span>
  </div>
  <div class="viz-toolbar" aria-label="Plot utilities">
    <div data-viz-export></div>
    <a class="viz-toolbar__button" href="https://plotly.com/javascript/">Plotly docs</a>
  </div>
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

### D3.js bar comparison
<div
  class="viz-block"
  data-viz-type="d3"
  data-viz-slug="d3-bar-example"
  data-viz-version="0.3"
  data-viz-updated="2024-02-20"
>
  <div class="viz-header">
    <h3 class="viz-title">Feature contribution snapshot</h3>
    <p class="viz-meta" data-viz-meta></p>
    <span class="viz-status" data-viz-status aria-live="polite">Loading…</span>
  </div>
  <div class="viz-toolbar" aria-label="D3 resources">
    <a class="viz-toolbar__button" href="https://d3js.org/">D3.js docs</a>
  </div>
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

const x = d3
  .scaleBand()
  .domain(data.map((d) => d.feature))
  .range([margin.left, width - margin.right])
  .padding(0.2);

const y = d3
  .scaleLinear()
  .domain([0, d3.max(data, (d) => d.value)])
  .nice()
  .range([height - margin.bottom, margin.top]);

svg
  .append('g')
  .attr('fill', '#3f7cff')
  .selectAll('rect')
  .data(data)
  .enter()
  .append('rect')
  .attr('x', (d) => x(d.feature))
  .attr('y', (d) => y(d.value))
  .attr('height', (d) => y(0) - y(d.value))
  .attr('width', x.bandwidth())
  .attr('rx', 6);

const axisBottom = d3.axisBottom(x);
const axisLeft = d3.axisLeft(y).tickFormat(d3.format('.0%'));

svg
  .append('g')
  .attr('transform', `translate(0, ${height - margin.bottom})`)
  .call(axisBottom)
  .selectAll('text')
  .style('font-size', '0.75rem')
  .style('transform', 'translateY(6px)');

svg
  .append('g')
  .attr('transform', `translate(${margin.left}, 0)`)
  .call(axisLeft)
  .selectAll('text')
  .style('font-size', '0.75rem');
    </script>
  </div>
</div>

### Observable notebook embed
<div
  class="viz-block"
  data-viz-type="observable"
  data-viz-title="Observable topic model"
  data-viz-slug="observable-topic-model"
  data-viz-version="1.1"
  data-viz-updated="2024-01-18"
  data-observable-src="https://observablehq.com/embed/@observablehq/plot-airports?cells=viewof+chart"
>
  <div class="viz-header">
    <h3 class="viz-title">Observable topic model controls</h3>
    <p class="viz-meta" data-viz-meta></p>
    <span class="viz-status" data-viz-status aria-live="polite">Loading…</span>
  </div>
  <div class="viz-toolbar" aria-label="Observable resources">
    <a class="viz-toolbar__button" href="https://observablehq.com/@observablehq/plot">Observable docs</a>
  </div>
  <div class="viz-canvas" data-viz-canvas></div>
</div>

### Bokeh interactive line chart
<div
  class="viz-block"
  data-viz-type="bokeh"
  data-viz-slug="bokeh-line-example"
  data-viz-version="0.8"
  data-viz-updated="2024-02-15"
>
  <div class="viz-header">
    <h3 class="viz-title">Batch processing durations</h3>
    <p class="viz-meta" data-viz-meta></p>
    <span class="viz-status" data-viz-status aria-live="polite">Loading…</span>
  </div>
  <div class="viz-toolbar" aria-label="Bokeh resources">
    <a class="viz-toolbar__button" href="https://docs.bokeh.org/en/latest/docs/user_guide/embed.html">Bokeh embedding guide</a>
  </div>
  <div class="viz-canvas" data-viz-canvas>
    <script nonce="{{ page.csp_nonce }}" type="text/plain" data-bokeh-script>
const figure = Bokeh.Plotting.figure({
  title: 'Nightly job duration',
  height: 280,
  sizing_mode: 'stretch_both',
  background_fill_alpha: 0,
  toolbar_location: null
});

const source = new Bokeh.ColumnDataSource({
  data: {
    hours: ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00'],
    duration: [12, 14, 11, 10, 13, 15]
  }
});

figure.line({ field: 'hours' }, { field: 'duration' }, {
  source,
  line_width: 3,
  line_color: '#ff8a5c'
});

figure.circle({ field: 'hours' }, { field: 'duration' }, {
  source,
  size: 8,
  fill_color: 'white',
  line_color: '#ff8a5c',
  line_width: 2
});

figure.xaxis.axis_label = 'Time of day';
figure.yaxis.axis_label = 'Duration (minutes)';

Bokeh.Plotting.show(figure, element);
    </script>
  </div>
</div>

### R Shiny forecasting app
<div
  class="viz-block"
  data-viz-type="shiny"
  data-viz-title="Retail demand forecaster"
  data-viz-slug="shiny-demand-example"
  data-viz-version="1.4"
  data-viz-updated="2024-02-22"
  data-shiny-src="https://shiny.posit.co/r/api/shiny-user-showcase/"
  data-shiny-height="720px"
>
  <div class="viz-header">
    <h3 class="viz-title">R Shiny demand explorer</h3>
    <p class="viz-meta" data-viz-meta></p>
    <span class="viz-status" data-viz-status aria-live="polite">Loading…</span>
  </div>
  <div class="viz-toolbar" aria-label="Shiny resources">
    <a class="viz-toolbar__button" href="https://shiny.posit.co/">R Shiny gallery</a>
  </div>
  <div class="viz-canvas" data-viz-canvas></div>
</div>

### Jupyter Widget slider control
<div
  class="viz-block"
  data-viz-type="ipywidgets"
  data-viz-slug="ipywidgets-slider-example"
  data-viz-version="0.6"
  data-viz-updated="2024-01-30"
>
  <div class="viz-header">
    <h3 class="viz-title">Threshold tuning widget</h3>
    <p class="viz-meta" data-viz-meta></p>
    <span class="viz-status" data-viz-status aria-live="polite">Loading…</span>
  </div>
  <div class="viz-toolbar" aria-label="Widget resources">
    <a class="viz-toolbar__button" href="https://ipywidgets.readthedocs.io/en/stable/">ipywidgets docs</a>
  </div>
  <div class="viz-canvas" data-viz-canvas>
    <script nonce="{{ page.csp_nonce }}" type="application/vnd.jupyter.widget-state+json">
{
  "version_major": 2,
  "version_minor": 0,
  "state": {
    "fdf8e44935ed4293a01418e1f529ea7c": {
      "model_name": "LayoutModel",
      "model_module": "@jupyter-widgets/base",
      "model_module_version": "2.0.0",
      "state": {}
    },
    "b4c410eb159f4defb4080042f2ab9373": {
      "model_name": "SliderStyleModel",
      "model_module": "@jupyter-widgets/controls",
      "model_module_version": "2.0.0",
      "state": {}
    },
    "7c9e707d1cf2454cbb120997e0cbdab7": {
      "model_name": "FloatSliderModel",
      "model_module": "@jupyter-widgets/controls",
      "model_module_version": "2.0.0",
      "state": {
        "_dom_classes": [],
        "description": "Threshold",
        "layout": "IPY_MODEL_fdf8e44935ed4293a01418e1f529ea7c",
        "max": 1.0,
        "step": 0.05,
        "style": "IPY_MODEL_b4c410eb159f4defb4080042f2ab9373",
        "value": 0.3
      }
    }
  }
}
    </script>
    <script nonce="{{ page.csp_nonce }}" type="application/vnd.jupyter.widget-view+json">
{"version_major": 2, "version_minor": 0, "model_id": "7c9e707d1cf2454cbb120997e0cbdab7"}
    </script>
  </div>
</div>

## Versioning and export workflow

Every visualization block stores version and update metadata, making it easy to coordinate pull requests and change logs. Export
buttons appear when the integration exposes a static download action (Plotly in this example), and you can attach additional export
links by adding anchors inside the toolbar region.

Large libraries are lazy-loaded only when a visualization enters the viewport so long-form research pages stay performant even when
hosting multiple dashboards, notebooks, and widget bundles.
