# Visual Testing Guide

The Playwright specs under `tests/visual/` check page structure at three viewports (mobile, tablet, desktop) without committing screenshots or using a snapshot service. They cover the home page, post layouts, the search page, dark mode and the visualization gallery.

## Prerequisites

* Node.js 22+
* The Playwright browsers: `npx playwright install chromium`

## Running the suites

```bash
# Integration specs: builds the site, serves it, runs the specs, cleans up
npm run test:integration

# Visual-structure specs, same bootstrap
npm run test:visual:auto

# Against a server you already run (set PLAYWRIGHT_BASE_URL first)
npm run test:integration:direct
npm run test:visual
```

The helper script serves `_site` on `http://127.0.0.1:4173` unless `PLAYWRIGHT_BASE_URL` is already set.

## Where they run in CI

The deploy workflow runs the integration specs against the freshly built site before publishing. The visual-structure specs are for local use; they are tagged `@visual` so `npm run test:integration` leaves them out.

## Stability helpers

`tests/visual/helpers.js` exports `waitForFonts`, `waitForMath` and `waitForViz`, which wait for font loading, MathJax or KaTeX rendering and visualization hydration before assertions, and `captureSnapshot`, a no-op placeholder to hook a snapshot service into if one is adopted again.
