# Changelog

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

