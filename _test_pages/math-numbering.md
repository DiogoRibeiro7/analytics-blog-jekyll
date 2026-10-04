---
layout: post
title: Equation numbering
permalink: /test-regressions/math-numbering/
date: 2026-09-30
toc: false
---

An equation the text does not refer to:

$$
x = 1
$$

One it does, written the way the user guide writes it:

$$
y = 2 \label{eq:labelled}
$$

An environment amsmath numbers, with a line left out:

\begin{align}
a &= 1 \label{eq:first-line} \\
b &= 2 \notag
\end{align}

A starred environment, which it does not number:

\begin{equation*}
z = 3
\end{equation*}

Equations \eqref{eq:labelled} and \eqref{eq:first-line}.
