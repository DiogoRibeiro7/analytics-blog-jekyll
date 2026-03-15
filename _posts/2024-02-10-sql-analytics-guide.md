---
title: "SQL Analytics Guide for Reproducible Pipelines"
date: 2024-02-10
author: Diogo Ribeiro
author_affiliation: ESMAD - Instituto Politécnico do Porto
difficulty: Intermediate
categories:
  - tutorials
tags:
  - sql
  - analytics-engineering
  - dbt
summary: "Design modular SQL models with testing, documentation, and lineage tracking."
description: >-
  An end-to-end guide to crafting warehouse-ready SQL transformations with
  dbt, including window functions, CTE patterns, and automated quality checks.
keywords:
  - sql guide
  - analytics engineering
  - dbt tutorial
interactive_components:
  - title: dbt docs site preview
    url: https://analytics.example.com/dbt-docs
    description: Explore the interactive lineage graph generated from the project.
render_with_liquid: false
---

## Modeling philosophy

- Separate staging, intermediate, and mart layers to isolate concerns.
- Document every model with `description` blocks to power dbt docs.
- Pair assertions with automated tests using `unique`, `not_null`, and `relationships`.

## Example staging model

```sql
with source as (
    select *
    from {{ source('stripe', 'charges') }}
),
renamed as (
    select
        id as charge_id,
        customer_id,
        amount / 100.0 as amount_eur,
        created::date as charge_date,
        status
    from source
)
select * from renamed
```

## Building aggregate marts

```sql
with charges as (
    select * from {{ ref('stg_stripe_charges') }}
),
customers as (
    select * from {{ ref('dim_customers') }}
)
select
    c.customer_id,
    c.segment,
    date_trunc('month', ch.charge_date) as charge_month,
    sum(ch.amount_eur) as monthly_revenue,
    count_if(ch.status = 'failed') as failed_payments
from charges ch
join customers c using (customer_id)
group by 1, 2, 3
```

## Testing critical assumptions

```yaml
version: 2
models:
  - name: fct_billing_health
    description: "Monthly revenue and failure counts per customer."
    tests:
      - unique:
          column_name: "customer_id || '-' || charge_month"
      - not_null:
          column_name: monthly_revenue
      - relationships:
          to: ref('dim_customers')
          field: customer_id
```

## Automation tips

1. Schedule CI builds with `dbt-cloud` or GitHub Actions to run on each PR.
2. Export lineage metadata to the technical search index for discoverability.
3. Snapshot slowly changing dimensions using `dbt snapshot` for audit trails.

Download the [project template](https://github.com/DiogoRibeiro7/warehouse-template)
and explore the generated docs site to navigate dependencies visually.
