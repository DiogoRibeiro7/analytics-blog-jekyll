---
title: "R Exploratory Analysis of Urban Housing Markets"
date: 2024-02-05
author: Diogo Ribeiro
author_affiliation: ESMAD - Instituto Politécnico do Porto
difficulty: Intermediate
categories:
  - tutorials
tags:
  - r
  - exploratory-data-analysis
  - ggplot2
summary: "Perform a reproducible exploratory analysis of housing prices in R using the tidyverse."
description: >-
  An R Markdown-inspired walkthrough of importing, transforming, and
  visualizing housing market data with tidyverse tools and reusable templates.
keywords:
  - r analysis
  - tidyverse EDA
  - housing prices
interactive_components:
  - title: Observable notebook comparison
    url: https://observablehq.com/@datalog/housing-market-eda
    description: Review the Observable notebook to contrast R and JavaScript pipelines.
---

## Project setup

```r
library(tidyverse)
library(lubridate)
library(scales)

housing <- read_csv("data/housing_portugal.csv")
glimpse(housing)
```

Key checks before modeling:

- Inspect missing values with `skimr::skim`.
- Validate coordinate reference systems if spatial joins are required.
- Record assumptions in an analysis log (see `/docs/analysis-playbook.md`).

## Feature engineering

```r
housing <- housing %>%
  mutate(
    price_per_m2 = price_eur / floor_area_m2,
    listing_month = floor_date(listing_date, "month"),
    energy_rating = fct_explicit_na(energy_rating, "Unknown"),
    is_new_build = if_else(construction_year > 2018, TRUE, FALSE)
  )
```

## Visualizing distributions

```r
ggplot(housing, aes(price_per_m2, fill = property_type)) +
  geom_histogram(binwidth = 250) +
  scale_x_continuous(labels = label_dollar(prefix = "€")) +
  facet_wrap(~property_type) +
  labs(
    title = "Distribution of price per square meter",
    subtitle = "Segmented by property type",
    x = "Price per m²",
    y = "Count"
  ) +
  theme_minimal(base_size = 14)
```

## Communicating findings

- Central Lisbon apartments average **€5,100/m²** with a right-skewed tail.
- New builds exhibit a 15% premium relative to comparable resale properties.
- Energy ratings remain missing for 32% of listings—prioritize data enrichment.

## Reproducibility checklist

1. Render the R Markdown document with `targets::tar_make()` to guarantee order.
2. Publish companion notebooks via Netlify or GitHub Pages with `quarto publish`.
3. Pin package versions using `renv::snapshot()` and commit the lockfile.

Download the [analysis repository](https://github.com/DiogoRibeiro7/urban-housing-eda)
or launch the interactive Observable notebook to explore alternative visual encodings.
