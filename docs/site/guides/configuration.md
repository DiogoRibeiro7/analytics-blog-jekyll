---
title: Configure a DataLog site
description: Set up site identity, navigation, search, and appearance with working Jekyll examples.
permalink: /guides/configuration/
---

## Site identity and project paths

Set your public URL in `_config.yml`. Leave `baseurl` empty for a root site, or use the repository path for a GitHub Pages project site:

```yaml
title: My research site
description: Notes, notebooks, and research articles
url: https://username.github.io
baseurl: /research-site
author:
  name: Your Name
```

The theme's navigation applies `relative_url` to internal paths, so links such as `/guides/` resolve correctly under `baseurl`. Within your own Markdown pages, use `{% raw %}{{ '/guides/' | relative_url }}{% endraw %}` for the same reason.

## Navigation and search

Create `_data/navigation.yml` in your site. Link only to pages that exist:

```yaml
header:
  - title: Home
    url: /
  - title: Articles
    url: /blog/
footer:
  - title: GitHub
    url: https://github.com/your-name/your-repository
```

Enable search and the appearance toggle in `_config.yml`:

```yaml
features:
  search: true
  dark_mode_toggle: true
theme_options:
  color_scheme:
    default: dark # light or system also work
```

When search is enabled, the theme generates `/search/` and `/search.json` from your site's published content. Try a query from the header after building your site. To control the search page title, set `search.title` in `_config.yml`.

## Continue exploring

Browse the [feature catalog]({{ '/features/' | relative_url }}) for layouts and content types, or read the full [configuration reference](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/blob/develop/docs/configuration-reference.md) for additional settings.
