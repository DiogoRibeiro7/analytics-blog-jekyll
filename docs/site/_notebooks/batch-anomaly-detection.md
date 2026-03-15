---
title: Batch anomaly detection notebook
summary: Detect anomalous sales spikes using rolling z-scores and isolation forests across multiple regions.
tags: [python, anomaly-detection]
date: 2024-02-15
notebook:
  source: notebooks/batch-anomaly-detection.ipynb
  download: /assets/notebooks/batch-anomaly-detection.ipynb
  executed_at: 2024-02-15 13:02
  duration: 8 min
  code_cells: 42
  markdown_cells: 19
  error_cells: 0
  kernelspec:
    display_name: Python 3.11
    language: python
  integrations:
    binder: https://mybinder.org/v2/gh/DiogoRibeiro7/datalog-notebooks/main?labpath=batch-anomaly-detection.ipynb
    colab: https://colab.research.google.com/github/DiogoRibeiro7/datalog-notebooks/blob/main/batch-anomaly-detection.ipynb
    source: https://github.com/DiogoRibeiro7/datalog-notebooks/blob/main/batch-anomaly-detection.ipynb
    branch: main
  git:
    last_commit: 8c1a4f2
---

This notebook ships with the documentation site to demonstrate the <code>notebook</code> layout. Embed executable code cells,
plot outputs, and ipywidgets inline while preserving provenance.

```python
import pandas as pd
from sklearn.ensemble import IsolationForest

sales = pd.read_csv("https://example.com/retail-demand.csv")
model = IsolationForest(contamination=0.03, random_state=42)
sales["score"] = model.fit_predict(sales[["units_sold", "stockout_risk"]])
```

Use the call-to-action buttons in the sidebar to open the notebook directly in Binder or Colab for live tinkering.
