---
title: Content type recipes
description: Front matter guides for posts, datasets, notebooks, and portfolio entries with links to live examples.
permalink: /features/content-types/
---

<section class="section">
  <div class="container">
    <h2>Posts</h2>
    <p>Posts are defined in <code>_posts</code> with dated filenames. Use the front matter block below to enable tags, summaries,
    and changelog callouts.</p>
```yaml
---
layout: post
title: Introducing DataLog Theme
summary: Walk through the documentation site structure and highlights.
tags: [release, documentation]
---
```
    <p>See the <a href="/blog/introducing-datalog-theme/">launch post</a> for the rendered output.</p>
  </div>
</section>

<section class="section section-alt">
  <div class="container">
    <h2>Datasets</h2>
    <p>Curate data sources in <code>_datasets</code>. The layout supports schema tables, licensing, update cadences, and download
    buttons.</p>
```yaml
---
layout: dataset
title: Retail demand benchmark
tags: [retail, forecasting]
frequency: Monthly
data_source: https://example.com/datasets/retail-demand.csv
license: CC-BY-4.0
---
```
    <p>Inspect the <a href="/datasets/retail-demand-benchmark/">retail demand benchmark</a> entry for the final look.</p>
  </div>
</section>

<section class="section">
  <div class="container">
    <h2>Notebooks</h2>
    <p>Notebook pages accept a <code>notebook</code> object in front matter. Populate it with metadata exported from Jupyter or
    Papermill for reproducibility.</p>
```yaml
---
layout: notebook
title: Batch anomaly detection notebook
notebook:
  source: notebooks/batch-anomaly-detection.ipynb
  download: /assets/notebooks/batch-anomaly-detection.ipynb
  executed_at: 2024-02-15 13:02
  kernelspec:
    display_name: Python 3.11
    language: python
---
```
    <p>The <a href="/notebooks/batch-anomaly-detection/">example notebook</a> includes binder/Colab integration links.</p>
  </div>
</section>

<section class="section section-alt">
  <div class="container">
    <h2>Portfolio</h2>
    <p>Showcase interactive case studies in <code>_portfolio</code>. The <code>project</code> layout adds CTA buttons and summary cards.</p>
```yaml
---
layout: project
title: Interactive forecasting workbench
summary: Combine Prophet and D3 to produce multi-horizon forecasts with scenario planning widgets.
tags: [forecasting, dashboards]
links:
  github: https://github.com/DiogoRibeiro7/forecasting-workbench
  demo: https://example.com/workbench/
  deck: https://example.com/workbench/slides.pdf
---
```
    <p>Open the <a href="/portfolio/interactive-forecasting-workbench/">interactive forecasting workbench</a> page to see the
    layout populated.</p>
  </div>
</section>
