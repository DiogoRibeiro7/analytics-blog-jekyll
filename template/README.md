# Datalog Starter Template

This starter repository provides a ready-to-deploy Jekyll site powered by the Datalog analytics theme. It is intended to be published as a GitHub template repository so that teams can launch new analytics blogs in a few clicks.

## What's included

- Opinionated `_config.yml` wired to the Datalog theme and popular plugins
- Sample content across posts, pages, portfolio case studies, datasets, and notebooks
- Prebuilt GitHub Actions workflow for building and deploying to GitHub Pages
- Developer tooling configuration for linting markdown and running theme stability checks

## Getting started locally

```bash
bundle install
npm install
bundle exec jekyll serve
```

## Deploying with GitHub Pages

The included workflow expects to publish from the `gh-pages` branch using the `jekyll-actions/jekyll-build-pages` action. Enable GitHub Pages in the repository settings and target the `gh-pages` branch after the first deployment run completes.

## Customization checklist

1. Update `_config.yml` metadata (`title`, `description`, `url`, `social` handles).
2. Replace sample content in `_posts`, `_pages`, `_portfolio`, `_datasets`, and `_notebooks`.
3. Configure analytics and comments providers as desired.
4. Adjust branding colors and typography via `_sass/theme.scss`.
5. Audit the GitHub Actions workflow for any organization-specific steps.

