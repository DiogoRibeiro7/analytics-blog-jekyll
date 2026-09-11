---
title: "Python Data Wrangling Foundations"
date: 2024-02-01
author: Diogo Ribeiro
author_affiliation: ESMAD - Instituto Politécnico do Porto
difficulty: Beginner
categories:
  - tutorials
tags:
  - python
  - pandas
  - data-wrangling
summary: "Learn how to shape tabular data with pandas using tidy data principles."
description: >-
  Step-by-step walkthrough of loading, cleaning, transforming, and validating
  datasets with pandas for analytics-ready pipelines.
keywords:
  - python tutorial
  - pandas data cleaning
  - tidy data
interactive_components:
  - title: Explore the notebook in Binder
    url: https://mybinder.org/v2/gh/DiogoRibeiro7/analytics-blog-jekyll/main?labpath=notebooks/python-wrangling.ipynb
    description: Launch the companion notebook to interactively run each transformation.
---

> “Clean data is the foundation for every successful analysis.”

## Why tidy data matters

- Consistent column naming and typing enables reproducible pipelines.
- Explicit missing data handling prevents silent downstream errors.
- Vectorized operations in pandas deliver fast, readable transformations.

## Loading and inspecting data

```python
import pandas as pd

def load_sales_data(path: str) -> pd.DataFrame:
    """Load the monthly sales CSV and parse dates."""
    return pd.read_csv(path, parse_dates=["order_date"])

sales = load_sales_data("data/monthly_sales.csv")
print(sales.head())
```

The `load_sales_data` helper enforces date parsing and sets the tone for reusable
functions.

## Cleaning column names

```python
import janitor

sales = janitor.clean_names(sales)
sales.columns
```

`pyjanitor.clean_names` standardizes casing and spacing. Track these helpers in
`utils/cleaning.py` to share with teammates.

## Handling missing values

1. Use `DataFrame.info()` to surface unexpected null columns.
2. Apply domain-driven imputations when appropriate.
3. Preserve the original column when imputing to maintain auditability.

```python
from sklearn.impute import SimpleImputer
import numpy as np

imputer = SimpleImputer(strategy="median")
sales["discount_filled"] = imputer.fit_transform(sales[["discount"]])
sales["discount_was_missing"] = np.where(sales["discount"].isna(), 1, 0)
```

## Deriving tidy features

Create narrow columns that answer single analytical questions.

```python
sales = (
    sales.assign(
        revenue=lambda df: df.quantity * df.unit_price,
        order_month=lambda df: df.order_date.dt.to_period("M"),
    )
    .query("status == 'completed'")
    .rename(columns={"customer_segment": "segment"})
)
```

## Validating assumptions with tests

```python
import pytest

def test_only_completed_orders():
    assert sales.status.unique().tolist() == ["completed"]
```

Automated data tests catch regressions when upstream schemas drift.

## Takeaways

- Encapsulate IO, cleaning, and feature engineering in composable functions.
- Version notebooks alongside unit tests to guard scientific integrity.
- Document design decisions inline so collaborators understand trade-offs.

Open the companion notebook through Binder to explore the exercises hands-on.
