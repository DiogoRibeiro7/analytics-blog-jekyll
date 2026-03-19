# Quarterly Coverage Review Process

A repeatable process to review test coverage trends, identify gaps, and prioritize improvements.

## Schedule

Reviews happen at the start of each quarter: **January, April, July, October**.

## Before the Review

Run the coverage report and save the output:

```bash
npm run test:coverage > coverage-report.txt 2>&1
```

## Review Checklist

For each module in the coverage report:

### 1. Record Current Coverage

Fill in the table below with current values from `npm run test:coverage`:

| Module | Statements | Branches | Functions | Lines | Trend |
|--------|-----------|----------|-----------|-------|-------|
| academic.js | | | | | |
| analytics-dashboard.js | | | | | |
| loader.js | | | | | |
| math.js | | | | | |
| notebook.js | | | | | |
| search.js | | | | | |
| visualizations.js | | | | | |
| core/dark-mode.js | | | | | |
| core/github-cards.js | | | | | |
| core/navigation.js | | | | | |
| core/scroll-progress.js | | | | | |
| core/search-hotkeys.js | | | | | |
| core/skip-links.js | | | | | |
| search/analytics.js | | | | | |
| search/app.js | | | | | |
| search/autocomplete.js | | | | | |
| search/engine.js | | | | | |
| search/filters.js | | | | | |
| search/render.js | | | | | |
| search/utils.js | | | | | |

### 2. Compare to Previous Quarter

- [ ] Did any module drop below its previous coverage?
- [ ] Did any module drop below the project minimums (80% statements, 70% branches)?
- [ ] Were new modules added without tests?

### 3. Identify Priority Gaps

Rank the top 3 modules needing improvement by:
1. Lowest branch coverage (most likely to hide bugs)
2. Most changed files since last review (`git log --since="3 months ago" --name-only`)
3. Critical user paths (navigation, search, math rendering)

### 4. Check Ruby Plugin Coverage

```bash
bundle exec ruby -Itests -e "Dir['tests/test_*.rb'].sort.each { |f| require_relative f }"
```

- [ ] All plugin test files pass
- [ ] Any new plugins in `_plugins/` have corresponding tests in `tests/`

### 5. Create Action Items

For each gap identified, create a GitHub issue:

```bash
gh issue create --title "test: improve [module] coverage to [target]%" --label "testing" --body-file .github/ISSUE_TEMPLATE/coverage-gap-body.md
```

## After the Review

- [ ] Coverage table committed to `docs/coverage-history/YYYY-QN.md`
- [ ] Action items created as GitHub issues
- [ ] Next review date added to calendar

## Coverage Minimums

| Metric | Minimum | Target |
|--------|---------|--------|
| Statements | 80% | 90% |
| Branches | 70% | 85% |
| Functions | 75% | 90% |
| Lines | 80% | 90% |

Modules on critical user paths (navigation, search, math) should target 95%+.
