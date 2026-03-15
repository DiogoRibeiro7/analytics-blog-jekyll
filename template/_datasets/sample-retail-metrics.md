---
title: Sample Retail Metrics Dataset
date: 2024-01-08
source: Internal data warehouse
format: csv
schema:
  - name: date
    type: date
    description: Calendar date for the metrics snapshot.
  - name: store_id
    type: string
    description: Unique identifier for the retail location.
  - name: revenue
    type: number
    description: Daily revenue in USD.
  - name: transactions
    type: integer
    description: Total number of transactions processed.
  - name: avg_basket
    type: number
    description: Average order value in USD.
---

Download the accompanying CSV from `datasets/sample-retail-metrics.csv` and explore the metrics referenced in related posts and notebooks.
