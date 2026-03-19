# npm Audit Severity Policy

Defines which npm audit findings block CI and when exceptions are permitted.

## Severity Thresholds

| Context | Blocking Severity | Scope |
|---------|------------------|-------|
| **Pre-commit hook** | high, critical | Production deps only (`--omit=dev`) |
| **CI (test/deploy)** | high, critical | Production deps only |
| **Dependency review workflow** | moderate+ | All deps (advisory only, non-blocking) |
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

Runs `npm audit --audit-level=moderate` on push/PR. Reports findings but uses `fail_ci_if_error: false` for moderate-only issues.

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
| GHSA-vpq2-c234-7xj6 | @tootallnate/once (via critical) | Transitive dev dep, no fix without breaking change | N/A | Next `critical` major release |
| GHSA-gmq8-994r-jv83 | yauzl (via @percy/core) | No upstream fix available | N/A | Next @percy/core release |

## Updating This Policy

Changes to severity thresholds or the exception process require a PR with the `security` label and review from a maintainer.
