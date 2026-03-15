---
layout: post
title: Multilevel Modeling in R with ggplot2 Diagnostics
date: 2024-04-03
tags: [r, statistics, visualization]
difficulty: advanced
summary: Fit hierarchical models in R, visualize partial pooling with ggplot2, and highlight reproducible figure exports.
hero: /assets/images/posts/r-hierarchical-modeling.jpg
---

R remains a powerhouse for statistical modeling. This walkthrough fits a varying-intercept model with `lme4`, then layers diagnostic charts created with **ggplot2** to verify assumptions.

## Load packages and data

```r
library(tidyverse)
library(lme4)

metrics <- read_csv("data/store-conversion.csv")
metrics <- metrics |> mutate(period = as.Date(period))
```

## Fit a multilevel model

```r
model <- lmer(conversion_rate ~ campaign_spend + (1 | region), data = metrics)
summary(model)
```

The random intercept term captures regional heterogeneity while partial pooling shrinks noisy estimates toward the grand mean.

## Visualize partial pooling

```r
library(broom.mixed)
coefs <- broom.mixed::ranef(model, condVar = TRUE)$region |> tibble::rownames_to_column("region")

posterior <- coefs |> mutate(
  estimate = `(Intercept)`[, "condval"],
  se = sqrt(`(Intercept)`[, "condvar"])
)

posterior_plot <- posterior |> 
  ggplot(aes(x = estimate, y = fct_reorder(region, estimate))) +
  geom_point(color = "#1b9e77", size = 2.6) +
  geom_errorbarh(aes(xmin = estimate - 2 * se, xmax = estimate + 2 * se), height = 0.15) +
  labs(
    title = "Regional baseline conversion rates",
    x = "Log-odds",
    y = NULL
  ) +
  theme_minimal(base_size = 14)

ggplot2::ggsave("assets/images/posts/conversion-region-effects.png", posterior_plot, width = 8, height = 6, dpi = 144)
```

![Partial pooling chart showing regional intercepts](https://raw.githubusercontent.com/allisonhorst/palmerpenguins/main/man/figures/culmen.png)
{: .figure}

Exporting figures directly from the R session ensures the rendered asset is tracked in version control. Pair the static PNG with an Observable embed for interactive exploration:

<div
  class="viz-block"
  data-viz-type="observable"
  data-viz-title="Multilevel conversions"
  data-viz-slug="observable-conversion-effects"
  data-viz-version="1.0"
  data-viz-updated="2024-04-03"
  data-viz-src="https://observablehq.com/embed/@datalog/conversion-effects?cells=plot"
></div>

## Share reproducibility artifacts

- Commit the R script or Quarto document to `_notebooks/`.
- Publish the model summary as a downloadable CSV in `_datasets/`.
- Capture session info with `sessionInfo()` for audit trails.

The article mixes syntax highlighting, figure embeds, and Observable visualizations so readers can scrutinize both the statistical rigor and presentation quality.
