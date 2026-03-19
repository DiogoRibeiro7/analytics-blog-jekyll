# Gemfile.lock Strategy

## Policy

**`Gemfile.lock` is NOT committed** to the repository (listed in `.gitignore`).

## Rationale

DataLog is distributed as a Ruby gem (`datalog-theme`). Following Ruby community conventions:

- **Gems/libraries** should not commit `Gemfile.lock` because consumers need to resolve dependencies against their own environment and other gems.
- The gemspec defines version constraints; `Gemfile.lock` would pin exact versions that may conflict downstream.

## Local Development

When you clone the repo and run `bundle install`, Bundler generates `Gemfile.lock` locally. This is expected and provides reproducible builds on your machine.

```bash
bundle install        # generates Gemfile.lock locally
bundle exec jekyll serve
```

## Security Auditing

`bundler-audit` works with the local `Gemfile.lock`:

```bash
gem install bundler-audit
bundler-audit update
bundler-audit check
```

This runs in CI via the [dependency-review workflow](../.github/workflows/dependency-review.yml) and the [test workflow](../.github/workflows/test.yml), which both generate a fresh `Gemfile.lock` during `bundler-cache: true`.

## When to Regenerate

Regenerate your local lock file when:

- Updating gem dependencies: `bundle update`
- Updating a specific gem: `bundle update <gem-name>`
- After modifying the gemspec version constraints
- When CI passes but local builds fail (version mismatch)

## Alternative: Committed Lock File

If the project transitions to being primarily a deployable application (not a gem), reconsider committing `Gemfile.lock` for full reproducibility. Update `.gitignore` accordingly.
