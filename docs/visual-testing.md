# Visual Testing Guide

This guide explains how to run the Playwright-powered UI regression suites and share Percy snapshots on pull requests without storing binary baselines in the repository.

## Prerequisites

* Node.js 20+
* The Playwright browsers (`npx playwright install`)
* Optional: a Percy account and `PERCY_TOKEN` for cloud comparisons

## Running the suites locally

The Playwright helper script handles the full bootstrap (build → serve → run → clean up). Use it for both integration and visual workflows:

```bash
# Integration scenarios (keyboard navigation, async flows, etc.)
npm run test:integration

# Visual semantics plus optional Percy snapshots
npm run test:visual:auto
```

The script spins up a static server on `http://127.0.0.1:4173` unless `PLAYWRIGHT_BASE_URL` is already set. To run Percy locally, supply the token while using the automated helper:

```bash
PERCY_TOKEN=... npm run test:visual:percy
```

Already running a preview server? Call the direct Playwright commands instead:

```bash
# Uses the existing PLAYWRIGHT_BASE_URL environment variable
npm run test:integration:direct
npm run test:visual
```

## Percy workflow

Pull requests automatically run the `.github/workflows/percy.yml` job when `PERCY_TOKEN` is configured in the repository secrets. The job:

1. Builds the production site with Jekyll.
2. Hosts the generated `_site` output.
3. Executes the Playwright suites tagged with `@visual`.
4. Uploads each scenario via `percy exec`, which applies the configuration in `percy.config.yml` (viewport widths 375/768/1920 and JavaScript enabled).

Percy opens a review for every PR. Approving the Percy build marks the visual check as passed.

### Setting up the Percy token

1. Visit **Settings → Secrets and variables → Actions** in the GitHub repository UI.
2. Create a new repository secret named `PERCY_TOKEN` and paste the token from your Percy project settings.
3. Re-run or trigger a pull request so the "Visual regression (Percy)" workflow executes with the new token.
4. Approve the Percy build following the steps in the [workflow](#percy-workflow) section above.

With the secret in place, every pull request automatically uploads snapshots for review, and missing secrets are now an explicit configuration step rather than an implicit failure.

### Handling Percy approvals

* Review Percy’s diff UI to inspect changes against the previous baseline.
* Approve intended changes so the GitHub status check succeeds.
* Request fixes or push follow-up commits when unexpected differences appear.

Minor anti-aliasing differences can be auto-approved if Percy flags them as low severity. Otherwise, confirm the change is acceptable before approving.

## What the Playwright assertions cover

Because binary screenshots are not tracked in git, the Playwright scenarios validate semantics instead of pixel output. Each spec checks for:

* Visible hero sections, navigation controls, and card grids across the standard viewports.
* Search form labels, filter controls, live regions, and populated result metadata.
* Visualization fallbacks including data-table toggles, captions, and header scope.
* Dark-mode theming by inspecting runtime color tokens and `dark-mode` classes.

These checks provide fast feedback during local development while Percy supplies full visual diffing when enabled.

## Troubleshooting

* **`PLAYWRIGHT_BASE_URL` not set** – Export the environment variable before running tests.
* **Fonts or math still loading** – The shared helper waits for fonts, MathJax, and visualizations. If you add new async assets, extend `tests/visual/helpers.js` accordingly.
* **Percy build fails** – Check the GitHub Actions logs for Playwright failures. Re-run the job after fixing issues or retrigger it from the Percy UI if the diff was already approved.
