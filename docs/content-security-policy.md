# Content Security Policy Guide

The DataLog theme ships with a strict Content Security Policy (CSP) that blocks inline scripts and
styles unless they are explicitly authorized. This guide explains how the CSP implementation works,
how nonces and script hashes are generated, and the steps required when adding new scripts or third-
party integrations.

## How the CSP is generated

- During the build the `_plugins/csp_generator.rb` plugin assigns a **unique nonce** to every page and
  document. The nonce is available in templates as `page.csp_nonce` and is stored centrally under
  `site.data.csp.nonces` for debugging.
- After each page renders, the plugin gives every inline `<script>` that lacks one the page's nonce.
- The `_includes/csp-meta.html` include writes the policy for each page, from what the page loads.
  Violations are reported to `/csp-report/` for local testing and observability.

## What each page allows

| Directive | Every page | Added when the page needs it |
|---|---|---|
| `script-src` | `'self'`, the page nonce | the math engine's directory on pages with math; Plotly, D3, BokehJS or Vega on pages with those blocks; Chart.js on the analytics dashboard; `https://*.disqus.com` and `https://*.disquscdn.com` on pages with Disqus comments; `https://*.googletagmanager.com` on a site that sets `google_analytics` |
| `style-src` | `'self'`, the page nonce, Google Fonts | KaTeX's `dist/` directory on KaTeX pages; `https://*.disquscdn.com` on Disqus pages; `'unsafe-inline'` in place of the nonce on pages with MathJax, Plotly, a Jupyter widget or Disqus comments |
| `font-src` | `'self'`, Google Fonts, `data:` | the math engine's directory on pages with math |
| `connect-src` | `'self'`, `https://api.github.com` | MathJax's directory on MathJax pages; `https://*.disqus.com` on Disqus pages; Google's analytics hosts on a site that sets `google_analytics` |
| `frame-src` | `'self'`, Observable (`observablehq.com` and `old.observablehq.com`, where its embeds redirect) | `https://disqus.com` on Disqus pages; the hosts in `csp.frame_src` |
| `object-src` | `'none'` | |
| `base-uri` | `'self'` | |
| `form-action` | `'self'` | |

jsDelivr serves any npm package, so the policy names the packages a page loads instead of the whole
host. The math engine's directory comes from `theme_options.math.mathjax_cdn` or `katex_cdn`, the
same setting the script tags use. The chart library URLs are written in
`assets/js/visualizations.js`, `assets/js/notebook.js` and `_includes/analytics/dashboard.html`;
when one changes, change it in `csp-meta.html` too, and `tests/test_csp.rb` fails until both agree.

A site that embeds something else lists the sources in `_config.yml`:

```yaml
csp:
  frame_src:
    - https://shiny.posit.co
  script_src:
    - https://widgets.example.org/
  style_src: []
  font_src: []
  connect_src:
    - https://api.example.org
```

## Working with inline scripts

- Whenever you add a new inline `<script>` block, include `nonce="{{ page.csp_nonce }}"` to authorize
  it. The CSP generator automatically inserts the nonce if you forget, but adding it manually keeps
  templates self-documenting.
- For JSON data blobs, specify the nonce as well: `<script type="application/json" nonce="{{
  page.csp_nonce }}">…</script>`.
- Avoid inline styles. If you must include them for critical rendering paths, use `<style
  nonce="{{ page.csp_nonce }}">` so the CSP allows them.

## Pages with Plotly or Jupyter widgets

Two libraries the visualization blocks load can't run under the strict policy:

- Plotly inserts its rules into a `<style>` element it creates, which carries no nonce.
- The Jupyter widget manager adds `<style>` elements as well, and compiles the widgets' JSON schemas
  with `new Function`.

The policy loosens only on the pages that run them. `_includes/csp-meta.html` looks at the rendered
page:

| The page contains | `style-src` | `script-src` | `font-src` |
|---|---|---|---|
| `data-viz-type="plotly"`, or a `notebook-output-plotly` element | `'unsafe-inline'` in place of the nonce | unchanged | unchanged |
| `data-viz-type="ipywidgets"`, or a widget state script | `'unsafe-inline'` in place of the nonce | adds `'unsafe-eval'` | adds jsDelivr, for the widget icon fonts |

Pages with MathJax, whose CHTML output inserts the stylesheet its layout depends on, and pages with
Disqus comments, whose embed sizes its iframe with an inline style, also get `'unsafe-inline'` in
`style-src`.

`style-src` drops the nonce on those pages because a browser ignores `'unsafe-inline'` in a directive
that also lists a nonce. Scripts need the nonce on every page.

A page that loads either library some other way can ask for the same allowances in its front matter:

```yaml
csp:
  unsafe_inline_styles: true
  unsafe_eval: true
```

## Extending CDN allowances with Subresource Integrity

- All external scripts and styles must provide Subresource Integrity (SRI) hashes. The canonical
  hashes live in `_data/cdn-integrity.yml` and are consumed automatically by the head include and the
  shared script loader.
- Run `npm run generate-sri` after adding or upgrading CDN assets. The script scans the templates,
  fetches each remote resource, and regenerates `_data/cdn-integrity.yml` with fresh SHA-384 hashes.
- After building the site, execute `npm run validate-sri` to confirm every external `<script>` and
  stylesheet reference includes `integrity="…" crossorigin="anonymous"`. The deploy workflow runs this
  check automatically to prevent regressions.

## Debugging violations

- In non-production builds the theme installs a `securitypolicyviolation` listener that logs blocked
  resources to the browser console with helpful metadata (directive, blocked URI, line number).
- Visit `/csp-report/` locally to submit mock violation payloads and verify your hosting provider
  accepts the `report-uri` endpoint. Reporting only works when the policy is delivered as an HTTP
  header; the `<meta>` policy the theme emits cannot carry a `report-uri` directive, so add it in
  your hosting configuration.
- If a violation persists, inspect the page’s source to confirm the nonce is present and that the CSP
  meta tag lists the expected domains. Adding `jekyll.environment=development` removes minification
  noise when debugging.

Following these practices keeps the analytics dashboard, visualization gallery, and math tooling
locked down while still enabling rich interactivity.
