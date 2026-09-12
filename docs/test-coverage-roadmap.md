---
layout: doc
title: Test Coverage Improvement Roadmap
nav_order: 13
---

# Test Coverage Improvement Roadmap

## Current Status

**JavaScript line coverage:** 91.05% ✅ (target 65%+, exceeded)

Coverage is no longer only a JavaScript unit-test question. Four suites run against
every change:

| Suite | Size | What it covers |
|-------|------|----------------|
| Vitest | 859 tests | JavaScript units, measured below |
| Minitest | 180 runs | Plugins, Liquid output, CSP, packaging |
| Playwright | 62 tests | The built site in a browser, both themes |
| Rake `ci:verify` | 12 scripts | Cross-cutting checks on the built output |

## Progress Summary

### Coverage by Module

| Module | Coverage | Status |
|--------|----------|--------|
| **Core Modules** | 96.11% | ✅ Excellent |
| `language-filter.js` | 100% | ✅ Complete |
| `scroll-progress.js` | 100% | ✅ Complete |
| `dark-mode.js` | 100% | ✅ Complete |
| `github-cards.js` | 98.3% | ✅ Excellent |
| `search-hotkeys.js` | 88.88% | ✅ Good |
| `skip-links.js` | 96% | ✅ Excellent |
| `navigation.js` | 96% | ✅ Excellent |
| **Search Modules** | 92.3% | ✅ Excellent |
| `filters.js` | 100% | ✅ Complete |
| `autocomplete.js` | 98.52% | ✅ Excellent |
| `analytics.js` | 97.77% | ✅ Excellent |
| `utils.js` | 97.72% | ✅ Excellent |
| `render.js` | 87.96% | ✅ Good |
| `app.js` | 84.1% | ✅ Good |
| `search.js` | 81.77% | ✅ Good |
| `engine.js` | 97.58% | ✅ Excellent |
| **Main Modules** | 89.7% | ✅ Excellent |
| `analytics-dashboard.js` | 100% | ✅ Complete |
| `math.js` | 94.91% | ✅ Excellent |
| `loader.js` | 95.16% | ✅ Excellent |
| `academic.js` | 92.53% | ✅ Excellent |
| `notebook.js` | 89.33% | ✅ Good |
| `visualizations.js` | 82.73% | ✅ Good |

## Phase 1: Completed ✅

- [x] Created comprehensive tests for core modules (31 tests)
- [x] Created comprehensive tests for search utilities (61 tests)
- [x] Improved coverage from 25.63% to 30.94%
- [x] Achieved 100% coverage on filters.js and utils.js
- [x] Updated vitest thresholds to realistic values

## Phase 2: Completed ✅

- [x] Added comprehensive tests for academic.js (92.53% coverage)
- [x] Added comprehensive tests for loader.js (93.75% coverage)
- [x] Added comprehensive tests for github-cards.js (98.3% coverage)
- [x] Added comprehensive tests for notebook.js (91.89% coverage)
- [x] Exceeded 50% overall coverage target

## Phase 3: Completed ✅

- [x] Added comprehensive tests for analytics-dashboard.js (100% coverage)
- [x] Improved math.js coverage (94.09%)
- [x] Improved visualizations.js coverage (82.88%)
- [x] Exceeded 65% overall coverage target (now at 89.37%!)

## Phase 4: Completed ✅

All three targets set for this phase have been met:

- [x] `navigation.js` 84% → 96%
- [x] `search/engine.js` 79% → 97.58%
- [x] `skip-links.js` 88% → 96%

## Phase 5: Beyond unit coverage

A day of auditing in September 2026 found several defects while JavaScript
coverage sat near 90%, which says something about where the remaining risk is.
None of them were reachable by a unit test:

- The published gem could not be used at all. It shipped a manifest pointing at
  browser bundles it did not contain, never registered its own Liquid tags, and
  omitted a runtime dependency. Every consumer site failed to build.
- The search index emitted each tag as a list of single characters, so the tag
  filter offered `a`, `b`, `[` instead of the real tags.
- Dark mode had unreadable components, including a heading rendering white on
  white, because no check had ever loaded the site in that theme.
- Two test reports were being published with the site.

### Guards added

| Guard | Catches |
|-------|---------|
| `tests/integration/axe.spec.js` | Contrast, accessible names and ARIA, in both themes |
| `tests/test_gem_package.rb` | A gem missing bundles, dependencies or tag registration |
| `scripts/verify_gem_package.rb` | The same, in the release workflow, before publishing |
| `tests/test_search_pages.rb` | Search pages missing from sites using the gem |
| `tests/test_search_index.rb` | Tag data that is an array but not of real tags |

### Where to look next

1. **Build a consumer site in CI.** Every gem defect above was found by
   installing the package and building a site with it. Nothing automated does
   this yet; the release workflow only inspects the package contents.
2. **Widen the browser audit.** The axe spec covers six pages. Pages such as
   `/datasets/`, `/research/` and `/academic/` are audited by hand only.
3. **Assert on data, not just shape.** The search index test passed throughout
   the tag corruption because the field was an array, of the wrong things.
   Other generated data files deserve the same scrutiny.

### Maintenance goals

- Keep JavaScript coverage above 85%
- Add tests for any new feature, at the level where the risk actually lives
- Prefer a guard that reproduces the failure over one that restates the code

## Testing Patterns & Best Practices

### Core Module Tests
```javascript
describe('Module Name', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
  });

  it('should initialize correctly', () => {
    // Setup
    document.body.innerHTML = '<div id="target"></div>';

    // Execute
    initModule();

    // Assert
    expect(document.querySelector('#target')).toBeTruthy();
  });

  it('should handle missing elements gracefully', () => {
    expect(() => initModule()).not.toThrow();
  });
});
```

### API/Async Tests
```javascript
it('should fetch data successfully', async () => {
  const mockData = { name: 'test' };
  global.fetch = vi.fn(() =>
    Promise.resolve({
      ok: true,
      json: () => Promise.resolve(mockData)
    })
  );

  const result = await fetchData();
  expect(result).toEqual(mockData);
});
```

### DOM Interaction Tests
```javascript
it('should respond to user interactions', () => {
  document.body.innerHTML = '<button id="test">Click</button>';
  const button = document.getElementById('test');
  const clickSpy = vi.fn();

  button.addEventListener('click', clickSpy);
  button.click();

  expect(clickSpy).toHaveBeenCalled();
});
```

## Implementation Strategy

### Week 1: Priority Modules (Phase 2)
- Days 1-2: academic.js tests
- Day 3: loader.js tests
- Day 4: github-cards.js tests
- Day 5: notebook.js tests

### Week 2: Depth Improvements (Phase 3)
- Days 1-2: analytics-dashboard.js tests
- Day 3: Improve math.js coverage
- Day 4: Improve visualizations.js coverage
- Day 5: Quick wins + buffer

### Week 3: Search Modules
- Days 1-2: search/app.js tests
- Day 3: search/autocomplete.js tests
- Day 4: search/render.js tests
- Day 5: search/analytics.js tests

## Continuous Improvement

### CI/CD Integration
- Coverage reports on every PR
- Block PRs that decrease coverage
- Weekly coverage trend reports
- Automated test generation suggestions

### Coverage Gates
- New files: minimum 70% coverage
- Modified files: cannot decrease coverage
- Critical modules: maintain 90%+ coverage

### Maintenance
- Monthly coverage review
- Quarterly test quality audit
- Update test fixtures with real data
- Refactor brittle tests

## Tools & Resources

### Current Setup
- Test framework: Vitest
- Coverage provider: v8
- Test environment: jsdom
- Assertion library: Vitest (Chai-compatible)

### Useful Commands
```bash
# Run all tests
npm test

# Run with coverage
npm run test:coverage

# Watch mode (development)
npm run test -- --watch

# Single file
npm test -- path/to/test.js

# Update snapshots
npm test -- --update
```

### Coverage Reports
- HTML report: `coverage/index.html`
- JSON data: `coverage/coverage-final.json`
- LCOV: `coverage/lcov.info`

## Success Metrics

### Achieved Targets ✅
- **Overall Coverage:** 89.37% (target was 65%+)
- **Core Modules:** 91.32% (target was 90%+)
- **Search Modules:** 88.08% (target was 75%+)
- **Main Modules:** 89.53% (target was 60%+)

### Quality Metrics
- Zero flaky tests ✅
- Fast execution (< 10s for all tests) ✅
- Clear test names ✅
- Comprehensive edge case coverage ✅
- Realistic test data ✅

## Blockers & Risks

### Resolved Issues ✅
1. ~~Some modules depend on browser APIs~~ - Using jsdom
2. ~~Async operations need careful mocking~~ - Comprehensive mocking in place
3. ~~Visual components hard to test~~ - Focus on logic with good coverage
4. ~~Third-party integrations require mocking~~ - Mock data created for all APIs

### Ongoing Considerations
- Keep tests up to date with code changes
- Monitor for flaky tests in CI
- Review coverage regularly

## Review & Sign-off

- [x] Phase 2 completed (50% coverage) ✅
- [x] Phase 3 completed (65% coverage) ✅
- [x] All critical modules above 70% ✅ (all above 79%!)
- [x] CI/CD gates implemented ✅
- [x] Documentation updated ✅

---

**Document Version:** 2.0
**Last Updated:** 2025-11-26
**Owner:** Development Team
**Status:** All targets exceeded - maintenance mode
