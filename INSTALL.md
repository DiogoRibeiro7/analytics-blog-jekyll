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

### 2.1 GitHub Pages Deployment

1. **Fork or clone** the repository and add the theme gem to your Jekyll site if it is not already present by including `gem "datalog-theme", "~> 0.1"` in your `Gemfile`.【F:README.md†L96-L103】
2. **Update `_config.yml`** to reference the theme: set `theme: datalog-theme` and review site metadata (title, URL, author profiles).【F:README.md†L105-L108】【F:_config.yml†L1-L115】
3. **Install dependencies** locally with Bundler: `bundle install`.【F:README.md†L66-L74】
4. **Push to GitHub** on the `main` branch, then enable GitHub Pages in the repository settings, selecting the `main` branch as the source.【F:README.md†L87-L94】
5. **Allow GitHub Pages to build** using the `github-pages` gem; the site will publish automatically after the workflow completes.【F:README.md†L109-L111】

### 2.2 Local Development Environment

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
   Both setups benefit from installing notebook helpers: `pip install jupyter nbconvert`.【F:docs/user-guide.md†L12-L31】
3. **Install Ruby dependencies** with Bundler: `bundle install`.【F:README.md†L66-L74】
4. **Run the development server** with live reload to preview changes:
   ```bash
   bundle exec jekyll serve --livereload
   ```
   The site will be available at `http://localhost:4000`.【F:docs/user-guide.md†L33-L40】
5. **Iterate on content and configuration**, committing changes as you go.

### 2.3 Docker Workflow

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
