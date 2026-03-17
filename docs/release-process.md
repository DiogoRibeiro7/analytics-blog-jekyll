# Release Process

## Overview

Releases promote `develop` to `main` via a validated workflow. The gem-release workflow then publishes to RubyGems when the version tag is pushed.

## Pre-release Checklist

1. Update `CHANGELOG.md` with a `## [X.Y.Z]` section
2. Update `lib/datalog/theme/version.rb` to match
3. Ensure all tests pass on `develop`
4. Push changes to `develop`

## Creating a Release

### Via GitHub Actions (recommended)

1. Go to **Actions → Release — Promote develop to main**
2. Click **Run workflow**
3. Enter the version (e.g. `0.3.0`)
4. Optionally enable **Dry run** to validate without merging
5. Click **Run workflow**

The workflow will:
- Verify the version exists in `CHANGELOG.md`
- Verify the version matches `lib/datalog/theme/version.rb`
- Run the full test suite and build
- Run `bundler-audit`
- Merge `develop` into `main` (non-fast-forward)
- Create a git tag `vX.Y.Z`
- Create a GitHub release with changelog notes
- Trigger `gem-release.yml` to publish to RubyGems

### Manual (fallback)

```bash
git checkout main
git merge --no-ff develop -m "release: vX.Y.Z"
git push origin main
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
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
