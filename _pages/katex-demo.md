---
layout: default
title: KaTeX Rendering Demo
permalink: /katex-demo/
math: true
math_engine: katex
nav_exclude: true
summary: Explore KaTeX rendering under the strict Content Security Policy.
---

This page verifies that the KaTeX asset pipeline works with the strict Content Security Policy.

When rendered you should see the integral below typeset by KaTeX:

$$\int_0^\pi \sin(x)\,dx = 2$$

Because KaTeX uses auto-rendering, the inline script responsible for invocation is protected by the
per-page nonce generated during the build.
