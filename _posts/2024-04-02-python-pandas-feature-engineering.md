---
layout: post
title: Feature Engineering with pandas Window Functions
date: 2024-04-02
tags: [python, pandas, tutorial]
difficulty: intermediate
summary: Build production-ready rolling metrics with pandas while documenting inline math expectations for analysts.
hero: /assets/images/posts/pandas-window-functions.jpg
---

Time-series feature engineering in **pandas** turns raw telemetry into actionable signals. We will compute rolling statistics, annotate seasonal trends, and document the math so collaborators can audit each transformation.

## Prerequisites

- Python 3.10+
- pandas 2.2+
- A dataset with timestamped metrics (e.g., request latency in milliseconds)

> **Tip:** Store raw data in [Parquet](https://parquet.apache.org/) to preserve schema metadata and improve I/O.

## Rolling aggregations

```python
import pandas as pd

latency = pd.read_parquet("data/api-latency.parquet").set_index("timestamp")
window = latency.rolling("7D", min_periods=3)
features = pd.DataFrame(
    {
        "latency_p50": window["p50"].median(),
        "latency_p95": window["p95"].max(),
        "error_rate": window["errors"].sum() / window["requests"].sum(),
    }
)
features = features.dropna()
```

Inline math keeps the feature derivation transparent. The error rate feature is simply $\hat{p} = \frac{\text{errors}}{\text{requests}}$ evaluated over the rolling window.

## Seasonal decomposition

Use statsmodels to separate long-term trend from seasonality:

```python
from statsmodels.tsa.seasonal import STL

stl = STL(features["latency_p95"], period=14)
result = stl.fit()
features["latency_trend"] = result.trend
features["latency_seasonal"] = result.seasonal
```

Documenting each derived column in the post ensures the **DataLog** theme renders callouts, syntax highlighting, and inline equations without extra plugins.

## Share the output

- Publish the generated CSV in `_datasets/` with provenance metadata.
- Attach the notebook run to `_notebooks/` for reviewers to replay calculations.
- Link to dashboards or alerts that consume the engineered features.

By combining equations with syntax-highlighted code snippets, the article remains reproducible while showcasing how the theme renders mathematical context alongside pandas transformations.
