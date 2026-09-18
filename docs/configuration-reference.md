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
| `publisher` | Map | Any |
| `publisher.type` | String | `Person`, `Organization` |
| `publisher.name` | String | Any |
| `publisher.url` | String | A URL, or a path on the site |
| `publisher.logo` | String | A URL, or a path on the site |
| `content_license` | String or map | An SPDX identifier such as `CC-BY-4.0`, or a map with the keys below |
| `content_license.id` | String | An SPDX identifier |
| `content_license.name` | String | Any |
| `content_license.url` | String | A URL |
| `content_license.holder` | String or list | A name, or a list of names |
| `content_license.year` | Integer or string | A year |
| `code_license` | String or map | An SPDX identifier such as `MIT`, or a map with the keys below |
| `code_license.id` | String | An SPDX identifier |
| `code_license.name` | String | Any |
| `code_license.url` | String | A URL |
| `code_license.holder` | String or list | A name, or a list of names |
| `code_license.year` | Integer or string | A year |
| `scholarly` | Boolean, list or string | `true` for every post, or the collections and layouts that get scholarly metadata |
| `dynamic_services` | Map | Any; a key naming a secret stops the build |
| `dynamic_services.base_url` | String | An HTTP or HTTPS URL, or `""` |
| `dynamic_services.api_version` | String or integer | `v1`, `1`, … |
| `dynamic_services.timeout_ms` | Integer | Any |
| `dynamic_services.credentials` | String | `omit`, `same-origin`, `include` |
| `dynamic_services.features` | Map | Feature name to `true` or `false` |
| `dynamic_services.paths` | Map | Feature name to its path under the versioned base |
| `dynamic_services.csrf_header` | String | Any |
| `dynamic_services.csrf_cookie` | String | Any |
| `corrections` | Map | Any |
| `corrections.enabled` | Boolean | `true` (default), `false` |
| `corrections.categories` | List | The report categories, in order |
| `contact` | Map | Any |
| `contact.enabled` | Boolean | `true` (default), `false` |
| `contact.categories` | List | The message categories, in order |
| `contact.prompts` | Map | Category to prompt |
| `contact.privacy_notice` | String | Any |
| `contact.retention` | String | Any |
| `reactions` | Map | Any |
| `reactions.enabled` | Boolean | `true` (default), `false` |
| `reactions.counts` | Boolean | `true` (default), `false` |
| `reactions.types` | List | The reactions, in order |
| `webmentions` | Map | Any |
| `webmentions.enabled` | Boolean | `true` (default), `false` |
| `webmentions.endpoint` | String | The receiver's URL, or `""` |
| `webmentions.types` | List | `mention`, `reply`, `repost`, `like` |
| `subscriptions` | Map | Any |
| `subscriptions.enabled` | Boolean | `true` (default), `false` |
| `subscriptions.double_opt_in` | Boolean | `true` (default), `false` |
| `subscriptions.placement` | List | `footer` (default), `post` |
| `subscriptions.topics` | List | The topics a reader can pick, in order |
| `subscriptions.privacy_url` | String | A path on the site, or a URL |
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
| `theme_options.reading_mode` | Map | Any |
| `theme_options.reading_mode.enabled` | Boolean | `true` (default), `false` |
| `theme_options.reading_mode.remember` | Boolean | `true`, `false` (default) |
| `theme_options.reading_state` | Map | Any |
| `theme_options.reading_state.enabled` | Boolean | `true` (default), `false` |
| `theme_options.reading_state.bookmarks` | Boolean | `true` (default), `false` |
| `theme_options.reading_state.progress` | Boolean | `true` (default), `false` |
| `theme_options.reading_state.highlights` | Boolean | `true` (default), `false` |
| `theme_options.reading_state.list_url` | String | The path of the page that lists the saved articles |

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

## Publisher

### publisher
- **Required:** No
- **Type:** Map
- **Description:** Who publishes the site, as named in each page's JSON-LD `publisher`, a post's microdata, and citation exports. Without it, the author publishes the site as a `Person` (or, with no author name, the site title as an `Organization`), which suits a personal site. An institutional publication sets `type: Organization`. `author.affiliation` is the author's, not the publisher's: structured data lists it as the author's `affiliation`.
- **Keys:**
  - `type`: `Person` (default) or `Organization`.
  - `name`: defaults to `author.name` for a `Person`, and to `title` for an `Organization`.
  - `url`: defaults to `url`. A path such as `/lab/` is made absolute.
  - `logo`: an `Organization`'s logo, a URL or a path on the site. Defaults to the theme's 512px icon. A `Person` has no logo.
- **Citations:** BibTeX, RIS and EndNote exports and the citation line name `publisher.name` when it is set, and otherwise the site `title`.
- **Examples:**
  ```yaml
  # A personal site
  publisher:
    type: Person
    name: Diogo Ribeiro
    url: https://example.org
  ```
  ```yaml
  # An institutional publication
  publisher:
    type: Organization
    name: Example Lab
    url: https://example.org/lab
    logo: /assets/img/lab-logo.png
  ```

## Licences

### content_license
- **Required:** No
- **Type:** String or map
- **Description:** The licence of every article's text and figures, shown in the reuse notice before "How to cite", linked with `rel="license"`, in the page's `<link rel="license">` and in the JSON-LD `license`, `copyrightYear` and `copyrightHolder`. A page replaces it with `license:` in front matter, or declines it with `license: false`. Datasets and packages never take it: their `license` is their own. The repository's `LICENSE` covers the theme's software, not what a site publishes.
- **Values:** an SPDX identifier the theme knows (`CC-BY-4.0`, `CC-BY-SA-4.0`, `CC-BY-ND-4.0`, `CC-BY-NC-4.0`, `CC-BY-NC-SA-4.0`, `CC-BY-NC-ND-4.0`, `CC0-1.0`, `MIT`, `Apache-2.0`, `BSD-2-Clause`, `BSD-3-Clause`, `GPL-3.0-only`, `GPL-3.0-or-later`, `LGPL-3.0-only`, `AGPL-3.0-only`, `MPL-2.0`, `ISC`, `Unlicense`, `all-rights-reserved`; spelling and case are free, `CC BY` alone means 4.0), or a map:
  - `name` and `url`: a licence the theme does not know. A `name` that is an identifier fills in the rest.
  - `holder`: the copyright holder, a name or a list. Defaults to the page's authors.
  - `year`: the copyright year. Defaults to the year of the page's date.
- **Examples:**
  ```yaml
  content_license: CC-BY-4.0
  ```
  ```yaml
  content_license:
    id: CC-BY-4.0
    holder: Example Lab
  ```

### code_license
- **Required:** No
- **Type:** String or map
- **Description:** The licence of the code samples in every article, when it differs from the text's: "Code samples under MIT." A page replaces it with `code_license:` in front matter, or declines it with `code_license: false`. It takes the same values as `content_license`.
- **Example:**
  ```yaml
  code_license: MIT
  ```

## Dynamic Services

### dynamic_services
- **Required:** No
- **Type:** Map
- **Description:** The optional backend the browser calls for correction reports, the contact form and the other dynamic features, as [dynamic-services.md](dynamic-services.md) describes. The site stays static. These settings are inlined into every page for the browser, so they hold no credential: a key under `dynamic_services` whose name contains `secret`, `token`, `password`, `api_key` or `private_key` stops the build. An empty or absent `base_url` turns every dynamic feature off.
- **Keys:**
  - `base_url`: the service's address; its origin is allowed in the Content Security Policy's `connect-src`.
  - `api_version`: the version segment of every path (`v1`) and the version the service must report in `GET /v1/capabilities`.
  - `timeout_ms`: how long the browser waits for an answer (default 8000).
  - `credentials`: `omit` (default), `same-origin` or `include`, for a service that authenticates with cookies.
  - `features`: feature name to `true` or `false`; a feature off here is off whatever the service offers.
  - `paths`: a feature's path under the versioned base when it is not `/<feature>`.
  - `csrf_header` and `csrf_cookie`: for cookie-authenticated writes, the cookie whose value is sent in that header.
- **Example:**
  ```yaml
  dynamic_services:
    base_url: https://api.example.org
    api_version: v1
    timeout_ms: 8000
    credentials: omit
    features:
      corrections: true
      contact: true
  ```

### corrections
- **Required:** No
- **Type:** Map
- **Description:** The correction-report form under every post, on a site whose dynamic services offer the `corrections` feature ([components.md: Correction Reports](components.md#correction-reports)). `enabled: false` removes it; `categories` lists the kinds of problem a reader can pick, in order, with their labels under `corrections.categories` in `_data/i18n`. A post opts out with `corrections: false` in its front matter.
- **Example:**
  ```yaml
  corrections:
    enabled: true
    categories: [mathematical-error, factual-error, citation, code, reproducibility, typo, accessibility, other]
  ```

### contact
- **Required:** No
- **Type:** Map
- **Description:** The contact and collaboration form on a page with `contact_form: true` ([components.md: Contact Form](components.md#contact-form)), on a site whose dynamic services offer the `contact` feature; without them the page shows `contact_email` instead. `enabled: false` removes both. `categories` lists the kinds of message, in order, with labels under `contact.categories` and optional prompts under `contact.prompts` in `_data/i18n`; `prompts` overrides a prompt per category; `privacy_notice` replaces the notice under the fields and `retention` is appended to it.
- **Example:**
  ```yaml
  contact:
    enabled: true
    categories: [research-collaboration, consulting, speaking, mentoring, reproducibility, media, other]
    prompts:
      consulting: Say the scope, the budget range and when you need it.
    retention: Messages are deleted after a year.
  ```

### reactions
- **Required:** No
- **Type:** Map
- **Description:** "Was this useful?" under every post, on a site whose dynamic services offer the `reactions` feature ([components.md: Reactions](components.md#reactions)). `enabled: false` removes it; `counts: false` hides the service's counts so readers see only their own choice; `types` lists the reactions, in order, with labels under `reactions.types` in `_data/i18n`. A post opts out with `reactions: false` in its front matter.
- **Example:**
  ```yaml
  reactions:
    enabled: true
    counts: true
    types: [useful, clear, interesting, needs-clarification]
  ```

### webmentions
- **Required:** No
- **Type:** Map
- **Description:** Webmention support ([components.md: Webmentions](components.md#webmentions)). `endpoint` is the receiver advertised in every page's head as `<link rel="webmention">`; empty, nothing is advertised. On a site whose dynamic services offer the `webmentions` feature, posts carry a "Mentioned elsewhere" section listing the verified mentions of the kinds in `types` (`mention` and `reply` by default; `repost` and `like` are opt-in). `enabled: false` removes both; a post opts out of the section with `webmentions: false`.
- **Example:**
  ```yaml
  webmentions:
    enabled: true
    endpoint: https://mentions.example.org/webmention
    types: [mention, reply]
  ```

### subscriptions
- **Required:** No
- **Type:** Map
- **Description:** The newsletter subscribe form and the page its emails link to ([components.md: Newsletter Subscriptions](components.md#newsletter-subscriptions)), on a site whose dynamic services offer the `subscriptions` feature; without them no form renders. `placement` puts the form in the `footer` (the default), at the end of every `post`, or both; `topics` lists what a reader can choose to receive, with labels under `subscriptions.topics` in `_data/i18n`; `double_opt_in` sets the consent wording and how an answer without a status is read; `privacy_url` is linked from the consent line. `enabled: false` removes the form everywhere.
- **Example:**
  ```yaml
  subscriptions:
    enabled: true
    double_opt_in: true
    placement: [footer, post]
    topics: [new-articles, research-notes, datasets]
    privacy_url: /privacy/
  ```

## Scholarly Metadata

### scholarly
- **Required:** No
- **Type:** Boolean, list or string
- **Description:** Which pages carry scholarly discovery metadata: the Highwire meta tags (`citation_title`, `citation_author`, `citation_publication_date`, `citation_doi`, `citation_pdf_url` and the rest) that Google Scholar and reference managers read, and their Dublin Core equivalents. A page with the `research` layout, or in a `research` collection, always has them unless its front matter says `scholarly: false`; any other page has them with `scholarly: true` in its front matter. This setting widens the default: `true` covers every post as well, and a list names the collections or layouts to cover, such as `[notebooks]`. See [google-scholar-setup.md: Scholarly Metadata on Articles](google-scholar-setup.md#scholarly-metadata-on-articles) for the tags and the front matter they read.
- **Examples:**
  ```yaml
  scholarly: true
  ```
  ```yaml
  scholarly: [posts, notebooks]
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

#### theme_options.reading_mode
- **Required:** No
- **Type:** Map
- **Description:** The "Reading mode" control on posts, which hides the site's navigation and the panels around the article and leaves the article, its metadata and its table of contents. `enabled: false` removes the control. `remember: true` keeps a reader's choice in the browser (`localStorage`) from one post to the next; by default the mode lasts for the page. See [components.md: Reading Mode and Print](components.md#reading-mode-and-print).
- **Example:**
  ```yaml
  theme_options:
    reading_mode:
      enabled: true
      remember: false
  ```

#### theme_options.reading_state
- **Required:** No
- **Type:** Map
- **Description:** Bookmarks, reading progress and private highlights on posts, kept in the reader's browser (`localStorage`) and never sent anywhere. `enabled: false` turns the whole layer off; `bookmarks`, `progress` and `highlights` turn each part off on its own; `list_url` names the page that lists the saved articles (one that includes `components/reading-list.html`), so posts link to it. See [components.md: Bookmarks, Progress and Private Highlights](components.md#bookmarks-progress-and-private-highlights).
- **Example:**
  ```yaml
  theme_options:
    reading_state:
      enabled: true
      bookmarks: true
      progress: true
      highlights: true
      list_url: /saved/
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
