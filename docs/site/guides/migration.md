---
title: Migration guides
permalink: /guides/migration/
description: Step-by-step instructions for migrating from popular Jekyll themes to DataLog without breaking URLs or SEO.
---

<section class="section">
  <div class="container">
    <h2 id="installing-the-theme-gem">Installing the theme gem</h2>
    <ol>
      <li>Add <code>gem "datalog-theme"</code> to your site's <code>Gemfile</code>.</li>
      <li>Update <code>_config.yml</code> with <code>theme: datalog-theme</code> and copy the sample configuration from this documentation site.</li>
      <li>Run <code>bundle exec jekyll serve</code> to verify the site builds locally.</li>
    </ol>
  </div>
</section>

<section class="section section-alt">
  <div class="container">
    <h2>Minimal Mistakes → DataLog</h2>
    <ol>
      <li>Rename <code>_posts</code> and collection folders to match the theme naming (`_portfolio`, `_datasets`, `_notebooks`).</li>
      <li>Replace layouts with the DataLog equivalents (<code>post</code>, <code>project</code>, <code>dataset</code>, <code>notebook</code>).</li>
      <li>Swap includes (e.g. hero, callouts) with the DataLog component includes demonstrated in the <a href="/features/components/">component showcase</a>.</li>
      <li>Review navigation in `_data/navigation.yml` to ensure header links point to the new sections.</li>
    </ol>
  </div>
</section>

<section class="section">
  <div class="container">
    <h2>Just the Docs → DataLog</h2>
    <ol>
      <li>Move Markdown files from the `docs/` directory into `_pages/` or appropriate collections.</li>
      <li>Remove the Just the Docs navigation config and adopt the DataLog navigation data structure.</li>
      <li>Set <code>permalink: pretty</code> in `_config.yml` to maintain clean URLs.</li>
      <li>Enable search by including <code>search_enabled: true</code> and running the theme's search index generator.</li>
    </ol>
  </div>
</section>

<section class="section section-alt">
  <div class="container">
    <h2>Chirpy → DataLog</h2>
    <ol>
      <li>Copy blog posts into `_posts/` preserving filenames to retain permalinks.</li>
      <li>Translate `_config.yml` settings such as Disqus, analytics, and author metadata into the DataLog config schema.</li>
      <li>Replace custom JavaScript with the theme's <code>assets/js/visualizations.js</code> where interactive charts are required.</li>
      <li>Test locally, then update your GitHub Actions workflow using the one bundled in <code>docs/site/.github/workflows/deploy.yml</code>.</li>
    </ol>
  </div>
</section>

<section class="section">
  <div class="container">
    <h2>Post-migration checklist</h2>
    <ul>
      <li>Regenerate favicons and touch icons to match your branding.</li>
      <li>Run the theme stability test suite (`bundle exec ruby -Itests ...`) to ensure notebooks, math, and visualizations render correctly.</li>
      <li>Update sitemap and RSS feed URLs in search consoles.</li>
      <li>Announce the migration in your documentation blog to inform subscribers of the refreshed experience.</li>
    </ul>
  </div>
</section>
