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
| `npm run test:coverage` | The same, with coverage, against the thresholds in `vitest.config.js` |
| `npm run test:integration` | Playwright integration tests, including the axe sweep |
| `bundle exec rake test` | Builds the demo site and runs the Minitest suite against it |
| `bundle exec rake coverage` | The same, under SimpleCov, against the thresholds in `.simplecov` |
| `bundler-audit check` | Ruby dependency vulnerability scan |
| `npm audit --omit=dev` | Node.js dependency vulnerability scan |

Running one file or one test, the conventions the suite follows, the fixtures
it offers and the things that will catch you out are in
[docs/testing-guide.md](docs/testing-guide.md).

## What's required vs optional

The CI matrix is broad. Use this map to know which checks gate a merge and
which run in the background.

### Per-PR (must pass to merge into `develop`)

| Workflow | Config files | Purpose |
| --- | --- | --- |
| `test.yml` | `vitest.config.js`, `Rakefile`, `eslint.config.js`, `.rubocop.yml` | JS + Ruby unit tests, lint |
| `accessibility.yml` | `pa11yci.json` | Pa11y a11y audit, in the runner's own Chrome |
| `lighthouse.yml` | `lighthouserc.json` | Performance budgets |
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

### Local-only / not wired to CI

`bundler-audit check` and `npm audit` are useful locally but are exercised
inside `test.yml` rather than as standalone workflows.

## Coverage Requirements

Both halves are measured and both gate. The gates sit a few points below the
measurement, so a regression fails and an ordinary change does not.

| Metric | Gate | Measured | Where the gate lives |
|--------|------|----------|----------------------|
| JS statements | 88% | 91.7% | `vitest.config.js` |
| JS branches | 78% | 81.9% | `vitest.config.js` |
| JS functions | 83% | 88.6% | `vitest.config.js` |
| JS lines | 88% | 92.0% | `vitest.config.js` |
| Ruby lines | 81% | 84.5% | `.simplecov` |
| Ruby branches | 59% | 62.7% | `.simplecov` |

Measured on 2026-09-23, over **581 Minitest tests, 1,094 Vitest tests and 137
Playwright tests**. Those two configuration files are the authority; this table
is a summary and may lag.

## Quarterly Coverage Review

Coverage is reviewed each quarter following the [coverage review process](docs/coverage-review-process.md). Past reviews are in [docs/coverage-history/](docs/coverage-history/).
