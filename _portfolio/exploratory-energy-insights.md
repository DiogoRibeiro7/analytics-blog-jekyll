---
layout: "project"
title: "Exploratory Data Analysis: Urban Energy Insights"
description: "Interactive EDA workspace revealing consumption clusters and behavioral archetypes."
key_technologies:
  - name: "R"
    icon: "📊"
    description: "Tidyverse pipelines and interactive Shiny components."
  - name: "Observable"
    icon: "🔗"
    description: "Linked visual encodings for rapid hypothesis testing."
  - name: "DuckDB"
    icon: "🦆"
    description: "Local analytical warehouse powering ad-hoc SQL exploration."
visualization_embed: >-
  <iframe title="Urban Energy Insights" src="https://eda.datalog-theme.example.com" loading="lazy" width="100%" height="420" style="border:0"></iframe>
problem_statement: |-
  Stakeholders needed to understand daily energy consumption behavior across city districts to
  prioritize infrastructure upgrades and demand response incentives.
solution_approach: |-
  - Consolidated smart meter readings into a unified DuckDB dataset accessible from R, Python, and SQL.
  - Developed a Shiny dashboard with drill-down charts, cluster analysis, and segmentation personas.
  - Embedded Observable notebooks to compare clustering algorithms and share reproducible narratives.
results: |-
  Decision makers identified three actionable consumption personas and secured funding for
  targeted efficiency retrofits.
metrics:
  - label: "Stakeholder workshops delivered"
    value: 6
  - label: "Time-to-insight reduction"
    value: "45%"
    description: "Compared to static PDF reporting workflows."
  - label: "Notebook reuse"
    value: "18 teams"
    description: "Number of cross-functional squads adopting the reusable notebooks."
dataset_information: |-
  - Hourly energy usage aggregated by district
  - Weather and mobility indicators aligned to the same temporal granularity
model_performance: |-
  Clustering evaluated using silhouette scores, Calinski-Harabasz, and Davies-Bouldin indices
  to confirm segmentation stability across random seeds.
challenges: |-
  Harmonizing anonymization policies required building automated privacy reports and ensuring
  each visualization contained clear aggregation messaging.
future_work: |-
  Incorporate indoor air-quality sensors and overlay socio-economic indicators to deepen
  neighborhood profiles.
collaboration: |-
  Contributions welcome via pull requests on the [EDA notebooks repository](https://github.com/DiogoRibeiro7/urban-energy-eda).
related_projects:
  - title: "Predictive Modeling: Energy Demand Forecasting"
    url: "/portfolio/predictive-modeling-energy-demand/"
    description: "Forecasting project that operationalizes insights from this analysis."
---

## Key artifacts

- DuckDB analytical dataset refreshed nightly using GitHub Actions.
- Observable gallery featuring interactive choropleths and anomaly detection timelines.
- Workshop playbook documenting facilitation exercises and feedback loops.
