---
layout: post
title: Experimental Design Blueprint with Power Analysis
date: 2024-04-09
tags: [experimentation, statistics, design]
difficulty: intermediate
summary: Document hypotheses, sample-size calculations, and statistical tests with tables and callouts for product teams.
hero: /assets/images/posts/experiment-design.jpg
---

Thoughtful experiment logs help product teams align on hypotheses before shipping features. This blueprint captures the essentials—design tables, power analysis code, and interpretation guidelines—all rendered cleanly by the **DataLog** theme.

## Hypotheses

| Hypothesis | Description | Metric | Direction |
|------------|-------------|--------|-----------|
| H1 | New onboarding improves activation | Activation rate | Increase |
| H2 | Tooltips reduce setup time | Median time-to-value | Decrease |

## Sample-size planning

```python
from statsmodels.stats.power import NormalIndPower

effect = 0.04  # minimum detectable effect (absolute)
alpha = 0.05
power = 0.8
baseline = 0.32

analysis = NormalIndPower()
n_per_group = analysis.solve_power(effect_size=effect / (baseline * (1 - baseline)) ** 0.5,
                                  power=power,
                                  alpha=alpha,
                                  ratio=1.0)
print(round(n_per_group))
```

> **Reminder:** Adjust for multiple comparisons if you expect to peek at intermediate checkpoints.

## Test plan

| Metric | Test | Rationale |
|--------|------|-----------|
| Activation rate | Two-proportion z-test | Large samples, binary outcome |
| Time-to-value | Mann–Whitney U | Non-parametric, skewed distribution |
| Retention (D28) | Kaplan–Meier log-rank | Survival analysis |

## Decision framework

1. Pre-register hypotheses and guardrails in `_datasets/experiment-hypotheses.csv`.
2. Automate metric extraction via notebooks stored in `_notebooks/`.
3. Attach Tableau or Looker dashboards with the `viz-block` include for executive readouts.

By combining Markdown tables, statistical code, and callouts, the post becomes a reusable experimentation template for every squad.
