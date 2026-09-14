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
    render_on_load: auto # auto | true | false
```

The math engine is loaded from a CDN and weighs several hundred kilobytes, so by default it is only loaded where it is needed:

- `math.render_on_load: auto` loads the math engine on pages where the math preprocessor finds expressions (`$…$`, `$$…$$`, `\(…\)` and `\[…\]`, outside code), and on notebook pages that render math. `true` loads it on every page; `false` only on pages that opt in.
- A page can force it with `math: true` or `math: false` in its front matter. Pages that render math from data fetched at runtime, such as the search page, should opt in. `math: false` also stops the math preprocessor from treating dollar signs on that page as LaTeX.

Code needs no settings. Rouge highlights it when the site builds (`highlighter: rouge`), adding line numbers when `kramdown.syntax_highlighter_opts.block.line_numbers` is on, and pages load nothing for it. The theme used to load Prism in the browser as well. `theme_options.syntax_highlighting` no longer has an effect, and a build that still sets it prints a warning.

A page that sets its own `hero_image` can also set `hero_image_small` (a version around 640 px wide) for phones; the theme preloads whichever applies.

### 4. Integrations

External services live in `_config.yml` under `integrations:` and are exposed to templates as `site.integrations`:

```yaml
integrations:
  github:
    enabled: true        # false turns off the live stars and forks on project pages
    owner: yourusername
    cache_ttl: 43200     # seconds a repository's figures stay cached in the browser
```

The Binder and Colab buttons on notebook pages are configured with the notebooks rather than here: they link to `notebooks.repository` at `notebooks.branch`, in the formats set by `notebooks.binder.base_url` and `notebooks.colab.base_url`.

### 5. Analytics and comments

```yaml
google_analytics: ""     # a GA4 measurement id enables the tag; empty disables it

datalog_plugins:
  enabled:
    - datalog-search     # datalog-comments depends on it
    - datalog-comments
  options:
    datalog-comments:
      provider: giscus   # giscus, utterances or disqus
      repo: owner/repo
      repo_id: ""        # from https://giscus.app
      category: General
      category_id: ""
      mapping: pathname
      enabled_by_default: false
```

A page shows comments when its front matter sets `comments: true`, or on every page with `enabled_by_default: true`. `comments: false` turns them off for one page, and a `comments:` hash overrides these settings for that page. Giscus needs `repo`, `repo_id`, `category` and `category_id`; utterances needs `repo`; Disqus needs `shortname`.

### 6. Embedded content

The Content Security Policy lets iframes load from the site itself and from Observable. List any other host your pages embed, such as a Shiny server, a slide deck or a video platform:

```yaml
csp:
  frame_src:
    - https://*.shinyapps.io
    - https://www.youtube-nocookie.com
```

A page that loads scripts, stylesheets, fonts or data from somewhere else lists those sources under `csp.script_src`, `csp.style_src`, `csp.font_src` or `csp.connect_src` in the same way.

Plotly, D3 and Bokeh load their libraries from jsDelivr. The policy of a page with one of those blocks allows that library's package, not the whole of jsDelivr. The code in a `data-d3-script` or `data-bokeh-script` block runs with the page's nonce, so the policy needs no `unsafe-eval`. [content-security-policy.md](content-security-policy.md) lists what each page allows.

## Accessing configuration in templates

```liquid
{{ site.title }}
{{ site.theme_options.math.engine }}
{{ site.integrations.github.owner }}
{{ site.data.config.author.name }}
```

## Need help?

- [User guide](user-guide.md)
- [Report an issue](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/issues)
