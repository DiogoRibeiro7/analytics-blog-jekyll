---
title: "Statistical Analysis Blueprint for Experimental Design"
date: 2024-02-20
author: Diogo Ribeiro
author_affiliation: ESMAD - Instituto Politécnico do Porto
difficulty: Advanced
categories:
  - statistics
tags:
  - experimental-design
  - hypothesis-testing
  - r
summary: "Plan, analyze, and interpret controlled experiments with rigorous statistical methods."
description: >-
  A practical framework for power analysis, randomized design selection,
  model fitting, and interpretation grounded in reproducible statistical tooling.
keywords:
  - statistical analysis
  - power analysis
  - experimental design
---

## Planning experiments

- Define primary outcome metrics before collecting data.
- Establish guardrail metrics for operational health.
- Use stratified randomization when heterogeneous subgroups exist.

## Power calculations

```r
library(pwr)

detectable_effect <- 0.03
baseline_rate <- 0.18
power_target <- 0.8
alpha <- 0.05

pwr_result <- pwr.2p.test(
  h = ES.h(baseline_rate, baseline_rate + detectable_effect),
  power = power_target,
  sig.level = alpha
)

ceiling(pwr_result$n)
```

## Analyzing outcomes

```r
library(broom)
library(sandwich)
library(lmtest)

model <- glm(conversion ~ treatment + device + country, family = binomial(), data = experiment)
robust <- coeftest(model, vcov = sandwich)
tidy(robust)
```

## Communicating uncertainty

| Metric | Estimate | 95% CI | Notes |
| --- | --- | --- | --- |
| Lift | 2.9% | [1.1%, 4.7%] | Practical significance achieved |
| p-value | 0.004 | – | Meets alpha threshold |
| Sample ratio mismatch | 0.6% | – | Within tolerance |

## Recommendations

1. Roll out treatment to 45% of traffic while monitoring device-specific effects.
2. Launch follow-up experiment measuring lifetime value after 90 days.
3. Share raw data and analysis scripts in the [open science workspace]({{ '/datasets/' | relative_url }}).

Download the power analysis workbook above to adapt these calculations for
your experimentation roadmap.
