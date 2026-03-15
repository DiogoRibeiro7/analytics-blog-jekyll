---
layout: doc
title: Configuration Reference
nav_order: 3
---

# Configuration Reference

This guide documents the configuration keys validated by the automated configuration checker. Each section lists whether the field is required, the expected data type, and any additional validation rules such as allowed values or format requirements.

## Global Settings

### title {#title}
- **Required:** Yes
- **Type:** String
- **Description:** The public-facing name of your site. Appears in the `<title>` tag and structured data.
- **Example:**
  ```yaml
  title: DataLog | Data Science & Research Theme
  ```

### url {#url}
- **Required:** Yes
- **Type:** String (valid HTTP or HTTPS URL)
- **Description:** Canonical base URL for the site. Used for sitemap, feed, and structured data generation.
- **Example:**
  ```yaml
  url: "https://datalog-theme.example.com"
  ```

## Author Profile

### author {#author}
- **Required:** Yes
- **Type:** Map
- **Description:** Contact and attribution metadata for the primary author.

#### author.name {#author-name}
- **Required:** Yes
- **Type:** String
- **Description:** Display name for attribution blocks, SEO markup, and article headers.
- **Example:**
  ```yaml
  author:
    name: Diogo Ribeiro
  ```

#### author.email {#author-email}
- **Required:** No
- **Type:** String (valid email address)
- **Description:** Optional email address for contact links and structured data.
- **Example:**
  ```yaml
  author:
    email: author@example.com
  ```

## Theme Options

### theme_options {#theme-options}
- **Required:** No
- **Type:** Map
- **Description:** Container for theme-specific configuration such as math rendering, typography, and component toggles.

#### theme_options.math {#theme-options-math}
- **Required:** No
- **Type:** Map
- **Description:** Math rendering configuration.

##### theme_options.math.engine {#theme-options-math-engine}
- **Required:** No
- **Type:** String (enum: `mathjax`, `katex`)
- **Description:** Selects the math rendering engine. Invalid values trigger a configuration error with suggestions.
- **Example:**
  ```yaml
  theme_options:
    math:
      engine: mathjax
  ```

##### theme_options.math.enabled {#theme-options-math-enabled}
- **Required:** No
- **Type:** Boolean
- **Description:** Explicitly toggle math rendering support regardless of engine selection.
- **Example:**
  ```yaml
  theme_options:
    math:
      enabled: true
  ```

## Deprecations

The validator also inspects configuration keys that have moved or been renamed and provides non-blocking warnings when it can migrate values automatically.

### math_engine (deprecated) {#math-engine}
- **Status:** Deprecated
- **Replacement:** `theme_options.math.engine`
- **Migration:** Automatically copied to the new key when not already set.
- **Action:** Remove the deprecated key after verifying the migrated value in `_config.yml`.

## Troubleshooting

When the configuration validator encounters invalid or missing values, it raises a build error with the following details:

- The configuration path where the issue occurred (e.g., `theme_options → math → engine`).
- The expected type, value range, or format.
- The value that was received.
- Suggested corrections for common typos.
- A link back to this document for quick reference.

Fix the reported configuration and rerun `jekyll build` (or your CI workflow) to continue.
