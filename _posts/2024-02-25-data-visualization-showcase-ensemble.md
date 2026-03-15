---
title: "Data Visualization Showcase: Communicating Ensemble Forecasts"
date: 2024-02-25
author: Diogo Ribeiro
author_affiliation: ESMAD - Instituto Politécnico do Porto
difficulty: Intermediate
categories:
  - visualization
tags:
  - plotly
  - d3
  - storytelling
summary: "Blend Plotly, D3, and Observable techniques to communicate ensemble climate forecasts."
description: >-
  Explore a gallery of interactive visualizations that compare probabilistic
  forecasts across models with annotations, animation, and accessibility best practices.
keywords:
  - data visualization
  - ensemble forecasts
  - climate analytics
interactive_components:
  - title: Launch the visualization hub
    url: /visualizations/
    description: Browse the live examples embedded across the Visualization Hub.
---

## Visualization goals

- Convey ensemble spread without overwhelming the viewer.
- Provide tactile controls for filtering, animation, and comparison.
- Maintain WCAG-compliant contrast and descriptive alt text for every figure.

## Plotly fan chart

```python
import plotly.graph_objects as go

fig = go.Figure()
for member in ensemble_members:
    fig.add_trace(go.Scatter(
        x=member["date"],
        y=member["temperature"],
        mode="lines",
        line=dict(color="rgba(33, 150, 243, 0.15)")
    ))
fig.add_trace(go.Scatter(
    x=ensemble_mean["date"],
    y=ensemble_mean["temperature"],
    mode="lines",
    line=dict(color="#ff9800", width=3),
    name="Ensemble mean"
))
fig.update_layout(
    template="plotly_white",
    hovermode="x unified",
    title="Ensemble temperature forecast",
    xaxis_title="Date",
    yaxis_title="Temperature (°C)"
)
fig.show()
```

## Observable linked highlighting

```javascript
viewof focus = Inputs.select(models, {label: "Forecast model"})

display(horizonChart(data, {
  color: model => model === focus ? "#d81b60" : "#90caf9",
  description: model => `${model.name} temperature anomalies`
}))
```

## Accessibility checklist

1. Provide textual summaries below each chart describing trends.
2. Enable keyboard navigation for filters and toggles.
3. Export static PNG/SVG snapshots for reports and offline review.

Embed the full gallery via the Visualization Hub link to experience the
animations, annotations, and export workflow in action.
