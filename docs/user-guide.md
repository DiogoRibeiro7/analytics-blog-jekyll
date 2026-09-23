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

1. Place `.ipynb` files inside `_notebooks/`. The `notebook_converter` plugin publishes each one as a page under `/notebooks/` during `jekyll build` or `jekyll serve`.
2. The page takes its title, authors and tags from the notebook's own metadata: `title` (or `datalog.title`, falling back to the notebook's first heading), `authors`, and `tags` or `keywords`.
3. Interactive outputs such as Plotly, ipywidgets, and Bokeh cells are preserved using the theme's visualization runtime. For custom JavaScript outputs, ensure they ship with self-contained HTML snippets.
4. Readers can download the original notebook automatically—links are generated in the notebook layout.
5. The “Run in Binder” and “Open in Colab” buttons link to the repository and branch set under `notebooks:` in `_config.yml` (`repository`, `branch`); `notebooks.binder.base_url` and `notebooks.colab.base_url` change the link formats.

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

### Figures, tables and cross-references

Figures and tables are numbered within each page, in the order they appear, and a reference reads "Figure 2" or "Table 1" and links to its target. Give each an id that starts with a letter; the number follows the page, so reordering the figures renumbers every reference to them. A worked example, with an equation, a figure and a table referring to each other:

```markdown
The power of a two-sided test (equation \eqref{eq:power}) grows with the
effect size $\delta$, as {% ref fig-power %} shows for the sample sizes in
{% ref tab-samples %}.

$$
1 - \beta = \Phi\left(\delta \sqrt{n} - z_{1-\alpha/2}\right) \label{eq:power}
$$

{% figure id="fig-power" src="/assets/img/power-curve.png" alt="Power rising with effect size" %}
Power as a function of effect size $\delta$ for $\alpha = 0.05$.
{% endfigure %}

{% table id="tab-samples" %}
Sample sizes simulated, with the runs for each.

| $n$ | Runs |
|-----|------|
| 20  | 5000 |
| 50  | 5000 |
{% endtable %}

Beyond $n = 50$, {% ref fig-power %} flattens.
```

- `{% figure %}` needs `id`, `src` and `alt`, and takes an optional `class`. Its body is the caption, so the caption can hold Markdown and math. Attributes accept either quote style, with `\"`, `\'` and `\\` for literal quotes and backslashes: `alt="The \"null\" model"`. Malformed attributes stop the build and identify the page and tag. Tables, statements and proofs use the same syntax.
- `{% figure %}` takes `dark_src`, the same figure exported for a dark page, and serves it to readers in dark mode. A `power-dark.png` beside `power.png` is found without being named; see [Dark figures](configuration-guide.md#dark-figures). To export both from matplotlib, draw under two rc contexts:

  ```python
  import matplotlib.pyplot as plt

  DARK = {"figure.facecolor": "#171717", "axes.facecolor": "#171717",
          "savefig.facecolor": "#171717", "text.color": "#f5f5f4",
          "axes.labelcolor": "#f5f5f4", "axes.edgecolor": "#a8a29e",
          "xtick.color": "#f5f5f4", "ytick.color": "#f5f5f4", "grid.color": "#2a2a2a"}

  def save_both(draw, stem):
      """draw(ax) twice: power.png for the light page, power-dark.png for the dark one."""
      for suffix, overrides in (("", {}), ("-dark", DARK)):
          with plt.rc_context(overrides):
              fig, ax = plt.subplots()
              draw(ax)
              fig.savefig(f"assets/img/{stem}{suffix}.png", dpi=150, bbox_inches="tight")
              plt.close(fig)
  ```

  Export both opaque. A transparent figure is worse than either: its black axes and labels land unreadable on the dark page.

- `{% table %}` needs `id`. Its body is the caption, then one Markdown table; the caption goes into the table's `<caption>`.
- `{% ref id %}` becomes a link reading "Figure 2" or "Table 1". It may come before its target. In a post's excerpt, on listings and in feeds, it links to the figure on the post's page.
- A reference to an id no figure or table on the page has, or two figures or tables with the same id, stops the build and names the page.
- The words come from `references.figure` and `references.table` in `_data/i18n`, so a page with `lang: pt` reads "Figura 2"; a site can change them there. Numbers do not carry across pages.
- Markdown images and tables written without these tags are left as they are. In print, a numbered figure or table is kept on one page where it fits.

### Theorems, definitions and proofs

Theorems, lemmas, propositions, corollaries, definitions, assumptions, examples and remarks are numbered and referred to like figures and tables. A proof names the statement it proves. A short article:

```markdown
Let $X_1, \dots, X_n$ be independent draws from a distribution with mean $\mu$.

{% definition id="def-consistent" title="Consistency" %}
An estimator $\hat\theta_n$ is *consistent* for $\theta$ when
$\hat\theta_n \to \theta$ in probability as $n \to \infty$.
{% enddefinition %}

{% assumption id="as-variance" %}
The variance $\sigma^2$ of each $X_i$ is finite.
{% endassumption %}

{% theorem id="thm-wlln" title="Weak law of large numbers" %}
Under {% ref as-variance %}, the sample mean $\bar X_n$ is consistent for $\mu$
in the sense of {% ref def-consistent %}.
{% endtheorem %}

{% proof for="thm-wlln" %}
By Chebyshev's inequality, for every $\varepsilon > 0$,

$$
P\left(|\bar X_n - \mu| \ge \varepsilon\right) \le \frac{\sigma^2}{n \varepsilon^2},
$$

which tends to $0$ as $n \to \infty$.
{% endproof %}

{% remark id="rem-strong" %}
The strong law gives almost sure convergence without {% ref as-variance %}:
a finite mean is enough.
{% endremark %}
```

- The tags are `theorem`, `lemma`, `proposition`, `corollary`, `definition`, `assumption`, `example` and `remark`, each closed by its `end` tag, such as `{% endtheorem %}`. Each needs `id` and takes an optional `title`, shown in parentheses after the number. The title is plain text; the body can hold Markdown, math, lists and code.
- Each kind is numbered on its own, in page order: the first lemma is "Lemma 1" however many theorems come before it. `{% ref id %}` reads "Theorem 1" and links to the statement. Statements, figures and tables share the page's ids, so two with the same id stop the build.
- `label="A"` shows "Theorem A" in place of a number, for a result named in an appendix or restated from elsewhere, and a statement with a label does not take a number. A label is letters and digits, with `.`, `'`, `*` or `-`.
- `{% proof %}` is not numbered. With `for="thm-wlln"` its heading reads "Proof of Theorem 1" and links to the theorem, and the build stops when the page has no statement with that id. A proof ends with ∎; `qed="false"` leaves the mark out, for a proof that continues after it.
- Theorems, lemmas, propositions and corollaries share one accent colour, definitions and assumptions another, and examples and remarks a neutral one. Screen readers announce each statement and proof as a group named by its heading, and skip the ∎. In print, a statement is kept on one page where it fits.
- The words come from `references.theorem` to `references.remark`, `references.proof` and `references.proof_of` in `_data/i18n`, so a page with `lang: pt` reads "Teorema 1" and "Demonstração de Teorema 1".

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

### Publishing a dataset so it can be found

A page in `_datasets/` carries `schema.org/Dataset` structured data, which is
what [Google Dataset Search](https://datasetsearch.research.google.com/)
indexes — an ordinary `WebPage` description does not reach it. The front matter
the dataset layout already renders is what fills it in, so most of this costs
nothing extra:

```yaml
---
title: Urban Mobility Sensor Dataset
summary: Multimodal transit sensor readings across Porto.
updated: 2024-05-01
license: CC-BY-4.0            # resolved to the licence's own URL
download_url: https://example.com/data/urban-mobility.zip
schema:                       # each field becomes a variableMeasured
  - name: timestamp
    description: UTC timestamp of the observation
---
```

Optional front matter, each left out of the output when absent:

| Key | Becomes |
| --- | --- |
| `doi` | `identifier`, as a PropertyValue and a `https://doi.org/…` URL |
| `keywords` | `keywords`; falls back to `tags` |
| `temporal_coverage` | `temporalCoverage`, e.g. `2019-01-01/2021-12-31` |
| `spatial_coverage` | `spatialCoverage` |
| `measurement_technique` | `measurementTechnique` |
| `citation` | `citation` |
| `is_accessible_for_free: false` | marks a dataset behind a wall |
| `distributions` | several downloads instead of one `download_url` |

`distributions` takes a list, and each entry may be a bare URL or a hash:

```yaml
distributions:
  - url: https://example.com/data/readings.csv
    name: Tabular export
  - url: /data/readings.parquet     # a site-relative path is made absolute
```

The media type is inferred from the extension — csv, tsv, json, jsonl, zip, gz,
parquet, xlsx, nc, h5 — and `format:` on the entry overrides it.

Two things worth knowing. A dataset with no `date:` in its front matter claims
no `datePublished`: Jekyll gives a collection document the build time, and
writing that out would both invent a date and change the page on every build.
And every dataset names the site's `/datasets/` index as the `DataCatalog` it
belongs to.

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
| Math not rendering | With `theme_options.math.render_on_load: auto`, MathJax loads only on pages that contain math. Inline math with spaces inside the dollars counts only when it holds a TeX command, `^` or `_`, so write `$ x $` as `$x$`, or add `math: true` to the page's front matter to load MathJax regardless. Check the browser console for LaTeX errors. |
| Visualizations not loading | Confirm data attributes (`data-viz-type`, `data-viz-src`) are set and the referenced files exist. |
| GitHub API rate limiting | Configure a `github_token` in `_config.yml` or as an environment variable for authenticated requests. |

## 13. Migration Guide

Coming from Minimal Mistakes? Its `header` images, `seo_title`, `seo_description`, `classes: wide` and `redirect_from` fields are read natively; see [docs/migrating-from-minimal-mistakes.md](migrating-from-minimal-mistakes.md) for the field table and the permalink settings that preserve URLs.

1. **Back up your existing theme** and export content.
2. **Copy Markdown posts, datasets, and projects** into the respective DataLog collections.
3. **Map configuration**: merge your existing `_config.yml` values into DataLog's configuration, paying special attention to `collections`, `theme_options`, and `integrations` blocks.
4. **Adapt styles**: port custom CSS into `_sass/_overrides.scss` (create the file if needed) and import it from `main.scss`.
5. **Validate navigation**: update `_data/navigation.yml` and `_data/social.yml` to reflect your desired menus and profile links.
6. **Run local builds** and address warnings, particularly around math, citations, and dataset metadata.

## 14. Contributing Guidelines

We welcome contributions from the academic and data science community:

1. Fork the repository and create a feature branch.
2. Ensure `npm test` and `bundle exec rake test` complete without errors.
3. Add or update tests/documentation when modifying plugins or layouts.
4. Follow the existing code style and Sass architecture (`_sass/` directory). Avoid wrapping imports in try/catch blocks.
5. Submit a pull request summarizing your changes and referencing related issues or discussions.

## 15. Release Management & Community Distribution

When you're ready to publish a new version of DataLog or announce major updates:

1. Update the version constants (`lib/datalog/theme/version.rb`, `_config.yml`, `CITATION.cff`).
2. Run the test suites (`npm test`, `bundle exec rake test`) and ensure GitHub Actions succeeds.
3. Follow the detailed checklist in [`docs/distribution.md`](distribution.md) to release the gem, submit to the Jekyll theme directory, and coordinate outreach with academic communities.
4. Share the preferred citation (from `CITATION.cff`) in announcements and research communications.

## 16. Browser Checks

- **Playwright integration specs**: `tests/integration/` verifies the rendered site in a real browser: landmarks and keyboard access, the dark-mode toggle, responsive layout without horizontal overflow, blog navigation and reading progress, search, and visualization loading with accessible data tables. Run them with `npm run test:integration` (builds and serves the site for you) or `npm run test:integration:direct` against an existing `PLAYWRIGHT_BASE_URL`.
- **Where they run**: the deploy workflow runs the same specs against the freshly built site before publishing, so a regression there blocks the deploy rather than the site.
- **Coverage**: `bundle exec rake coverage` runs the Minitest suite under SimpleCov and holds it to the thresholds in `.simplecov`; `npm run test:coverage` does the same for the browser modules against `vitest.config.js`. Both write a readable report into `coverage/`. A plain `rake test` measures nothing and stays about three times quicker.

For support or collaboration inquiries, reach out to **Diogo Ribeiro** (<dfr@esmad.ipp.pt>) or open a GitHub issue at [`DiogoRibeiro7/analytics-blog-jekyll`](https://github.com/DiogoRibeiro7/analytics-blog-jekyll).

