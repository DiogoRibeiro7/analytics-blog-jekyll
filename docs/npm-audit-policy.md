# npm Audit Severity Policy

Defines which npm audit findings block CI and when exceptions are permitted.

## Severity Thresholds

| Context | Blocking Severity | Scope |
|---------|------------------|-------|
| **Pre-commit hook** | high, critical | Production deps only (`--omit=dev`) |
| **CI (test/deploy)** | high, critical | Production deps only |
| **Dependency review workflow** | high, critical | Production deps only (`--omit=dev`); moderate+ across all deps is reported, not blocking |
| **Manual review** | low, moderate | Dev deps — reviewed quarterly |

### Rationale

- **Critical / High in production deps** — must be resolved before merge. These can affect end users.
- **Moderate in production deps** — should be resolved within 2 weeks. Non-blocking in CI to avoid stalling unrelated work.
- **Dev dependency vulnerabilities** — tracked but non-blocking. Most dev deps (test runners, build tools) never reach production output.

## CI Configuration

### Pre-commit hook (`.husky/pre-commit`)

```bash
npm audit --audit-level=high --omit=dev
```

Blocks commit if high/critical production vulnerabilities exist.

### Dependency review workflow (`.github/workflows/dependency-review.yml`)

Two steps in the `npm-audit` job, on push, PR and the nightly schedule:

1. `npm audit --audit-level=high --omit=dev` — blocking. Same gate as the pre-commit hook.
2. `npm audit --audit-level=moderate` — advisory. The full report goes to the job summary, a `::warning::` annotation carries the counts, and the JSON is uploaded as the `npm-audit-results` artifact. This step never fails the job.

## Exception Process

When a vulnerability cannot be immediately fixed (e.g., waiting for upstream patch):

1. **Document the exception** — create a GitHub issue with the `security` label describing:
   - Advisory ID (GHSA-xxxx)
   - Affected package and version
   - Why it can't be fixed now
   - Mitigation in place (if any)
   - Expected resolution date

2. **Track in audit config** — if needed, add to `.nsprc` or `audit-resolve.json` to suppress the known advisory in CI. This must reference the tracking issue.

3. **Review quarterly** — all exceptions are reviewed during the [quarterly coverage review](coverage-review-process.md). Stale exceptions must be resolved or re-justified.

## Current Known Exceptions

| Advisory | Package | Reason | Tracking Issue | Expires |
|----------|---------|--------|----------------|---------|
| GHSA-vwc7-r8mq-g2x9 | adm-zip (via @percy/core) | Every published release from 0.5.9 to the latest 0.6.0 is affected, so there is no version to move to. Dev-only: the Percy CLI, which does not run in CI without a `PERCY_TOKEN`. `npm audit` also lists the ten `@percy/*` packages that depend on it under this one advisory. | N/A | First adm-zip release after 0.6.0 |

Resolved exceptions (kept for the record): `@tootallnate/once` via `critical` (gone with `critical` 8), `yauzl` via `@percy/core` (no longer reported).

Transitive pins in `package.json` `overrides` (`fast-xml-parser`, `uuid`, `snyk-nodejs-lockfile-parser`) exist only because `@percy/cli` pins older versions of them; drop the overrides once Percy updates its own dependencies.

## Updating This Policy

Changes to severity thresholds or the exception process require a PR with the `security` label and review from a maintainer.
