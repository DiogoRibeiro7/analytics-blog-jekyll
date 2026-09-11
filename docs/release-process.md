# Release Process

## Overview

Releases promote `develop` to `main` via a validated workflow. The gem-release workflow then publishes to RubyGems when the version tag is pushed.

## Pre-release Checklist

1. Everything to ship is merged into `develop` and CI is green there.
2. `CHANGELOG.md` has a `## [Unreleased]` section listing the changes. The release turns it into the version heading; do not add the version yourself.
3. Pick the version: patch for fixes only, minor when the section has an `### Added` entry, major for breaking changes.

## Creating a Release

### Via GitHub Actions (recommended)

1. Go to **Actions → Release — Promote develop to main** and click **Run workflow**.
2. Enter the version (e.g. `0.6.2`). Tick **Dry run** first if you want to see the bump without side effects.
3. Click **Run workflow**.

The workflow validates the version (format, not already tagged, `[Unreleased]` has entries), bumps `CHANGELOG.md`, `lib/datalog/theme/version.rb`, `CITATION.cff` and `theme_version` in `_config.yml`, verifies the gem builds, pushes that commit to `develop`, and opens (or refreshes) the pull request from `develop` into `main` with the release notes as its body.

4. Review the PR and merge it with **Create a merge commit**. Squash or rebase merges detach `main` from `develop`'s history and make the next promotion conflict.

On that merge the same workflow tags `main` with `vX.Y.Z` and publishes the GitHub release with the changelog section. The tag push starts `gem-release.yml`, which pauses in the `rubygems` environment until a reviewer approves it, then pushes the gem to RubyGems.

Requirements this flow relies on:

- `RELEASE_TOKEN`: a repository secret holding a fine-grained personal access token of a repository admin, scoped to this repository with **Contents: read and write** and **Pull requests: read and write**. The workflow pushes the bump and the tag and opens the PR with it. The built-in token cannot do this on a personal repository: it may not push past the branch rules, pull requests it opens do not trigger the checks, and tags it pushes do not start the publish.
- `RUBYGEMS_API_KEY` exists as a secret of the `rubygems` environment.

### Manual (fallback)

```bash
git checkout develop && git pull
# bump CHANGELOG.md ([Unreleased] -> [X.Y.Z] - YYYY-MM-DD), lib/datalog/theme/version.rb,
# CITATION.cff (version, date-released) and theme_version in _config.yml, then:
git commit -am "chore(release): bump version to X.Y.Z"
git push origin develop
gh pr create --base main --head develop --title "release: vX.Y.Z"
# merge the PR with a merge commit; the tag, GitHub release and gem publish follow automatically.
```

If the automatic tagging did not run, tag `main` by hand and start the publish:

```bash
git checkout main && git pull
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z          # a tag pushed by a person triggers gem-release.yml directly
```

## Rollback

If a release needs to be reverted:

```bash
# Revert the merge commit on main
git checkout main
git revert -m 1 <merge-commit-sha>
git push origin main

# Delete the tag if gem was not yet published
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z
```

If the gem was already published, publish a new patch version with the fix instead.

## Version Strategy

This project follows [Semantic Versioning](https://semver.org/):

- **Patch** (0.2.x): Bug fixes, dependency updates, doc improvements
- **Minor** (0.x.0): New features, non-breaking layout/config changes
- **Major** (x.0.0): Breaking changes to config, layouts, or plugin APIs
