---
layout: post
title: Research Article Template with Citations and BibTeX
date: 2024-04-06
tags: [research, publication, citations]
difficulty: advanced
summary: Structure a scholarly article, reference prior work with footnotes, and supply BibTeX so readers can cite your study.
hero: /assets/images/posts/research-template.jpg
citations:
  - id: li2010
    title: A Contextual-Bandit Approach to Personalized News Article Recommendation
    authors:
      - Li, Lihong
      - Chu, Wei
      - Langford, John
      - Schapire, Robert
    journal: WWW
    year: 2010
    url: https://dl.acm.org/doi/10.1145/1772690.1772758
  - id: zafar2017
    title: Fairness Beyond Disparate Treatment & Disparate Impact
    authors:
      - Zafar, Muhammad Bilal
      - Valera, Isabel
      - Rodriguez, Manuel Gomez
      - Gummadi, Krishna P.
    journal: WWW
    year: 2017
    url: https://dl.acm.org/doi/10.1145/3038912.3052660
---

Publishing reproducible scholarship requires more than compelling charts. This template demonstrates how to structure a research article, cite related work, and provide BibTeX metadata so colleagues can reference your study quickly.

## Abstract

We evaluate adaptive experimentation for recommendation systems, focusing on policy regret minimization across cold-start cohorts. Empirical results indicate a 12% lift in engagement relative to static baselines while maintaining fairness constraints.

## Introduction

Personalized experiences need to balance accuracy and fairness. Prior work on contextual bandits[^1] and constrained optimization[^2] lays the foundation for our framework.

[^1]: Li, Lihong, et al. "A Contextual-Bandit Approach to Personalized News Article Recommendation." *WWW* (2010).
[^2]: Zafar, Muhammad Bilal, et al. "Fairness Beyond Disparate Treatment & Disparate Impact." *WWW* (2017).

## Methodology

We define policy regret as

\begin{equation}\label{eq:regret}
\mathcal{R}_T = \sum_{t=1}^T \bigl( r_t(x_t, a_t^\star) - r_t(x_t, a_t) \bigr)
\end{equation}

where $r_t$ is the reward and $a_t^\star$ is the action chosen by an oracle. Algorithm 1 summarizes the constrained Thompson sampling procedure.

```pseudo
Initialize posterior priors for all arms
for each round t = 1..T:
  sample reward estimates from posterior
  project samples to satisfy fairness constraints
  choose arm with highest adjusted draw
  update posterior with observed reward
```

## Results

| Metric                | Baseline | Adaptive policy |
|-----------------------|----------|-----------------|
| Click-through rate    | 5.4%     | **6.1%**        |
| Retention (28-day)    | 42.0%    | **45.8%**       |
| Fairness gap (Δ)      | 0.17     | **0.06**        |

## Discussion

Equation \eqref{eq:regret} highlights how regret decomposes into reward differences. Future work will incorporate causal constraints to prevent drift.

## Cite this work

```bibtex
@article{ribeiro2024adaptive,
  title = {Adaptive Recommendation Under Fairness Constraints},
  author = {Ribeiro, Diogo and Smith, Ada},
  journal = {Journal of Responsible AI},
  year = {2024},
  volume = {12},
  number = {2},
  pages = {45--63},
  doi = {10.1234/jrai.2024.5678}
}
```

Add this BibTeX block to your citation manager or to the `CITATION.cff` file when you release accompanying code. The DataLog theme handles footnotes, equations, and code blocks seamlessly in a single article.
