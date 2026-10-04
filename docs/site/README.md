# DataLog Theme Documentation Site

This directory contains the source of a documentation site for the DataLog Jekyll theme. The site
is built with the theme itself, so every page doubles as an example of the layouts, components, and
interactive visualization runtime.

**It is not published anywhere yet.** `_config.yml` names `https://datalog-theme.github.io`, the
address it was planned for, but no repository or workflow publishes it there, and that address does
not answer. The Browser Tests job of `.github/workflows/test.yml` builds it on every pull request
(`bundle exec jekyll build --source docs/site --config docs/site/_config.yml`) and checks it in a browser. Until it is published, the guides are the
Markdown files in [`docs/`](../README.md), and the theme's live example is the
[demo site](https://diogoribeiro7.github.io/analytics-blog-jekyll/), which `.github/workflows/deploy.yml` publishes from the repository root.

## Local development

```bash
cd docs/site
bundle install
bundle exec jekyll serve --livereload
```

The site will be available at <http://localhost:4000>. Changes are hot-reloaded so you can iterate on
copy and code samples quickly.

## Publishing it

Nothing in this repository publishes the site; `.github/workflows/deploy.yml` publishes the demo
site from the repository root, not this directory. To publish it:

1. Decide where it lives: its own GitHub Pages repository, or a path under an existing Pages site.
2. Set `url` and `baseurl` in `_config.yml` to that address, and update the contact details in
   `_data/navigation.yml`, `_config.yml` and the showcase data.
3. Build it with `bundle exec jekyll build --source docs/site --config docs/site/_config.yml --destination <dir>`
   and publish `<dir>` with GitHub Pages. The build and deploy steps of `deploy.yml`
   (`actions/configure-pages`, `actions/upload-pages-artifact`, `actions/deploy-pages`) show the
   way for the demo; point the build at this directory instead.
4. Once the site answers at its address, update this README and the Documentation Site entry in the
   repository's `README.md`.

## Structure

- **`features/`** – Narrative walkthroughs of every layout, component, and content type.
- **`visualizations/`** – Interactive demos for Plotly, D3, Observable, Bokeh, Shiny, and ipywidgets embeds.
- **`showcase/`** – Curated gallery of public sites that rely on the theme.
- **`guides/`** – Migration playbooks for switching from other Jekyll themes to DataLog.
- **`_data/navigation.yml`** – Header/footer links and grouped guide sidebar links. The order of the guide links drives previous/next navigation.
- **Collections** – Rich sample content for posts, datasets, notebooks, and portfolio entries that power the
  landing page.

Because the documentation site is a working Jekyll project, it can be forked or cloned to seed analytics
initiatives that need extensive storytelling patterns out of the box.
