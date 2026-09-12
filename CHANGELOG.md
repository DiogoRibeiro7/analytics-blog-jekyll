# Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `tests/test_gem_consumer.rb` builds a minimal site against the packaged theme and against a checkout of the repository, and fails if the build breaks or publishes anything that identifies the maintainer.

### Changed

- The release workflow promotes a `release/vX.Y.Z` branch to `main` instead of promoting `develop` itself, so the pull request and the merge commit on `main` name the release rather than reading "from develop". `develop` still receives the version bump.
- The installation guide covers what a site supplies itself (pages, navigation, social links), installing from a Git checkout, and publishing to GitHub Pages with GitHub Actions. It replaces instructions for the built-in Pages build, which cannot run the theme.

### Fixed

- Sites installing the gem published part of the demo site. The maintainer's CV templates and publication exports were copied into every site, and the demo's social profiles, contact addresses and academic profiles reached the footer and the script data on every page through `_data`. The gem now contains only the `_data` files the layouts need (translations, the script manifest and CDN integrity hashes) and none of the demo's downloads, and `scripts/verify_gem_package.rb` refuses a gem that does.
- A site installing the theme from a Git checkout or a local path inherited the whole demo site. Jekyll merged the demo's `_config.yml` into the site's configuration, so the build stopped on a `datasets` feed for a collection the site did not have, and a site that declared the collection to get past it carried the maintainer's author details, contact addresses and social profiles. The build now stops with an explanation until the site sets `ignore_theme_config: true`, and with that set the theme also leaves out the demo's `_data` files and downloads.
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

