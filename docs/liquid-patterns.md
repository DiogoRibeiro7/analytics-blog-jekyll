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
{% include meta/schema.html page=page type='TechnicalArticle' %}
```

### `meta/scripts-loader.html`
*Purpose*: Consolidate Prism asset loading and shared data bootstrapping.
*Usage*:
```liquid
{% include meta/scripts-loader.html location='head' %}
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
Encapsulates the default layout article structure and metadata.
```liquid
{% include layouts/default/article.html page=page content=content date_format=date_format %}
```

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
{% include meta/scripts-loader.html location='head' %}
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
