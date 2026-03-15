---
layout: post
title: Introducing the DataLog Theme
date: 2024-01-01
tags: [announcement, jekyll, data-science]
summary: Learn how the DataLog theme supports research communication with notebooks, datasets, and interactive visualizations.
---

The **DataLog** theme is designed for data scientists and researchers who need a dependable platform for publishing technical content. It supports:

- MathJax for rendering LaTeX equations such as $\\int_0^1 x^2 \\mathrm{d}x = \tfrac{1}{3}$
- Syntax highlighting for Python, R, SQL, and Julia
- Embedded visualizations from Plotly, Vega-Lite, or other frameworks via `<iframe>`

```python
import pandas as pd

def summarize(df: pd.DataFrame) -> pd.Series:
    return df.describe().loc['mean']
```

Use this starter post to share your research agenda, lab news, or a welcome message for collaborators.
