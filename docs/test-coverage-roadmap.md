---
layout: doc
title: Test Coverage Improvement Roadmap
nav_order: 13
---

# Test Coverage Improvement Roadmap

## Current Status

**JavaScript line coverage:** 91.59% ✅ (target 65%+, exceeded)

Coverage is no longer only a JavaScript unit-test question. Three suites run on
every pull request:

| Suite | Size | What it covers |
|-------|------|----------------|
| Vitest | 890 tests (2 skipped) | JavaScript units, measured below |
| Minitest | 271 runs (2 skipped), on Ruby 3.2, 3.3 and 3.4 | Plugins, Liquid output, CSP, packaging and the built site |
| Playwright | 69 tests (1 skipped) | The built site in Chromium, both themes, with axe-core |

The figures are from the Tests workflow on `develop` at v0.8.0. The `rake ci:verify`
scripts, which mostly checked source files for strings, were removed in 0.8.0; the
checks nothing else covered moved into Minitest, against the built site.

## Progress Summary

### Coverage by Module

Line coverage from `npm run test:coverage`.

| Module | Coverage | Status |
|--------|----------|--------|
| **Core Modules** | 96.08% | ✅ Excellent |
| `dark-mode.js` | 100% | ✅ Complete |
| `scroll-progress.js` | 100% | ✅ Complete |
| `github-cards.js` | 98.64% | ✅ Excellent |
| `navigation.js` | 96% | ✅ Excellent |
| `skip-links.js` | 96% | ✅ Excellent |
| `copy-buttons.js` | 93.1% | ✅ Excellent |
| `language-filter.js` | 90% | ✅ Excellent |
| `search-hotkeys.js` | 88.88% | ✅ Good |
| **Search Modules** | 92.43% | ✅ Excellent |
| `filters.js` | 100% | ✅ Complete |
| `autocomplete.js` | 98.55% | ✅ Excellent |
| `engine.js` | 98.33% | ✅ Excellent |
| `utils.js` | 97.95% | ✅ Excellent |
| `analytics.js` | 97.91% | ✅ Excellent |
| `render.js` | 87.59% | ✅ Good |
| `app.js` | 84.1% | ✅ Good |
| **Main Modules** | 90.35% | ✅ Excellent |
| `analytics-dashboard.js` | 100% | ✅ Complete |
| `academic.js` | 97.16% | ✅ Excellent |
| `loader.js` | 95.16% | ✅ Excellent |
| `math.js` | 94.91% | ✅ Excellent |
| `notebook.js` | 89.33% | ✅ Good |
| `visualizations.js` | 84.58% | ✅ Good |
| `search.js` | 80.32% | ✅ Good |

`search.js` is the search orchestrator in `assets/js/`, so it counts with the main
modules.

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

### Where we looked next

1. **Build a consumer site in CI.** ✅ Done. `tests/test_gem_consumer.rb` builds a
   minimal site against the gemspec's file list and against a checkout of the
   repository, in the Ruby test jobs. It fails if the build breaks or if the site
   publishes the maintainer's details.
2. **Widen the browser audit.** Still open, and carried into Phase 6. The axe spec
   still covers six pages.
3. **Assert on data, not just shape.** Partly done. `tests/test_head_metadata.rb`
   parses every page's JSON-LD and rejects empty values, and
   `tests/test_related_posts.rb` checks which posts a post lists, not only that a
   list exists.

## Phase 6: Check what renders, not what is on the page

A second audit on 13 September 2026 (issues #195 to #206), and the work on the
Content Security Policy that followed it, found defects that every suite passed:

- MathJax typeset no equation on any page. Its configuration loaded the
  `\require` extension, which stopped MathJax while it started up.
  `tests/test_math_rendering.rb` checked that the script and its configuration
  were on the page, and axe passed the math pages because the expressions were
  still plain text.
- The browser refused the inline scripts on notebook pages, because their
  templates printed an empty nonce.
- Plotly, Jupyter widget and Bokeh blocks never rendered. The theme called a
  `WidgetManager` the widget library does not export, and the browser test's stub
  of that library offered one, so the test passed.
- Disqus comments, Observable embeds and a slide deck were refused by the policy
  or pointed at addresses that no longer exist.
- Related posts never appeared, and search matched no code.
- `rake ci:verify` passed whether or not the built site worked.

The MathJax, notebook, Bokeh and embed defects were found by a script that loaded
pages in Chromium and recorded CSP violations, page errors and failed requests.
It was run by hand and is not in the repository.

### Guards added in 0.8.0

| Guard | Catches |
|-------|---------|
| `tests/test_csp_pages.rb` | A nonce the page's policy does not name; math, Disqus and Observable sources missing from the policy |
| `tests/integration/csp-charts.spec.js` | Plotly and widget blocks that do not render or cause a CSP violation, with the real libraries |
| `tests/test_site_output.rb` | What `ci:verify` checked, against the built site, and in-page links that lead nowhere |
| `tests/test_page_structure.rb` | More than one `<h1>`, footer headings and landmarks, and a theme script that runs too late |
| `tests/test_head_metadata.rb` | Repeated head tags, empty verification tags, indexed utility pages, and JSON-LD that does not parse or has empty values |
| `tests/test_gem_consumer.rb` | A site using the theme that does not build, or that publishes the maintainer's details |
| `tests/test_workflows.rb` | Release and CI guards removed from the workflows |
| Lint job | ESLint and RuboCop offenses; both linters ran in no workflow before |
| Ruby Tests on 3.3 and 3.4 | Ruby code that works on 3.2 only |
| Browser Tests and coverage on pull requests | Playwright and coverage failures that used to surface only after a merge |
| Docker Images workflow | Dockerfiles that no longer build |

### Where to look next

1. **Check rendered output on every kind of page.** A Playwright spec could load
   each page with math, a notebook, an embed or comments, wait for what should
   appear (an `mjx-container`, a chart, an iframe), and fail on any CSP violation,
   page error or failed request. `csp-charts.spec.js` does this for two pages.
2. **Widen the axe audit.** Carried over from Phase 5. The spec covers six pages;
   `/research/`, `/academic/`, `/datasets/`, `/notebooks/` and the notebook pages
   are audited by hand only. axe judges only what has rendered: the math wrapper's
   ARIA error and MathJax's positive `tabindex` surfaced once equations rendered.
3. **Test against the real library, not a stub of it.** A stub repeats the theme's
   assumptions about a library's API. Where the theme calls a third-party library,
   one test should load the pinned version, as `csp-charts.spec.js` does for Plotly
   and the widget manager.
4. **Check external addresses.** The broken-links workflow runs lychee with
   `--offline`, so it checks only links within the site. External links and the
   embed addresses in `data-viz-src` are never requested; two Observable notebooks
   returned 404 and the slide host did not resolve, and nothing reported it.
5. **Move to Vitest 5.** #214 and #215 are held. Vitest 5 rejects the `vi.mock`
   call that is not at the top level of `tests/js/loader.test.js`, and 15 search
   app tests fail with "Cannot set property history of [object Window]".
6. **Measure Ruby coverage.** Nothing measures how much of `_plugins/` and `lib/`
   the Minitest suite runs; the figures above cover JavaScript only.

### Maintenance goals

- Keep JavaScript coverage above the thresholds in `vitest.config.js` and
  `scripts/check_coverage.js`
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

## Continuous Improvement

### CI/CD Integration
- Every pull request runs Vitest with coverage, Minitest on Ruby 3.2, 3.3 and 3.4,
  Playwright with axe-core, ESLint and RuboCop
- The Tests workflow fails when coverage drops below the thresholds
- Coverage is uploaded to Codecov on pushes, when the `CODECOV_TOKEN` secret is set

### Coverage Gates
- Whole suite (`vitest.config.js`): statements 88%, branches 78%, functions 83%, lines 88%
- Critical modules (`scripts/check_coverage.js`, statement coverage):

| Module | Minimum |
|--------|---------|
| `search/engine.js` | 93% |
| `core/navigation.js` | 93% |
| `math.js` | 90% |
| `core/` (average) | 90% |
| `search/` (average) | 85% |
| `search.js` | 78% |
| `visualizations.js` | 78% |

No gate applies to a new or modified file on its own.

### Maintenance
- Quarterly coverage review, following
  [coverage-review-process.md](coverage-review-process.md); the last record in
  `docs/coverage-history/` is 2026-Q1
- Update test fixtures with real data
- Refactor brittle tests

## Tools & Resources

### Current Setup
- Unit tests: Vitest, with the v8 coverage provider and jsdom
- Ruby tests: Minitest, run by `bundle exec rake test`
- Browser tests: Playwright in Chromium, with axe-core
- Assertion library: Vitest (Chai-compatible)

### Useful Commands
```bash
# Run the JavaScript unit tests
npm test

# Run with coverage and the per-module minimums
npm run test:coverage

# Watch mode (development)
npx vitest

# Single file
npm test -- path/to/test.js

# Build the site and run the Ruby suite
bundle exec rake test

# Build the site and run the Playwright suite
npm run test:integration

# Lint JavaScript and Ruby
npm run lint
bundle exec rubocop
```

### Coverage Reports
- HTML report: `coverage/index.html`
- JSON data: `coverage/coverage-final.json`
- LCOV: `coverage/lcov.info`

## Success Metrics

### Achieved Targets ✅
- **Overall Coverage:** 91.59% (target was 65%+)
- **Core Modules:** 96.08% (target was 90%+)
- **Search Modules:** 92.43% (target was 75%+)
- **Main Modules:** 90.35% (target was 60%+)

### Run Times
- Vitest: about 27 s locally, 7 s of it in the tests themselves
- Playwright: about 34 s in CI

## Blockers & Risks

### Resolved Issues ✅
1. ~~Some modules depend on browser APIs~~ - Using jsdom
2. ~~Async operations need careful mocking~~ - Comprehensive mocking in place
3. ~~Visual components hard to test~~ - Focus on logic with good coverage
4. ~~Third-party integrations require mocking~~ - Mock data created for all APIs

### Ongoing Considerations
- Stubs of third-party libraries can drift from the real APIs (see Phase 6)
- Vitest 5 is held until the tests are migrated (#214, #215)
- Keep tests up to date with code changes
- Monitor for flaky tests in CI

## Review & Sign-off

- [x] Phase 2 completed (50% coverage) ✅
- [x] Phase 3 completed (65% coverage) ✅
- [x] All critical modules above 70% ✅ (all above 80%)
- [x] CI/CD gates implemented ✅
- [x] Consumer site built in CI (Phase 5) ✅
- [x] Documentation updated ✅

---

**Document Version:** 3.0
**Last Updated:** 2026-09-15
**Owner:** Development Team
**Status:** Coverage targets exceeded; Phase 6 open
