---
title: Introducing the DataLog documentation hub
summary: Tour the documentation site structure, deployment workflow, and the components showcased across each section.
tags: [release, documentation]
---

Welcome to the official documentation site for the **DataLog** theme. The pages you are reading are rendered with the theme
gem itself, so you can treat every component as an executable example.

## What's inside

- **Feature deep dives** for layouts, reusable components, and YAML front matter recipes.
- **Interactive demos** that exercise the visualization runtime across Plotly, D3, Observable, Bokeh, Shiny, and ipywidgets.
- **Migration guides** to help you port content from Minimal Mistakes, Chirpy, and Just the Docs without losing SEO equity.
- **Showcase gallery** highlighting community deployments of the theme in academia and data teams.

## Deployment workflow

1. Fork or clone the [`datalog-theme.github.io`](https://github.com/datalog-theme/datalog-theme.github.io) repository.
2. Edit `_config.yml` and `_data/navigation.yml` with your organisation's metadata.
3. Push to `main` to trigger the GitHub Actions workflow that publishes the site to `gh-pages`.

> #### ℹ Tip
> Keep your documentation repository in sync with the theme releases. Add the stability tests introduced in the main theme
> repository to ensure notebooks, math rendering, search indexes, and visualizations stay healthy as you upgrade.

## What's next

Head over to the [feature catalog](/features/) for hands-on tutorials or jump straight into the
[visualization gallery](/visualizations/) to copy embed-ready snippets.
