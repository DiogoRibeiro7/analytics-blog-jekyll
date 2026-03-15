---
title: Visualization gallery
description: Interactive demos for every visualization engine supported by the DataLog theme runtime.
permalink: /visualizations/
---

<section class="section">
  <div class="container">
    <h2 id="interactive-gallery">Interactive gallery</h2>
    <p>The cards below pull from <code>_data/visualizations.yml</code>. Filter by technology or tag to surface Plotly dashboards,
    Observable notebooks, Bokeh apps, and more.</p>
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
  </div>
</section>

<section class="section section-alt">
  <div class="container">
    <h2>Inline embeds</h2>
    <p>Every visualization below is rendered client-side using the bundled <code>assets/js/visualizations.js</code> runtime.
    Copy the markup into your own content and swap the configuration payload for your dataset.</p>

    <h3>Plotly.js line chart</h3>
    <div class="viz-block" data-viz-type="plotly" data-viz-slug="plotly-line-example" data-viz-version="1.0" data-viz-updated="2024-03-01">
      <div class="viz-header">
        <h4 class="viz-title">Model performance drift</h4>
        <p class="viz-meta" data-viz-meta></p>
        <span class="viz-status" data-viz-status aria-live="polite">Loading…</span>
      </div>
      <div class="viz-toolbar" aria-label="Plot utilities">
        <div data-viz-export></div>
        <a class="viz-toolbar__button" href="https://plotly.com/javascript/">Plotly docs</a>
      </div>
      <div class="viz-canvas" data-viz-canvas>
        <script nonce="{{ page.csp_nonce }}" type="application/json">
{"data":[{"type":"scatter","mode":"lines+markers","name":"Production","x":["Jan","Feb","Mar","Apr"],"y":[0.82,0.8,0.78,0.81]},{"type":"scatter","mode":"lines+markers","name":"Shadow","x":["Jan","Feb","Mar","Apr"],"y":[0.8,0.82,0.79,0.83]}],"layout":{"title":{"text":"F1 score drift"},"yaxis":{"tickformat":".2f","title":"F1 Score"},"margin":{"t":50,"r":30,"b":50,"l":60}}}
        </script>
      </div>
    </div>

    <h3>D3.js bar comparison</h3>
    <div class="viz-block" data-viz-type="d3" data-viz-slug="d3-bar-example" data-viz-version="0.3" data-viz-updated="2024-02-20">
      <div class="viz-header">
        <h4 class="viz-title">Feature contribution snapshot</h4>
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

    <h3>Observable notebook embed</h3>
    <div class="viz-block" data-viz-type="observable" data-viz-title="Observable topic model" data-viz-slug="observable-topic-model" data-viz-version="1.1" data-viz-updated="2024-01-18" data-viz-src="https://observablehq.com/embed/@datalog/topic-modeling-overview?cells=chart">
      <div class="viz-header">
        <h4 class="viz-title">Topic modelling playground</h4>
        <p class="viz-meta" data-viz-meta></p>
        <span class="viz-status" data-viz-status aria-live="polite">Loading…</span>
      </div>
      <div class="viz-canvas" data-viz-canvas></div>
    </div>

    <h3>Bokeh dashboard</h3>
    <div class="viz-block" data-viz-type="bokeh" data-viz-slug="bokeh-line-example" data-viz-version="0.8" data-viz-updated="2024-02-15" data-viz-src="https://demo.bokeh.org/dashboard/embed">
      <div class="viz-header">
        <h4 class="viz-title">Pipeline performance monitor</h4>
        <p class="viz-meta" data-viz-meta></p>
        <span class="viz-status" data-viz-status aria-live="polite">Loading…</span>
      </div>
      <div class="viz-canvas" data-viz-canvas></div>
    </div>

    <h3>R Shiny application</h3>
    <div class="viz-block" data-viz-type="shiny" data-viz-title="Retail demand forecaster" data-viz-slug="shiny-demand-example" data-viz-version="1.4" data-viz-updated="2024-02-22" data-viz-src="https://shiny.posit.co/r/price-forecasting/">
      <div class="viz-header">
        <h4 class="viz-title">Scenario planning</h4>
        <p class="viz-meta" data-viz-meta></p>
        <span class="viz-status" data-viz-status aria-live="polite">Loading…</span>
      </div>
      <div class="viz-canvas" data-viz-canvas></div>
    </div>

    <h3>Ipywidgets viewer</h3>
    <div class="viz-block" data-viz-type="ipywidgets" data-viz-slug="ipywidgets-slider-example" data-viz-version="0.6" data-viz-updated="2024-01-30">
      <div class="viz-header">
        <h4 class="viz-title">Feature importance inspector</h4>
        <p class="viz-meta" data-viz-meta></p>
        <span class="viz-status" data-viz-status aria-live="polite">Loading…</span>
      </div>
      <div class="viz-canvas" data-viz-canvas>
        <script nonce="{{ page.csp_nonce }}" type="application/vnd.jupyter.widget-state+json">
{"version_major":2,"version_minor":0,"state":{}}
        </script>
        <script nonce="{{ page.csp_nonce }}" type="application/vnd.jupyter.widget-view+json">
{"model_id":"mock-model","version_major":2,"version_minor":0}
        </script>
      </div>
    </div>
  </div>
</section>
