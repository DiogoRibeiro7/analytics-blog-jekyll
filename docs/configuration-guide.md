# Configuration Guide

Where the DataLog theme's settings live and how to change the common ones.

## Overview

| File | Purpose |
|------|---------|
| `_config.yml` | Everything the theme reads: site identity, features, `theme_options`, integrations, notebooks, plugin settings |
| `_data/config/author.yml` | The author profile used by the about and research pages (`site.data.config.author`) |
| `_data/navigation.yml`, `_data/social.yml`, `_data/i18n/*.yml` | Navigation menus, social and RSS links, translations |

`_config.yml` is organised in labelled sections (Jekyll core, site identity, features, theme customization, integrations, notebooks, plugins). Search for the banner comment of the section you need.

## Quick Start

### 1. Update your profile

Edit `_data/config/author.yml`:

```yaml
name: Your Name
affiliation: Your Institution
email: your@email.com
photo:            # e.g. /assets/img/author.jpg; leave unset for the initial-letter placeholder

profiles:
  orcid: https://orcid.org/YOUR-ORCID
  github: yourusername

research_areas:
  - id: machine-learning
    title: Machine Learning
    url: /tags/#machine-learning
```

### 2. Site identity

In `_config.yml`:

```yaml
title: Your Site
description: One-sentence description used for meta tags
url: https://your-domain.example
baseurl: ""            # "/repo-name" for a GitHub Pages project site
author:
  name: Your Name
```

### 3. Features and theme options

In `_config.yml`:

```yaml
features:
  search: true
  mathjax: true
  visualizations: true

theme_options:
  math:
    engine: mathjax      # or katex
    output: chtml
    accessibility: true
  syntax_highlighting:
    components: [core, python, r, sql, julia, javascript]
```

### 4. Integrations

External services live in `_config.yml` under `integrations:` and are exposed to templates as `site.integrations`:

```yaml
integrations:
  github:
    enabled: true
    owner: yourusername
  binder:
    enabled: true
  colab:
    enabled: true
```

### 5. Analytics and comments

```yaml
google_analytics: ""     # a GA4 measurement id enables the tag; empty disables it

datalog_plugins:
  comments:
    provider: giscus
    giscus:
      repo: owner/repo
      repo_id: ""        # from https://giscus.app
      category_id: ""
```

## Accessing configuration in templates

```liquid
{{ site.title }}
{{ site.theme_options.math.engine }}
{{ site.integrations.binder.enabled }}
{{ site.data.config.author.name }}
```

## Need help?

- [User guide](user-guide.md)
- [Report an issue](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/issues)
