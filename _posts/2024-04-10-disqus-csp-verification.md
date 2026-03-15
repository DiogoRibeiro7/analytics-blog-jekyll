---
layout: post
title: Disqus CSP Verification
date: 2024-04-10
summary: Sanity-check the Disqus embed under strict CSP for automated tests.
comments:
  provider: disqus
  shortname: datalog-demo
  mapping: pathname
  enabled_by_default: true
nav_exclude: true
tags: [testing]
---

This hidden post exists purely for automated tests that confirm inline scripts emitted by the
Disqus embed receive the correct Content Security Policy nonce. It is excluded from the primary
navigation but published so that the Jekyll site generator renders the markup used by the tests.
