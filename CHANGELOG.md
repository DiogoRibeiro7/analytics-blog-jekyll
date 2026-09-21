# Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Put the site's `baseurl` in front of every bundle in the script manifest the loader reads, and in the 404 page's search form, so a site served from a subdirectory runs its JavaScript instead of importing paths at the domain root (#328).
- Read MathJax's expressions as a list that can be iterated, so equation numbering, the copy and edit tools, the reference map and the `role="math"` labels reach a typeset page at all. Leave the number to MathJax where it numbers, rather than drawing a second one beside it, and keep the tools out of the element that carries the maths role (#329).
- Name a scaffolded post after its title, accents and all: `datalog new post` now slugifies the way Jekyll does, so "Análise de Séries Temporais" becomes `analise-de-series-temporais` rather than `an-lise-de-s-ries-temporais`, a title in a script no transliteration covers keeps its own characters, and a title the console tagged as something other than UTF-8 no longer raises (#333).
- Stop `datalog update` where `npm install` fails, instead of reporting that the theme's dependencies are up to date (#333).

## [0.9.2] - 2026-09-20

### Fixed

- Keep newly posted comments visible when an older thread read finishes, and refresh moderation reads that overlap completed actions without losing their filters or pagination.
- Retry subscription preference saves with the edited topics, clearing retry handlers left by earlier loading failures.
- Preserve indented code blocks during math preprocessing, distinguish them from indented prose, and accept longer closing code fences so following math is still detected.
- Percent-encode generated image paths once in the responsive manifest so filenames containing spaces produce valid image candidates in Markdown and responsive-image includes.

## [0.9.1] - 2026-09-20

Planned patch release: **0.9.1**. This release contains bug fixes only.

### Fixed

- Keep numbered figure, table and statement references unchanged when posts are embedded in feeds or listings. Parse escaped attribute quotes completely and fail malformed tags with the page and tag name (#298, #299).
- Keep editorial asides in the article flow, preserve image proportions at narrow widths, contain wide tables and equations, and restore spacing beside Rouge line numbers (#300, #301, #319, #321).
- Use `TechArticle` structured data, respect layout schema types, preserve comparison operators in titles and descriptions, escape script-sensitive JSON, and include `baseurl` in publisher, author and breadcrumb URLs (#302, #303, #313).
- Preserve idempotency keys across retries of unchanged submissions and recover contact, correction and subscription forms after temporary capability failures (#304, #305).
- Retain subscription management retries and distinguish service failures from expired links. Prevent stale reaction and moderation reads from overwriting newer state, respect moderation-specific endpoints, show retry timing and body request IDs, and sort timestamps by instant (#306).
- Capture correction quotes before pointer interaction clears the selection, and clear them after successful submission (#307).
- Offer reading resume above the article, preserve the saved position until resumed or dismissed, flush pending progress when leaving, and keep erased data erased. Restore highlights after math and visualization rendering and avoid ambiguous matches in other sections (#308, #309).
- Correct macOS highlight shortcuts and Escape handling, report storage failures while keeping erase available, merge and sanitize imports, honor disabled reading lists, and keep fallback marks out of table/list whitespace and SVG (#310).
- Produce complete BibTeX, RIS and EndNote records with format-specific types and escaped BibTeX fields. Share the exporter with research pages, preserve semicolon-separated author names, and support organization authors (#311).
- Supply missing notebook labels in English, Spanish and Portuguese and validate literal translation keys (#312).
- Validate author and licence shapes, resolve author names and profile handles, inherit partial licence settings, preserve year ranges, normalize repository and DOI links, prevent image variant collisions, handle encoded image paths, and propagate `updated` to feeds and sitemaps (#313).
- Preserve visualization fallback tables and live content in print and hide code line-number gutters (#314).
- Default omitted math loading settings to automatic detection and preserve inline parenthesis and double-dollar TeX through Markdown conversion, and leave empty delimiters literal (#315, #316, #320).
- Render tag and category links only when their archive page exists, removing broken links without adding archive features (#293).

## [0.9.0] - 2026-09-18

### Added

- The build warns when front matter `defaults` set `math: true` or `mathjax: true` while `theme_options.math.render_on_load` is `auto`, since every page in their scope then loads the math engine, with math or without. It also warns that `theme_options.math.enabled` has no effect: nothing reads it, though the user guide's troubleshooting table told readers to check it (#234).
- `publisher` in `_config.yml` names who publishes the site, as a `Person` or an `Organization`, with a `name`, `url` and, for an organization, `logo`. Each page's JSON-LD, a post's microdata and the citation exports use it. `docs/configuration-reference.md` describes the defaults (#240).
- A JPEG or PNG image on a page, a Markdown image included, is offered its AVIF and WebP copies in a `<picture>`, with its resized copies as the `srcset` of its `<img>`. Only the `responsive-image.html` include rendered a `<picture>` before, so Markdown images never got one. An image that has its own `srcset`, sits in a `<picture>` or sets `data-no-optimize` keeps its markup, and `theme_options.images.variants: false` turns the copies off. The configuration guide lists the tools to install (#243).
- A site can keep the theme in a Git submodule and use it as its theme: `gem "datalog-theme", path: "vendor/datalog"` and `theme: datalog-theme`, with nothing copied into the site. `docs/install.md` covers the setup, updates, the CI steps, and moving from a site that pointed `layouts_dir`, `includes_dir`, `plugins_dir` and `sass.sass_dir` into the submodule and copied the theme's assets and data in (#241).
- The build stops when a theme checkout's script bundles were not built from the sources beside them, or were never built, and names the command that builds them. `npm run build:js` records a SHA-256 of every file it builds from in `assets/js/dist/sources.json` (#241).
- The build stops when a site has its own copy of a file in `assets/js/dist`, of `assets/js/loader.js`, `_data/js_manifest.json` or `_data/cdn-integrity.yml` that differs from the theme's. The site's copy takes the place of the theme's file, so it would load scripts from another version of the theme (#241).
- The build warns when `layouts_dir`, `includes_dir`, `plugins_dir` or `sass.sass_dir` point into a copy of the theme, a setup that cannot read the theme's assets and data (#241).
- `bundle exec datalog critical-css` writes a site's critical CSS. It builds the site for production, extracts the CSS a page with the home layout, a post and one other page need for their first screen with the `critical` npm package, and writes `_includes/critical-css/home.html`, `post.html` and `default.html` in the site. A site installed from the gem had only the theme's empty files, so `critical_css.enabled` changed nothing there. The demo's deploy and Lighthouse runs use the same command through `npm run build:critical`, which ran `scripts/extract_critical_css.js` before. The configuration guide describes the settings and what to install (#238).
- A production build warns when `critical_css.enabled` is true and a critical CSS file is empty (#238).
- A page can name several authors, as `authors:` (names, `_data/authors.yml` keys or maps with `name`, `affiliation`, `orcid` and `url`), and its contributors with their roles, as `contributors:`. The byline, the author cards, the JSON-LD, the `citation_author` meta tags and the BibTeX, RIS and EndNote exports all read the same list, from the new `page_authors` and `page_contributors` filters. The JSON-LD `author` becomes a list for several authors, and `contributor` lists the contributors. Several authors get compact cards; `author_cards: detailed` gives each a full card, and `false` none. Each `citation_author` tag is followed by that author's `citation_author_institution` and `citation_author_orcid`. `author:` still names a single author. `docs/components.md` has a collaborative article example (#252).
- Numbered figures and tables, with references to them: `{% figure id="fig-power" src="..." alt="..." %}` and `{% table id="tab-runs" %}` take their caption, with Markdown and math, from their body, and `{% ref fig-power %}` becomes a link reading "Figure 1". Numbers follow each page's order, so a reference can come before its target and reordering renumbers every reference; in a post's excerpt it links to the post's page. A reference to an id no figure or table has, or two with the same id, stops the build. The words come from `references.figure` and `references.table` in `_data/i18n`, and in print a numbered figure or table is kept on one page. The user guide has a worked example with an equation, a figure and a table (#250).
- Theorems, lemmas, propositions, corollaries, definitions, assumptions, examples and remarks, as `{% theorem id="thm-wlln" title="Weak law of large numbers" %}` and the like, and proofs, as `{% proof for="thm-wlln" %}`. Articles wrote them as a blockquote with a bold "Theorem 1." typed by hand, which nothing numbered, linked or checked. Each kind is numbered on its own in page order and `{% ref thm-wlln %}` reads "Theorem 1", with the ids and build errors of figures and tables; `label="A"` names a statement "Theorem A" in place of a number. A proof's heading reads "Proof of Theorem 1", linked to the theorem, and it ends with ∎ unless `qed="false"`. Bodies keep their Markdown, math and code. Statements and proofs are groups named by their heading, and the words come from `_data/i18n`. The user guide has a short article as an example (#249).
- A revision history for articles: `revisions:` in front matter lists what changed since publication, each entry with a `date`, a `type` (`correction`, `update`, `review` or `editorial`), a `summary` and an optional `details_url`. The newest correction or update is announced under the post's metadata, with a link to the full history after the body, which ends with the publication date; `revision_notice: false` turns the notice off. The newest revision that changed the article sets `last_modified_at` when it is later than the page's own, so the JSON-LD `dateModified`, the microdata, the feed and the sitemap carry it, and each correction is a schema.org `CorrectionComment`. The post's metadata now shows "Updated" when the article changed on another day than it was published. A malformed date, a missing summary or an unknown type stops the build and names the page. `docs/components.md` explains which date is which, from `date` to `reviewed_at` (#245).
- A licence for an article's text and figures, and one for its code samples. `content_license: CC-BY-4.0` in `_config.yml` is the default for every article; `license:` in front matter replaces it, with an SPDX identifier (the Creative Commons family, `CC0-1.0`, `MIT`, `Apache-2.0`, the BSD and GPL families, `MPL-2.0`, `ISC`, `Unlicense`, `all-rights-reserved`), a map with `name`, `url`, `holder` and `year` for any other licence, or `false` to decline. `code_license` names the code samples' terms the same way. A post shows the notice before "How to cite": "© 2024 Diogo Ribeiro. Text and figures under CC BY 4.0. Code samples under MIT.", each licence a `rel="license"` link that keeps its address in print. The head carries `<link rel="license">`, and the JSON-LD `license`, `copyrightYear` and `copyrightHolder`. A dataset's header and a research article's "Rights" row link the licence the same way; datasets and packages carry their own `license` and never take the site's default. `docs/components.md` explains the difference between the repository's licence and an article's (#251).
- Scholarly discovery metadata for research articles: the Highwire meta tags Google Scholar and reference managers read, and their Dublin Core equivalents, from `_includes/meta/scholarly.html`. Besides the `citation_title`, `citation_author` (with each author's institution and ORCID), `citation_publication_date`, `citation_doi`, `citation_journal_title` and `citation_conference_title` the head already carried, a page gets `citation_public_url` and `citation_fulltext_html_url`, `citation_pdf_url` from `pdf_url` (or `citation_pdf`), `citation_volume`, `citation_issue`, `citation_firstpage` and `citation_lastpage`, `citation_issn`, `citation_isbn`, `citation_publisher`, `citation_language` and `citation_keywords`, and `DC.title`, `DC.creator`, `DC.date`, `DC.identifier` (the DOI, else the URL), `DC.type`, `DC.language`, `DC.publisher`, `DC.rights` (the licence) and `DC.description`. A field the page lacks leaves its tag out. The authors are the page's, as in the byline, the JSON-LD and the citation exports. `docs/google-scholar-setup.md` lists the tags and the front matter they read (#247).
- Article series: `series: {id: missing-data, order: 3}` in front matter (or `series: missing-data` with `series_order: 3`) makes a post part of a series, whose title and description live once in `_data/series.yml` (or on a part as `title`). The post shows the series at the top, with "Part 3 of 4", a progress bar, every part in order with the current one marked `aria-current`, and the previous and next parts, and again the previous and next parts at the end; both are `<nav>` landmarks apart from the chronological previous/next pagination. Parts are ordered by `order`, whatever was published between them; a part without a whole-number order, or two parts with the same order, stops the build and names the posts. `docs/components.md` has a complete three-part example (#244).
- A "Reproduce this analysis" panel: `reproducibility:` in front matter names the `code` (with the commit, tag or branch as `ref`), `data` (with `version` and `doi`), `notebook`, `environment` (a `file` in the repository at that ref, a `container` image and an `archive`) and `results` behind an article, every one optional and each a bare URL if that is all there is. The post shows the artifacts given with their identifiers, after the body and before the revision history, and a research article after its "Code and reproducibility" section; a ref or a file in a GitHub or GitLab repository is linked to that exact version. External links carry `rel="external noopener"`, a site path takes the baseurl, and in print every artifact keeps its address. A URL that is not http(s), a site path or a DOI stops the build and names the page and the field. `docs/components.md` has a worked example (#246).
- Reading mode and print for posts. A "Reading mode" button under the metadata hides the site's navigation, the sharing buttons, the citation tools, the badges, the author card, the related posts and the chronological pagination, and leaves the article with its metadata, its table of contents, its equations, figures, code and the panels that belong to it; the button stays in reach, Escape leaves the mode, and nothing is duplicated. `theme_options.reading_mode.enabled: false` removes it and `remember: true` keeps the choice across pages. A print stylesheet (`_sass/_print.scss`) prints the article black on white whatever the theme, hides the chrome and the interactive-only controls, keeps figures, tables, code blocks, statements and display equations on one page where the browser can, wraps code without a dark background, writes the address after every external link in the text and the article's own address (and DOI) under the metadata, and replaces interactive embeds with a note (#248).
- Local-first reading state on posts: a "Save for later" bookmark, reading progress with a "Resume where you left off" prompt on return, and private highlights with notes, all kept in the reader's browser (`localStorage`) with no account, no server and no telemetry. A highlight is saved as the quoted text with what comes before and after it, so it is found again after the article is edited as long as the passage survives, and one whose passage is gone is listed as not found; the CSS Custom Highlight API paints them where the browser has it, marks elsewhere, so selecting and copying are untouched. The toolbar over a selection and the shortcuts Alt+Shift+H and Alt+Shift+N add a highlight; the panel under the article lists them with their notes, apart from any comments, and offers export, import and erase. `{% include components/reading-list.html %}` lists the saved articles on a page, which the demo has at `/saved/`. `theme_options.reading_state` turns the layer, each part and the list page on or off. A browser that blocks storage sees a message and disabled controls, and nothing breaks. A later sync with the dynamic services (#259) would be opt-in and separate (#260).
- A dynamic-services contract for the optional backend-backed features: `dynamic_services` in `_config.yml` (`base_url`, `api_version`, `timeout_ms`, `credentials`, `features`, `paths`, `csrf_header`, `csrf_cookie`), inlined into every page as public settings and allowed in the Content Security Policy's `connect-src`; a browser client (`assets/js/dynamic-services/client.js`) that builds versioned URLs, sends and reads JSON, times requests out, retries idempotent reads only, sends idempotency keys and CSRF headers on writes, turns every failure into one `ServiceError` with a kind (`disabled`, `unsupported`, `version`, `timeout`, `network`, `malformed`, `unauthorized`, `forbidden`, `not_found`, `conflict`, `invalid`, `rate_limited`, `server`, `http`), the request id and `Retry-After`, and discovers the service's features from `GET /v1/capabilities`, treating another API version as a visible mismatch; and shared form states (`form-state.js`) for the forms that post to it. A key naming a secret under `dynamic_services` stops the build. `docs/dynamic-services.md` holds the contract, the security boundary and a reference serverless-plus-MongoDB deployment; the reader-facing messages live under `dynamic_services.errors` in `_data/i18n` (#259).
- Correction reports: on a site whose dynamic services offer the feature, every post carries "Report an error or suggest a correction", a collapsed form with a category (`corrections.categories`, labelled in `_data/i18n`), the section from the article's headings, the message, an optional email for a reply, and the text the reader had selected. It posts to `/v1/corrections` with the article's address and title and an idempotency key, through the shared client, and shows pending, success, the site's own checks and the service's `422` as field errors, a rate limit and a failure with the request id, and a disabled state when the backend is missing, the feature off, not offered or of another API version; a hidden honeypot catches bots. Reports are never shown on the page: `docs/components.md` explains how one feeds the revision history only after the author has looked. `corrections.enabled: false` or `corrections: false` on a post removes the form. The browser suite builds the site with `tests/integration/site-config.yml`, which points the services at an address the specs answer themselves (#256).
- Contact form: a page with `contact_form: true` (the demo's `/contact/`, now the footer's Contact link) carries a structured message form, a category (`contact.categories`, labelled in `_data/i18n`, with a short prompt per category that the hint follows), the sender's name, email and optional affiliation, a subject and the message, posted to `/v1/contact` with the page it came from and an idempotency key, through the shared client, with the same states as the correction report. `contact.prompts`, `contact.privacy_notice` and `contact.retention` change the prompts and the privacy wording. Without a backend, or with the feature off, the page shows `contact_email` instead, so it is never empty; `contact.enabled: false` removes both. Messages never reach the page or a feed (#261).
- Self-hosted comments: `datalog-comments` gains a fourth provider, `api`, which reads and writes the thread through the site's dynamic services (`GET /v1/comments?path=…`, `POST /v1/comments`) instead of Giscus, utterances or Disqus, so the author owns the discussion. The thread loads when the reader gets near it, shows loading, empty, error (with a retry) and disabled states, nests replies under their parent (`replies: false` for a flat list), and renders everything the service returns as text, keeping an author's link only when it is an http(s) address. The form posts a comment or a reply with a name, an optional email (never shown) and website, and the text, with an idempotency key; a comment held for moderation appears to its author with an "Awaiting moderation" badge. `endpoint` keeps comments on a host apart from `dynamic_services.base_url`, and its origin joins the Content Security Policy. `docs/components.md` carries the contract, the backend's duties and a MongoDB reference model that no part of the theme requires (#253).
- Reactions: "Was this useful?" under every post of a site whose dynamic services offer the feature, with a small configurable set of answers (`reactions.types`, labelled in `_data/i18n`), read from `GET /v1/reactions?path=…` and sent to `POST /v1/reactions` with an idempotency key. The counts are the service's own and only those: none is shown without a backend, with the feature off, when the service cannot be read or answers in another shape, and none is added by the theme after a vote. The reader's choice is kept on their device (`localStorage`) and shown pressed on the next visit; nothing identifies the reader to the service and the theme does not fingerprint. States loading, loaded, unavailable, pending, selected, disabled, with a conflict shown as already counted and a rate limit or failure announced without changing anything. `reactions.counts: false` hides the counts; `reactions.enabled: false` or `reactions: false` on a post removes the strip (#255).
- Webmentions: `webmentions.endpoint` advertises a receiver in every page's head with the standard `<link rel="webmention">`, and on a site whose dynamic services offer the feature every post carries "Mentioned elsewhere", the links, replies and reposts other websites sent about it, read from `GET /v1/webmentions?target=…` when the reader gets near the section. Only entries the receiver verified, from http(s) sources and of the kinds in `webmentions.types` (mention and reply by default) are shown, newest first and as text: no markup from a source is parsed, titles and excerpts are cut, links carry `rel="nofollow noopener ugc"`. Loading, empty, error (with a retry) and disabled (the section hides itself) states; the section says it is not the comments. `docs/components.md` carries the contract, the receiver's duties and a reference deployment with a receiver and a store that nothing requires (#258).
- Newsletter subscriptions: on a site whose dynamic services offer the feature, a compact subscribe form in the footer, at the end of posts or both (`subscriptions.placement`), with an email address, optional topics (`subscriptions.topics`, labelled in `_data/i18n`), consent wording that follows `double_opt_in` and a link to `privacy_url`. It posts to `/v1/subscriptions` with an idempotency key and shows pending confirmation, confirmed, already subscribed (a `409`, not an error), the site's checks and the service's `422` on the fields, a rate limit and a failure; a honeypot catches bots. A page with `subscription_manage: true` (the demo's `/subscriptions/`, out of search results and the sitemap) is where the emails lead: `?confirm=` confirms, `?unsubscribe=` ends the subscription after a press of the button, `?manage=` loads and saves the topics, and the token leaves the address bar as soon as it is read. The client gains `patch` and `delete`. No form renders without a backend; addresses never reach a page or an analytics product. `docs/components.md` carries the contract and a reference model that MongoDB is one way to store (#254).
- Moderation inbox: a page with `moderation_inbox: true` (the demo's `/admin/moderation/`: `noindex,nofollow`, out of the sitemap, the search index and the navigation) lists what the self-hosted features received, pending comments, comments flagged as spam, correction reports and abuse reports, with filters (what, status, report category, page path, since, text) and the actions each item's type and status allow: approve, mark as spam, hide, delete; mark reviewed, accept for editorial action, reject, resolve with the address of the issue, pull request or revision; dismiss. Off unless `moderation.enabled: true`. The page is a shell and says so: authentication and authorization are the moderation service's, or an identity-aware proxy's, on every request; the browser only sends its session (`credentials: include`), a `401` links `moderation.sign_in_url`, a `403` says the account may not moderate, and the build now refuses a key named like a secret under `moderation` as it does under `dynamic_services`. Everything the service returns is rendered as text; an action changes the page only when the service says it happened, and a failure leaves the item as it was with the reason next to it. `docs/moderation.md` carries the contract, the audit trail, the security boundary (CORS with credentials, CSRF) and a reference deployment that needs no particular database (#257).

### Changed

- The site's author, not the author's affiliation, is the publisher when `publisher` is not set. The JSON-LD named `author.affiliation` as the publishing `Organization`, so every post on a personal site said the author's university published it, and a post's microdata and its BibTeX, RIS and EndNote exports named the university as publisher too. Now the JSON-LD names the author as a `Person`, or the site title as an `Organization` when there is no author name, and the citation exports name the site title. The affiliation moves to the author's own `affiliation` in the JSON-LD, only when the page's author is the site's author. A site that the author's institution does publish keeps its old output with `publisher: {type: Organization, name: <the institution>}` (#240).
- The theme no longer depends on `mini_magick`: the image optimizer runs ImageMagick itself (#243).
- A site using the theme from a Git checkout or a local path no longer publishes the checkout's script sources, which no page loads. It gets the theme assets the packaged gem contains (#241).
- Scholarly meta tags are emitted only for pages read as research articles, not for every page with a title: the home page, the search page and every casual post carried `citation_title` and `citation_author`. A page with the `research` layout has them unless it says `scholarly: false`; any other page has them with `scholarly: true` in its front matter; and `scholarly: true` in `_config.yml` covers every post, as the demo's does, while a list names the collections or layouts to cover. A site that wants its posts indexed as before sets it. The `citation_orcid` and `citation_dataset_doi` tags, which no index defines, and the `<link rel="citation_pdf_url">`, which Google Scholar reads only as a meta tag, are no longer emitted; each author's ORCID is in `citation_author_orcid`, and `citation_pdf_url` is now a meta tag (#247).

### Fixed

- A post without a table of contents, because it has no headings or says `toc: false`, was laid out in the 14rem column meant for the contents at the large breakpoint, 224px wide; the article now spans the wrapper. The demo's first post was one.
- The table of contents is a `<nav role="doc-toc">`: an `<aside>` may not carry that role (axe `aria-allowed-role`). Its active entry uses the accent as readable text (`--color-accent-text`; the plain accent was 4.12:1 on the entry's tint) and its reading-progress line the secondary ink (the tertiary one was 2.41:1 in the light theme and 3.73:1 in the dark one).
- Strings, attributes and insertions in code blocks used the success green and regular expressions and tracebacks the warning amber, both about 3:1 on the code background in the light theme; they use `$color-success-text` and `$color-warning-text` now, as the teal and the warning notices already did.
- MathJax draws `\eqref` and `\ref` as a link inside its `aria-hidden` output, which the Tab key reached and a screen reader could not name (axe `aria-hidden-focus`). The drawn link leaves the tab order and the same address follows the expression as a real link, "Equation (3)", shown when it takes the focus.
- The axe spec now scans a post with a table of contents and code blocks and one with equation references, in both themes; the post it scanned had neither, which is how these went unnoticed.
- The Pa11y workflow failed now and then in "Install Pa11y CI", when Puppeteer could not download its browser ("All providers failed for chrome-headless-shell"), with nothing wrong with the pages. It installs pa11y-ci without that download and points Puppeteer at the Chrome the runner image ships.
- `docs/README.md` linked to the installation guide's "Install from a Git Checkout" section by its old anchor, which #242 renamed (#250).
- `author: jane_smith` put "jane_smith" in the post's byline, JSON-LD and meta tags; only the author card looked the key up in `_data/authors.yml`. The research layout gave every author the site author's ORCID and affiliation, and the JSON-LD gave any author the site author's GitHub, Twitter and LinkedIn profiles, and only when an ORCID was set. Each author now has their own details (#252).
- The EndNote export wrote each author as `%A  - Name`, since it rewrote the RIS `AU  - Name` lines, and with several authors the BibTeX author field and the RIS author lines held stray line breaks (#252).
- The author card's placeholder showed no initials: `map: 'first'` on the words of the name returned nothing (#252).
- The critical CSS inlined on the demo's pages carried the Google Fonts `@font-face` rules for the TrueType files headless Chrome is served: eight on the home page. Extraction now reads only `main.css`, which also cut the home page from over a minute to seconds (#238).
- The image optimizer never created a resized, AVIF or WebP copy of any image, with ImageMagick installed or not. Looking for avifenc, it called `Jekyll::Utils.which`, which Jekyll does not have, and the error, logged at debug level only, stopped every copy. The optimizer now finds ImageMagick 7 (`magick`) or, outside Windows, ImageMagick 6 (`convert`), creates only the formats it can write, and encodes each copy as the build starts, into `.jekyll-cache/datalog-images`, where later builds find it. A copy that fails to encode is left out with a warning, so no page offers a file that was never written. The Tests workflow installs ImageMagick and avifenc, and `tests/test_image_variants.rb` checks the encoded files (#243).
- On a site served below a `baseurl`, such as a GitHub project page, a JPEG or PNG from the site's files got a `srcset` naming it without the baseurl, so the browser requested it from the wrong path and showed no image. Every URL the optimizer writes now starts with the baseurl (#243).
- The README, the installation guide and the starter template's `Gemfile` install the gem with `~> 0.8.0`; they still said `~> 0.7` after 0.8.0 was released. The Release workflow now rewrites these constraints, and the release tag in the guide's Git example, when it bumps the version, and it runs `tests/test_install_versions.rb`, which fails a release whose install examples fall behind (#242).
- The starter template's deploy workflow set up Ruby 3.1, and the installation guide said Ruby 3.0 was enough, but 0.8.0 requires Ruby 3.2: on an older Ruby, Bundler cannot install it. Both say 3.2 now. `datalog check` also accepted Ruby 3.0; it now checks the requirement the gemspec declares (#242).
- The installation guide told Git users to install from `develop`, and `docs/branch-trigger-policy.md` said `main` was reserved for future use. The guide now lists the release channels (RubyGems, release tags, `main` for the latest release, `develop` for unreleased work) and pins a release tag, and the branch policy describes `main` as the stable release branch and lists every workflow's triggers. The template guide pushed the starter to `develop`, while its deploy workflow runs on `main` (#242).
- Pages scroll smoothly only when the reader has not asked for reduced motion. `html { scroll-behavior: smooth }` applied to every reader, and the site navigation, the post table of contents and package pages passed `behavior: "smooth"` to their scroll calls, which overrides that preference. The stylesheet now sets smooth scrolling inside `@media (prefers-reduced-motion: no-preference)`, and the three scripts pass no behavior, so they follow it. `tests/integration/reduced-motion.spec.js` checks both preferences in the browser (#239).
- A page's `math` front matter now takes precedence over `mathjax`. `mathjax`, which the configuration guide did not mention, was read first, so under a `mathjax: true` in front matter defaults a page with `math: false` still loaded MathJax, which then rendered the page's dollar signs. `mathjax` is still read, as an alias, when `math` is not set, and the math preprocessor resolves the two the same way (#234).
- Inline math with spaces inside the dollars, such as `$ \frac{TP}{TP + FP} $`, counts as math when it holds a TeX command, `^` or `_`. MathJax and KaTeX render it, but the math preprocessor followed Pandoc's rule and left it out, so with `render_on_load: auto` a page whose only math was written that way loaded no engine and showed the TeX source. The preprocessor now sets aside each expression it wraps, as it does code, so a later pattern cannot pair a dollar sign inside one with a dollar sign outside it (#234).
- `jekyll serve` stopped regenerating the site after its first build when `_config.yml` set `sass.style`, as the demo's does. Converting a stylesheet, jekyll-sass-converter replaces that value in the site's configuration with a Symbol, and the config validator, which checked the configuration again on every build, stopped each rebuild with "Invalid type for 'sass.style'". A site's configuration is now checked on its first build only, and a Symbol passes where a String is expected. `jekyll build` was not affected (#235).
- Configuration errors linked to a documentation site that was never published. They link to `docs/configuration-reference.md` on GitHub, which now lists every key the validator checks (#235).

## [0.8.0] - 2026-09-14

### Added

- `tests/test_csp_pages.rb` checks that every nonce in a page matches its policy, that MathJax and Disqus pages get what they load, and that Observable's classic embeds may be framed (#196).
- `csp.script_src`, `csp.style_src`, `csp.font_src` and `csp.connect_src` in `_config.yml` add sources to the Content Security Policy, as `csp.frame_src` does for iframes (#196).
- The policy sets `object-src 'none'`, `base-uri 'self'` and `form-action 'self'`. None of them falls back to `default-src`, so all three were open (#196).
- `tests/test_csp.rb` checks which pages get the looser policy. `tests/integration/csp-charts.spec.js` loads the real Plotly and widget manager, checks that the chart and the widget render, and fails on any script or style violation. Unit tests in `tests/js/visualizations.test.js` cover the order in which chart libraries and require.js load (#195).
- A `rouge_highlight` Liquid filter highlights code passed to an include as the site builds. The package API examples and the enhanced code block, which printed its code unescaped, use it, and the notebook converter highlights code cells the same way (#197).
- The head preloads the visualization, notebook and academic bundles on the pages that use them, as it already did for search and math, so they download alongside the core bundle instead of after it (#197).
- `tests/test_rouge_highlighting.rb` checks that code is highlighted as the site builds and that pages load no Prism. `tests/test_feature_loading.rb` checks the new preloads and which pages inline the academic data, and a Playwright test checks that the copy button labels the language and leaves out line numbers (#197).
- Ruby Tests jobs on Ruby 3.3 and 3.4 in the Tests workflow run the Ruby suite on the newer releases, next to the existing job on 3.2. `tests/test_gem_package.rb` checks the Ruby requirement, that every runtime dependency has an upper bound, that the unused and optional gems stay out, and which script files the gem ships (#203).
- `tests/test_site_output.rb` checks that every in-page link on the built site reaches an element on that page (#206).
- A Docker Images workflow builds `Dockerfile` and `Dockerfile.dev`, without pushing, on pull requests that change what they are built from (#205).
- `bundle exec rake test` builds the demo site and runs the Minitest suite, the same command as the Tests workflow, and is the default Rake task. `tests/test_site_output.rb` takes over what the `ci:verify` scripts checked and no other suite did: `CITATION.cff` matching the theme version, citation exports and scholar metadata on posts, the math status live region, `noopener` on every link that opens a new tab, and sandboxed app embeds. The browser suite checks that code blocks in a post get a labelled copy button, which the post layout adds when the page loads (#204).
- A Lint job in the Tests workflow runs ESLint and RuboCop, and the test summary fails when it does. Both linters were configured in the repository but ran in no workflow. RuboCop is now a development dependency, pinned because the repository has no `Gemfile.lock`; the offenses that predate the job are listed in `.rubocop_todo.yml`, so new code has to pass (#204).
- `tests/test_workflows.rb` checks the release and CI guards described below, and `tests/js/cdn-integrity.test.js` runs the Subresource Integrity check from `tests/test_sri.js`, a script no test command ran (#204).
- `tests/test_gem_consumer.rb` builds a minimal site against the packaged theme and against a checkout of the repository, and fails if the build breaks or publishes anything that identifies the maintainer.
- `tests/test_navigation_cache.rb` checks that each section still marks only its own navigation link now that the navigation is cached.
- The performance tests fail if the stylesheet grows past 25 KB gzipped, as they already did for the core script bundle.
- `tests/test_related_posts.rb` checks that a post lists the posts it shares a tag with.
- `csp.frame_src` in `_config.yml` lists the hosts a site embeds iframes from, such as Shiny apps, slide decks or videos, and the Content Security Policy allows them next to Observable.
- `tests/test_feature_loading.rb` checks which pages load MathJax and the search bundle.
- `show_title: false` in a page's or a layout's front matter leaves out the title the default layout prints, for pages and layouts that render their own `<h1>`.
- `tests/test_page_structure.rb` checks that no built page has more than one `<h1>`, the footer's headings and landmark name, the color scheme script at the top of `<body>` and the heights of the academic chart's bars. `tests/js/blocked-storage.test.js` covers dark mode and the core initializers with storage blocked, and the browser suite checks that the saved theme applies before any script bundle loads and that the core bundle still loads when storage is blocked.
- `tests/test_head_metadata.rb` checks that each head tag appears once, that empty verification tags are left out, that the 404, search and admin pages carry `noindex` and stay out of the sitemap, and that every page's JSON-LD parses without empty values.
- Tests for the fixes to the config validator, the warning filter, notebook images and languages, the analytics cache, plugin hook registration, `{% t %}` options, `datalog publish` and `datalog new post`, in the existing test files for each.

### Changed

- Each page's Content Security Policy allows only the jsDelivr packages that page loads: the math engine's directory, and Plotly, D3, BokehJS, Vega or Chart.js where the page uses them. The policy allowed all of jsDelivr, which serves any npm package, on every page. Widget pages still allow all of jsDelivr, and they are the only pages that allow require.js from cdnjs (#196).
- Google's analytics hosts are in the policy only on a site that sets `google_analytics`. They are the hosts Google documents for GA4, including the regional `*.google-analytics.com` hosts GA4 reports to (#196).
- The Content Security Policy is looser on pages with a Plotly or ipywidgets block and unchanged on every other page. Plotly pages allow inline styles in place of the style nonce. Widget pages also allow `'unsafe-eval'` and fonts from jsDelivr. A page that loads either library another way can set `csp.unsafe_inline_styles` or `csp.unsafe_eval` in its front matter (#195).
- Code is highlighted by Rouge alone, when the site builds. Pages with code also loaded Prism from jsDelivr (seven scripts and two stylesheets on a post), which highlighted the blocks again in the browser and turned every language it had no grammar for, such as bash and yaml, into plain text. The theme now styles Rouge's tokens and line numbers in light and dark mode, in greys that meet 4.5:1 contrast (the comment grey Prism used measured 2.33:1 in light mode), and gives every code block tabindex="0", as Prism did, so a wide block can be scrolled from the keyboard. Search results show code snippets as plain text (#197).
- The academic and publication data is inlined only on pages that render citation metrics, tables or charts, the only pages whose script reads it. On the home page it was nearly a quarter of the HTML (#197).
- The image optimizer fetches one image per page early: the first image in the post or page content, and none on a page that preloads its hero. It gave the first image anywhere on the page both `loading="lazy"` and `fetchpriority="high"`, which was a post card below the hero on the home page and a related-post thumbnail at the bottom of tutorials (#197).
- Google Fonts is asked for the eight weights the stylesheet uses instead of eleven, and the font stylesheet link no longer repeats its `media` and `data-async-style` attributes (#197).
- The gem requires Ruby 3.2, the version the sass-embedded and nokogiri releases it resolves need; it claimed 3.0. Every runtime dependency is bounded below its next major version (`~> 1.15` rather than `>= 1.15`), so a breaking release arrives through a pull request instead of an untested `bundle update` (#203).
- `googleauth` is no longer a dependency of the theme. Only the analytics dashboard with a GA4 property configured uses it, and every site installed it with its Google Cloud dependencies; a site that uses the dashboard adds `gem "googleauth"` to its Gemfile, and without it the dashboard says so (#203).
- The Docker images build on `ruby:3.4-slim` and serve from `nginx:1.30-alpine`. `ruby:3.2-slim` is end of life, and 1.27 was an nginx mainline branch that no longer gets releases (#203).
- The pre-commit hook runs lint-staged only: ESLint and the Vitest tests related to the staged JavaScript. It used to run `npm audit`, which needs the network, and the whole Vitest suite on every commit; both still run on every pull request (#205).
- Dependabot pull requests are titled `chore(deps)`, `chore(deps-dev)` and `ci(deps)`. The prefixes repeated the scope Dependabot appends, which gave titles like `chore(deps-dev)(deps-dev)` (#205).
- The accessibility, broken link, dependency review and Lighthouse workflows cancel a pull request's superseded runs, the accessibility workflow installs a pinned `pa11y-ci` and uses the `http-server` devDependency, and `package.json` is marked private so `npm publish` refuses to publish the repository's tooling (#205).
- `gem-release.yml` publishes only from a `v*` tag, a manual run included, and stops when the tag does not match `lib/datalog/theme/version.rb`. The tag job in `release.yml` builds the script bundles and the gem and runs `scripts/verify_gem_package.rb` before it creates the tag, so a broken package no longer leaves a tag and a GitHub release for a gem that never published (#204).
- The Python security audit runs `pip-audit` on `requirements.txt`. It used to collect `import` lines from `scripts/`, which name modules rather than packages, and ignore every result (#204).
- `search.json` no longer stores a normalized copy of each document's title, summary, content, tags and languages. The search engine normalizes them in the browser, once per document, with the function it applies to queries; the copy was 41% of the file, and queries and documents had been normalized by different code. With the code blocks below added, the demo's index goes from 219 KB to 137 KB.
- The Tests workflow runs the Playwright suite and enforces the coverage thresholds on pull requests. The coverage steps waited for a Node 20 leg the matrix no longer has, and the browser specs only ran in the deploy after a merge, so both kinds of failure surfaced on `develop` instead of on the pull request.
- MathJax loads only on pages with math, and the search bundle only on the search page. With `render_on_load: auto`, MathJax loaded wherever a dollar sign or an escaped parenthesis appeared in the rendered page, including shell variables, prices and inline scripts, and the demo also turned it on for every post; it now follows the expressions the math preprocessor finds, and on the demo loads on 6 pages instead of 28. The search bundle was preloaded and run on every page because the header's search form matched the loader's check; it now loads on the one page that renders the search app.
- The release workflow promotes a `release/vX.Y.Z` branch to `main` instead of promoting `develop` itself, so the pull request and the merge commit on `main` name the release rather than reading "from develop". `develop` still receives the version bump.
- The stylesheet carries the styles of an optional feature only when the site uses it: search (`features.search`), visualizations (`features.visualizations`), notebook pages, the `packages` collection, the academic dashboard (`features.academic_dashboard`) and open science badges (badges in `_data/academic.yml`). `assets/css/main.scss` configures the new `_sass/_features.scss` from the site's settings, and each partial loads those styles at the position they always had, so a site with every feature on gets the same stylesheet byte for byte. With all six off it shrinks from 169 KB to 122 KB, or from 27.6 KB to 20.5 KB gzipped. A site that replaced `main.scss` with a plain `@use "theme"` keeps the complete stylesheet. `_sass/_phase1-enhancements.scss` is now `_sass/_post-components.scss`.
- The layouts use `jekyll-include-cache`, a dependency the theme already declared but never used. The footer and skip link are rendered once per build (the skip link once per page language) and the header navigation once per distinct current section, where each was rendered on every page before: on the demo site the navigation renders 10 times instead of 53. The CSP meta tag, the script loader and the analytics snippet stay per page because each carries that page's CSP nonce. Requiring the theme now also loads `jekyll-include-cache`.
- The documentation is organised by task. `docs/README.md` indexes the guides by what a reader wants to do; the phase summaries, the configuration refactoring plan and the 2025 security audit moved to `docs/history/` under a note that they are not maintained; and the Phase 1 features guide became `docs/components.md`, without the `phase1_features` settings the theme never read and with instructions that work for a site using the gem. The installation guide lost its leftover citation markers, and the README and the starter template pin the current `~> 0.7` series.
- The installation guide covers what a site supplies itself (pages, navigation, social links), installing from a Git checkout, and publishing to GitHub Pages with GitHub Actions. It replaces instructions for the built-in Pages build, which cannot run the theme.

### Deprecated

- `theme_options.syntax_highlighting` no longer has an effect, and a build that sets it prints a warning (#197).

### Removed

- The CSP generator's inline script hashes. It computed them after a page had rendered, too late to reach the policy written into its head, and every inline script already carries the nonce (#196).
- Prism: its scripts and stylesheets, their SRI entries, the `meta/syntax-config.html` include, the `syntax_highlighting` page setting and the `theme_options.syntax_highlighting` block in the demo configuration (#197).
- `window.DatalogTheme` and `window.DatalogContent`, which every page inlined and no script read (#197).
- `jekyll-archives` and `jekyll-remote-theme` from the gem's dependencies, which nothing in the theme used, and the 22 unbundled script sources from the gem. Pages load the bundles in `assets/js/dist` and `assets/js/loader.js`; every site copied the sources into its published output as well. A site that installs the theme from a checkout still has them (#203).
- Settings in the demo `_config.yml` that nothing reads: `features.math_toolkit`, `math_search`, `accessibility_skip_link`, `academic_calendar` and `notebook_support`, `theme_options.math.equation_numbering`, and `integrations.binder` and `integrations.colab`, whose buttons are configured under `notebooks:` (#206).
- `rake ci:verify` and its twelve scripts in `scripts/`. Most checked that source files contained particular strings, repeated what Minitest, Vitest and Playwright already cover, and passed whether or not the built site worked. The Tests workflow no longer sets up Python, which only one of them needed (#204).
- `project-sync.yml`, which only printed what it would have done, and `tests/test_critical_css.js`, `tests/test_search_accessibility.js` and `tests/test_viz_accessibility.js`, which no test command ran and which failed against the current sources (#204).
- `lib/datalog/theme/theme.rb`, a theme registration hook that nothing required.
- Includes and layouts that no layout, page or plugin used, with the styles written for them: the `archive` and `post-sidebar` layouts, and the user preferences panel, popular posts, back-to-top button and keyboard shortcuts panel (`navigation-enhancements`), social proof, enhanced metadata, reading progress, reading time, content recommendations, comments, language switcher, bookmark, email preferences, advanced search, newsletter signup and series navigation includes. Several read `phase2_features` to `phase5_features` settings that nothing defined. Comments still render through the `datalog-comments` plugin. The rules in those stylesheets that did style rendered pages (the `kbd` element, fieldsets, `.button` and the search result cards) moved to the partials for what they style, and `_sass/_phase3-enhancements.scss`, `_phase4-enhancements.scss` and `_phase5-enhancements.scss` are gone. Together with the feature gating above, the demo's stylesheet goes from 169 KB to 134 KB (27.6 KB to 23 KB gzipped), and a site with every optional feature off gets 85 KB (15.7 KB gzipped).

### Fixed

- MathJax typesets math again. Its configuration loaded the `\require` extension, which stopped MathJax 3.2 while starting up (`Illegal characters used in \require prefix`), so no page rendered an equation. Every extension the pages use is loaded directly, so authors don't need `\require`.
- Posts with math no longer throw `Cannot read properties of undefined (reading 'then')`. The post layout read `MathJax.startup.promise` before MathJax had loaded; MathJax now announces typeset math with a `datalog:math-ready` event.
- Equations are no longer taken out of the tab order. MathJax's explorer gave each one `tabindex="1"`, which axe reports; it is turned off, and the assistive MathML screen readers use stays on.
- The math preprocessor's wrapper has `role="math"`. It carried an `aria-label` with no role, which ARIA forbids, and axe failed the page once MathJax rendered the expression inside it.
- Notebook pages run their inline scripts. The pages are created after the CSP generator assigns nonces, and their templates printed an empty `page.csp_nonce`, so the browser refused every inline script in the head. MathJax's inserted stylesheet is allowed on math pages.
- Bokeh blocks render. The theme loaded BokehJS's core bundle, which has no `Bokeh.Plotting`; it now loads the API bundle too, and logs a failed load instead of ignoring it.
- Disqus comments load. The policy refused Disqus's script, stylesheet, iframe and the inline style that sizes the iframe.
- Observable embeds display. An `observablehq.com` embed redirects to `old.observablehq.com`, which the policy refused. The demo's two embeds pointed at notebooks that return 404 and now embed D3's zoomable sunburst and bar chart.
- The demo post's slide deck loads. It pointed at a host that does not exist; it now embeds the reveal.js demo deck, and `revealjs.com` is in the demo's `csp.frame_src`.
- KaTeX's fonts load. The policy refused the fonts its stylesheet requests from jsDelivr (#196).
- Plotly charts render. Plotly inserts its rules into a `<style>` element it creates, which the policy refused, so every Plotly block reported that Plotly failed to load (#195).
- Jupyter widgets render. The policy refused the widget manager's `<style>` elements, the `new Function` it compiles widget schemas with, and its icon fonts. The theme also called a `WidgetManager` that `@jupyter-widgets/html-manager` does not export, and the error was swallowed; it now uses `HTMLManager` (#195).
- A page with a widget no longer loses its Plotly, D3 or BokehJS chart depending on which script loads first. require.js, which the widget manager loads, made a bundle that ran after it register as an anonymous module, and require.js threw `Mismatched anonymous define()`. Bundles requested after require.js now load through it (#195).
- The package API include's "See Also" list treated its comma-separated `see_also` string as a single item, so every list became one link to an anchor that did not exist; on the StatFlow page six of them led nowhere. It now splits the list, and StatFlow only lists functions it documents. The Plotly showcase post's contents linked to a heading written as raw HTML without an id, which now has one (#206).
- Documentation that contradicted the code: the testing guide and the coverage review process quoted coverage thresholds of 20% and 80% where `vitest.config.js` enforces 88/78/83/88; the testing guide still listed Percy; the configuration guide described a comments configuration the plugin does not read, Binder and Colab settings nothing reads, and the MathJax detection #194 replaced; the user guide sent notebook metadata to an unread `_data/notebooks.yml` and Binder links to an unread `integrations.notebooks`; `_config.yml` pointed at `_data/config` files that do not exist; `_data/config/author.yml` linked to a missing page; and the Minimal Mistakes post linked to a docs page the site does not build (#206).
- Neither Docker image built. `Dockerfile` copied a `Gemfile.lock` the repository does not have, then built the script bundles without esbuild, a dev dependency it had skipped; `Dockerfile.dev` ran `bundle install` without the gemspec the Gemfile loads. Both copy what the gemspec requires, install the OpenSSL and YAML headers that gems such as `openssl` compile against, drop the Python they installed for a notebook check that is gone, and use Node.js 22 like CI (#205).
- The config validator stopped a build with "Invalid type for 'author'" for `author: Jane Doe`, and with "Invalid value for 'url'" for `url: ""`, which `jekyll new` writes. Both are accepted (#202).
- Loading the theme broke `warn` keyword arguments for the whole build: a `Kernel#warn` override printed `uplevel:` and `category:` as a hash after the message. The override is gone; the `Warning` filter beside it still silences the same two messages (#202).
- Notebook images whose base64 data Jupyter had split over lines or ended with a newline failed the data URI check and lost their `src`. The data is joined without whitespace first (#202).
- A notebook's language went into a code cell's `class` attribute unescaped; it is now cut down to the characters a class name can hold (#202).
- The analytics dashboard cached a missing-configuration or error report for a day, so after `GA4_PROPERTY_ID` was set it went on saying analytics wasn't configured. Only successful reports are cached (#202).
- Every DataLog plugin hook ran twice for each post: the loader registered its hooks for posts as well as documents, and Jekyll fires both for a post (#202).
- `{% t %}` split its options on every comma, so a quoted value such as `name: "Doe, Jane"` reached the translation as a fragment (#202).
- `datalog publish` built without `JEKYLL_ENV=production`, so the published site left out the analytics tag and included the development CSP logger, and it ignored the exit status of `git commit` and `git push`, so a rejected push still ended as a publish. It builds for production and exits with an error when either step fails (#202).
- `datalog new post` wrote the title, summary, author and tags between plain quotes, so a title with a double quote or a tag with a colon produced front matter that didn't parse (#202).
- The `datalog_slides`, `datalog_comments` and `datalog_bibliography` fallback tags, which stand in when their plugin is disabled, printed "feature coming soon", the slides one with the page's raw configuration, on a page that set the key by hand. They render nothing and log a warning naming the plugin to enable (#202).
- Search never matched code: every document's code list in `search.json` was empty, because the index template split the content on backticks after Jekyll had already rendered posts to HTML. `_plugins/search_code_blocks.rb` collects fenced code blocks from the source before rendering, and the demo's index now carries 34 of them (#198).
- The 404, search and admin pages asked search engines to index them, the search and admin pages were listed in `sitemap.xml`, and all three appeared in site search. The robots tag now comes from `robots:` in front matter, and those pages set `noindex`, `sitemap: false` and `exclude_from_search: true` (#198, #199).
- Every page carried the `keywords`, `format-detection` and jsDelivr `preconnect` tags twice, written by both `head.html` and the default layout, and empty Google, Bing, Yandex and Baidu verification tags when the site set no codes (#199).
- The JSON-LD had `"dateModified": ""` on 26 pages, `"description": ""` where a page had no description, and `"headline": null` on the home page. Values a page doesn't have are left out, and the headline falls back to the site title (#199).
- A blocked `localStorage` stopped every script feature on the page. Where storage access throws (Safari with all cookies blocked, sandboxed iframes, some privacy extensions), the dark mode toggle threw while the core bundle loaded, the loader gave up, and search, math, visualizations and the academic features never started. Dark mode now treats blocked storage as no saved choice, and each core initializer runs on its own, so a failure is logged without stopping the others (#201).
- Readers who chose the dark theme saw each page in the light theme first, because the core bundle applied the theme after the page had been drawn. A small nonced script at the top of `<body>` now applies the saved or system choice before anything paints (#201).
- GitHub repository cards kept their "—" placeholders when the API request failed, with no sign the numbers weren't coming, and asked again on every page view against the unauthenticated limit of 60 requests an hour. A card whose request failed now shows the translated "N/A" and is marked `data-github-state="error"`, and the failure is remembered for ten minutes (#201).
- Fourteen demo pages had more than one `<h1>`: the default layout printed the title, and so did the dataset, project, portfolio, notebook and package layouts, the 404 page, the archive, category and tag pages and the CV page. Those layouts and pages now set `show_title: false`. Headings in notebook markdown cells move down a level, since a notebook usually opens with its title, and package API examples render as code rather than Markdown, which had turned every Python comment into a heading (15 `<h1>`s on the StatFlow page) (#200).
- The footer's column titles were `<h3>` regardless of the page above them, and its navigation was an unnamed landmark next to "Primary navigation". The titles are `<h2>` with the same look, and the navigation takes its name from the "Explore" heading (#200).
- Screen readers announced "Reading progress: N%" on every scroll event, because the percentage sat in a live region. The live region is gone; the progress bar stays hidden from assistive technology (#200).
- On narrow screens, Escape moved focus to the menu button even with the menu closed, for example while clearing the search field. It now acts only when the menu is open (#200).
- The bars of the citations-by-year chart on `/academic/` had no height: each set it in a `style` attribute, which the Content Security Policy drops. The heights now come from a nonced style block (#195).
- Related posts never appeared: the list of posts was split into single characters before it was filtered, so every post said "No related posts yet".
- Search dropped every letter outside ASCII from its index, so accented, Greek, Cyrillic and CJK words could not be found, and every build printed "[search_normalizer] unicode_normalize gem not available": `String#unicode_normalize` is part of Ruby, not a gem. The browser also cut queries down to the letters a to z; both now keep letters of any script.
- The search page trapped keyboard focus: Tab from the input or any filter cycled through the filters, so the results could not be reached.
- Search results inserted text from the index as HTML, and highlighting several words could put one `<mark>` inside the tags of another ("remark" became `re<<mark>ma</mark>rk>`). Results and suggestions are now escaped and highlighted in one pass, and index content is stripped of markup in an inert document.
- A `_data/publications.yml` written as a list of entries stopped the build with a `TypeError`. A list is now read as the manual entries.
- The math preprocessor wrapped dollar signs inside code as math, inserting markup into shell, R and SQL snippets, and read prices such as "$5 a month, or $50 a year" as an expression. Fenced code, highlight tags and inline code are left alone, and inline math follows Pandoc's rule: the opening `$` is followed by a non-space, and the closing `$` follows one and is not followed by a digit.
- The analytics dashboard never rendered: its script uses `export` but was loaded as a classic script from the unbundled source, which failed to parse. It now loads as a module from the built bundle.
- The Copy buttons of the citation tools on posts, datasets and projects did nothing: their handler lived in the academic bundle, which those pages never load. The core bundle now handles them.
- Visualizations were refused by the theme's own Content Security Policy. D3 and scripted Bokeh blocks ran their code with `new Function`, which the policy refuses; the code now runs as a script carrying the page's nonce. Plotly and Bokeh loaded from hosts the policy does not list, and Bokeh also requested a stylesheet BokehJS 3 does not publish; both load from jsDelivr now. Observable blocks ignored `data-viz-src`, the attribute the user guide documents; they now accept it, and take embed addresses only from observablehq.com, so a `javascript:` or `data:` URL in the markup never becomes the frame's source. Iframes from any host but Observable were refused. On the demo, the D3 chart, the Observable embed and the Shiny app now render in Chromium. Plotly and ipywidgets charts still fail, because those libraries insert inline styles or evaluate strings, which the policy forbids, and Bokeh has not been confirmed to render.
- Sites installing the gem published part of the demo site. The maintainer's CV templates and publication exports were copied into every site, and the demo's social profiles, contact addresses and academic profiles reached the footer and the script data on every page through `_data`. The gem now contains only the `_data` files the layouts need (translations, the script manifest and CDN integrity hashes) and none of the demo's downloads, and `scripts/verify_gem_package.rb` refuses a gem that does.
- A site installing the theme from a Git checkout or a local path inherited the whole demo site. Jekyll merged the demo's `_config.yml` into the site's configuration, so the build stopped on a `datasets` feed for a collection the site did not have, and a site that declared the collection to get past it carried the maintainer's author details, contact addresses and social profiles. The build now stops with an explanation until the site sets `ignore_theme_config: true`, and with that set the theme also leaves out the demo's `_data` files and downloads.
- The repository and the gem carried `_data/js_meta.json`, the esbuild metafile, whose committed copy had fallen behind the sources: its byte counts described an older build than the bundles it shipped with, and running `npm run build:js` left it modified. The metafile now stays with the bundles in `assets/js/dist/` and out of the gem. The build also no longer rewrites an unchanged `_data/js_manifest.json`, which Windows checkouts reported as modified because of line endings, and the test and gem release workflows fail if the committed manifest does not match the sources.
- The README said notebooks publish under `/blog/` and that GitHub Pages builds a site with the `github-pages` gem. Notebooks publish under `/notebooks/`, and the build GitHub Pages runs by itself cannot load the theme's plugins, so the README now points to the GitHub Actions workflow in the installation guide.
- Without `_data/navigation.yml` the header and footer linked to the demo's sections (Research, Projects, Datasets, Academic Ops), which a site using the theme does not have, and the header and footer showed "DataLog" rather than the site's title. The navigation and the footer's "Explore" and "Connect" columns are now left out when there is nothing to list, and the name falls back to `title`.

## [0.7.0] - 2026-09-12

### Added

- `tests/test_search_pages.rb` covers the generator: both pages when search is on, neither when it is off or unconfigured, and no duplicate when the site provides its own.
- The README carries a badge showing the version published on RubyGems, linking to the gem page.
- `scripts/verify_gem_package.rb` checks that a built gem contains every bundle its manifest references; the release workflow builds the bundles and runs it before publishing.
- `tests/test_gem_package.rb` covers what a site using the gem needs: the bundles are packaged, the plugins' gem dependencies are declared, and requiring the theme registers its Liquid tags.
- The search index test checks that tags are whole tags rather than only that the field is an array.
- The integration suite runs axe-core over six pages in both light and dark mode, so contrast, missing accessible names and misplaced ARIA cannot regress unnoticed.
- A social card image (`assets/img/social-card.png`), so the Open Graph and Twitter image tags no longer point at a missing file.
- The release workflow now does a release in one run plus one pull request: "Run workflow" with a version bumps `develop` and opens the PR into `main`; merging it tags `main`, publishes the GitHub release and starts the gem publish.

### Changed

- MathJax is only loaded on pages that contain math (`theme_options.math.render_on_load: auto`, the new default of the demo site) and Prism only on pages with a code block (`theme_options.syntax_highlighting.load: auto`); pages can still opt in or out with `math:` and `syntax_highlighting:` front matter, and a page with `math: false` is also left alone by the math preprocessor. Pages without either skip about 400 KB of CDN scripts and stylesheets.
- The IBM Plex web fonts fall back to local fonts scaled to Plex's metrics, so the swap once the web font arrives no longer moves the layout, and the Google Fonts stylesheet no longer blocks rendering.
- The home hero image is preloaded and small screens get a 640 px variant (`hero_image_small` for pages that set their own `hero_image`).
- The Lighthouse workflow inlines critical CSS before building, as the deploy does, so it measures the published configuration.
- CI jobs install only what they use: the Jekyll test job no longer installs libvips (the image plugin uses MiniMagick, which the runners already provide) or keeps redundant pip and `_site` caches, and the accessibility, Lighthouse and deploy workflows no longer set up Python, which only the Rake verification task needs.
- The hero background is served as a 46 KB WebP instead of a 1.27 MB PNG.
- Footer text and links, and the skip link in dark mode, meet the 4.5:1 contrast ratio; the blog listing uses second-level headings for its cards.
- The Tests workflow runs for pull requests into `main` as well as `develop`; the duplicate theme-stability workflow is gone.
- The configuration guide documents where settings actually live (`_config.yml` plus `_data/config/author.yml`).
- The gem publish can authenticate with RubyGems trusted publishing (OpenID Connect) instead of a stored API key; the `RUBYGEMS_TRUSTED_PUBLISHING` repository variable selects it.

### Fixed

- Sites installing the gem had the search interface and its JavaScript but no search: the page that renders it and the one that builds its index are pages, which a theme gem cannot ship. Both are generated now for any site with `features.search` enabled, and a site that defines either path keeps its own.
- The published gem could not be used. Jekyll reads `_plugins/` for a site but not for a theme gem, and `lib/datalog-theme.rb` did not load them, so the tags the layouts use were never registered and every consumer site failed to build with `Unknown tag 't'`. Naming the theme under `plugins:` now loads them.
- The gem shipped `_data/js_manifest.json`, which points every page at the browser bundles, without the bundles themselves: `assets/js/dist/` is build output that git does not track, and the gemspec selected files with `git ls-files`. Sites using the theme loaded no JavaScript at all.
- The gemspec did not declare `loofah`, which the notebook plugin requires, so loading the theme raised `cannot load such file -- loofah`.
- The home layout sorted `site.portfolio`, which is nil unless a site declares that collection, and sorting nil stops the build. The section is skipped when the collection is absent.
- The search index shipped every tag as a list of single characters, so the tag filter on the search page offered 34 buttons reading `a`, `b`, `[`, `"` and so on instead of the 48 real tags. A `split: ''` in the index template turned each tag array into its string form before splitting it.
- A tag consisting only of whitespace produced a filter button with no accessible name at all, which fails WCAG 4.1.2.
- The fallback author avatar carried an `aria-label` on a plain `div`, where ARIA prohibits it, so screen readers announced nothing for it. It is now an image role, matching the photo it stands in for.
- Text set in the teal accent failed WCAG AA everywhere it appeared, reaching only 3.0:1 to 3.5:1 on post badges, skill tags, search highlights and Prism keywords. Teal text now uses a darker tone; the original teal stays for fills and borders.
- Dark mode had several unreadable components, none of which any check covered: the citation tools kept light backgrounds under light text, leaving a heading white on white at 1.09:1, and difficulty badges kept their light-mode text colour on a near-black pill at 1.93:1.
- Buttons marked `btn--ghost` were never styled, so they fell back to the browser's own button chrome and could not follow the theme.
- The Playwright and coverage reports were copied into the built site and published with it. Both are excluded now, and the Playwright report is also ignored by git.
- `datalog check` reported every dependency as missing on Windows, including bundler, which it treats as a critical failure. The probe called `command -v`, a POSIX shell builtin with no executable behind it; it now searches `PATH` itself, honouring `PATHEXT`.
- The build and test scripts run on Windows. `npm run test:integration` spawned the Playwright `.cmd` launcher, which Node refuses with `EINVAL`; `npm run build:critical` spawned `bundle`, which is a `.bat` there and failed with `ENOENT`; `bundle exec rake ci:verify` invoked `python3`, which on Windows is a Microsoft Store stub rather than the interpreter; and the CLI tests ran the binstub through its shebang. Node dependencies now run under the current Node binary instead of their launcher shims, and the remaining launchers go through the command interpreter with arguments quoted, so paths containing spaces survive.
- The site navigation no longer renders expanded and then animates shut on small screens once the script runs, which moved the whole page by about 340 px and put every page's cumulative layout shift near 0.3.

### Removed

- Percy and its visual suite (`tests/visual/`): Percy never ran without a token and carried the last open npm advisory and about 150 packages, and the suite failed 34 of its 58 specs on CDN waits and strict locators, locally and in CI. The integration specs under `tests/integration/` remain the browser checks and gate every deploy. `npm audit` is clean.
- The `jekyll-jupyter-notebook` gem and the Jupyter toolchain. Notebook pages are rendered by the theme; only `nbformat` remains, for the notebook validation script.
- `_data/config/site.yml`, `theme.yml` and `features.yml`, which nothing read.

## [0.6.1] - 2026-09-11

### Fixed

- An overlay hero on the home page produced an empty id (and an "Empty `slug` generated" warning) because `/` slugifies to nothing; it now uses `post-hero-home`.

## [0.6.0] - 2026-09-11

### Added

- `tocify` Liquid filter (`_plugins/toc_filter.rb`): the table-of-contents includes called `content | tocify` but no plugin defined it, so the aside rendered the whole article. The filter builds nested `toc-list` lists from the rendered headings within the requested level range.
- `show_author: false` in front matter hides the byline in the article meta, for pages that are site chrome rather than articles.
- The footer's "Explore" column reads `footer:` from `_data/navigation.yml` when present, falling back to the demo sections.

### Fixed

- Prism was blocked on every page by a stale integrity hash for `prism.min.js` in `_data/cdn-integrity.yml`; the hashes are regenerated.
- The `<head>` emitted every SEO tag twice (title, description, Open Graph, Twitter, canonical, JSON-LD) because `{% seo %}` duplicated the theme's own markup; the tag is gone.
- The Content Security Policy blocked MathJax's accessibility data (`connect-src` now allows jsDelivr) and logged an error for a `report-uri` directive that `<meta>` policies cannot carry.
- The home-page hero set its background through a `style` attribute the policy blocks; it now uses a nonced style element.
- The header's search row overflowed the viewport on phones; it wraps below the brand now.
- `<body data-theme>` stays in sync with the effective theme when either theme control is used.
- The visualizations gallery's Plotly block gained the status, meta and toolbar markup the script and the docs expect.
- The `<head>` now writes the `<title>` itself for every page (`Page | Site`, or the site title on the home page); it used to rely on the removed SEO tag when no `seo_title` was set.
- Google Analytics was loaded with an empty measurement id because `google_analytics: ""` is truthy in Liquid; the tag is emitted only when an id is set.
- Google Fonts CSS and `gtag.js` are exempt from subresource integrity (both are served per-browser); the generator also ignores scratch directories, and the validator skips the notebook iframe documents nbconvert writes.
- Internal links written as root-absolute paths (the 404 page, the getting-started and tools pages, two posts, and the portfolio, post, package and project layouts) now go through `relative_url`, so the site works under a base path. A `browserconfig.xml` reference to a file that does not ship is gone.
- The deploy workflow builds the published artifact with the Pages base path, and runs the integration suite without the Percy-only `@visual` specs. `npm run test:integration` excludes those specs too, and the runner can start its static server on Windows.
- The archive layout grouped posts with `where_exp` expressions containing filters, which Jekyll's Liquid cannot parse; posts are now grouped by year and month with plain loops. Posts without a `difficulty` no longer trigger "Empty `slug` generated" warnings.
- The page layout printed the title and subtitle a second time above the article scaffold, which already renders them.
- The math preprocessor hooked both `documents` and `posts`, so every post was processed twice and display math came out nested. The inline pattern also matched the `$` of a `$$` block; it now requires single delimiters on both sides.
- `{% t %}` with a quoted key leaked the closing quote into the first option name, so `{% t 'post.reading_time' minutes=... %}` printed a literal `{{minutes}}`.
- Overlay post heroes set the background through an inline `style` attribute, which the Content Security Policy blocks. The image is now applied by a nonce'd `<style>` element scoped to the hero's id.
- Card thumbnails on card grids were stretched by the `height` attribute the image optimizer adds and by the grid stretching card bodies. Cards now keep their intrinsic thumbnail ratio and align their content to the top.
- The skip link peeked into the viewport before it received focus; it is now moved fully out of view until focused.

## [0.5.0] - 2026-09-11

### Added

- Minimal Mistakes front-matter compatibility (`_plugins/front_matter_compat.rb`): `header.image`, `header.overlay_image`, `header.teaser`, `header.og_image` and `header.twitter_image` map to a `post_hero` hash, `teaser`, `image`, `og_image` and `twitter_image`; `seo_description` fills `description`; a string `classes` value becomes a list. Explicit DataLog fields always win.
- Post hero component (`components/post-hero.html`): a title-over-image hero for overlay images and a figure for plain header images, with the Minimal Mistakes overlay filter syntax.
- `seo_title` support: when set, the `<title>` element and the social titles use it while the heading keeps the real title.
- `subtitle` rendered under the post title, and inside overlay heroes.
- Editorial provenance note (`components/content-provenance.html`) from `why_this_exists`, `evidence`, `methodology` and `reviewed_at`, with translations in all locales.
- Teaser thumbnails on home-page cards and related-post cards when a post has a `teaser`.
- `body.wide` styling so `classes: wide` lifts the reading measure inside the article.
- `jekyll-redirect-from` as a runtime dependency and demo plugin, so `redirect_from` front matter keeps old URLs alive.
- Tag and category links honour `site.tag_archive.path` and `site.category_archive.path`, the keys Minimal Mistakes uses, defaulting to `/tags/` and `/categories/`.
- A demo post written entirely in Minimal Mistakes front matter, a migration guide (`docs/migrating-from-minimal-mistakes.md`) and `tests/test_front_matter_compat.rb`.

### Fixed

- The image optimizer re-serialised any page containing a local image from an HTML fragment, which dropped the `<!DOCTYPE>`, `<html>` and `<head>` elements from the output. Full documents are now parsed and written back as documents.

### Changed

- The meta description now prefers an explicit `description` (or `seo_description`) over the auto-generated excerpt; previously the excerpt won even when a description was set.

## [0.4.0] - 2026-04-25

### Added

- Full author profile on the about page: photo placeholder, skills grid, experience timeline, education cards, and expanded `_data/config/author.yml` with skills/education/experience/bio fields.
- Sun/moon SVG icons for the dark mode toggle.
- Consolidated `requirements.txt` for Python dependencies, replacing duplicated `pip install nbformat jupyter` invocations across 7 workflows, both Dockerfiles, and `scripts/setup-dev.sh`.
- Test-tier matrix in `TESTING.md` documenting which workflows gate merges versus run on cron or release events.
- Repository layout table in `README.md` clarifying which paths ship in the gem versus which are demo content.
- Top-level link to `.env.example` from `README.md`.
- `bin/datalog` CLI executable is now tracked in git so the `datalog-theme` gem actually ships its declared executable.

### Changed

- Dependabot now targets the `develop` branch across all four ecosystems.
- `INSTALL.md` and `PLUGIN_DEVELOPMENT.md` moved under `docs/` (`docs/install.md`, `docs/plugin-development.md`).
- `GISCUS_REPO_ID` and `GISCUS_CATEGORY_ID` placeholder strings in `_config.yml` are now empty defaults pointing to <https://giscus.app>.
- `datalog-theme.gemspec` `spec.files` switched from a permissive deny-list to an allow-list. The packaged gem now ships only theme infrastructure (`_layouts/`, `_includes/`, `_sass/`, `_plugins/`, `_data/`, `assets/`, `lib/`, `bin/`) plus `LICENSE`, `README.md`, `CHANGELOG.md`, and `CITATION.cff` — down from ~440 files to ~175. Demo content (`_posts/`, `_pages/`, `_portfolio/`, `_datasets/`, `_packages/`, `_notebooks/`), tests, docs, scripts, CI configs, and frontend tooling no longer ship to RubyGems consumers.

### Removed

- Stale auto-generated `REPOSITORY_ANALYSIS.md` and `ANALYSIS_EXECUTIVE_SUMMARY.md` snapshots.
- Tracked CSP test artifact `csp-report.html` (now gitignored).
- Dead duplicate `_data/config/integrations.yml` (the live source is `site.integrations` in `_config.yml`).
- Redundant `demo/` stub directory (its README only restated that the repo root is the demo site).

## [0.3.0] - 2026-03-18

### Added
- Production Dockerfile with multi-stage nginx build and `.dockerignore`.
- ESLint flat config for browser JS, Node scripts, and Vitest tests.
- RuboCop config with auto-fixed style issues across all Ruby files.
- Unit tests for 6 previously untested Ruby plugins: reading_time, sri_filter, math_preprocessor, image_optimizer, publications_generator, warning_filter (69 tests, 199 assertions).
- Navigation module tests improving coverage from 84% to 96%.
- Search engine tests improving coverage from 79% to 97%.
- Skip-links accessibility tests improving coverage from 88% to 96%.
- Search engine test suite with 48 tests covering scoring, filters, fuzzy matching, and edge cases.
- Quarterly coverage review process with Q1 2026 baseline snapshot.
- Monthly security audit issue template.
- Stale issue/PR automation workflow with safe label exemptions.
- Release workflow for promoting develop to main with changelog gate.
- Project automation workflow for syncing priority labels to project fields.
- Branch-trigger policy, action-pinning policy, npm audit policy, Gemfile.lock strategy, and release process documentation.
- Issue SLA policy (P0–P3) in CONTRIBUTING.md with issue template link.
- Coverage review GitHub issue template.
- Security audit GitHub issue template.
- Top-level TESTING.md with quick-reference commands.
- Missing /research/ page for navigation.
- Missing favicon files (favicon.ico, 16x16, 32x32, 512x512, apple-touch-icon).

### Changed
- Redesigned homepage hero with background image and gradient overlay.
- Redesigned header as compact two-row layout with horizontal nav links.
- Redesigned footer from 11 sections to 4 clean sections plus copyright bar.
- Redesigned blog page with card grid layout matching homepage.
- Redesigned research page with citation metrics, area cards, submissions, and profiles.
- Redesigned projects page with featured project cards and performance metrics.
- Redesigned datasets page with license badges, schema info, and external resources.
- Redesigned packages page with theme-consistent card grid.
- Redesigned academic ops page with citation chart, submissions, events, and funding.
- Redesigned about page with data-driven header, publication cards, and community cards.
- Switched font family from Roboto to IBM Plex (Sans, Serif, Mono).
- Rebalanced color palette from all-blue to warm neutrals with teal/purple accents.
- Recalibrated coverage gates from 80/70/75/80 to 88/78/83/88 with per-module thresholds.
- Expanded config validator schema to cover markdown, highlighter, paginate, sass, features, notebooks, and SEO.
- Updated all CI workflows to target develop as default branch.
- Pinned all 16 GitHub Actions to commit SHAs across 11 workflow files.
- Upgraded lint-staged to run ESLint instead of echoing messages.
- Updated husky pre-commit hook: removed deprecated shebang, audit production deps only.
- Stripped console calls from production JS bundles via esbuild drop option.
- Made bundler-audit fail CI on actionable vulnerabilities.
- Guarded Codecov upload with secret availability check.
- Migrated deprecated Sass darken() calls to color.adjust().

### Fixed
- Main stylesheet loading synchronously when critical CSS is disabled (was deferred behind useless placeholder comment).
- SRI filter producing malformed HTML with doubled quote characters.
- Liquid syntax errors in research layout (Python-style and/or operators).
- Excluded docs/ directory from Jekyll build (eliminated missing 'doc' layout warnings).
- Broken documentation URL in site config.
- Date format test made locale-independent in search-render.
- RuboCop auto-fix that incorrectly renamed @identifier to @id in plugin system.
- Removed simulated social-proof metrics (fabricated view counts, active readers, completion rates).
- Removed newsletter subscribe form with no backend.

### Security
- Replaced 29 of 36 innerHTML usages with safer DOM APIs (replaceChildren, createElement, insertAdjacentHTML).
- Ran npm audit fix resolving 10 safe vulnerabilities.
- Created npm audit severity policy with exception process.
- Added action-pinning policy for supply-chain hardening.

## [0.2.0] - 2025-10-09
### Added
- Stability regression suite that validates notebook conversion, math rendering, search indexing, and visualization embeds during CI.
- GitHub Actions workflow that provisions notebook tooling and runs the new stability suite on every push and pull request.
- Comprehensive installation guide covering GitHub Pages deployment, local development, Docker workflows, configuration, and first-post authoring.
- Interactive `bin/datalog` command-line tool for scaffolding content, verifying dependencies, publishing to GitHub Pages, and updating the theme.

### Changed
- Bumped the theme version metadata and citation to publish the 0.2.0 release artifacts.

## [0.1.0] - 2024-02-29
### Added
- Initial public release with the core DataLog Jekyll theme, demo content, and documentation.

