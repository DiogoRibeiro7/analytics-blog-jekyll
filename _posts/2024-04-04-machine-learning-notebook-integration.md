---
layout: post
title: MLOps Walkthrough with Jupyter Notebook Integration
date: 2024-04-04
tags: [machine-learning, mlops, notebooks]
difficulty: intermediate
summary: Connect a notebook-driven training pipeline to DataLog call-to-action buttons, experiment tracking, and reproducibility checklists.
hero: /assets/images/posts/mlops-notebook-handoff.jpg
---

Production-grade machine learning documentation pairs code, metrics, and narrative. This guide walks through a churn prediction notebook and highlights how the **DataLog** theme embeds notebooks with launch buttons for popular runtimes.

## Notebook overview

The project notebook `notebooks/churn-segmentation.ipynb` contains:

- Feature engineering with pandas and scikit-learn `ColumnTransformer`
- Model training using `xgboost.XGBClassifier`
- MLflow logging for parameters, metrics, and artifacts

```python
from xgboost import XGBClassifier
from sklearn.compose import ColumnTransformer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

numeric = ["monthly_charges", "tenure", "support_tickets"]
categorical = ["contract", "region"]

preprocess = ColumnTransformer(
    [
        ("num", StandardScaler(), numeric),
        ("cat", OneHotEncoder(handle_unknown="ignore"), categorical),
    ]
)

model = Pipeline(
    steps=[
        ("preprocess", preprocess),
        (
            "classifier",
            XGBClassifier(
                max_depth=4,
                n_estimators=200,
                subsample=0.8,
                colsample_bytree=0.9,
                eval_metric="auc",
            ),
        ),
    ]
)
```

## Launch options

<div class="cta-group">
  <a class="btn btn--primary" href="https://mybinder.org/v2/gh/DiogoRibeiro7/datalog-notebooks/main?labpath=churn-segmentation.ipynb">Run in Binder</a>
  <a class="btn" href="https://colab.research.google.com/github/DiogoRibeiro7/datalog-notebooks/blob/main/churn-segmentation.ipynb">Open in Colab</a>
  <a class="btn btn--ghost" href="https://github.com/DiogoRibeiro7/datalog-notebooks/blob/main/churn-segmentation.ipynb">View on GitHub</a>
</div>

Readers can open the notebook in the environment of their choice, while the theme preserves accessibility labels for screen readers.

## Track experiments

```python
import mlflow

mlflow.set_experiment("churn-segmentation")
with mlflow.start_run(run_name="xgboost-baseline"):
    model.fit(train_features, train_labels)
    auc = model.score(test_features, test_labels)
    mlflow.log_metric("test_auc", auc)
    mlflow.xgboost.log_model(model.named_steps["classifier"], "model")
```

Embed evaluation tables and charts produced by MLflow in the post so stakeholders understand progress:

| Metric          | Value |
|-----------------|-------|
| Validation AUC  | 0.864 |
| Test AUC        | 0.851 |
| Drift monitor   | Stable |

## Checklist before deployment

- [x] Notebook executed from top to bottom without errors
- [x] Model registered with reproducible environment metadata
- [x] Alert thresholds documented for precision/recall trade-offs

DataLog’s notebook integration keeps workflows transparent—link to runnable notebooks, surface experiment logs, and capture decisions alongside the code that produced them.
