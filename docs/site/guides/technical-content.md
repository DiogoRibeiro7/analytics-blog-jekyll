---
title: Write technical pages
description: Publish readable code, tables, equations, and notes with the DataLog theme.
permalink: /guides/technical-content/
math: true
---

## Code examples

Give fenced code a language so Rouge can highlight it and the copy control can identify it. For example, a research post can declare its layout and enable equations in its front matter:

```yaml
layout: post
title: Estimating a mean
math: true
```

Then use a fenced block for the analysis itself:

```python
from statistics import mean

observations = [2.1, 2.4, 2.2]
print(mean(observations))
```

The copy button is available beside each rendered block. For an existing site's installation commands, see the [installation guide]({{ '/guides/installation/' | relative_url }}).

## Tables and captions

A caption tells readers what a table measures. Use a semantic table when you need a caption or header cells:

<table>
  <caption>Example observations used to estimate the mean</caption>
  <thead><tr><th scope="col">Observation</th><th scope="col">Value</th><th scope="col">Unit</th></tr></thead>
  <tbody>
    <tr><th scope="row">First</th><td>2.1</td><td>seconds</td></tr>
    <tr><th scope="row">Second</th><td>2.4</td><td>seconds</td></tr>
    <tr><th scope="row">Third</th><td>2.2</td><td>seconds</td></tr>
  </tbody>
</table>

Wide tables scroll inside the reading column on a phone. Keep the heading labels and units in the table itself so the data remains useful outside the surrounding prose.

## Equations

Write inline math such as $\bar{x}$ in the paragraph and put longer expressions on their own line:

$$
\bar{x} = \frac{1}{n}\sum_{i=1}^{n}x_i
$$

The `math: true` front matter explicitly enables MathJax for this guide. The theme can also load math automatically when it detects an expression; see the [author guide](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/blob/develop/docs/user-guide.md) for authoring details.

## Notes and links

<aside class="callout" role="note" aria-label="Project site paths">
  <p><strong>Project site paths.</strong> Internal guide links use Jekyll's <code>relative_url</code> filter so they work when a site has a <code>baseurl</code>.</p>
</aside>

Use descriptive link text and section headings. The guide navigation and “On this page” links make those sections reachable by keyboard.
