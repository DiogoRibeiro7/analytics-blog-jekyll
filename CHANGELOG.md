# Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

