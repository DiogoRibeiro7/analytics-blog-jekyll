# Configuration Guide

Where the DataLog theme's settings live and how to change the common ones.

## Overview

| File | Purpose |
|------|---------|
| `_config.yml` | Everything the theme reads: site identity, features, `theme_options`, integrations, notebooks, plugin settings |
| `_data/config/author.yml` | The author profile used by the about and research pages (`site.data.config.author`) |
| `_data/navigation.yml`, `_data/social.yml`, `_data/i18n/*.yml` | Navigation menus, social and RSS links, translations |

`_config.yml` is organised in labelled sections (Jekyll core, site identity, features, theme customization, integrations, notebooks, plugins). Search for the banner comment of the section you need.

### Documentation guides

Use `layout: docs` for a guide that needs a section sidebar, an on-page contents list, and previous/next guide links. The sidebar reads optional `docs` groups from `_data/navigation.yml`:

```yaml
docs:
  - title: Start here
    links:
      - title: Installation
        url: /guides/installation/
      - title: Configuration
        url: /guides/configuration/
```

Links use Jekyll's `relative_url` for project sites. Guide pagination follows the order of links under `/guides/`; omit the `docs` groups when you do not use this layout. Set `features.search: true` to generate the search page and index, and `features.dark_mode_toggle: true` to expose the palette control.

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

Two settings decide how display equations look:

```yaml
theme_options:
  math:
    display_style: plain   # or card
    numbering: ams         # or all, none
```

- `display_style: plain`, the default, sets a display equation on its own line with space around it and nothing else. Its copy and edit tools appear at the end of the line when the pointer is over the equation or the keyboard focus is on it. `card` puts each equation in a framed panel with the tools always showing.
- `numbering: ams`, the default, numbers the equations a text can refer to: those in a numbered amsmath environment (`equation`, `align`, `gather`, `multline`, not the starred forms) and any `$$…$$` display with a `\label{}`. `all` numbers every display equation; `none` only those with a `\tag{}`.

Code needs no settings. Rouge highlights it when the site builds (`highlighter: rouge`), adding line numbers when `kramdown.syntax_highlighter_opts.block.line_numbers` is on, and pages load nothing for it. The theme used to load Prism in the browser as well. `theme_options.syntax_highlighting` no longer has an effect, and a build that still sets it prints a warning.

#### Homepage

Create `index.md` with `layout: home`. Its hero uses a dark gradient and needs
no image. Set one or both calls to action and list the feature cards in the
page's front matter:

```yaml
---
layout: home
hero_title: Research worth exploring
hero_tagline: Reproducible analysis, open data, and clear explanations.
hero_cta_label: Read the research
hero_cta_url: /blog/
hero_secondary_cta_label: Explore projects
hero_secondary_cta_url: /portfolio/
home_features_heading: What you can explore
home_features:
  - title: Research notes
    description: Methods, findings, and reproducible code.
    url: /blog/
  - title: Open datasets
    description: Provenance and documentation alongside the data.
    url: /datasets/
  - title: Projects
    description: Case studies and working demos.
    url: /portfolio/
---
```

Each action appears only when its URL is set. Each card needs a title; its
description and link are optional. Remove a card, or omit `home_features`
entirely, to hide it. Recent posts and featured portfolio entries appear
below the cards only when those collections have content. Use site-root paths
for local links so `baseurl` is applied.

To add a hero background image, set `hero_image` on the page. An optional
`hero_image_small` supplies a version around 640 px wide for phones. Only
configured hero images are preloaded; the gradient works without one.

#### Colour scheme

DataLog opens in its dark indigo/cyan palette. The header toggle lets each
visitor choose light or dark, and the choice persists across pages. To start a
site in light mode, or to follow the visitor's operating-system setting until
they use the toggle, set:

```yaml
theme_options:
  color_scheme:
    default: light  # or dark (the default), or system
```

The theme applies this initial palette before its script bundles load. A
visitor's saved choice always takes precedence. Theme colours are defined in
the Sass variables and CSS custom properties, so a site can also override
the palette in its own stylesheet without changing the gem.

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

`prefers-color-scheme` follows the operating system; the site's default and its toggle may not. `assets/js/core/dark-mode.js` closes that gap, selecting the companion that matches the effective page palette. Without JavaScript, image sources still follow the operating system; on a site whose default differs, the plot may not match the page until the scripts run. The browser may briefly fetch the other file first.

A figure that does not follow the convention names its companion itself:

```liquid
{% figure id="fig-power" src="/assets/img/power.png" dark_src="/assets/img/power-night.png" alt="Power curve" %}
Power as a function of effect size.
{% endfigure %}
```

Any `<img data-dark-src="/assets/img/power-night.png">` is treated the same way, in a Markdown page or in a notebook's HTML. A companion the variant pipeline never reads, an SVG or an image on another host, is offered as the single file it is. A page's `hero_image` follows the convention too.

#### Share cards

A link to a post shows a preview image wherever it is shared. Without one of its own, every post shows `social.default_image`, so a link to an article looks the same as a link to the about page. With share cards on, the build draws a 1200×630 PNG for each post that names no image. The card shows the post's title, its series or subtitle, its authors and date, and the site's name and logo, on the theme's colours. A research article also shows its venue and DOI.

```yaml
theme_options:
  social_cards:
    enabled: true               # off by default
    scheme: dark                # or light
    background: "#0b1d3d"       # over the scheme's background
    logo: /assets/img/logo.svg  # an SVG or an image; false for none; true or unset for the theme's mark
    template: _social/card.svg  # a template of the site's own
    collections: [posts]        # add "pages" for the site's pages
```

- **Tools:** the cards need ImageMagick, the same tool the image optimizer uses: `magick`, or `convert` outside Windows. Nothing else is needed. The card's text is set in IBM Plex, which ships with the gem, and drawn as outlines, so no font has to be installed. On a runner, install ImageMagick before the build step with `sudo apt-get install -y --no-install-recommends imagemagick`. Without ImageMagick, the build warns once and every page keeps `social.default_image`. No page points at a card that was not drawn.
- **Which image a page gets:** `og_image` or `image` in front matter always wins, then the card, then `social.default_image`. A blank `image:` counts as none. `social_card: false` in front matter asks for no card. A page with a card also gets `og:image:width`, `og:image:height`, `og:image:alt` (its title) and `twitter:image:alt`, and its JSON-LD `image` is the card.
- **Maths in titles:** TeX in a title becomes readable text: `$\alpha$-stable laws for $X_t^2$` reads "α-stable laws for X_t²". A long title wraps and shrinks to fit. A 140-character title fits whole; past four lines at the smallest size, it ends in an ellipsis.
- **Caching:** cards are published as `/assets/social/<page>-<hash>.png` and kept in `.jekyll-cache/datalog-social-cards`. The cache is keyed by everything drawn on the card, including the content of its logo and of any image the template shows, so a later build draws only the cards whose pages changed. A changed card gets a new address, so sites that cached the old preview fetch the new one. A site that sets `disable_disk_cache` keeps the cards in a temporary directory, removed when Jekyll exits.
- **Colours:** both schemes keep every text colour at 4.5:1 or more against their background (WCAG AA). A `background` of your own is checked too, and the build warns when a text colour falls below 4.5:1 on it.

A template of your own is an SVG file inside the site. It may use `rect`, `circle`, `ellipse`, `line`, `polyline`, `polygon`, `path`, `image` (a file in the site) and `g`, with fills, strokes, opacity and transforms. Fills, strokes and opacity set on the `<svg>` itself reach every element in it; a transform there is not applied, so put it on a `g`. Gradients, filters and masks are not drawn, and the build names any element it skipped. ImageMagick reads no SVG on a minimal install, so the build draws the template itself. Text goes in slots: an empty `<text>` with `data-field` set to `site`, `kicker` (the series or subtitle), `title`, `byline` or `detail`. The slot's `y` is the top of its box. `<rect data-field="logo">` is where the logo goes. `{{background}}`, `{{ink}}`, `{{muted}}` and `{{accent}}` are the scheme's colours. Copy [the default template](../lib/datalog/social_cards/template.svg) to start:

```xml
<text data-field="title" x="80" y="236" width="1040" height="262"
      font-size="66" data-min-font-size="40" data-max-lines="4"
      data-line-height="1.15" data-font="serif" fill="{{ink}}"/>
```

`data-font` is `serif` (IBM Plex Serif SemiBold) or `sans` (IBM Plex Sans). Both fonts are under the SIL Open Font License, which ships beside them.

#### Search results

A result is a page, and under it the sections of that page the query was found in — at most three, each a link to the heading itself rather than to the top of the article. A reader who searches for a term buried in a long methods post lands on the paragraph instead of starting again with Ctrl+F.

The sections come from the page's own headings. `_plugins/search_sections.rb` splits each document at its `h2` and `h3` when `search.json` is built, and takes the anchor from the id kramdown already gave the heading — the same id the contents list links to. Nothing to configure and nothing to write in front matter:

- A page with no headings indexes as one section, which is what every page did before.
- The text before the first heading belongs to the page, not to a section of it, so it is never offered as one.
- A heading with no id still indexes; its section links to the page.
- The split runs over the document's own content, so the headings a layout puts around an article — "About this post", "Reading notes" — are not sections of every result.
- `exclude_from_search: true` keeps a page out of the index entirely, sections and all.

The index repeats each page's text under its headings, which is smaller than it sounds: on the demo site it takes `search.json` from 147 KB to 224 KB uncompressed, but from 32 KB to 39 KB served compressed, because the repeat is exactly what a compressor is good at. `tests/test_search_sections.rb` holds the index to a budget per indexed page so it cannot drift.

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
