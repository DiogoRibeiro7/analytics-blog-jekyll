---
layout: doc
title: Configuration Reference
nav_order: 3
---

# Configuration Reference

This guide documents the configuration keys validated by the automated configuration checker. The table lists every key it checks; the sections after it describe some of them in more detail. A build stops on a missing required key, or on a key with the wrong type or value, and each error links here.

## Keys the validator checks

| Key | Type | Allowed values |
| --- | --- | --- |
| `title` | String, required | Any |
| `url` | String, required | An HTTP or HTTPS URL, or `""` |
| `author` | String or map, required | A name, or a map with `name` |
| `author.name` | String, required when `author` is a map | Any |
| `author.email` | String | An email address |
| `markdown` | String | `kramdown`, `commonmark` |
| `highlighter` | String | `rouge`, `pygments` |
| `permalink` | String | Any |
| `paginate` | Integer | Any |
| `timezone` | String | Any |
| `collections` | Map | Any |
| `plugins` | List | Any |
| `features` | Map | Any |
| `features.mathjax` | Boolean | `true`, `false` |
| `features.search` | Boolean | `true`, `false` |
| `features.dark_mode_toggle` | Boolean | `true`, `false` |
| `features.notebook_support` | Boolean | `true`, `false` |
| `features.portfolio` | Boolean | `true`, `false` |
| `features.datasets` | Boolean | `true`, `false` |
| `notebooks` | Map | Any |
| `notebooks.enabled` | Boolean | `true`, `false` |
| `notebooks.source` | String | Any |
| `notebooks.output_dir` | String | Any |
| `seo` | Map | Any |
| `seo.type` | String | Any |
| `seo.name` | String | Any |
| `sass` | Map | Any |
| `sass.style` | String | `compressed`, `expanded` |
| `theme_options` | Map | Any |
| `theme_options.math` | Map | Any |
| `theme_options.math.engine` | String | `mathjax`, `katex` |
| `theme_options.math.enabled` | Boolean | `true`, `false`; deprecated, with no effect |

## Global Settings

### title
- **Required:** Yes
- **Type:** String
- **Description:** The public-facing name of your site. Appears in the `<title>` tag and structured data.
- **Example:**
  ```yaml
  title: DataLog | Data Science & Research Theme
  ```

### url
- **Required:** Yes
- **Type:** String (valid HTTP or HTTPS URL)
- **Description:** Canonical base URL for the site. Used for sitemap, feed, and structured data generation.
- **Example:**
  ```yaml
  url: "https://datalog-theme.example.com"
  ```

## Author Profile

### author
- **Required:** Yes
- **Type:** Map
- **Description:** Contact and attribution metadata for the primary author.

#### author.name
- **Required:** Yes
- **Type:** String
- **Description:** Display name for attribution blocks, SEO markup, and article headers.
- **Example:**
  ```yaml
  author:
    name: Diogo Ribeiro
  ```

#### author.email
- **Required:** No
- **Type:** String (valid email address)
- **Description:** Optional email address for contact links and structured data.
- **Example:**
  ```yaml
  author:
    email: author@example.com
  ```

## Theme Options

### theme_options
- **Required:** No
- **Type:** Map
- **Description:** Container for theme-specific configuration such as math rendering, typography, and component toggles.

#### theme_options.math
- **Required:** No
- **Type:** Map
- **Description:** Math rendering configuration.

##### theme_options.math.engine
- **Required:** No
- **Type:** String (enum: `mathjax`, `katex`)
- **Description:** Selects the math rendering engine. Invalid values trigger a configuration error with suggestions.
- **Example:**
  ```yaml
  theme_options:
    math:
      engine: mathjax
  ```

## Deprecations

The validator also inspects configuration keys that have moved, been renamed or stopped having an effect, and provides non-blocking warnings, migrating values automatically where it can.

### math_engine (deprecated)
- **Status:** Deprecated
- **Replacement:** `theme_options.math.engine`
- **Migration:** Automatically copied to the new key when not already set.
- **Action:** Remove the deprecated key after verifying the migrated value in `_config.yml`.

### theme_options.math.enabled (deprecated)
- **Status:** Deprecated. Nothing reads it, so it has no effect.
- **Replacement:** `theme_options.math.render_on_load` (`auto`, `true` or `false`) decides which pages load the math engine, and a page's `math` front matter overrides it.
- **Action:** Remove the key.

## Troubleshooting

When the configuration validator encounters invalid or missing values, it raises a build error with the following details:

- The configuration path where the issue occurred (e.g., `theme_options → math → engine`).
- The expected type, value range, or format.
- The value that was received.
- Suggested corrections for common typos.
- A link back to this document for quick reference.

Fix the reported configuration and rerun `jekyll build` (or your CI workflow) to continue. The configuration is checked on a site's first build: `jekyll serve` does not read `_config.yml` again when files change, so restart it after editing the configuration.
