---
title: Tools & Resources for Data Scientists
permalink: /tools/
layout: page
description: Curated software, libraries, and learning materials that power the DataLog workflow.
---

## Core analytics stack

| Layer | Tooling | Notes |
| --- | --- | --- |
| Data engineering | dbt, Airbyte, DuckDB | Reproducible pipelines with modular SQL and high-performance in-process analytics. |
| Machine learning | scikit-learn, PyTorch, Tidymodels | Balanced coverage for classical and deep learning workloads across Python and R. |
| Visualization | Plotly, Observable, D3.js, Bokeh | Interactive storytelling with responsive, accessible embeds. |
| Experimentation | Optimizely, custom sequential testing services | Control randomization, guardrails, and automated reporting. |

## Notebook productivity

- **JupyterLab extensions**: jupyterlab-lsp, variable inspector, theme toggles.
- **VS Code**: Remote Containers for reproducible dev environments.
- **Quarto**: Unified publishing for notebooks, manuscripts, and slide decks.

## Statistical & scientific libraries

- `pymc` and `cmdstanr` for Bayesian inference.
- `evidently` for model monitoring dashboards.
- `powerAnalysisR` templates included in the [experiment platform](https://github.com/DiogoRibeiro7/experimental-design-platform).

## Collaboration utilities

- **Version control**: GitHub Actions templates for notebooks, tests, and documentation.
- **Documentation**: MkDocs + Material theme for lightweight knowledge bases.
- **Communication**: Slack integrations with automated status digests for experiments and pipelines.

## Learning pathways

1. [Getting started guide]({{ '/getting-started/' | relative_url }}) for new practitioners.
2. [Visualization Hub]({{ '/visualizations/' | relative_url }}) to explore interactive patterns.
3. [Research layout documentation]({{ '/research/' | relative_url }}) describing scholarly publishing workflows.

Have a recommendation? Email <a href="mailto:dfr@esmad.ipp.pt">dfr@esmad.ipp.pt</a> or open a GitHub issue.
