# Testing

Quick reference for running tests. See [docs/testing-guide.md](docs/testing-guide.md) for the full guide.

## Prerequisites

```bash
bundle install
npm install
```

## Commands

| Command | What it runs |
|---------|-------------|
| `npm test` | JavaScript unit tests (Vitest) |
| `npm run test:coverage` | Unit tests with coverage report |
| `npm run test:integration` | Playwright integration tests |
| `npm run test:visual` | Visual regression tests |
| `npm run test:visual:percy` | Visual tests with Percy snapshots |
| `bundle exec rake ci:verify` | Full Ruby verification suite |
| `bundler-audit check` | Ruby dependency vulnerability scan |
| `npm audit --omit=dev` | Node.js dependency vulnerability scan |

## What's required vs optional

The CI matrix is broad. Use this map to know which checks gate a merge and
which run in the background.

### Per-PR (must pass to merge into `develop`)

| Workflow | Config files | Purpose |
| --- | --- | --- |
| `test.yml` | `vitest.config.js`, `Rakefile`, `eslint.config.js`, `.rubocop.yml` | JS + Ruby unit tests, lint |
| `theme-stability.yml` | — | Theme builds clean against demo content |
| `accessibility.yml` | `pa11yci.json` | Pa11y a11y audit |
| `lighthouse.yml` | `lighthouserc.json` | Performance budgets |
| `percy.yml` | `percy.config.yml`, `playwright.config.js` | Visual regression snapshots |
| `codeql.yml` | — | Static security analysis |
| `dependency-review.yml` | — | New-deps vulnerability check |

### Scheduled (run on cron, do not block merges)

| Workflow | Cadence | Purpose |
| --- | --- | --- |
| `broken-links.yml` | Mondays 06:00 UTC | Crawl site for 4xx links |
| `dependency-review.yml` | Daily 02:00 UTC | Re-scan tracked deps |
| `codeql.yml` | Mondays 06:00 UTC | Re-scan code |
| `update-citations.yml` | Mondays 05:00 UTC | Refresh `_data/academic.yml` from Scholar |
| `stale.yml` | Mondays 09:00 UTC | Mark inactive issues/PRs |

### Release / event-driven

| Workflow | Trigger | Purpose |
| --- | --- | --- |
| `deploy.yml` | Push to `develop` | Build + publish GitHub Pages |
| `gem-release.yml` | Push tag `v*` | Publish theme gem |
| `release.yml` | `workflow_dispatch` | Cut a release branch |
| `project-sync.yml` | Issue labeled/opened | Mirror to GitHub Project |

### Local-only / not wired to CI

`bundler-audit check` and `npm audit` are useful locally but are exercised
inside `test.yml` rather than as standalone workflows.

## Coverage Requirements

| Metric | Gate | Current |
|--------|------|---------|
| Statements | 88% | 91% |
| Branches | 78% | 82% |
| Functions | 83% | 86% |
| Lines | 88% | 91% |

Current: **859 passing tests**. Gates are set ~3-5 points below baseline to catch regressions.

## Quarterly Coverage Review

Coverage is reviewed each quarter following the [coverage review process](docs/coverage-review-process.md). Past reviews are in [docs/coverage-history/](docs/coverage-history/).
