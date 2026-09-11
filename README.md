# DataLog — A Data Science Jekyll Theme

[![Tests](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/actions/workflows/test.yml/badge.svg)](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/actions/workflows/test.yml)
[![Deploy](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/actions/workflows/deploy.yml/badge.svg)](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/actions/workflows/deploy.yml)
[![Gem Release](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/actions/workflows/gem-release.yml/badge.svg)](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/actions/workflows/gem-release.yml)
[![Lighthouse CI](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/actions/workflows/lighthouse.yml/badge.svg)](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/actions/workflows/lighthouse.yml)
[![Accessibility Audit](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/actions/workflows/accessibility.yml/badge.svg)](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/actions/workflows/accessibility.yml)
[![Broken Link Scanner](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/actions/workflows/broken-links.yml/badge.svg)](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/actions/workflows/broken-links.yml)
[![Citation Sync](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/actions/workflows/update-citations.yml/badge.svg)](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/actions/workflows/update-citations.yml)

DataLog is a modern, academic-inspired Jekyll theme tailored for data scientists, researchers, and technical writers who need a clean platform to publish reproducible analyses, research papers, tutorials, datasets, and project showcases. The theme emphasizes accessibility, performance, and beautiful code presentation while remaining fully compatible with GitHub Pages.

## Features

- **Research-ready layouts** for posts, pages, datasets, and portfolio case studies
- **Jupyter Notebook integration**: `.ipynb` files in `_notebooks/` become sanitized, CSP-safe pages via the theme's notebook converter
- **Advanced MathJax tooling** with accessible numbering, cross-references, equation editor, and LaTeX copy helpers
- **Optimized syntax highlighting** for Python, R, SQL, and Julia code blocks
- **Responsive and accessible UI** that meets WCAG 2.1 AA guidelines
- **SEO friendly** metadata (Open Graph, Twitter cards, canonical links, JSON-LD) and sitemap generation
- **Interactive visualization hub** with lazy-loaded Plotly, D3.js, Bokeh, Observable, R Shiny, and Jupyter widget support plus export tooling
- **Portfolio section** for highlighting research projects, experiments, and case studies
- **Dataset collection** for sharing curated datasets with download links
- **English-first header experience** with accessible labels and data-driven navigation out of the box
- **Dark mode toggle** with preserved user preference
- **Theme gem distribution** with GitHub Actions validation across Ruby, Python, and Node environments
- **Academic citation tooling** via `CITATION.cff`, BibTeX, RIS, and EndNote exports
- **Analytics operations hub** with a GA4-powered `/admin/analytics/` dashboard for top content, search trends, events, and Scholar metrics cached for 24 hours

## Repository Layout

This repository serves a dual purpose: it ships the **`datalog-theme` gem**
*and* runs as a working **demo site** that previews every feature. When you
consume DataLog as a theme, only the gem-side files are installed into your
site; the rest is reference content you can copy from.

| Role | Paths |
| --- | --- |
| Theme (shipped in the gem) | `lib/datalog/`, `_layouts/`, `_includes/`, `_sass/`, `assets/`, `_plugins/`, `datalog-theme.gemspec` |
| Demo content (this site only) | `_posts/`, `_notebooks/`, `_portfolio/`, `_datasets/`, `_packages/`, `_pages/`, `index.md`, `404.html` |
| Starter scaffold | `template/` — minimal seed for the [GitHub template repository](docs/template-repository.md); excluded from this site's build |
| Configuration | `_config.yml`, `_data/`, `Gemfile`, `package.json`, `requirements.txt` |
| Tests & tooling | `tests/`, `scripts/`, `Rakefile`, `vitest.config.js`, `playwright.config.js`, `pa11yci.json`, `lighthouserc.json`, `percy.config.yml` |
| Docs | `docs/`, `README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`, `TESTING.md` |

```
.
├── _config.yml                # Theme configuration with MathJax and syntax highlighting
├── _data/
│   ├── navigation.yml         # Global navigation structure
│   ├── social.yml             # Academic and community profiles
│   ├── publications.yml       # Publication settings and manual entries
│   ├── datasets.yml           # Dataset catalog configuration
│   └── projects.yml           # Portfolio showcase configuration
├── _datasets/                 # Collection for dataset descriptions
├── _includes/                 # Reusable components (head, footer, analytics, etc.)
├── _layouts/                  # Page layouts (default, post, notebook, portfolio, dataset)
├── _notebooks/                # Source notebooks rendered by _plugins/notebook_converter.rb
├── _pages/                    # Standalone pages (About, Contact, etc.)
├── _plugins/                  # Custom helpers (accessibility, filters, etc.)
├── _portfolio/                # Portfolio items for data science projects
├── _posts/                    # Blog posts and research updates
├── _sass/                     # Sass partials used by the theme
├── assets/
│   ├── css/main.scss          # Compiled stylesheet entry point
│   ├── img/                   # Images and cover art
│   └── js/main.js             # Progressive enhancement scripts
├── lib/datalog/               # Theme gem source (published as `datalog-theme`)
├── Gemfile                    # Ruby dependencies (GitHub Pages compatible)
├── .gitignore                 # Ignore build artifacts and notebook outputs
└── README.md                  # Theme documentation (this file)
```

## Documentation

- [Documentation Site](docs/site/README.md) — source for the live `datalog-theme.github.io` documentation hub with feature walk-throughs, interactive demos, and migration guides.
- [User Guide](docs/user-guide.md) — comprehensive documentation covering installation, notebooks, math, visualizations, research workflows, accessibility, performance, and collaboration best practices for DataLog users.
- [Environment Setup Guide](docs/environment-setup.md) — configure environment variables, secrets, and integrations for analytics, testing, and deployment.
- [Scripts Reference](docs/scripts-reference.md) — complete reference for all build, test, import/export, and utility scripts.
- [Changelog](CHANGELOG.md) — release highlights and upgrade guidance for each published version of the DataLog theme.
- [Template Repository Guide](docs/template-repository.md) — instructions for publishing a GitHub template with starter content, configuration, and automated deployments.
- [Installation Guide](docs/install.md) — prerequisites, GitHub Pages, local, and Docker setup paths.
- [Migrating from Minimal Mistakes](docs/migrating-from-minimal-mistakes.md) — the front-matter fields DataLog reads natively (hero and teaser images, SEO title and description, `classes: wide`, `redirect_from`) and the settings that keep existing URLs.
- [Plugin Development Guide](docs/plugin-development.md) — understand the hook system and learn how to package extensions for reuse.
- [Security Policy](SECURITY.md) — report security vulnerabilities and learn about security best practices.
- [Contributing Guidelines](CONTRIBUTING.md) — contribution workflow, code standards, and community guidelines.

## Getting Started

1. **Install dependencies**
   ```bash
   bundle install
   ```

2. **Configure environment** (optional)

   Copy [`.env.example`](.env.example) to `.env` and fill in any keys you
   need — GA4 credentials, Percy/Codecov tokens, Playwright base URL, etc.
   All values are optional; the site runs without them, and features that
   require credentials will skip cleanly. See
   [docs/environment-setup.md](docs/environment-setup.md) for the full reference.

3. **Run the development server**
   ```bash
   bundle exec jekyll serve
   ```

   JavaScript enhancements are bundled with [esbuild](https://esbuild.github.io/). After modifying files under `assets/js/`,
   regenerate the production-ready scripts with:

   ```bash
   npm install
   npm run build:js
   ```

4. **Create content**
   - Add Markdown posts to `_posts/`
   - Place Jupyter notebooks in `_notebooks/` and they will automatically publish as rich blog posts
   - Document datasets in `_datasets/`
   - Showcase research projects in `_portfolio/`

### Command-line toolkit

Use the bundled `bin/datalog` helper to scaffold content and manage deployments:

```bash
bin/datalog --help
```

- `bin/datalog new post` — walk through the interactive post generator with best-practice front matter.
- `bin/datalog new notebook` — create a notebook landing page and starter `.ipynb` in one step.
- `bin/datalog new project` — scaffold a portfolio entry with metadata and placeholder sections.
- `bin/datalog check` — validate runtime dependencies, configuration, and optional tooling like Node.js.
- `bin/datalog publish` — build the site and push the `_site` artifacts to your GitHub Pages branch via git worktrees.
- `bin/datalog update` — upgrade the `datalog-theme` gem and refresh npm packages when applicable.

### Analytics dashboard

The `/admin/analytics/` workspace combines Google Analytics 4, notebook telemetry, and Google Scholar metrics:

- Set `GA4_PROPERTY_ID` in your environment or `_config.yml` under `analytics.ga4_property_id`.
- Provide service account credentials via `GA4_CREDENTIALS_JSON` (raw JSON) or `GA4_CREDENTIALS_PATH` (file path).
- Data is cached for 24 hours in `.jekyll-cache/datalog-analytics.json` to keep builds fast and avoid rate limits.
- Citations are pulled from `_data/academic.yml`; run `scripts/update_google_scholar.py` to refresh them automatically.

Once configured, Chart.js visualizations will highlight top-performing posts, search queries, visitor trends, notebook downloads, demo launches, and automatically generated monthly rollups.

### Notebook publishing workflow

DataLog ships with an opinionated notebook-to-post pipeline tailored for technical storytelling:

1. **Drop `.ipynb` files into `_notebooks/`** — the custom generator transforms each notebook into a permalink under `/blog/` while keeping a downloadable copy at `/notebooks/<slug>.ipynb`.
2. **Leverage notebook metadata** — optional fields like `title`, `tags`, `keywords`, `difficulty`, and execution metadata will surface in the rendered article header and sidebar.
3. **Preserve interactivity** — HTML outputs, Plotly figures, and widget placeholders are embedded automatically with responsive styling and dark-mode aware formatting.
4. **Launch live sessions** — configure `notebooks.repository` and `notebooks.branch` in `_config.yml` to enable Binder and Google Colab links for each notebook, alongside GitHub source references and clone instructions.
5. **Highlight execution context** — kernel information, cell counts, runtime summaries, error outputs, and git history are extracted to help readers gauge reproducibility at a glance.

Matplotlib/Seaborn plots, LaTeX, and code syntax highlighting are optimized for both desktop and mobile viewing, while cell numbering and input/output differentiation mirror the native Jupyter experience.

4. **Deploy to GitHub Pages**
   - Push the repository to GitHub
   - Enable GitHub Pages on the repository settings (use the `develop` branch)
   - GitHub Pages will automatically build the site using the `github-pages` gem

## Data Science Workflow Integration

- **Version-controlled notebooks** — store `.ipynb` files inside `_notebooks/`
- **Reproducible environments** — document dependencies in `environment.yml` or `requirements.txt`
- **Interactive visualizations** — embed Plotly, Altair/Vega-Lite, or Observable notebooks using `<iframe>` or custom scripts
- **Dataset documentation** — use the dataset collection to provide metadata, download links, and provenance for each dataset
- **Research pipelines** — highlight end-to-end workflows with diagrams, metrics, and evaluation summaries

## Theming & Customization

- Update `_data/navigation.yml` to manage the global navigation items
- Curate academic, social, and contact details in `_data/social.yml`
- Manage featured projects, GitHub repositories, and demo links via `_data/projects.yml`
- Synchronize datasets with `_data/datasets.yml` and the dataset configuration options in `_config.yml`
- Import publications automatically by pointing `_data/publications.yml` to a BibTeX file (`assets/publications/publications.bib`)
- Modify `_sass/datalog.scss` to customize colors, spacing, and typography
- Override partials in `_includes/` to add analytics, consent banners, or custom JavaScript
- Configure SEO metadata, author details, and pagination in `_config.yml`

### Flexible configuration system

The `_config.yml` file exposes an opinionated set of options crafted for research teams:

- `theme_options.math` toggles between **MathJax** and **KaTeX** engines, equation numbering, and accessibility defaults.
- `theme_options.syntax_highlighting` defines the Prism CDN, theme pairings for light/dark modes, and the language components to preload.
- `theme_options.visualizations` controls default behaviour for Plotly, D3, Bokeh, Observable, Shiny, and widget embeds.
- `theme_options.taxonomy`, `content.research_areas`, and `content.methodologies` organize content by research area and methodology for archive navigation.
- `integrations.github` enables live repository metrics with caching support for portfolio cards, while Binder/Colab/Kaggle toggles control interactive notebook links.
- `localization` and `filters.languages` still power multilingual content in data files, while the bundled header ships with English labels that can be customized by overriding `_includes/header.html`.

Data-driven configuration allows you to publish or reorder projects, datasets, social profiles, and publication lists without modifying templates—everything is sourced from `_data/` files and the theme options block.

### Academic & professional integrations

- The **Academic Operations Hub** (`/academic/`) aggregates Google Scholar, ORCID, ResearchGate, and Academia.edu profiles, syncing citation metrics, per-publication counts, and bibliography exports generated from BibTeX sources.
- Submission tracking panels display conference and journal deadlines with collaborator context, while the academic calendar filters workshops, funding calls, and special issues by type.
- Grant overviews, collaboration opportunities, mentorship programs, and networking channels are all driven by `_data/academic.yml`, making it easy to publicize professional initiatives without editing templates.
- Open science and reproducibility badges appear automatically across posts, research articles, datasets, and projects, reinforcing transparency commitments alongside standardized citation export controls (BibTeX, RIS, EndNote).

## Installation

Add the theme gem to your Jekyll site:

```ruby
gem "datalog-theme", "~> 0.1"
```

Then enable it in `_config.yml`:

```yml
theme: datalog-theme
```

For GitHub Pages, pin the `github-pages` gem and allow the included workflow to build and deploy the site automatically.

## Continuous Integration & Testing

The repository ships with a multi-language CI pipeline located in `.github/workflows/ci.yml`. It performs the following checks:

- Ruby matrix builds (3.1 & 3.2) to compile the theme, run lint-style verifications, and execute the `ci:verify` Rake task.
- Python notebook validation to ensure `.ipynb` files retain kernel metadata and can be published.
- Node.js checks that interactive visualizations (Plotly, Observable, Bokeh, R Shiny, ipywidgets) remain wired up.
- Accessibility, math rendering, syntax highlighting, and performance budgets enforced through scripts in the `scripts/` directory.

Run the suite locally with:

```bash
bundle exec rake ci:verify
```

## Demo Site

The repository doubles as a demo site and content laboratory. Explore the curated examples locally via `bundle exec jekyll serve` or review the walkthrough in [`demo/README.md`](demo/README.md) for deployment and navigation tips.

## Citation & Academic Metadata

If you reference DataLog in research outputs, cite it using the metadata in [`CITATION.cff`](CITATION.cff). Additional export formats are generated automatically in `assets/publications/` when you build the site.

## Distribution & Community Integration

Use the release checklist in [`docs/distribution.md`](docs/distribution.md) to publish new versions, submit the theme to the official Jekyll directory, and announce updates across data science communities.

## Licensing & Contributions

DataLog is released under the [MIT License](LICENSE). We welcome academic and industry contributions—see [`CONTRIBUTING.md`](CONTRIBUTING.md) for guidelines covering notebooks, datasets, visualization enhancements, and accessibility improvements.

## Accessibility

DataLog ships with semantic HTML landmarks, skip navigation links, proper color contrast, and focus-visible states. Please review custom components to ensure they remain compliant with WCAG 2.1 AA standards.

## License

Released under the [MIT License](LICENSE). Review the academic integrity guidance in [`docs/user-guide.md`](docs/user-guide.md) before publishing derivative datasets or research outputs.
