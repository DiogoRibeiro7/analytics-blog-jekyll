---
layout: project
title: "Experimental Design Platform for Behavioral Science"
description: "Automated experimentation tooling supporting rapid hypothesis testing and peer review."
key_technologies:
  - name: TypeScript
    icon: 🧩
    description: Front-end analytics dashboards and experimentation workflows.
  - name: R
    icon: 📐
    description: Statistical engines for sequential testing and Bayesian analysis.
  - name: PostgreSQL
    icon: 🗄️
    description: Versioned experiment metadata and audit trails.
github:
  owner: DiogoRibeiro7
  repo: experimental-design-platform
  description: Infrastructure-as-code, APIs, and statistical services powering the lab platform.
visualization_embed: >-
  <iframe title="Experiment Control Center" src="https://experiments.datalog-theme.example.com" loading="lazy" width="100%" height="420" style="border:0"></iframe>
problem_statement: |-
  Research teams needed a compliant, auditable system to run concurrent behavioral experiments
  while sharing progress with peer reviewers and external collaborators.
solution_approach: |-
  - Implemented experiment blueprints, randomization engines, and sequential monitoring.
  - Integrated JupyterHub and RStudio Server for reproducible analysis with shared datasets.
  - Shipped automated report generation with APA-style summaries and data availability statements.
results: |-
  Platform adoption cut experiment setup time from four weeks to five days and improved
  audit outcomes thanks to comprehensive provenance tracking.
metrics:
  - label: Setup time reduction
    value: 75%
  - label: Active research groups
    value: 14
  - label: Peer review approval rate
    value: 96%
dataset_information: |-
  - Secure object storage for raw behavioral logs
  - Public derivatives published via Zenodo with DOIs per study
model_performance: |-
  Sequential Bayes factors stabilized within 1.5% of ground-truth simulations across
  10,000 bootstrapped trials.
future_work: |-
  Add adaptive experimentation modules leveraging contextual bandits and integrate ORCID-based
  single sign-on for external collaborators.
challenges: |-
  Balancing audit requirements with researcher autonomy necessitated granular access controls and
  automated consent verification pipelines.
collaboration: |-
  External labs can request sandbox access through the [collaboration form](mailto:dfr@esmad.ipp.pt?subject=Experimental%20Design%20Collaboration).
related_projects:
  - title: Statistical Analysis Blueprint for Experimental Design
    url: /statistics/2024/02/20/statistical-analysis-experimental-design/
    description: Companion article describing the statistical methodology that powers the platform.
---

## Operational highlights

- Experiment registry exposes REST and GraphQL APIs for automation.
- Automated APA reports export to PDF, DOCX, and HTML for quick dissemination.
- Integrated Slack and email digests keep stakeholders informed about milestone events.
