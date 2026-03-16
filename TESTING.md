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

## Coverage Requirements

- Statements: 80%
- Branches: 70%
- Functions: 75%
- Lines: 80%

Current coverage: **~93%** (850 passing tests).

## Quarterly Coverage Review

Coverage is reviewed each quarter following the [coverage review process](docs/coverage-review-process.md). Past reviews are in [docs/coverage-history/](docs/coverage-history/).
