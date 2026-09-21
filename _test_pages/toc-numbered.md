---
layout: post
title: Numbered headings
permalink: /test-regressions/toc-numbered/
date: 2026-09-20
---

Research articles number their sections, and kramdown slugifies the text as it
finds it, so these headings get ids that start with a digit. `#1-introduction`
is not a valid CSS selector, and the contents script used to pass it to
`querySelector` after cancelling the link's own navigation: the entry did
nothing at all (#330).

## 1. Introduction

Enough text to give the article a scrollbar, so the reading position and the
progress indicator have something to report.

## 2. Method

The second section, far enough down the page that reaching it is a scroll
rather than a step.

### 2.1 Sampling

A third-level heading, numbered the same way.

## 3. Results

The last section of the fixture. It holds [a link](https://example.org/) so a
test can check where the Tab key goes after the browser jumps to this heading:
native fragment navigation sets the point the next Tab starts from, which the
script that cancelled it did not.
