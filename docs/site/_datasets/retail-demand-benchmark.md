---
title: Retail demand benchmark
tags: [retail, forecasting]
frequency: Monthly
data_source: https://example.com/datasets/retail-demand.csv
license: CC-BY-4.0
summary: Synthetic demand dataset covering three retail regions with seasonality and promotion features for experimentation.
updated: 2024-02-12
schema:
  - name: date
    type: date
    description: Calendar date for the observation.
  - name: region
    type: string
    description: Sales region code (north, central, south).
  - name: channel
    type: string
    description: Primary sales channel (in-store, e-commerce, wholesale).
  - name: units_sold
    type: integer
    description: Units sold during the period.
  - name: promo_flag
    type: boolean
    description: Whether a promotion was active.
  - name: stockout_risk
    type: float
    description: Derived probability of stockout for the region.
links:
  dashboard: https://example.com/dashboards/retail-demand/
  notebook: /notebooks/batch-anomaly-detection/
---

The retail demand benchmark helps data teams test forecasting workflows in a controlled environment. Combine it with the
[interactive forecasting workbench](/portfolio/interactive-forecasting-workbench/) to explore seasonality decomposition,
model comparison, and scenario planning.
