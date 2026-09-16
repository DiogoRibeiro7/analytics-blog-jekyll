# Branch Trigger Policy

## Default Branch

The repository default branch is **`develop`**. Pull requests target `develop`, and most CI workflows trigger on pushes and pull requests there.

## Branch Strategy

| Branch | Purpose | CI Triggers |
|--------|---------|-------------|
| `develop` | Default and integration branch: the changes merged since the last release | All workflows (test, deploy, security, accessibility, performance) |
| `main` | Stable release branch. It changes only when a release is merged, and each merge is tagged `vX.Y.Z` | release.yml (push), test.yml (pull requests) |
| `release/vX.Y.Z` | Cut by the Release workflow at the version bump; its pull request promotes the release to `main` | test.yml, through that pull request |
| Feature branches | Short-lived branches for individual changes | Workflows run via PR to `develop` |

## Release Channels

A site using the theme picks one of these; [install.md](install.md#22-install-from-git-or-a-local-path) shows the Gemfile line for each.

| Channel | Holds | For |
|---------|-------|-----|
| RubyGems, `datalog-theme` | Every release | The recommended install, constrained to a minor series |
| Tags, `vX.Y.Z` | The commit released as that version; a tag is never moved | Reproducible installs from Git |
| `main` | The latest release | Git installs that follow each release |
| `develop` | Unreleased work | Testing changes before a release, not publishing a site |

[release-process.md](release-process.md) describes how `develop` is promoted to `main`.

## Workflow Summary

| Workflow | Push to develop | PR to develop | Push to main | PR to main | Scheduled | Tag |
|----------|:-:|:-:|:-:|:-:|:-:|:-:|
| test.yml | yes | yes | - | yes | - | - |
| deploy.yml | yes | - | - | - | - | - |
| codeql.yml | yes | yes | - | - | weekly | - |
| dependency-review.yml | yes | yes | - | - | daily | - |
| accessibility.yml | - | yes | - | - | - | - |
| lighthouse.yml | - | yes | - | - | - | - |
| docker.yml | - | when Docker or dependency files change | - | - | - | - |
| release.yml | - | - | yes | - | - | - |
| gem-release.yml | - | - | - | - | - | v* |
| broken-links.yml | - | - | - | - | weekly | - |
| stale.yml | - | - | - | - | weekly | - |
| update-citations.yml | - | - | - | - | weekly | - |

Every workflow can also be run by hand from the Actions tab (`workflow_dispatch`); a release starts that way.

## Guidelines

- **Never add `master`** to branch filters — the repository has no `master` branch.
- **Name `main` only in the release path**: release.yml runs on pushes to `main` to tag the release, and test.yml checks pull requests into it. gem-release.yml runs on version tags, not branch pushes.
- When adding a new workflow, use `branches: [ develop ]` for both push and pull_request triggers.
- Use `workflow_dispatch` for manual runs when needed.
