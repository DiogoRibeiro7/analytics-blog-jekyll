---
title: Install DataLog
description: Install the DataLog Jekyll theme and preview your site locally.
permalink: /guides/installation/
---

## Requirements

You need Ruby, Bundler, and a Jekyll site. The theme is a Ruby gem; there is no separate documentation generator. If you already have a site, keep its content and add the theme to its Gemfile.

## Add the theme

In your site's `Gemfile`, add:

```ruby
gem "datalog-theme"
```

Then set the theme in `_config.yml`:

```yaml
theme: datalog-theme
title: My research site
url: https://example.com
baseurl: ""
```

For a GitHub Pages project site, set `baseurl` to `"/repository-name"`. Use the [configuration guide]({{ '/guides/configuration/' | relative_url }}) to add navigation, search, and a colour preference.

## Preview the site

Install dependencies and start Jekyll from your site's directory:

```sh
bundle install
bundle exec jekyll serve
```

Open the local address printed by Jekyll. On an existing site, check that your layouts and navigation point to pages you actually publish. For a migration from another theme, follow the [migration guide]({{ '/guides/migration/' | relative_url }}).
