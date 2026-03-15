---
layout: "project"
title: "Predictive Modeling: Energy Demand Forecasting"
description: "Building probabilistic forecasts to optimize grid operations across Portuguese municipalities."
key_technologies:
  - name: "Python"
    icon: "🐍"
    description: "Feature engineering and probabilistic modeling with pandas and scikit-learn."
  - name: "Prophet"
    icon: "🔮"
    description: "Hierarchical time-series forecasting with external regressors."
  - name: "MLflow"
    icon: "📈"
    description: "Experiment tracking, model registry, and deployment packaging."
github:
  owner: "DiogoRibeiro7"
  repo: "energy-demand-forecasting"
  description: "Forecasting pipeline with reproducible experiments and deployment assets."
demo_url: "https://energy.datalog-theme.example.com/"
problem_statement: |-
  Municipal grid operators struggled to anticipate demand spikes during extreme weather
  events, leading to costly peaker plant activations and service disruptions.
solution_approach: |-
  - Aggregated smart meter telemetry, weather forecasts, and socioeconomic indicators.
  - Engineered lagged consumption features, holiday flags, and regional mobility indices.
  - Trained gradient boosted decision trees and Prophet ensembles with hyperparameter sweeps.
results: |-
  The combined ensemble reduced mean absolute percentage error (MAPE) by 18% compared
  to the incumbent baseline and enabled proactive load shifting programs.
metrics:
  - label: "MAPE improvement"
    value: "18%"
    description: "Relative to previous autoregressive baseline across validation windows."
  - label: "Peak demand warning lead time"
    value: "4 hours"
    description: "Average actionable notice before critical threshold breaches."
  - label: "Carbon savings"
    value: "6.5%"
    description: "Reduction in emergency peaker usage measured quarter-over-quarter."
dataset_information: |-
  - Portuguese smart meter telemetry (2021–2023)
  - ECMWF weather ensemble forecasts
  - Municipal census indicators sourced from national statistics offices
model_performance: |-
  Forecast intervals calibrated within ±6% coverage error across municipalities.
  Residual diagnostics confirmed minimal autocorrelation after differencing and regressor tuning.
model_visualizations:
  - embed: >-
      <iframe title="Energy Demand Forecast" src="https://energy.datalog-theme.example.com/embed/forecast" loading="lazy" width="100%" height="420" style="border:0"></iframe>
    caption: "Interactive forecast explorer with interval coverage overlays."
future_work: |-
  Extend the model to include real-time grid telemetry and reinforcement learning-based
  demand response optimization.
challenges: |-
  Harmonizing disparate telemetry sampling rates required building a robust temporal alignment
  service and data quality audit dashboard.
collaboration: |-
  Interested utilities and research partners can open issues or reach out via
  [dfr@esmad.ipp.pt](mailto:dfr@esmad.ipp.pt) to discuss pilot deployments.
contribution_guidelines: "https://github.com/DiogoRibeiro7/energy-demand-forecasting/blob/main/CONTRIBUTING.md"
related_projects:
  - title: "Exploratory Analysis: Urban Energy Patterns"
    url: "/portfolio/exploratory-energy-insights/"
    description: "Visual analytics companion detailing consumption clusters."
---

## Implementation notes

- Time-series cross-validation configured with rolling windows and seasonality-aware folds.
- Feature importance tracked via SHAP to guide stakeholder communication.
- Deployment packaged as containerized batch jobs triggered by Prefect flows.
