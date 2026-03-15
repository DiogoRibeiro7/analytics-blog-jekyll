# Distribution & Community Integration

DataLog is engineered for both academic research teams and the wider open-source data science community. Use the checklist below when preparing a release:

## Versioning & Citation

1. Update `lib/datalog/theme/version.rb` and `datalog-theme.gemspec` with the new version number.
2. Regenerate citation exports via `bundle exec jekyll build` to refresh BibTeX, RIS, and EndNote files under `assets/publications/`.
3. Update `CITATION.cff` with the release date and version.
4. Document the release in [`CHANGELOG.md`](../CHANGELOG.md) following Keep a Changelog conventions.
5. Create a Git tag (`git tag -s vX.Y.Z`) referencing the changelog entry and scholarly highlights.

## Publishing to RubyGems & GitHub Releases

1. Run `bundle exec rake release` (or `gem build datalog-theme.gemspec` followed by `gem push`).
2. Draft a GitHub Release summarizing new features, accessibility fixes, and performance improvements. Attach generated citation files if desired, and link back to the corresponding changelog section.
3. Announce the update on ResearchGate, ORCID works, and academic mailing lists with the preferred citation snippet.

## Jekyll Theme Directory Submission

1. Ensure the demo site builds cleanly through GitHub Actions (`DataLog CI`).
2. Confirm `datalog-theme.gemspec` includes the `jekyll-theme` metadata key and that `README.md` documents installation steps.
3. Submit a pull request to [`jekyll/jekyll`](https://github.com/jekyll/jekyll/tree/master/docs/themes) adding DataLog to the theme catalog.
4. Share the theme with the [Jekyll Talk](https://talk.jekyllrb.com/) community and highlight academic-oriented functionality.

## Data Science Community Outreach

- Publish release highlights on Kaggle, LinkedIn, and specialized Slack/Discord communities.
- Prepare tutorial threads or short videos demonstrating notebook publishing, visualization galleries, and reproducibility dashboards.
- Invite collaborators through the academic operations hub (update `_data/academic.yml`) and track outreach metrics in GitHub Discussions.

## Compliance Checklist

- [ ] All datasets document licensing and provenance.
- [ ] Accessibility checks (`bundle exec rake ci:verify`) pass on the release branch.
- [ ] Performance budgets remain under thresholds defined in `scripts/test_performance.rb`.
- [ ] Localization files are updated for any new interface strings.
- [ ] Research ethics statements and reproducibility badges reflect the latest policies.
