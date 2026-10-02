# Liquid Patterns and Reusable Partials

This document describes the reusable Liquid includes introduced to simplify site layouts and component logic. Each include documents required and optional parameters inside a YAML-style comment block at the top of the file.

## Meta Includes

### `meta/math-config.html`
*Purpose*: Normalize math rendering flags for layouts.
*Usage*:
```liquid
{% include meta/math-config.html page=page %}
```
*Provides*: `math_enabled`, `math_engine`, `math_status_id`, `math_has_expressions`.

### `meta/schema.html`
*Purpose*: Emit JSON-LD schema data with sensible defaults.
*Usage*:
```liquid
{% include meta/schema.html page=page type='TechArticle' %}
```

### `meta/publisher.html`
*Purpose*: Resolve the site's publisher from `publisher` in `_config.yml`, defaulting to the author as a `Person`.
*Usage*:
```liquid
{% include meta/publisher.html %}
```
*Provides*: `publisher_type`, `publisher_name`, `publisher_url`, `publisher_logo`, `publisher_logo_default`, `site_author_name`.

### `meta/scripts-loader.html`
*Purpose*: Output the page data scripts and the feature loader at the end of the body.
*Usage*:
```liquid
{% include meta/scripts-loader.html location='body' %}
```

### `meta/language-attributes.html`
*Purpose*: Resolve `lang` and `dir` attributes for the root HTML element.
*Usage*:
```liquid
{% include meta/language-attributes.html page=page %}
{{ html_lang }} {{ html_dir }}
```

## Helper Includes

### `helpers/array-to-sentence.html`
Formats arrays into human-readable comma-separated strings with an optional conjunction.
```liquid
{% include helpers/array-to-sentence.html items=page.tags conjunction='and' %}
```

### `helpers/date-format.html`
Centralizes localized date formatting.
```liquid
{% include helpers/date-format.html date=page.date format='long' %}
```

### `helpers/link-with-icon.html`
Renders an accessible link with optional icon markup.
```liquid
{% include helpers/link-with-icon.html url=profile.url label=profile.label icon='↗' target='_blank' %}
```

## Layout Components

### `layouts/default/article.html`
The heading and content of every layout built on `default`.
```liquid
{% include layouts/default/article.html page=page content=content date_format=date_format %}
```

What the heading holds:
- **Title:** the page's `<h1>`, unless the layout or the page sets `show_title: false` because it renders its own.
- **Summary:** under the title, the page's `summary`, or a collection document's `description`. It is never the excerpt, which is the content's own first paragraph.
- **Date and authors:** labelled, as the post's metadata row is.
  - The date is the one front matter or a post's file name gives. Jekyll gives an undated document the time of the build, and that is never shown as a publication date; the `published_date` filter tells them apart.
  - The authors are left out with `show_author: false`.
  - Neither appears when the layout or the page sets `article_meta: false`. The post, package, dataset, notebook, project, portfolio, research, home and archive layouts set it, because they show their own (#411).

The element is no microdata item. The page's JSON-LD (`meta/schema.html`) describes it, and a layout that wants microdata, as the post, notebook, project and research layouts do, opens its own item.

### `components/math-fallback.html`
Provides `<noscript>` fallbacks for preprocessed math expressions.
```liquid
{% include components/math-fallback.html expressions=page.math_expressions %}
```

### `post/related-posts.html`
Generates the related posts list based on shared taxonomy.
```liquid
{% include post/related-posts.html page=page date_format=date_format limit=3 %}
```

### `header/navigation.html`
Handles primary navigation rendering and active state detection.
```liquid
{% include header/navigation.html items=nav_items page=page contexts=page_contexts %}
```

### `footer/nav-column.html`
Outputs footer navigation columns with optional descriptions.
```liquid
{% include footer/nav-column.html title=research_title items=research_items show_descriptions=true %}
```

## Refactor Highlights

### `_layouts/default.html`
**Before**: Inline math configuration, schema generation, and script bootstrapping logic (~150 lines).
```liquid
{% assign math_settings = site.theme_options.math %}
{% if page.tags and page.tags.size > 0 %}
  <meta name="keywords" content="{{ page.tags | join: ', ' }}" />
{% endif %}
...
<script defer src="{{ prism_cdn }}/prism.min.js"></script>
```
**After**: Concise layout delegating concerns to targeted includes (~50 lines).
```liquid
{% include meta/math-config.html page=page %}
{% include meta/language-attributes.html page=page %}
...
{% include meta/scripts-loader.html location='body' %}
...
{% include layouts/default/article.html page=page content=content date_format=date_format %}
```

### `_layouts/post.html`
**Before**: Embedded 60-line related posts loop with manual filtering.
**After**: One-line include call with the same behavior:
```liquid
{% include post/related-posts.html page=page date_format=date_format %}
```

### `_includes/header.html`
**Before**: Primary navigation loop duplicated across layouts.
**After**: Centralized navigation rendering:
```liquid
{% include header/navigation.html items=nav_items page=page contexts=page_contexts %}
```

### `_includes/footer.html`
**Before**: Repeated markup for each footer column.
**After**: Config-driven include usage:
```liquid
{% include footer/nav-column.html title=research_title items=research_config.items show_descriptions=true %}
```

These patterns keep layouts focused on structure while allowing other pages to reuse the same helpers.
