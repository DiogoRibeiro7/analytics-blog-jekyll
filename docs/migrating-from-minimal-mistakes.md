# Migrating from Minimal Mistakes

DataLog understands the front matter that the [Minimal Mistakes](https://mmistakes.github.io/minimal-mistakes/) theme uses, so a site can move over without rewriting every post. This guide lists what is mapped, what is ignored, and the three configuration settings that keep existing URLs alive.

## 1. Front matter

A build hook, `_plugins/front_matter_compat.rb`, reads the Minimal Mistakes fields and fills the DataLog fields the layouts use. It only fills fields that are absent: a post that sets `image`, `description` or `post_hero` explicitly keeps those values. The hero lives under its own `post_hero` key so that DataLog's existing `hero_image` field, used by page and portfolio layouts, is never touched.

| Minimal Mistakes | DataLog | Effect |
| --- | --- | --- |
| `header.overlay_image` | `post_hero.image`, `post_hero.overlay: true` | Title rendered over the image at the top of the post |
| `header.image` (without overlay) | `post_hero.image`, `post_hero.overlay: false` | Image rendered as a figure above the post header |
| `header.overlay_filter`, `header.overlay_color` | `post_hero.overlay_filter`, `post_hero.overlay_color` | Darkening or tint over the overlay image, same syntax as Minimal Mistakes |
| `header.image_description`, `header.caption` | `post_hero.alt`, `post_hero.caption` | Alt text and caption of the figure variant |
| `header.teaser` | `teaser` | Thumbnail on home-page cards and related-post cards |
| `header.og_image`, `header.twitter_image` | `og_image`, `twitter_image` | Social sharing images; `image` is also set for structured data |
| `seo_title` | `<title>` and social titles | The heading keeps the real title; only the tab and share cards use the SEO title |
| `seo_description` | `description` | Meta description and social descriptions |
| `classes: wide` | body class `wide` | Removes the reading measure inside the article, as the Minimal Mistakes wide layout does |
| `subtitle` | rendered under the title | Also shown inside an overlay hero |
| `excerpt`, `summary`, `keywords`, `toc`, `toc_label`, `permalink`, `redirect_from` | same names | Read natively |
| `why_this_exists`, `evidence`, `methodology`, `reviewed_at` | provenance note | An editorial note rendered between the topics and the article body |

Ignored, with no effect on the build:

- `author_profile`: DataLog has no sidebar; the author card is rendered after the post.
- `seo_type`: posts are already marked as articles for social cards and structured data.
- `read_time`, `share`, `related` and `comments` toggles from Minimal Mistakes defaults.

Everything the hook produces can also be written directly in DataLog's own fields; the Minimal Mistakes names are an input format, not a second configuration.

## 2. URLs

Three settings decide whether a migrated site keeps its addresses.

**Permalink.** DataLog's demo site uses `permalink: pretty`, which puts the date in every post URL. A Minimal Mistakes site usually uses `/:categories/:title/`. Keep the setting the old site had, in the consuming site's `_config.yml`:

```yaml
permalink: /:categories/:title/
```

Posts that carry an explicit `permalink` in their front matter keep it regardless.

**Redirects.** `jekyll-redirect-from` is a runtime dependency of the theme and is listed in the demo `_config.yml`, so `redirect_from` lists in front matter generate redirect pages at the old addresses. Sites that install the theme by copying its files need the gem in their `Gemfile` and the plugin in their `plugins` list:

```yaml
plugins:
  - jekyll-redirect-from
```

**Taxonomy paths.** Post tags and categories link to anchors on an archive page, `/tags/#slug` and `/categories/#slug`, which is also what Minimal Mistakes produces with its `liquid` archive type. The base paths are read from the same keys Minimal Mistakes uses, so an existing configuration carries over:

```yaml
category_archive:
  path: /categories/
tag_archive:
  path: /tags/
```

The archive pages themselves have to exist at those paths; build them on DataLog's `archive` layout.

## 3. Checking a migration

The demo post [Minimal Mistakes Front Matter, Rendered by DataLog](../_posts/2026-05-05-minimal-mistakes-front-matter-compatibility.md) is written entirely in Minimal Mistakes front matter and exercises every row of the table above, including a `redirect_from` entry. Build the site and compare a migrated post against it. The tests in `tests/test_front_matter_compat.rb` assert the same things against the built demo and are the regression guard for this layer.
