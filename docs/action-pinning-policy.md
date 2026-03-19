# GitHub Actions Pinning Policy

All third-party GitHub Actions are pinned to immutable commit SHAs to mitigate supply-chain attacks.

## Format

```yaml
uses: owner/action@<full-sha> # <version-tag>
```

The version tag comment makes it easy to identify which release is pinned.

## Current Pins

| Action | SHA | Tag |
|--------|-----|-----|
| actions/checkout | de0fac2e4500dabe0009e67214ff5f5447ce83dd | v6 |
| actions/setup-node | 53b83947a5a98c8d113130e565377fae1a50d02f | v6 |
| actions/setup-python | a26af69be951a213d495a4c3e4e4022e16d87065 | v5 |
| actions/cache | 0057852bfaa89a56745cba8c7296529d2fc39830 | v4 |
| actions/upload-artifact | bbbca2ddaa5d8feaa63e36b76fdaad77386f024f | v7 |
| actions/upload-pages-artifact | 56afc609e74202658d3ffba0e8f6dda462b719fa | v3 |
| actions/deploy-pages | d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e | v4 |
| actions/dependency-review-action | 2031cfc080254a8a887f58cffee85186f0e49e48 | v4 |
| github/codeql-action | 603b797f8b14b413fe025cd935a91c16c4782713 | v3 |
| codecov/codecov-action | b9fd7d16f6d7d1b5d2bec1a2887e65ceed900238 | v4 |
| lycheeverse/lychee-action | 7cd0af4c74a61395d455af97419279d86aafaede | v2.0.2 |
| ruby/setup-ruby | c984c1a20bb35a1cbda04477c816cea024418be9 | v1 |
| stefanzweifel/git-auto-commit-action | 04702edda442b2e678b25b537cec683a1493fcb9 | v7 |
| treosh/lighthouse-ci-action | 512cc908a55bfb0ad231facca52adf3d3a651df4 | v12 |

## Update Process

Run quarterly (alongside the [coverage review](coverage-review-process.md)):

1. Check for new releases:
   ```bash
   gh api repos/OWNER/ACTION/releases/latest --jq '.tag_name'
   ```

2. Get the commit SHA for the new tag:
   ```bash
   gh api repos/OWNER/ACTION/commits/TAG --jq '.sha'
   ```

3. Update the workflow file with the new SHA and tag comment.

4. Test the workflow by pushing a branch or using `workflow_dispatch`.

5. Update the table above in this document.

## Adding New Actions

When adding a new third-party action to any workflow:

1. Never use a floating tag (`@v4`, `@main`).
2. Look up the commit SHA for the desired version tag.
3. Pin to the SHA with a tag comment.
4. Add the action to the table above.
