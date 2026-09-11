---
title: "Research Methodology for Open Science Workflows"
date: 2024-03-01
author: Diogo Ribeiro
author_affiliation: ESMAD - Instituto Politécnico do Porto
difficulty: Intermediate
categories:
  - research
tags:
  - methodology
  - open-science
  - reproducibility
summary: "Adopt an end-to-end methodology for transparent, reproducible research projects."
description: >-
  Outline study design, data management, analysis, and dissemination practices
  that align with open science principles and reproducibility checklists.
keywords:
  - research methodology
  - open science
  - reproducible workflows
interactive_components:
  - title: Launch the reproducibility checklist
    url: https://DiogoRibeiro7.github.io/open-science-checklist/
    description: Track progress across data, analysis, and dissemination milestones.
---

## Define research questions

1. Document hypotheses, constructs, and expected contributions.
2. Pre-register protocols on OSF or institutional repositories.
3. Align study design with ethical review outcomes and consent forms.

## Data management plan

- Store raw data in encrypted, access-controlled buckets.
- Publish anonymized derivatives with clear licensing on Zenodo.
- Version datasets and metadata using [DataLad](https://www.datalad.org/).

## Analysis workflow

```bash
# Create an isolated environment
mamba env create -f environment.yml

# Execute notebooks in a controlled order
papermill pipelines/analysis.ipynb output/analysis.ipynb -p seed 123

# Validate results
pytest tests/statistics --maxfail=1
```

## Documentation

- Maintain a living README describing objectives, dependencies, and contacts.
- Generate API docs for custom tooling with `sphinx-build`.
- Provide narrative summaries in the repository wiki for non-technical audiences.

## Dissemination

1. Publish preprints on arXiv and deposit supplementary code in GitHub releases.
2. Submit replication packages to the [DataLog datasets hub]({{ '/datasets/' | relative_url }}).
3. Track citations and altmetrics through ORCID, Google Scholar, and ResearchGate.

Adopt the reproducibility checklist to ensure each milestone—data, code,
documentation, and publications—meets open science expectations.
