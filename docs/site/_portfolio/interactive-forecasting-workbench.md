---
title: Interactive forecasting workbench
summary: Combine Prophet forecasting pipelines with D3-powered explainability panels for scenario planning.
tags: [forecasting, dashboards]
weight: 1
links:
  github: https://github.com/DiogoRibeiro7/forecasting-workbench
  demo: https://example.com/workbench/
  deck: https://example.com/workbench/slides.pdf
metrics:
  - label: Forecast accuracy
    value: 3.4%
  - label: Stakeholders onboarded
    value: 12 teams
---

## Overview

This project packages an end-to-end forecasting workflow built on top of the DataLog theme. It includes:

- **Notebook handoff** – Analysts publish Jupyter notebooks with the [notebook layout](/notebooks/batch-anomaly-detection/)
  and link the outputs to the workbench.
- **Dataset governance** – The [retail demand benchmark dataset](/datasets/retail-demand-benchmark/) tracks data freshness
  and schema drift.
- **Interactive dashboards** – The workbench renders Plotly and D3 components for multi-horizon forecasts and driver analysis.

## Implementation checklist

1. Clone the starter configuration from the [`/template` directory](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/tree/main/template).
2. Configure the GitHub Pages workflow for automated deployments.
3. Publish notebooks, datasets, and portfolio entries to connect the storytelling flow end-to-end.
