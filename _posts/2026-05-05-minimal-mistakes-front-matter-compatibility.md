---
title: "Minimal Mistakes Front Matter, Rendered by DataLog"
subtitle: "The compatibility layer in action"
date: 2026-05-05
categories:
  - tutorials
tags:
  - migration
  - minimal-mistakes
  - front-matter
seo_title: "Migrating Minimal Mistakes Front Matter to DataLog"
seo_description: "How DataLog reads Minimal Mistakes header images, teasers, SEO titles and descriptions, wide layouts and redirects without editing every post."
excerpt: "A post written entirely with Minimal Mistakes front matter, rendered by DataLog without a single field renamed."
keywords:
  - minimal mistakes migration
  - jekyll theme migration
  - front matter
classes: wide
author_profile: false
header:
  image: /assets/img/20220607123041_detail.001.png
  overlay_image: /assets/img/20220607123041_detail.001.png
  overlay_filter: 0.35
  teaser: /assets/img/20220607123041_detail.001.png
  og_image: /assets/img/20220607123041_detail.001.png
  twitter_image: /assets/img/20220607123041_detail.001.png
why_this_exists: "Shows every Minimal Mistakes field the compatibility layer understands, on a real rendered page, so a migration can be checked against it."
evidence: "The front matter of this post itself, which is written in the Minimal Mistakes dialect and left untouched."
methodology: "Each field is listed with the DataLog field it maps to and the place on this page where its effect is visible."
reviewed_at: 2026-05-05
redirect_from:
  - /legacy/minimal-mistakes-post/
---

This post's front matter is written the way the [Minimal Mistakes](https://mmistakes.github.io/minimal-mistakes/) theme expects it, and none of it has been renamed for DataLog. The hero image above, the teaser on the home page cards, the title in the browser tab, the meta description, the wide body class and the editorial note below all come from Minimal Mistakes fields.

## What was mapped

| Minimal Mistakes field | DataLog field | Where it shows |
| --- | --- | --- |
| `header.overlay_image` | `post_hero.image` with `post_hero.overlay: true` | The title sits over the image at the top of this page |
| `header.overlay_filter` | `post_hero.overlay_filter` | The darkening over the hero image |
| `header.teaser` | `teaser` | Thumbnail on the home page and related-post cards |
| `header.og_image`, `header.twitter_image` | `og_image`, `twitter_image` | Social sharing previews |
| `seo_title` | `<title>` and social titles | The browser tab reads the SEO title, the heading reads the real one |
| `seo_description` | `description` | The meta description |
| `classes: wide` | body class `wide` | Paragraphs use the full content width |
| `subtitle` | subtitle under the title | The line under the heading |
| `why_this_exists`, `evidence`, `methodology`, `reviewed_at` | provenance note | The editorial note above the article body |
| `redirect_from` | redirect page | `/legacy/minimal-mistakes-post/` redirects here |

## What is ignored

`author_profile` controls the Minimal Mistakes sidebar, which DataLog does not have; DataLog shows the author card at the end of the post instead. `seo_type: article` is redundant, because DataLog already marks posts as articles for social cards and structured data.

## Where the rules live

The mapping is a single build hook in `_plugins/front_matter_compat.rb`. It only fills DataLog fields that are absent, so a post that sets `image` or `description` explicitly keeps those values. The full field table and the URL-preservation settings are in the [migration guide]({{ '/docs/migrating-from-minimal-mistakes/' | relative_url }}).
