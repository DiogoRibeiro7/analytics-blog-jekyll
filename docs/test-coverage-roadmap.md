---
layout: doc
title: Test Coverage Improvement Roadmap
nav_order: 13
---

# Test Coverage Improvement Roadmap

## Current Status

**JavaScript line coverage:** 92.16% ✅ (gate 88%)
**Ruby line coverage:** 89.67%, branch 70.5% ✅ (gates 81% and 59%)

Three suites run on every pull request:

| Suite | Size | What it covers |
|-------|------|----------------|
| Vitest | 1,170 tests (2 skipped) in 41 files | JavaScript units, measured below |
| Minitest | 798 runs in 86 files, on Ruby 3.2, 3.3 and 3.4 | Plugins, the CLI, Liquid output, CSP, packaging, the built site and sites built against the gem |
| Playwright | 184 tests (13 skipped) in 31 specs, and 12 for the documentation site | The built site in Chromium, both themes, with axe-core on 16 pages |

The figures are from the Tests workflow on `develop` at v0.11.0 (c6571ff). Ruby
coverage is measured by SimpleCov on the Ruby 3.4 leg (`bundle exec rake coverage`),
over everything in `lib/` and `_plugins/`, including the sites the consumer tests
build in a subprocess; `.simplecov` holds the gates.

## Progress Summary

### Coverage by Module

Line coverage from `npm run test:coverage`. ⚠️ marks a module below 80%, or one
that has fallen by more than five points since the 0.8.0 figures.

| Module | Coverage | Status |
|--------|----------|--------|
| **Core Modules** (`core/`) | 93.11% | ✅ Excellent |
| `dark-mode.js` | 100% | ✅ Complete |
| `scroll-progress.js` | 100% | ✅ Complete |
| `github-cards.js` | 98.64% | ✅ Excellent |
| `code-blocks.js` | 97.36% | ✅ Excellent |
| `install-tabs.js` | 96.87% | ✅ Excellent |
| `navigation.js` | 96% | ✅ Excellent |
| `skip-links.js` | 96% | ✅ Excellent |
| `toc.js` | 91.78% | ✅ Excellent |
| `language-filter.js` | 90% | ✅ Excellent |
| `search-hotkeys.js` | 88.88% | ✅ Good |
| `copy-buttons.js` | 65.95% | ⚠️ was 93.1% |
| **Search Modules** (`search/`) | 92.81% | ✅ Excellent |
| `filters.js` | 100% | ✅ Complete |
| `autocomplete.js` | 98.55% | ✅ Excellent |
| `utils.js` | 97.95% | ✅ Excellent |
| `analytics.js` | 97.91% | ✅ Excellent |
| `engine.js` | 97.51% | ✅ Excellent |
| `render.js` | 89.44% | ✅ Good |
| `app.js` | 84.1% | ✅ Good |
| **Main Modules** (`assets/js/*.js`) | 88.5% | ✅ Good |
| `academic.js` | 97.29% | ✅ Excellent |
| `analytics-dashboard.js` | 96.72% | ✅ Excellent |
| `math.js` | 95.83% | ✅ Excellent |
| `notebook.js` | 89.33% | ✅ Good |
| `visualizations.js` | 84.64% | ✅ Good |
| `loader.js` | 84.28% | ⚠️ was 95.16% |
| `search.js` | 78.49% | ⚠️ was 80.32% |
| **Feature Modules** (added since 0.8.0) | | |
| `dynamic-services/` (`client.js`, `form-state.js`) | 98.74% | ✅ Excellent |
| `corrections/` | 98.48% | ✅ Excellent |
| `subscriptions/` | 98.08% | ✅ Excellent |
| `contact/form.js` | 97.26% | ✅ Excellent |
| `reactions/widget.js` | 96.68% | ✅ Excellent |
| `math/latex-speech.js` | 95.96% | ✅ Excellent |
| `comments/thread.js` | 95.7% | ✅ Excellent |
| `webmentions/list.js` | 95.51% | ✅ Excellent |
| `moderation/inbox.js` | 95.16% | ✅ Excellent |
| `reading-state/` | 88.69% | ✅ Good |

`search.js` is the search orchestrator in `assets/js/`, so it counts with the main
modules. The main modules' figure includes eight entry files at 0%
(`comments.js`, `contact.js`, `corrections.js`, `moderation.js`, `reactions.js`,
`reading-state.js`, `subscriptions.js`, `webmentions.js`): each only starts its
feature module on the page, and the tests import the feature modules directly.

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

### Where we looked next

Where each item stood at 0.11.0:

1. **Check rendered output on every kind of page.** Partly done. The maths specs
   (`math-decoration`, `math-display`, `math-rerender`) wait for MathJax to typeset
   the demo article and check what it drew, and `csp-charts.spec.js` and
   `reading-state.spec.js` fail on page errors. No spec yet loads every kind of
   page and fails on any CSP violation, page error or failed request.
2. **Widen the axe audit.** Mostly done. The sweep covers 16 pages, among them
   `/academic/`, the package pages, a notebook, and the search page with results
   showing. `/research/`, `/datasets/` and `/notebooks/` are still audited by hand.
3. **Test against the real library, not a stub of it.** Partly done. The maths
   specs run the pinned MathJax from the CDN, which is how the collapse-on-click
   (#412) and start-up (#421) defects were found, and `csp-charts.spec.js` loads
   Plotly and the widget manager.
4. **Check external addresses.** Still open. The broken-links workflow runs lychee
   with `--offline`, so external links and the embed addresses in `data-viz-src`
   are never requested.
5. **Move to Vitest 5.** ✅ Done. The suite runs on Vitest 5.
6. **Measure Ruby coverage.** ✅ Done. SimpleCov measures `lib/` and `_plugins/` on
   the Ruby 3.4 leg, including the consumer sites built in a subprocess, and fails
   the job below 81% of lines or 59% of branches.

## Phase 7: What a passing suite still missed

The releases from 0.9.0 to 0.11.0 fixed defects that every suite passed. They
have a shape in common: each test looked where the defect wasn't.

- **The toolkit never decorated a real article** (#329). MathJax hands over its
  expressions as a linked list, the toolkit called `forEach` on it, and a `catch`
  swallowed the error. The unit tests mocked the list as an array, the one shape it
  never has.
- **What a test spelled out was all it checked** (#417). The screen-reader name of
  each expression was derived twice, once by the build and once in the browser,
  and both dropped every LaTeX command they had no rule for. The tests checked
  what each copy spelled out (an integral, a fraction), never what it dropped, and
  the page showed the build's copy, where the browser's had most of the tests.
- **One load order was never tested** (#421). The toolkit started only if its
  script arrived before MathJax was ready. Every test loaded pages with an empty
  cache, where it always did; with MathJax cached, about one reload in six left
  the page undecorated.
- **axe passed what it could not judge** (#415). It leaves text over a gradient or
  a pseudo-element undecided rather than failing it, and passes over single
  characters. The notebook header's values were at 2.1:1 in dark mode, and 14
  syntax-token colours, punctuation among them, at about 2:1 in every dark-mode
  code block.
- **A click was never made** (#412). A click on a formula collapsed part of it, and
  the redrawn expression lost its name, its tab stop and the focus. No test
  clicked a formula.

### Guards added

| Guard | Catches |
|-------|---------|
| `tests/fixtures/latex-speech.json`, run by `test_latex_speech.rb` and `latex-speech.test.js` | The build's and the browser's labels saying different things |
| The start-up test in `math-decoration.spec.js` | A toolkit that does not start when `math.js` loads after MathJax |
| `tests/integration/notebook-contrast.spec.js` | Low contrast that axe leaves undecided, measured against the layers under each text |
| `test_toc_and_contrast.rb` (dark palette, token colours) | A dark ink that does not read on the dark surfaces, a code token with no dark colour |
| `tests/integration/math-rerender.spec.js` | A redrawn expression that loses its name, tab stop or focus |
| SimpleCov gates | Ruby code the suite stops running |

### Where to look next

1. **Measure contrast where axe can't, on every page.** Only the notebook page's
   text is measured against what it sits on. Other components with a gradient or
   an overlay (cards, the home hero, the package header) rely on axe alone.
2. **Force the other load orders.** Comments, charts and the analytics dashboard
   also wait on a script that may arrive first or second. A test can hold one back
   with `page.route`, as the start-up test does for `math.js`.
3. **Find the behaviours written twice.** Where the build and the browser both
   produce the same output, one fixture should check both, as the LaTeX labels'
   does.
4. **Win back the coverage that fell.** `copy-buttons.js` is down from 93.1% to
   65.95%, `loader.js` from 95.16% to 84.28%, and `search.js` is just under 80%.
5. **Carried over:** the rendered-output spec, the last three pages for axe, and
   external addresses, from Phase 6.

## Maintenance goals

- Keep JavaScript coverage above the thresholds in `vitest.config.js` and
  `scripts/check_coverage.js`, and Ruby coverage above the gates in `.simplecov`
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
- Ruby (`.simplecov`, on the Ruby 3.4 leg): lines 81%, branches 59%
- Whole JavaScript suite (`vitest.config.js`): statements 88%, branches 78%, functions 83%, lines 88%
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
- **Overall JavaScript coverage:** 92.16% (target was 65%+)
- **Core Modules:** 93.11% (target was 90%+)
- **Search Modules:** 92.81% (target was 75%+)
- **Main Modules:** 88.5% (target was 60%+), counting the eight entry files at 0%
- **Ruby coverage:** 89.67% of lines, 70.5% of branches

### Run Times
In CI at 0.11.0:
- Vitest: 11 s on Node 24, 23 s with coverage on Node 22
- Minitest: about 1 minute, and 1.5 minutes under SimpleCov
- Playwright: about 1.8 minutes

## Blockers & Risks

### Resolved Issues ✅
1. ~~Some modules depend on browser APIs~~ - Using jsdom
2. ~~Async operations need careful mocking~~ - Comprehensive mocking in place
3. ~~Visual components hard to test~~ - Focus on logic with good coverage
4. ~~Third-party integrations require mocking~~ - Mock data created for all APIs

### Ongoing Considerations
- Stubs of third-party libraries can drift from the real APIs (see Phase 6)
- A test can only find a defect where it looks: a mocked shape, one load order or
  one copy of a behaviour (see Phase 7)
- Keep tests up to date with code changes
- Monitor for flaky tests in CI. The Performance audit's critical CSS step timed
  out once at 0.11.0 while a page loaded its external resources, and passed when
  run again

## Review & Sign-off

- [x] Phase 2 completed (50% coverage) ✅
- [x] Phase 3 completed (65% coverage) ✅
- [x] All critical modules above 70% ✅ (all above 80%)
- [x] CI/CD gates implemented ✅
- [x] Consumer site built in CI (Phase 5) ✅
- [x] Ruby coverage measured and gated (Phase 6) ✅
- [x] Documentation updated ✅

---

**Document Version:** 4.0
**Last Updated:** 2026-10-04
**Owner:** Development Team
**Status:** Coverage targets exceeded; Phase 7 open
