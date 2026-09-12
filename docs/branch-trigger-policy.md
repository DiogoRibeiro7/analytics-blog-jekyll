# Branch Trigger Policy

## Default Branch

The repository default branch is **`develop`**. All CI workflows trigger on pushes and pull requests targeting `develop`.

## Branch Strategy

| Branch | Purpose | CI Triggers |
|--------|---------|-------------|
| `develop` | Default branch, active development | All workflows (test, deploy, security, accessibility, performance) |
| `main` | Not used as default; reserved for future release promotion | gem-release.yml (tag-based only) |
| Feature branches | Short-lived branches for individual changes | Workflows run via PR to `develop` |

## Workflow Summary

| Workflow | Push to develop | PR to develop | Scheduled | Tag |
|----------|:-:|:-:|:-:|:-:|
| test.yml | yes | yes | - | - |
| deploy.yml | yes | - | - | - |
| codeql.yml | yes | yes | weekly | - |
| dependency-review.yml | yes | yes | daily | - |
| accessibility.yml | - | yes | - | - |
| lighthouse.yml | - | yes | - | - |
| gem-release.yml | - | - | - | v* |
| broken-links.yml | - | - | weekly | - |

## Guidelines

- **Never add `master`** to branch filters — the repository has no `master` branch.
- **Keep `main` references** only in `gem-release.yml` (triggered by version tags, not branch pushes).
- When adding a new workflow, use `branches: [ develop ]` for both push and pull_request triggers.
- Use `workflow_dispatch` for manual runs when needed.
