# DataLog Theme Documentation Site

This directory contains the source for [`datalog-theme.github.io`](https://datalog-theme.github.io),
the canonical documentation hub for the DataLog Jekyll theme. The site is built with the theme
itself so every page doubles as a live example of the layouts, components, and interactive
visualization runtime.

## Local development

```bash
cd docs/site
bundle install
bundle exec jekyll serve --livereload
```

The site will be available at <http://localhost:4000>. Changes are hot-reloaded so you can iterate on
copy and code samples quickly.

## Deploying to GitHub Pages

1. Create the `datalog-theme.github.io` repository under the organisation or account that maintains the theme.
2. Copy the contents of this directory into the new repository (or add this repository as a Git submodule).
3. Enable the **GitHub Pages** workflow included in `.github/workflows/deploy.yml` and set the branch to
   `main` with the root directory (`/`).
4. Update the contact details in `_data/navigation.yml`, `_config.yml`, and the showcase data to reflect
your team.
5. Push to `main` to trigger the publish workflow. The site will be deployed to
   <https://datalog-theme.github.io> once the job succeeds.

## Structure

- **`features/`** – Narrative walkthroughs of every layout, component, and content type.
- **`visualizations/`** – Interactive demos for Plotly, D3, Observable, Bokeh, Shiny, and ipywidgets embeds.
- **`showcase/`** – Curated gallery of public sites that rely on the theme.
- **`guides/`** – Migration playbooks for switching from other Jekyll themes to DataLog.
- **Collections** – Rich sample content for posts, datasets, notebooks, and portfolio entries that power the
  landing page.

Because the documentation site is a working Jekyll project, it can be forked or cloned to seed analytics
initiatives that need extensive storytelling patterns out of the box.
