---
layout: post
title: Mathematical Proof Template with Numbered Equations
date: 2024-04-08
tags: [mathematics, proof, latex]
difficulty: advanced
summary: Showcase theorem statements, numbered equations, and cross-references rendered via MathJax within the DataLog theme.
hero: /assets/images/posts/math-proof.jpg
---

Document rigorous mathematics directly inside your documentation hub. This template illustrates how theorem statements, lemmas, and numbered equations render cleanly on the **DataLog** theme.

## Theorem

> **Theorem 1.** Let $f : [a, b] \to \mathbb{R}$ be twice continuously differentiable with $f(a) = f(b) = 0$. Then there exists $c \in (a, b)$ such that $f''(c) + \frac{\pi^2}{(b-a)^2} f(c) = 0$.

## Proof

We adapt the standard Wirtinger inequality. Consider the sine basis function $g(x) = \sin\left(\frac{\pi(x-a)}{b-a}\right)$ and define

\begin{equation}\label{eq:inner-product}
% alt: inner product equals the integral of f times g over the interval from a to b
\langle f, g \rangle = \int_a^b f(x) g(x) \, \mathrm{d}x.
\end{equation}

Integration by parts shows that

\begin{equation}\label{eq:ibp}
\int_a^b f'(x) g'(x) \, \mathrm{d}x = -\int_a^b f(x) g''(x) \, \mathrm{d}x = \frac{\pi^2}{(b-a)^2} \langle f, g \rangle.
\end{equation}

Combining Equations \eqref{eq:inner-product} and \eqref{eq:ibp} yields the desired critical point when $f$ is not identically zero. $\square$

## Notes for authors

- MathJax automatically numbers `equation` environments so you can reference them with `\eqref{}`.
- Inline math, such as $\int_a^b f(x)\,\mathrm{d}x$, remains crisp across light and dark modes.
- Use definition, lemma, and corollary blocks as needed—Markdown blockquotes keep the typography consistent.

Add proof sketches, exercises, or downloadable solution PDFs to round out your mathematical articles.
