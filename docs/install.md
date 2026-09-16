# Installation Guide

Welcome to **DataLog**, a Jekyll theme for data scientists, researchers, and technical writers. This guide walks you through preparing your environment, installing the project in multiple scenarios, configuring the theme, troubleshooting common issues, and publishing your first post.

## 1. Prerequisites

Ensure the following tools are installed before you begin:

- **Ruby 3.2 or higher**.
- **Bundler** for installing Ruby dependencies: `gem install bundler`.
- **Git** for version control and deployment.

Working on the theme repository itself (section 2.4) also needs **Node.js 22 or higher**, which builds the JavaScript bundles and runs the test suites, and **Python 3.8 or higher** for the notebook validation script. A site that installs the published gem does not: the gem ships the built bundles.

> **Tip:** If you maintain multiple Ruby versions, consider using `rbenv`, `rvm`, or Conda to isolate the toolchain.

## 2. Installation Paths

Choose the workflow that matches how you plan to host and work with DataLog.

### 2.1 Add the Theme to a Jekyll Site

The theme is published on RubyGems as `datalog-theme` and needs Jekyll 4.3 or later.

1. **Add the gem** to your site's `Gemfile`:

   ```ruby
   source "https://rubygems.org"

   gem "jekyll", "~> 4.3"
   gem "datalog-theme", "~> 0.8.0"
   ```

   The constraint takes the patch releases of the current minor series and
   stops before the next one. Until 1.0 a minor release may break a site, as
   0.8.0 did when it required Ruby 3.2, so read the [changelog](../CHANGELOG.md)
   before moving to the next series. Section 2.2 covers the other release
   channels.

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

### 2.2 Install from Git or a Local Path

RubyGems is the place to install a release from. The repository holds the same
releases, and the work that is not released yet:

| Channel | What it holds | Use it to |
| --- | --- | --- |
| RubyGems, `datalog-theme` | Every release | Install a release (section 2.1) |
| A tag, `vX.Y.Z` | The commit released as that version; a tag is never moved | Build from Git reproducibly |
| The `main` branch | The latest release; it changes only when a release is merged | Follow each release from Git |
| The `develop` branch | Changes merged since the last release | Try unreleased work, not publish a site |

Bundler can install from any of them. Pin a release tag:

```ruby
gem "datalog-theme", github: "DiogoRibeiro7/analytics-blog-jekyll", tag: "v0.8.0"
```

Write `branch: "main"` in place of the tag to follow releases, or
`branch: "develop"` to test unreleased work. With a branch, Bundler records the
commit it installed in `Gemfile.lock`, and the site moves to a newer commit only
when you run `bundle update datalog-theme`. A theme kept as a Git submodule
should likewise check out a release tag.

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
way, with its test suites added. To publish AVIF, WebP and resized copies of your
images, install ImageMagick and avifenc before the build step; the
[configuration guide](configuration-guide.md#images) has the command.

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
   Notebook pages are rendered by the theme itself, so building the site needs no Python.
3. **Install dependencies**: `bundle install` for Ruby, then `npm ci` for Node.js.
4. **Build the JavaScript bundles** with `npm run build:js`. The layouts load them from `assets/js/dist/`, which is build output and not in the repository.
5. **Run the development server** with live reload to preview changes:
   ```bash
   bundle exec jekyll serve --livereload
   ```
   The site will be available at `http://localhost:4000`.
6. **Iterate on content and configuration**, committing changes as you go.

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

Customize the theme by editing `_config.yml`; [configuration-guide.md](configuration-guide.md) covers the settings in detail. Key sections include:

- **Site identity:** `name`, `title`, `description`, and `url` define how the site appears to readers and search engines.
- **Author profile:** `author` holds the name (required), affiliation, email, ORCID and social handles shown in the footer, the author card and the citation metadata.
- **Collections:** declare the content types you use under `collections:`, for example `portfolio`, `datasets` or `packages`, with their permalinks. The theme has layouts for them but cannot declare collections for your site.
- **Notebook integration:** the `notebooks` block sets the source folder, the output path and the repository used for Binder and Colab links.
- **Theme options:** `theme_options` controls math rendering, syntax highlighting and localization, and `integrations` the GitHub repository cards and the Binder and Colab links.
- **Social metadata:** `social` supplies the default share image and Twitter handle for page metadata; the footer's links come from `_data/social.yml` (section 2.1).

After updating `_config.yml`, restart the development server (or rebuild in Docker) to apply changes.

## 4. Creating Your First Post

1. **Create a new Markdown file** in `_posts/` named with the `YYYY-MM-DD-your-title.md` convention.
2. **Add front matter** similar to:
   ```yaml
   ---
   layout: post
   title: "Welcome to DataLog"
   author: "Your Name"
   tags: [introduction, reproducibility]
   ---
   ```
3. **Write your content** using Markdown. Include code blocks, math, or visualizations as needed; [components.md](components.md) covers the front matter for the difficulty badge, table of contents and author card.
4. **Serve the site locally** (`bundle exec jekyll serve`) to review the post before publishing.
5. **Commit and push** the new post. If the site publishes with a workflow like the one in section 2.3, the push rebuilds it.

> **Notebook posts:** Drop executed `.ipynb` files into `_notebooks/` and the notebook converter publishes each one as a page under `/notebooks/`.

## 5. Common Troubleshooting

| Problem | Solution |
| --- | --- |
| `jekyll` command not found | Install Ruby (via rbenv, rvm, or Conda) and rerun `bundle install` to ensure all dependencies are available. |
| `Unknown tag 't'` | Add `datalog-theme` under `plugins:` in `_config.yml` (section 2.1). |
| `Missing required configuration 'author'` | Set `author.name` in `_config.yml`. |
| The build stops and asks for `ignore_theme_config` | The theme is installed from a Git checkout or a local path; see section 2.2. |
| Notebook conversion fails | Verify the notebook contains metadata and review `_plugins/notebook_converter.rb` logs; re-run the notebook to capture outputs. |
| Math does not render | With `theme_options.math.render_on_load: auto`, MathJax loads only on pages that contain math. Add `math: true` to a page's front matter to load it regardless, and check the browser console for LaTeX errors. Inline math with spaces inside the dollars counts only when it holds a TeX command, `^` or `_`, so write `$ x $` as `$x$`. |
| Visualizations missing | Ensure embeds include the correct `data-viz-*` attributes and referenced files exist under `assets/` or your chosen path. |

## 6. Next Steps

- Browse the [documentation index](README.md) for guides to configuration, post components, notebooks, math, visualizations and accessibility.
- Add `_data/navigation.yml` and `_data/social.yml` for your site's navigation and footer links (section 2.1).
- When working on the theme repository, run `npm test` and `bundle exec rake test` for the unit and Ruby suites the Tests workflow runs.

With your environment configured and first post published, you are ready to build a reproducible analytics publication on top of DataLog.
