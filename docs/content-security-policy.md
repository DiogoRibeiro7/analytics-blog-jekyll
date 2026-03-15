# Content Security Policy Guide

The DataLog theme ships with a strict Content Security Policy (CSP) that blocks inline scripts and
styles unless they are explicitly authorized. This guide explains how the CSP implementation works,
how nonces and script hashes are generated, and the steps required when adding new scripts or third-
party integrations.

## How the CSP is generated

- During the build the `_plugins/csp_generator.rb` plugin assigns a **unique nonce** to every page and
  document. The nonce is available in templates as `page.csp_nonce` and is stored centrally under
  `site.data.csp.nonces` for debugging.
- After each page renders the plugin calculates SHA-256 hashes for any inline script blocks. These
  hashes are exposed via `page.csp_hashes` and referenced inside the CSP meta tag to support
  third-party snippets that cannot accept nonces.
- The `_includes/csp-meta.html` include assembles a directive set that whitelists first-party assets,
  trusted CDNs, and the per-page nonce. Violations are reported to `/csp-report/` for local testing
  and observability.

## Working with inline scripts

- Whenever you add a new inline `<script>` block, include `nonce="{{ page.csp_nonce }}"` to authorize
  it. The CSP generator automatically inserts the nonce if you forget, but adding it manually keeps
  templates self-documenting.
- For JSON data blobs, specify the nonce as well: `<script type="application/json" nonce="{{
  page.csp_nonce }}">…</script>`.
- Avoid inline styles. If you must include them for critical rendering paths, use `<style
  nonce="{{ page.csp_nonce }}">` so the CSP allows them.

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
  accepts the `report-uri` endpoint.
- If a violation persists, inspect the page’s source to confirm the nonce is present and that the CSP
  meta tag lists the expected domains. Adding `jekyll.environment=development` removes minification
  noise when debugging.

Following these practices keeps the analytics dashboard, visualization gallery, and math tooling
locked down while still enabling rich interactivity.
