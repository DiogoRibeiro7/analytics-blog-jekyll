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
content_license: CC-BY-4.0   # the reuse terms of your articles' text and figures (optional)
```

`content_license` is the default licence of every article, shown before "How to cite" and in the page's metadata; a page sets its own with `license:` or none with `license: false`, and `code_license` names the code samples' terms when they differ. It covers what you publish, not the theme: the repository's `LICENSE` is the theme's software licence. See [components.md: License Notice](components.md#license-notice) and the [configuration reference](configuration-reference.md#licences).

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

- `math.render_on_load: auto` (also the default when omitted) loads the math engine on pages where the math preprocessor finds expressions (`$…$`, `$$…$$`, `\(…\)` and `\[…\]`, outside code), and on notebook pages that render math. `true` loads it on every page; `false` only on pages that opt in.
- Inline math with spaces inside the dollars, such as `$ \frac{a}{b} $`, counts when it holds a TeX command, `^` or `_`, so `$ 5 or $ 10` stays text. Where MathJax loads it renders `$ x $` as well, but the preprocessor does not count it: write `$x$`, or set `math: true` on the page.
- A page can force it with `math: true` or `math: false` in its front matter. `mathjax` is read as an alias when `math` is not set, so a page's `math: false` turns off what a `mathjax: true` default turned on. Pages that render math from data fetched at runtime, such as the search page, should opt in. `math: false` also stops the math preprocessor from treating dollar signs on that page as LaTeX.
- Leave `math: true` and `mathjax: true` out of `defaults` while `render_on_load` is `auto`: every page in their scope would load the engine, math or not. The build prints a warning when it finds one.

Code needs no settings. Rouge highlights it when the site builds (`highlighter: rouge`), adding line numbers when `kramdown.syntax_highlighter_opts.block.line_numbers` is on, and pages load nothing for it. The theme used to load Prism in the browser as well. `theme_options.syntax_highlighting` no longer has an effect, and a build that still sets it prints a warning.

A page that sets its own `hero_image` can also set `hero_image_small` (a version around 640 px wide) for phones; the theme preloads whichever applies.

#### Images

When the site builds on a machine with [ImageMagick](https://imagemagick.org), each JPEG and PNG in the site's files gets resized copies and a WebP version; with `avifenc` from [libavif](https://github.com/AOMediaCodec/libavif) it also gets an AVIF version. Pages then offer them. A Markdown image such as `![Power curve](/assets/img/power.png)` becomes a `<picture>` with an AVIF and a WebP `<source>`, and its `<img>` keeps its attributes and gains a `srcset` of the resized copies. Without ImageMagick, no resized or converted copies are created. The optimizer still adds loading, decoding and known intrinsic dimensions, serializes optimized HTML, and writes the image manifest. A supplied width or height is preserved without adding an incompatible intrinsic counterpart. Relative image URLs are left alone; use site-root paths for optimization.

```yaml
theme_options:
  images:
    variants: true                      # false: create no copies, even with the tools installed
    sizes: [320, 640, 960, 1280, 1920]  # widths to create, up to the image's own
    default_sizes: 100vw                # the sizes attribute of an image that has none
    quality:
      avif: 45
      webp: 75
```

- The build uses ImageMagick 7's `magick`, or ImageMagick 6's `convert` outside Windows, and creates only the formats ImageMagick lists as writable. Install both tools on a runner with `sudo apt-get install -y --no-install-recommends imagemagick libavif-bin`, before the build step.
- Copies are published beside the original, as `/assets/img/responsive/power-640w.webp`, and kept in `.jekyll-cache/datalog-images`, so a later build reuses them. A site that sets `disable_disk_cache` keeps them in a temporary directory, removed when Jekyll exits.
- A copy that fails to encode is left out, with a warning, and the page does not offer it.
- An image keeps its markup when it already has a `srcset`, sits in a `<picture>` of its own, or sets `data-no-optimize="true"`.

##### Dark figures

A plot exported for a white page is a white rectangle on a dark one. Export the figure twice and the theme serves whichever suits the reader: put `power-dark.png` beside `power.png` and it becomes a `<source media="(prefers-color-scheme: dark)">` at the front of the same `<picture>`, with its own resized copies and modern formats. Nothing else changes. The `<img>` still points at the light file and keeps its alt text and its dimensions, so it is the same figure described once, and a browser that ignores the query shows the light version.

```yaml
theme_options:
  images:
    dark_suffix: "-dark"   # "" turns the convention off
```

`prefers-color-scheme` follows the operating system; this theme's toggle does not. `assets/js/core/dark-mode.js` closes that gap, overruling the query on those sources whenever a reader has chosen a mode for the site. With JavaScript off the figures follow the system, which is right for every reader who has not touched the toggle. The figure the browser first picked may be fetched before the script runs, so a reader whose choice disagrees with their system pays for one extra image on pages with figures.

A figure that does not follow the convention names its companion itself:

```liquid
{% figure id="fig-power" src="/assets/img/power.png" dark_src="/assets/img/power-night.png" alt="Power curve" %}
Power as a function of effect size.
{% endfigure %}
```

Any `<img data-dark-src="/assets/img/power-night.png">` is treated the same way, in a Markdown page or in a notebook's HTML. A companion the variant pipeline never reads, an SVG or an image on another host, is offered as the single file it is. A page's `hero_image` follows the convention too.

#### Critical CSS

With `critical_css.enabled: true`, a production build inlines the CSS each page needs to draw its first screen and loads `main.css` without blocking rendering. That CSS depends on your own pages and styles, so the theme ships none. Write your site's with:

```bash
bundle exec datalog critical-css
```

The command builds the site for production into a temporary directory, extracts the critical CSS of a page with the home layout, a post and one other page, and writes `_includes/critical-css/home.html`, `post.html` and `default.html` in your site, where they take the place of the theme's empty files. Run it again when your layouts or styles change; in CI, run it before `jekyll build`.

```yaml
critical_css:
  enabled: true
  dimensions:                # the viewports a page's first screen is measured in
    - { width: 1920, height: 1080 }
    - { width: 375, height: 667 }
  penthouse_options:
    timeout: 30000
  pages:                     # optional: which pages to extract from, as site paths
    default: /blog/
```

- The command runs the [critical](https://github.com/addyosmani/critical) npm package, which needs Node.js 22.13 or later and renders pages in headless Chrome that its install downloads. It uses `node_modules/.bin/critical` when your site has installed it (`npm install --save-dev critical@8`), and `npx --yes critical@8` otherwise. `--critical` names another command.
- Without `pages`, each file comes from the first page with that layout, nearest the site root; `default` skips pages kept out of search engines, such as the search page.
- Only `assets/css/main.css` is read, so the inlined CSS carries no Google Fonts rules.
- A production build warns when `critical_css.enabled` is true and one of the three files is empty.

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
      provider: giscus   # giscus, utterances, disqus, or api: the site's own backend
      repo: owner/repo
      repo_id: ""        # from https://giscus.app
      category: General
      category_id: ""
      mapping: pathname
      enabled_by_default: false
```

A page shows comments when its front matter sets `comments: true`, or on every page with `enabled_by_default: true`. `comments: false` turns them off for one page, and a `comments:` hash overrides these settings for that page. Giscus needs `repo`, `repo_id`, `category` and `category_id`; utterances needs `repo`; Disqus needs `shortname`. The `api` provider needs a backend, `dynamic_services.base_url` or its own `endpoint`, and is described in [components.md: Comments](components.md#comments), with the HTTP contract the backend implements.

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
