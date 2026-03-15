---
layout: post
title: SQL Optimization Playbook for Warehouse Analysts
date: 2024-04-05
tags: [sql, performance, warehousing]
difficulty: intermediate
summary: Profile query plans, apply windowing strategies, and document optimization tips with the DataLog theme’s code annotations.
hero: /assets/images/posts/sql-optimization.jpg
---

Modern cloud warehouses give you sophisticated tuning knobs, but documentation often lags behind. This guide shows how to annotate SQL plans, highlight critical snippets, and attach performance artifacts so every reviewer can reproduce improvements.

## Baseline query

```sql
SELECT
  customer_id,
  SUM(spend) AS total_spend,
  AVG(spend) AS avg_spend,
  ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY purchase_ts DESC) AS purchase_rank
FROM analytics.fact_orders
WHERE purchase_ts >= DATEADD('day', -90, CURRENT_DATE)
GROUP BY 1
```

Use the built-in explain tools to gather diagnostics:

```sql
EXPLAIN USING JSON
SELECT *
FROM (
  -- baseline aggregation
  SELECT
    customer_id,
    SUM(spend) AS total_spend,
    AVG(spend) AS avg_spend
  FROM analytics.fact_orders
  WHERE purchase_ts >= DATEADD('day', -90, CURRENT_DATE)
  GROUP BY 1
) src
JOIN analytics.dim_customer dc USING (customer_id);
```

## Optimization checklist

1. Materialize the 90-day window as an incremental model.
2. Cluster the fact table on `purchase_ts` to prune partitions.
3. Replace repeated JSON parsing with persisted staged columns.
4. Cache high-cardinality dimension joins using search optimization services.

> **Note:** Store the JSON explain output in `_datasets/` so reviewers can diff the query plan over time.

## Annotate performance wins

| Change | Before (s) | After (s) | Impact |
|--------|------------|-----------|--------|
| Clustering on `purchase_ts` | 22.4 | 9.7 | 2.3× faster |
| Incremental materialization  | 9.7  | 4.5 | 2.1× faster |
| Persisted JSON attributes    | 4.5  | 3.8 | 1.2× faster |

Wrap up by linking to dbt models, scheduling notes, and alert thresholds so stakeholders can keep the warehouse humming.
