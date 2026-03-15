# DataLog Demo Site

The root of this repository doubles as a fully configured demo site showcasing every major capability of the DataLog theme:

- **Blog Posts & Tutorials** with technical metadata, math, syntax highlighting, and reproducibility checklists.
- **Research Articles** featuring abstract layouts, citation exports, peer review timelines, and dataset disclosures.
- **Project Portfolios** complete with interactive demos, GitHub statistics, model performance metrics, and collaboration notes.
- **Datasets & Visualization Hubs** with licensing information, accessibility affordances, and responsive embeds for Plotly, D3, Bokeh, Observable, and Jupyter widgets.
- **Notebook Publishing** powered by the bundled converter plugin that transforms `.ipynb` files into theme-aware posts.

## Running the Demo Locally

```bash
bundle install
npm install --global yarn # optional for additional tooling
bundle exec jekyll serve
```

The site loads sample content under `/`, `/blog/`, `/portfolio/`, `/datasets/`, `/visualizations/`, and `/docs/` to illustrate end-to-end data science storytelling.

## Deploying to GitHub Pages

1. Fork the repository.
2. Enable GitHub Actions and allow the provided CI workflow to build the site.
3. Configure the repository as a GitHub Pages site (Project Pages or User/Org Pages).

The included workflow publishes build artifacts and verifies math rendering, syntax highlighting, accessibility, and visualization readiness, ensuring the demo remains production-quality.
