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
