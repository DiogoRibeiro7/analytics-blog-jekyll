# DataLog Theme User Guide

Welcome to **DataLog**, a Jekyll theme crafted for data scientists and researchers. This guide provides practical instructions and best practices for installing, customizing, and maintaining a high-impact technical publication built on DataLog.

## 1. Installation & Environment Setup

DataLog is compatible with GitHub Pages and can be developed locally on macOS, Linux, or Windows (via WSL). Choose one of the following environment setups:

### Conda environment

```bash
conda create -n datalog python=3.11 ruby=3.2 nodejs
conda activate datalog
# Install Ruby dependencies
bundle install
# Optional: install Python tooling for notebooks and builds
pip install jupyter nbconvert
```

### Pip + system Ruby

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install jupyter nbconvert
# Ensure Ruby and Bundler are available
ruby -v
bundle install
```

### Running the site locally

```bash
bundle exec jekyll serve --livereload
```

The site will be available at `http://localhost:4000`. The command watches Markdown, notebooks, Sass, and data files, rebuilding pages as you edit them.

## 2. Jupyter Notebook Integration Tutorial

1. Place `.ipynb` files inside `_notebooks/`. The `notebook_converter` plugin renders them into blog posts during `jekyll build` or `jekyll serve`.
2. Populate notebook metadata (`title`, `authors`, `difficulty`, `tags`) through the notebook JSON or via front matter overrides created in `_data/notebooks.yml`.
3. Interactive outputs such as Plotly, ipywidgets, and Bokeh cells are preserved using the theme's visualization runtime. For custom JavaScript outputs, ensure they ship with self-contained HTML snippets.
4. Readers can download the original notebook automatically—links are generated in the notebook layout.
5. Configure Binder and Colab URLs in `_config.yml` under `integrations.notebooks` to expose “Run in Binder” and “Open in Colab” buttons.

## 3. Mathematical Expression Authoring

DataLog supports MathJax and KaTeX. Configure the engine in `_config.yml` under `theme_options.math.engine`.

### Inline and display math

```markdown
Einstein's equation $E = mc^2$ demonstrates mass–energy equivalence.

$$
\nabla \cdot \vec{E} = \frac{\rho}{\varepsilon_0}
$$
```

### Common packages and numbering

- Use `\begin{align}` to typeset multi-line derivations.
- Reference equations with `\label{eq:bayes}` and `\eqref{eq:bayes}`—DataLog auto-numbers and links equations.
- For chemical notation, rely on `mhchem` syntax: `\ce{H2O + CO2 ->[light] C6H12O6 + O2}`.

## 4. Interactive Visualization Embedding

- **Plotly/D3/Bokeh**: Wrap serialized chart specs in `<div class="viz" data-viz-type="plotly" data-viz-src="/assets/plots/sample.json"></div>` and the visualization runtime handles lazy loading.
- **Observable notebooks**: Embed using `data-observable="https://observablehq.com/@user/notebook"` on the same container.
- **R Shiny or external apps**: Use responsive iframes with the `viz-frame` class for automatic sizing and accessibility overlays.
- **Static exports**: The export toolbar in visualization cards allows readers to download PNG/SVG representations; configure defaults in `_config.yml` under `theme_options.visualizations`.

## 5. Research Workflow Integration

- Synchronize publications by pointing `_data/academic.yml` to Google Scholar, ORCID, and BibTeX feeds.
- Track submissions via the Academic Operations data structures (`_data/academic.yml -> submissions`).
- Use project layouts to document experimental design, datasets, and collaboration guidelines, ensuring reproducibility checklists are filled out in the front matter.
- Configure academic calendars and grant trackers to keep lab members informed of deadlines and funding opportunities.

## 6. Academic Writing & Citation Guidelines

- Cite literature with the built-in citation blocks: include a `citations` array in front matter referencing BibTeX keys.
- Export references via the citation toolbar (BibTeX, RIS, EndNote). Users can download ready-made bibliography files located in `assets/publications/`.
- Provide data availability statements in research layouts to align with open science expectations.
- Include ORCID IDs and institutional affiliations (e.g., *ESMAD – Instituto Politécnico do Porto*) for transparent authorship.

## 7. Data Science Project Showcase Optimization

- Use `_layouts/project.html` to highlight problem statements, solution approaches, datasets, metrics, and lessons learned.
- Populate `_data/projects.yml` with GitHub repository URLs to enable live star/fork/issue statistics.
- Add `tech_stack` arrays to control icon badges and tooltips.
- Embed demo videos or interactive dashboards in the layout's demo slot (`project_demo` in front matter) for an immersive portfolio experience.

## 8. SEO for Technical Content

- Customize `title`, `description`, and `keywords` in `_config.yml` and per-page front matter.
- Enable `jekyll-seo-tag` and structured data (already configured in `default.html`).
- Provide canonical URLs, `og:image`, and `twitter:image` paths for each post—especially visualizations and notebooks.
- Use descriptive alt text for charts and code snippets to improve accessibility and search rankings.

## 9. Accessibility Guidelines

- Maintain semantic heading order and use `<figure>`/`<figcaption>` for charts and tables.
- Provide text equivalents for complex math and ensure contrast ratios meet WCAG 2.1 AA (the default palette complies).
- Enable keyboard-accessible components: the theme already supplies focus states, but verify custom embeds respect tab order.
- Utilize the skip link (`_includes/skip-link.html`) and ARIA labels present in the header/footer includes.

## 10. Performance Optimization

- Defer heavy scripts by toggling `theme_options.performance.defer_visualizations` and `...lazy_math` in `_config.yml`.
- Compress large images and datasets. Store raw data externally when possible and link via metadata.
- Paginate long collections using `paginate` and `paginate_path` in `_config.yml`.
- Run `JEKYLL_ENV=production bundle exec jekyll build` to generate minified assets before deployment.

## 11. Collaboration & Version Control Workflows

- Use Git LFS for binary datasets or large media files.
- Store environment definitions (`environment.yml`, `requirements.txt`, `Dockerfile`) in the repository to support reproducibility.
- Encourage pull request templates that capture academic peer-review checklists (methodology validation, dataset licensing, etc.).
- Automate CI with GitHub Actions to run `bundle exec jekyll build` and notebook linting (e.g., `nbqa`, `pytest`).

## 12. Troubleshooting

| Issue | Resolution |
| --- | --- |
| `jekyll` command missing | Install Ruby via rbenv/rvm or Conda and rerun `bundle install`. |
| Notebook conversion fails | Ensure the notebook has been executed and contains JSON metadata; check `_plugins/notebook_converter.rb` logs. |
| Math not rendering | Verify `theme_options.math.enabled` is `true` and there are no LaTeX syntax errors (MathJax will log them in the console). |
| Visualizations not loading | Confirm data attributes (`data-viz-type`, `data-viz-src`) are set and the referenced files exist. |
| GitHub API rate limiting | Configure a `github_token` in `_config.yml` or as an environment variable for authenticated requests. |

## 13. Migration Guide

1. **Back up your existing theme** and export content.
2. **Copy Markdown posts, datasets, and projects** into the respective DataLog collections.
3. **Map configuration**: merge your existing `_config.yml` values into DataLog's configuration, paying special attention to `collections`, `theme_options`, and `integrations` blocks.
4. **Adapt styles**: port custom CSS into `_sass/_overrides.scss` (create the file if needed) and import it from `main.scss`.
5. **Validate navigation**: update `_data/navigation.yml` and `_data/social.yml` to reflect your desired menus and profile links.
6. **Run local builds** and address warnings, particularly around math, citations, and dataset metadata.

## 14. Contributing Guidelines

We welcome contributions from the academic and data science community:

1. Fork the repository and create a feature branch.
2. Ensure `bundle exec jekyll build` and `bundle exec rake ci:verify` complete without errors (install Jekyll locally if necessary).
3. Add or update tests/documentation when modifying plugins or layouts.
4. Follow the existing code style and Sass architecture (`_sass/` directory). Avoid wrapping imports in try/catch blocks.
5. Submit a pull request summarizing your changes and referencing related issues or discussions.

## 15. Release Management & Community Distribution

When you're ready to publish a new version of DataLog or announce major updates:

1. Update the version constants (`lib/datalog/theme/version.rb`, `_config.yml`, `CITATION.cff`).
2. Run the verification suite (`bundle exec rake ci:verify`) and ensure GitHub Actions succeeds.
3. Follow the detailed checklist in [`docs/distribution.md`](distribution.md) to release the gem, submit to the Jekyll theme directory, and coordinate outreach with academic communities.
4. Share the preferred citation (from `CITATION.cff`) in announcements and research communications.

## 16. Visual Regression & Percy Workflows

- **Playwright assertions**: The browser specs verify semantic structure—hero content, navigation behavior, search live regions, visualization fallbacks, and dark-mode tokens—without committing binary screenshots. Run them with the helper (`npm run test:visual:auto`) or point them at an existing preview via `npm run test:visual`.
- **Percy snapshots**: Pull requests trigger the "Visual regression (Percy)" workflow, which builds the site and executes `npm run test:visual:percy` against a preview server. Set `PERCY_TOKEN` in repository secrets to enable uploads.
- **Approvals**: Percy will pause merges until visual diffs are reviewed. Approve intended design updates in Percy’s UI so the check passes.
- **Stability tips**: The shared visual helper waits for fonts, math rendering, and visualization hydration and freezes animations for deterministic snapshots. Update `tests/visual/helpers.js` when new UI surfaces need additional stabilizers.

For support or collaboration inquiries, reach out to **Diogo Ribeiro** (<dfr@esmad.ipp.pt>) or open a GitHub issue at [`DiogoRibeiro7/analytics-blog-jekyll`](https://github.com/DiogoRibeiro7/analytics-blog-jekyll).

