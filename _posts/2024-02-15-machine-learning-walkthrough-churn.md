---
title: "Machine Learning Walkthrough: Predicting Customer Churn"
date: 2024-02-15
author: Diogo Ribeiro
author_affiliation: ESMAD - Instituto Politécnico do Porto
difficulty: Advanced
categories:
  - machine-learning
tags:
  - python
  - scikit-learn
  - mlops
summary: "Train, evaluate, and deploy a churn classifier with reproducible ML workflows."
description: >-
  Build a gradient boosted model with feature engineering, cross-validation,
  experiment tracking, and deployment-ready artifacts for customer retention teams.
keywords:
  - churn model
  - ml walkthrough
  - gradient boosting
interactive_components:
  - title: Launch the MLflow experiment dashboard
    url: https://mlflow.datalog-theme.example.com
    description: Inspect metrics, parameters, and artifacts captured during training.
---

## Business framing

A subscription analytics company wants to proactively engage at-risk customers.
The objective is to maximize precision while maintaining acceptable recall so
that retention specialists focus on high-quality leads.

## Feature engineering pipeline

```python
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder, StandardScaler

categorical = ["region", "plan_type", "engagement_cluster"]
numeric = ["tenure_months", "support_tickets", "nps", "usage_minutes"]

preprocessor = ColumnTransformer(
    transformers=[
        ("categorical", OneHotEncoder(handle_unknown="ignore"), categorical),
        ("numeric", StandardScaler(), numeric),
    ]
)
```

## Training with cross-validation

```python
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.model_selection import StratifiedKFold, cross_validate

clf = GradientBoostingClassifier(random_state=42)
cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)

metrics = cross_validate(
    clf,
    preprocessor.fit_transform(train_X),
    train_y,
    cv=cv,
    scoring=["precision", "recall", "roc_auc"],
    return_estimator=True,
)
```

Track each run with MLflow to version hyperparameters and feature sets:

```python
import mlflow

with mlflow.start_run(run_name="gb-churn-baseline"):
    mlflow.log_params(clf.get_params())
    mlflow.log_metrics({
        "precision_mean": metrics["test_precision"].mean(),
        "recall_mean": metrics["test_recall"].mean(),
        "roc_auc_mean": metrics["test_roc_auc"].mean(),
    })
    mlflow.sklearn.log_model(clf.fit(train_X, train_y), "model")
```

## Model evaluation

- Precision@Top500 = **0.71**, aligning with business targets.
- Calibration curve indicates slight overconfidence above 0.8 probability.
- SHAP values highlight tenure and NPS as the dominant predictors.

## Deployment considerations

1. Export the pipeline via `mlflow.sklearn.log_model` and load it in the scoring API.
2. Schedule batch predictions with Prefect using data quality gates before inference.
3. Monitor live metrics with Evidently AI dashboards connected to the feature store.

Download the [serving blueprint](https://github.com/DiogoRibeiro7/ml-serving-blueprint)
or open the MLflow dashboard to review the registered model versions.
