---
layout: post
title: Dataset Announcement – Retail Demand Benchmark
date: 2024-04-11
tags: [dataset, announcement, documentation]
difficulty: beginner
summary: Introduce a curated retail demand dataset, document its schema, and outline governance steps for contributors.
hero: /assets/images/posts/dataset-announcement.jpg
---

Today we are releasing the **Retail Demand Benchmark** dataset to help analytics teams evaluate forecasting models under realistic constraints. The DataLog theme lets you pair documentation, schema tables, and governance checklists in one place.

## Download options

- `retail-demand-benchmark.csv` via the dataset page
- Parquet export via `_datasets/retail-demand-benchmark.md`
- Companion notebook: `_notebooks/batch-anomaly-detection.ipynb`

## Schema

| Column | Type | Description |
|--------|------|-------------|
| `date` | Date | Week-ending timestamp |
| `store_id` | String | Unique store identifier |
| `category` | String | Product category slug |
| `units_sold` | Integer | Units sold in the week |
| `price` | Decimal | Average selling price |
| `promo_flag` | Boolean | Promotion indicator |
| `stockout_minutes` | Integer | Minutes unavailable due to stockouts |

## Usage guidelines

```yaml
data_quality:
  freshness: P1D
  source_system: retail_warehouse
  owners:
    - name: Diogo Ribeiro
      email: diogo.debastos.ribeiro@gmail.com
    - name: Analytics Platform Team
      email: platform@example.com
  sla:
    anomalies: notify-analytics-oncall@example.com
    completeness: >= 0.98
```

> **Governance tip:** Store ownership metadata in `_data/catalog.yml` so the theme can surface it across dataset and notebook pages.

## Next steps

1. Publish baseline forecasts and accuracy benchmarks in the notebooks collection.
2. Embed interactive Plotly charts showing store-level variability.
3. Solicit community contributions via GitHub Discussions and credit accepted pull requests in the showcase gallery.

With schema documentation and ownership metadata in place, teams can trust the dataset before wiring it into production pipelines.
