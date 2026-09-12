# Installation Guide

Welcome to **DataLog**, a Jekyll theme for data scientists, researchers, and technical writers. This guide walks you through preparing your environment, installing the project in multiple scenarios, configuring the theme, troubleshooting common issues, and publishing your first post.

## 1. Prerequisites

Ensure the following tools are installed before you begin:

- **Ruby 3.0 or higher** (3.2 is used in the reference environment).【F:docs/user-guide.md†L9-L20】
- **Node.js 16 or higher** for JavaScript tooling bundled with the theme.【F:docs/user-guide.md†L9-L20】
- **Python 3.8 or higher** to support notebook conversion, validation, and optional build tooling.【F:docs/user-guide.md†L9-L20】
- **Bundler** for installing Ruby dependencies: `gem install bundler`.
- **Git** for version control and deployment.

> **Tip:** If you maintain multiple Ruby versions, consider using `rbenv`, `rvm`, or Conda to isolate the toolchain.【F:docs/user-guide.md†L9-L26】

## 2. Installation Paths

Choose the workflow that matches how you plan to host and work with DataLog.

### 2.1 Add the Theme to a Jekyll Site

The theme is published on RubyGems as `datalog-theme` and needs Jekyll 4.3 or later.

1. **Add the gem** to your site's `Gemfile`:

   ```ruby
   source "https://rubygems.org"

   gem "jekyll", "~> 4.3"
   gem "datalog-theme", "~> 0.7"
   ```

2. **Configure the site.** A site using the gem needs three things in `_config.yml`:

   ```yaml
   theme: datalog-theme
   plugins:
     - datalog-theme   # registers the theme's Liquid tags and filters
   author:
     name: Your Name   # required; the build stops without it
   ```

   Naming the theme under `plugins:` is what makes Jekyll load it. Jekyll reads
   `_plugins/` for a site but not for a theme gem, so without that line the tags
   the layouts use are never registered and the build fails with
   `Unknown tag 't'`.

   Turning on search adds two pages your site does not have to write:

   ```yaml
   features:
     search: true
   ```

   The theme then generates `/search/` and the `/search.json` index it reads,
   because a theme gem can ship layouts and includes but not pages. A site that
   defines either path itself keeps its own version.

3. **Install and preview** with `bundle install` and `bundle exec jekyll serve`.

The gem contains the layouts, includes, styles and scripts, plus the data the
layouts need in order to render: translations, the script manifest and CDN
integrity hashes. Everything that describes a particular site is yours to
supply, and the theme leaves it out when you do not:

- **Pages.** A theme gem cannot ship pages, so write your own home page
  (`layout: home`), about page and blog index. The search page above is the one
  exception.
- **Navigation.** `_data/navigation.yml` lists the header links under `header:`
  and the footer's "Explore" column under `footer:`. Without the file the header
  has no navigation and the footer leaves that column out.

  ```yaml
  header:
    - title: Blog
      url: /blog/
      description: Tutorials and walkthroughs
    - title: About
      url: /about/
  footer:
    - title: Privacy
      url: /privacy/
  ```

- **Social links and feeds.** `_data/social.yml` lists the profiles in the
  footer's "Connect" column under `primary:` and its feeds under `rss:`. Without
  it the footer shows `author.email`, if you set one, and a link to `/feed.xml`.

  ```yaml
  primary:
    - label: GitHub
      url: https://github.com/your-name
  rss:
    - label: All posts
      url: /feed.xml
  ```

### 2.2 Install from a Git Checkout or a Local Path

To try changes that are not released yet, Bundler can install the theme straight
from the repository:

```ruby
gem "datalog-theme", github: "DiogoRibeiro7/analytics-blog-jekyll", branch: "develop"
```

The repository is also the theme's demo site. A checkout therefore includes the
demo's `_config.yml`, and Jekyll merges a theme's `_config.yml` into the
configuration of every site using it, so your site would take on the demo's
author details, contact addresses, social profiles and feeds. Add this line to
your `_config.yml` to keep it out:

```yaml
ignore_theme_config: true
```

The build stops with an explanation until the line is there. With it the theme
also leaves out the demo's own `_data` files and downloads, so your site sees
the same theme files the published gem contains.

### 2.3 Publish with GitHub Pages

The build GitHub Pages runs by itself uses Jekyll 3 and allows only a fixed set
of plugins, so it cannot build a site that uses this theme. Build the site with
GitHub Actions and publish the result instead:

1. In your repository's **Settings → Pages**, set the source to **GitHub Actions**.
2. Add a workflow, for example `.github/workflows/pages.yml`:

   ```yaml
   name: Deploy to GitHub Pages

   on:
     push:
       branches: [main]
     workflow_dispatch:

   permissions:
     contents: read
     pages: write
     id-token: write

   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v6
         - id: pages
           uses: actions/configure-pages@v5
         - uses: ruby/setup-ruby@v1
           with:
             ruby-version: '3.2'
             bundler-cache: true
         - run: bundle exec jekyll build --baseurl "${{ steps.pages.outputs.base_path }}"
           env:
             JEKYLL_ENV: production
         - uses: actions/upload-pages-artifact@v4

     deploy:
       needs: build
       runs-on: ubuntu-latest
       environment:
         name: github-pages
         url: ${{ steps.deployment.outputs.page_url }}
       steps:
         - id: deployment
           uses: actions/deploy-pages@v4
   ```

3. Push to `main`. The site is published once the workflow finishes.

This repository's `.github/workflows/deploy.yml` publishes the demo site the same
way, with its test suites added.

### 2.4 Work on the Theme Repository

1. **Clone the repository** and move into the project directory.
2. **Prepare your environment** using one of the documented approaches:
   - **Conda** (recommended for cross-language tooling):
     ```bash
     conda create -n datalog python=3.11 ruby=3.2 nodejs
     conda activate datalog
     ```
   - **Python virtualenv + system Ruby:**
     ```bash
     python3 -m venv .venv
     source .venv/bin/activate
     ```
   Notebook pages are rendered by the theme itself; Python is only needed for `scripts/notebook_validation.py` (`pip install -r requirements.txt`).【F:docs/user-guide.md†L12-L31】
3. **Install Ruby dependencies** with Bundler: `bundle install`.【F:README.md†L66-L74】
4. **Run the development server** with live reload to preview changes:
   ```bash
   bundle exec jekyll serve --livereload
   ```
   The site will be available at `http://localhost:4000`.【F:docs/user-guide.md†L33-L40】
5. **Iterate on content and configuration**, committing changes as you go.

### 2.5 Docker Workflow

Use Docker when you need an isolated environment without installing Ruby, Node.js, or Python on your host system.

1. **Create a `Dockerfile`** at the project root:
   ```Dockerfile
   FROM jekyll/jekyll:4
   WORKDIR /srv/jekyll
   COPY . .
   RUN bundle install
   CMD ["jekyll", "serve", "--livereload", "--host", "0.0.0.0"]
   ```
2. **Build the image**:
   ```bash
   docker build -t datalog-site .
   ```
3. **Run the container** while mounting the current directory so edits on the host trigger rebuilds:
   ```bash
   docker run --rm -it -p 4000:4000 -v "$PWD":/srv/jekyll datalog-site
   ```
4. **Access the site** at `http://localhost:4000`. Use `JEKYLL_ENV=production` in the `docker run` command when you want to simulate production builds.

## 3. Configuration Walkthrough

Customize the theme by editing `_config.yml`. Key sections include:

- **Site identity:** `name`, `title`, `description`, and `url` define how the site appears to readers and search engines.【F:_config.yml†L4-L32】
- **Author profile:** Update `author` details (emails, ORCID, affiliations, social links) to match your public presence.【F:_config.yml†L18-L47】
- **Collections:** The `portfolio`, `datasets`, and `notebooks` collections control custom content types and permalinks.【F:_config.yml†L59-L79】
- **Notebook integration:** Configure repository links, Binder/Colab buttons, and output directories under the `notebooks` block.【F:_config.yml†L87-L113】
- **Theme options:** Tune math rendering, syntax highlighting, visualization defaults, taxonomy, localization, and accessibility preferences under `theme_options` and `integrations`.【F:_config.yml†L117-L256】
- **Contact and social metadata:** Align `social`, `contact`, and `seo` sections with your communication strategy.【F:_config.yml†L131-L184】【F:_config.yml†L247-L268】

After updating `_config.yml`, restart the development server (or rebuild in Docker) to apply changes.

## 4. Creating Your First Post

1. **Create a new Markdown file** in `_posts/` named with the `YYYY-MM-DD-your-title.md` convention.
2. **Add front matter** similar to:
   ```yaml
   ---
   layout: post
   title: "Welcome to DataLog"
   author: "Diogo Ribeiro"
   tags: [introduction, reproducibility]
   ---
   ```
3. **Write your content** using Markdown. Include code blocks, math, or visualizations as needed.
4. **Serve the site locally** (`bundle exec jekyll serve`) to review the post before publishing.【F:README.md†L66-L82】
5. **Commit and push** the new post. If you are using GitHub Pages, the site will rebuild automatically after the push.【F:README.md†L87-L94】

> **Notebook posts:** Drop executed `.ipynb` files into `_notebooks/` and the notebook converter will publish them as blog entries automatically.【F:README.md†L75-L86】【F:docs/user-guide.md†L41-L52】

## 5. Common Troubleshooting

| Problem | Solution |
| --- | --- |
| `jekyll` command not found | Install Ruby (via rbenv, rvm, or Conda) and rerun `bundle install` to ensure all dependencies are available.【F:docs/user-guide.md†L111-L140】 |
| Notebook conversion fails | Verify the notebook contains metadata and review `_plugins/notebook_converter.rb` logs; re-run the notebook to capture outputs.【F:docs/user-guide.md†L41-L52】【F:docs/user-guide.md†L111-L140】 |
| Math does not render | Confirm `theme_options.math.enabled` is `true` and fix LaTeX syntax errors reported by MathJax in the browser console.【F:_config.yml†L173-L218】【F:docs/user-guide.md†L115-L133】 |
| Visualizations missing | Ensure embeds include the correct `data-viz-*` attributes and referenced files exist under `assets/` or your chosen path.【F:docs/user-guide.md†L63-L110】 |
| GitHub API rate limit warnings | Add a `github_token` environment variable or configure credentials in `_config.yml` under `integrations.github`.【F:_config.yml†L219-L256】【F:docs/user-guide.md†L111-L140】 |

## 6. Next Steps

- Explore `docs/user-guide.md` for in-depth tutorials on notebooks, math, visualizations, accessibility, and workflow automation.【F:docs/user-guide.md†L1-L210】
- Review `_data/` YAML files to manage navigation, social links, projects, datasets, and academic dashboards.
- Configure CI by running `bundle exec rake ci:verify` to mirror the repository’s automated checks before deploying.【F:README.md†L121-L138】

With your environment configured and first post published, you are ready to build a reproducible analytics publication on top of DataLog.
