---
layout: post
title: Research Article Template with Citations and BibTeX
date: 2024-04-06
tags: [research, publication, citations]
difficulty: advanced
summary: Structure a scholarly article, cite prior work from a BibTeX file, and supply BibTeX so readers can cite your study.
hero: /assets/images/posts/research-template.jpg
bibliography: _bibliography/research-paper.bib   # the works {% cite %} draws on; see docs/components.md#citations
---

Publishing reproducible scholarship requires more than compelling charts. This template demonstrates how to structure a research article, cite related work, and provide BibTeX metadata so colleagues can reference your study quickly.

## Abstract

We evaluate adaptive experimentation for recommendation systems, focusing on policy regret minimization across cold-start cohorts. Empirical results indicate a 12% lift in engagement relative to static baselines while maintaining fairness constraints.

## Introduction

Personalized experiences need to balance accuracy and fairness. Prior work on contextual bandits {% cite li2010 %} and on fairness constraints in classification {% cite zafar2017 %} lays the foundation for our framework.

## Methodology

We define policy regret as

\begin{equation}\label{eq:regret}
\mathcal{R}_T = \sum_{t=1}^T \bigl( r_t(x_t, a_t^\star) - r_t(x_t, a_t) \bigr)
\end{equation}

where $r_t$ is the reward and $a_t^\star$ is the action chosen by an oracle. Algorithm 1 summarizes the constrained Thompson sampling procedure, whose regret guarantees follow the classical analysis {% cite agrawal2012 russo2018 %}.

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

Equation \eqref{eq:regret} highlights how regret decomposes into reward differences, as in the contextual setting of {% cite li2010 %}. Posterior sampling adapts to the cold-start cohorts without a tuned exploration rate {% cite russo2018 sec="7" %}. Future work will incorporate causal constraints to prevent drift.

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

Add this BibTeX block to your citation manager or to the `CITATION.cff` file when you release accompanying code. The DataLog theme numbers the citations, equations and code blocks of a single article, and lists the cited works under References.
