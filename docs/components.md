# Post Components

The `post` layout adds five components to every post: social sharing buttons, breadcrumbs, an author card, an enhanced table of contents and a difficulty badge. This guide covers what each one shows, the front matter that controls it, how to include it in other layouts, and how to change its look.

## Table of Contents

1. [Social Sharing Buttons](#social-sharing-buttons)
2. [Breadcrumb Navigation](#breadcrumb-navigation)
3. [Author Bio Cards](#author-bio-cards)
4. [Enhanced Table of Contents](#enhanced-table-of-contents)
5. [Difficulty Badges](#difficulty-badges)
6. [Revision History](#revision-history)
7. [License Notice](#license-notice)
8. [Series Navigation](#series-navigation)
9. [Reproducibility Panel](#reproducibility-panel)
10. [Reading Mode and Print](#reading-mode-and-print)
11. [Bookmarks, Progress and Private Highlights](#bookmarks-progress-and-private-highlights)
12. [Correction Reports](#correction-reports)
13. [Contact Form](#contact-form)
14. [Comments](#comments)
15. [Reactions](#reactions)
16. [Webmentions](#webmentions)
17. [Front Matter](#front-matter)
18. [Customization](#customization)
19. [Troubleshooting](#troubleshooting)

The components follow the light and dark themes through the CSS variables described under [Customization](#customization).

---

## Social Sharing Buttons

### What It Does

Allows readers to share your content on social media platforms with beautiful, icon-based buttons.

### Platforms Supported

- Twitter/X
- LinkedIn
- Facebook
- Reddit
- Email
- Copy link to clipboard

### Usage

The social sharing component is **automatically included** in all posts. No configuration needed!

### Choosing Platforms

To change which platforms appear, copy `_includes/components/social-share.html` from the theme into your site's `_includes/components/` and remove the platforms you do not want. A file in your site replaces the theme's file of the same name.

#### Manual Usage in Other Layouts

```liquid
{% include components/social-share.html
   url=page.url
   title=page.title
   description=page.excerpt
   show_count=false %}
```

**Parameters:**
- `url` - URL to share (default: page.url)
- `title` - Title to share (default: page.title)
- `description` - Description for sharing (default: page.excerpt)
- `show_count` - Show share count (default: false)

### Styling

Override the `.social-share` rules in your stylesheet (see [Customization](#customization)):

```scss
.social-share__button {
  // Customize button appearance
  padding: 0.5rem 1rem;
  border-radius: 6px;

  &:hover {
    transform: translateY(-2px);
  }
}
```

---

## Breadcrumb Navigation

### What It Does

Provides hierarchical navigation showing the user's location in your site structure.

**Example breadcrumb:**
```
Home / Blog / Machine Learning / Understanding Neural Networks
```

### Features

- Automatic generation based on collection and category
- Schema.org structured data for SEO
- Mobile-responsive design
- Customizable separator

### Usage

Breadcrumbs are **automatically included** at the top of all posts.

### Manual Usage

```liquid
{% include components/breadcrumbs.html
   show_current=true
   separator=" > " %}
```

**Parameters:**
- `show_current` - Show current page in breadcrumbs (default: true)
- `separator` - Custom separator (default: " / ")

### Customization

#### Change Separator

```liquid
{% include components/breadcrumbs.html separator=" > " %}
```

#### Hide Current Page

```liquid
{% include components/breadcrumbs.html show_current=false %}
```

#### Styling

Override the `.breadcrumbs` rules in your stylesheet:

```scss
.breadcrumbs {
  border-bottom: 1px solid var(--color-border);

  &__link {
    color: var(--color-accent);
  }
}
```

---

## Author Bio Cards

### What It Does

Displays professional author information with avatar, bio, research interests, and social links.

### Features

- Avatar with fallback to initials
- Affiliation and biography
- Research interests
- Social media links (GitHub, Twitter, LinkedIn, ORCID, Google Scholar)
- Compact variant option

### Usage

The author bio is **automatically included** at the end of all posts.

### Configuration

Edit your `_config.yml` to configure author information:

```yaml
author:
  name: Your Name
  affiliation: Your Institution
  email: your.email@example.com
  biography: Your professional biography here
  avatar: /assets/images/avatar.jpg  # Optional

  # Social links
  github: yourusername
  twitter: yourusername
  linkedin: yourusername
  orcid: https://orcid.org/0000-0000-0000-0000
  google_scholar: https://scholar.google.com/citations?user=yourID

  # Research areas
  research_areas:
    - Machine Learning
    - Data Science
    - Statistical Modeling
```

### Manual Usage

```liquid
{% assign authors = page | page_authors %}
{% include components/author-bio.html
   person=authors.first
   show_avatar=true
   show_social=true
   compact=false %}
```

**Parameters:**
- `person` - An author from `page | page_authors` (default: the page's first author)
- `author` - An author's name or `_data/authors.yml` key, instead of `person`
- `show_avatar` - Show author avatar (default: true)
- `show_social` - Show social links (default: true)
- `compact` - Avatar, name, affiliation and links only, without the biography and research interests (default: false)

### Authors and Contributors

Without anything in its front matter, a post was written by the site's `author`. A collaborative article lists its authors, in order, and the people who contributed in other ways:

```yaml
---
title: Imputation accuracy versus inferential validity
authors:
  - Diogo Ribeiro                # the site's author: _config.yml has the rest
  - jane_smith                   # a key of _data/authors.yml
  - name: John Doe               # or the author's details
    affiliation: Example Institute
    orcid: 0000-0002-1825-0097   # an ORCID iD, or its https://orcid.org/ URL
    url: https://johndoe.example
contributors:
  - name: Ada Curator
    role: Data curation
author_cards: detailed           # optional: detailed, or false for none
---
```

Every place that names the authors reads the same list, `page | page_authors` (and `page | page_contributors`):

- the byline, with each author's affiliation and a link to their `url`, and a Contributors line with each role;
- the author cards after the post: a full card for a single author, a compact card for each of several authors, a full card for each with `author_cards: detailed`, and none with `author_cards: false`;
- the JSON-LD: `author` is one `Person`, or a list of them for several authors, each with its own affiliation and profile links (`sameAs`), and contributors are listed under `contributor`;
- the `citation_author` meta tags, each followed by that author's `citation_author_institution` and `citation_author_orcid`;
- the BibTeX, RIS and EndNote exports and the citation line.

A person's details come from the entry itself, then from `_data/authors.yml` (by the entry's `id`, or the key or name it gives), and, for the site's own author, from `author` in `_config.yml`. Another author never takes the site author's affiliation or profiles.

`author: jane_smith` or `author: Jane Doe` still names a single author, and `author_affiliation` sets that author's affiliation. `authors: "Ann Lee; Bo Kim"` separates names with semicolons. A research page's `citation_authors` names the authors for citation indexes alone.

Create `_data/authors.yml` for the people who write for the site:

```yaml
john_doe:
  name: John Doe
  affiliation: Data Science Institute
  email: john@example.com
  biography: Data scientist specializing in ML
  avatar: /assets/images/john.jpg
  github: johndoe
  research_areas:
    - Deep Learning
    - NLP

jane_smith:
  name: Jane Smith
  affiliation: AI Research Lab
  email: jane@example.com
  biography: AI researcher and educator
  github: janesmith
  research_areas:
    - Computer Vision
    - Robotics
```

Then in your post front matter:

```yaml
---
title: My Post
author: john_doe  # References _data/authors.yml
---
```

---

## Enhanced Table of Contents

### What It Does

Provides an interactive, sticky table of contents with reading progress tracking.

### Features

- **Sticky positioning** - Follows you as you scroll
- **Reading progress** - Shows percentage complete
- **Active highlighting** - Highlights current section
- **Collapsible** - Save space when needed
- **Smooth scrolling** - Scrolls to a section, or jumps straight to it when the reader has asked their system for reduced motion
- **Progress bar** - Visual reading progress indicator

### Usage

The enhanced TOC **automatically replaces** the standard TOC in all posts with `toc: true`.

### Disable for a Specific Post

In your post front matter:

```yaml
---
title: My Post
toc: false  # Disables TOC completely
---
```

### Customization

#### Configure Heading Levels

In your post front matter:

```yaml
---
title: My Post
toc_h_min: 2  # Start from H2
toc_h_max: 3  # End at H3
---
```

#### Custom TOC Title

```yaml
---
title: My Post
toc_label: "Contents"
---
```

#### Manual Usage

```liquid
{% include components/enhanced-toc.html
   html=content
   h_min=2
   h_max=4
   heading="Table of Contents"
   collapsible=true
   show_progress=true %}
```

**Parameters:**
- `html` - Content to parse (default: content)
- `h_min` - Minimum heading level (default: 2)
- `h_max` - Maximum heading level (default: 4)
- `heading` - TOC title (default: "Table of Contents")
- `collapsible` - Make TOC collapsible (default: true)
- `show_progress` - Show reading progress (default: true)

### Styling

Override the `.enhanced-toc` rules in your stylesheet:

```scss
.enhanced-toc {
  &.is-sticky {
    top: 80px;  // Adjust based on your header height
  }

  &__progress-bar {
    background: linear-gradient(90deg, #3277f6, #5b8ef7);
  }
}
```

---

## Difficulty Badges

### What It Does

Displays visual, color-coded badges indicating content difficulty level.

### Difficulty Levels

| Level | Color | Icon | Use Case |
|-------|-------|------|----------|
| **Beginner** | Green | Single bar | New to topic |
| **Intermediate** | Blue | Two bars | Some experience |
| **Advanced** | Orange | Three bars | Experienced |
| **Expert** | Red | Star | Cutting-edge/specialized |

### Usage

Every post shows a badge in its metadata section. Set the level in front matter:

```yaml
---
title: Understanding Neural Networks
difficulty: intermediate
---
```

A post without `difficulty` uses `post_defaults.difficulty` from `_config.yml`, or Intermediate when that is not set either.

### Supported Values

The component normalizes various inputs:

- **Beginner**: "beginner", "easy", "introductory", "basic"
- **Intermediate**: "intermediate", "moderate", "medium"
- **Advanced**: "advanced", "hard", "difficult"
- **Expert**: "expert", "very advanced", "research"

### Manual Usage

```liquid
{% include components/difficulty-badge.html
   level="intermediate"
   show_icon=true
   show_description=false %}
```

**Parameters:**
- `level` - Difficulty level (default: page.difficulty or "beginner")
- `show_icon` - Show difficulty icon (default: true)
- `show_description` - Show difficulty description (default: false)

### Styling

Override the `.difficulty-badge` rules in your stylesheet:

```scss
.difficulty-badge--beginner {
  background-color: #ECFDF5;
  color: #047857;
  border-color: #A7F3D0;
}
```

---

## Revision History

### What It Does

Records what changed in an article after it was published, for a post that is corrected or rewritten while keeping its URL. The newest correction or update is announced under the post's metadata, and the full history follows the article's body, ending with the publication date. Readers see what changed and why without reading the Git history.

### Usage

```yaml
---
title: Normality tests and sample size
date: 2019-03-12
revisions:
  - date: 2026-09-16
    type: correction
    summary: Replaced the sample-size rules for normality tests with model diagnostics.
    details_url: https://github.com/example/repo/pull/425
  - date: 2024-03-12
    type: update
    summary: Updated the code examples for the current SciPy.
---
```

- `date` is the day of the change: a date, a time or a string such as `2026-09-16`.
- `type` is `correction` (a claim, a result or a method was wrong), `update` (new material or a rewrite), `review` (the article was read through and stands) or `editorial` (wording, typos, links). It defaults to `update`.
- `summary` says what changed, in a sentence. It is shown as text, so it holds no Markdown or HTML.
- `details_url` is optional: a pull request, a commit, a release note or a page with the full account. A site path gets the site's base URL.

The list may be in any order; it is shown newest first, and two revisions on one day keep their order. A revision without a date or a summary, an unknown type, or a `revisions` that is not a list stops the build and names the page.

### What Renders

- **The notice.** When there is a correction or an update, an aside under the metadata reads "Corrected on September 16, 2026." or "Updated on …" with the newest one's summary, its details link and a link to the history. A review or an editorial change makes no notice. `revision_notice: false` in front matter turns the notice off for a post whose history is enough.
- **The history.** A "Revision history" section after the article body lists every revision with its date, its type and its summary, newest first, and ends with the publication date.
- **The "Updated" date.** The post's metadata shows "Updated" next to "Published" when the article changed on another day than it was published.
- **Structured data.** The newest revision that changed the article (any type but `review`) sets `last_modified_at` when it is later than the `last_modified_at` or `updated` the page gives. The JSON-LD `dateModified`, the microdata, the feed's `<updated>` and the sitemap's `<lastmod>` all read it. Each correction is also a schema.org `CorrectionComment` under `correction`, with its date, its summary and its link.

### Which Date Is Which

| Field | Meaning | Where it shows |
| --- | --- | --- |
| `date` | When the article was published. It never changes, and neither does the URL. | "Published" in the metadata, `datePublished` |
| `last_modified_at` (or `updated`) | When the article last changed. The newest revision sets it when later. | "Updated" in the metadata, `dateModified`, the feed and the sitemap |
| `reviewed_at` | When the article was last read through by its author or an editor. | "Reviewed" in the provenance note |
| `why_this_exists`, `evidence`, `methodology` | Provenance: why the article exists and what it rests on. | The provenance note |
| `revisions` | The history: what changed since publication, when and why. | The notice, the history and the structured data |

Provenance explains the evidence and the method; the revision history explains how the published claim changed over time. A `review` revision records a read-through in the history and leaves `reviewed_at` alone.

### Styling

```scss
.revision-notice { }                    // the notice; --correction and --update variants
.revision-history__item { }             // one entry; --correction, --update, --review, --editorial, --published
.revision-history__type { }             // the type badge
```

---

## License Notice

### What It Does

States the reuse terms of an article: who holds the copyright, the licence of its text and figures and, when it differs, the licence of its code samples. The line sits before "How to cite", where a reader deciding whether to reuse the article looks, and it stays on paper with the licence's address.

The repository's `LICENSE` (MIT) covers the theme's software, not what a site publishes with it. An article's prose and figures are the author's, under whatever terms the author chooses; the code samples in it may reasonably carry a different, software licence. These settings say which.

### Usage

A site-wide default in `_config.yml`:

```yaml
content_license: CC-BY-4.0   # the text and figures of every article
code_license: MIT            # the code samples, when their terms differ (optional)
```

A page keeps, replaces or declines it in front matter:

```yaml
license: CC-BY-SA-4.0        # this article's own terms
license: false               # no notice and no licence metadata for this page
code_license: Apache-2.0
```

```yaml
license:                     # a licence the theme does not know
  name: Open Government Licence v3.0
  url: https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/
  holder: The Lab            # optional; defaults to the page's authors
  year: 2026                 # optional; defaults to the year of the page's date
```

- Identifiers are SPDX: `CC-BY-4.0`, `CC-BY-SA-4.0`, `CC-BY-ND-4.0`, `CC-BY-NC-4.0`, `CC-BY-NC-SA-4.0`, `CC-BY-NC-ND-4.0`, `CC0-1.0`, `MIT`, `Apache-2.0`, `BSD-2-Clause`, `BSD-3-Clause`, `GPL-3.0-only`, `GPL-3.0-or-later`, `LGPL-3.0-only`, `AGPL-3.0-only`, `MPL-2.0`, `ISC`, `Unlicense` and `all-rights-reserved`. Case and spacing do not matter (`CC BY 4.0`), `CC BY` alone means the 4.0 version, and `CC0` the 1.0 one.
- Any other string is shown as given, without a link. Give a map with `name` and `url` for a licence the theme does not know.
- `holder` and `year` can also sit on the site's `content_license` map, for a site whose articles belong to an institution.
- Datasets and packages carry their own `license` and never take the site's default: a dataset's data and a package's code have their own terms.

### What Renders

- **The notice**, on a post before "How to cite": "© 2024 Diogo Ribeiro. Text and figures under CC BY 4.0. Code samples under MIT." Each licence with a URL is a link with `rel="license"`. `all-rights-reserved` reads "© 2024 Diogo Ribeiro. All rights reserved."
- **In print**, the licence's address follows the link, so a PDF or a printout keeps the terms.
- **A dataset's** header and **a research article's** "Rights" row show the licence the same way, linked.
- **Metadata:** the page's `<head>` carries `<link rel="license">`, and the JSON-LD `license`, `copyrightYear` and `copyrightHolder` (the authors as `Person`s, or an institution as an `Organization`).

### Styling

```scss
.content-license { }           // the notice
.content-license__holder { }   // "© 2024 Diogo Ribeiro."
.license-link { }              // a licence's name, linked or not
```

---

## Series Navigation

### What It Does

Joins the parts of a multi-part article into a series a reader can follow in order, whatever was published in between. A post that belongs to a series shows the series at the top (its title, "Part 2 of 3", a progress bar, every part in order with the current one marked, and the previous and next parts) and the previous and next parts again at the end. Both are navigation landmarks of their own; the chronological previous and next post at the foot of the page stay as they are.

### Usage

A complete three-part series. The title and description live once, in `_data/series.yml`:

```yaml
# _data/series.yml
missing-data:
  title: Missing Data and Statistical Inference
  description: From the missing-data mechanisms to sensitivity analysis, in three parts.
```

Each part names the series and its place in it:

```yaml
# _posts/2026-01-10-missing-data-mechanisms.md
---
title: Missing Data Mechanisms
series:
  id: missing-data
  order: 1
---
```

```yaml
# _posts/2026-03-02-multiple-imputation.md
---
title: Multiple Imputation in Practice
series:
  id: missing-data
  order: 2
---
```

```yaml
# _posts/2026-05-20-sensitivity-analysis.md
---
title: Sensitivity Analysis for Untestable Assumptions
series: missing-data        # the flat form says the same
series_order: 3
---
```

- `id` names the series; `order` is a whole number from 1. Parts are shown in `order`, so a series can be written out of publication order, and gaps are fine: with orders 1, 2 and 4 the last part is "Part 3 of 3".
- The title comes from `_data/series.yml`, else from a part that gives `series.title` (or `series_title`), else from the id ("Missing Data").
- A part without an order, an order that is not a whole number, or two parts with the same order stops the build and names the posts.
- A series is any set of posts or collection documents sharing an id; one part alone is a series of one, shown as "Part 1 of 1" without previous or next links.

### What Renders

- **At the top** of the post, after the metadata: a `<nav>` labelled by its heading ("Series · Missing Data and Statistical Inference · Part 2 of 3"), the description when there is one, a `<progress>` bar (hidden from assistive technology, which has the text), an ordered list of every part linked, the current one carrying `aria-current="page"`, and the previous and next parts with `rel="prev"` and `rel="next"`.
- **At the end** of the post, before the revision history: the previous and next parts again, in a compact `<nav>` labelled "Series: …". A series of one renders nothing there.
- The chronological "Previous" and "Next" post links at the foot of the page are unchanged, so a reader can follow either the series or the calendar.

### Styling

```scss
.series-nav { }                   // the box; --compact at the end of the post
.series-nav__heading { }          // label, title and "Part k of n"
.series-nav__progress { }         // the <progress> bar
.series-nav__part--current { }    // the current part in the list
.series-nav__link--previous { }   // the previous and next parts
.series-nav__link--next { }
```

---

## Reproducibility Panel

### What It Does

Gives an article one compact place for the computational artifacts behind it: the source code at the exact commit or tag, the data and its version or DOI, the notebook, the software environment, and the archived results. The panel shows what is given and claims nothing more; a link is a link and a ref is a ref, so link the immutable things (a commit, a tag, a DOI, a release) rather than a repository's home page, and readers can fetch the same versions.

It complements the provenance note and the open science badges: provenance says why and how the article was made, the badges say which practices the site follows, and the panel says where the artifacts are.

### Usage

A reproducible analysis, as its front matter:

```yaml
---
title: Imputation Accuracy and Inferential Validity
reproducibility:
  code:
    url: https://github.com/example/missing-data
    ref: 4f2c1ab                              # the commit, tag or branch the results came from
  data:
    doi: 10.5281/zenodo.1234567               # or url:; a DOI is linked at doi.org
    version: v2
  environment:
    file: requirements.txt                    # in the repository at that ref
    container: ghcr.io/example/missing-data:1.4.0
    archive: https://doi.org/10.5281/zenodo.7654321
  notebook:
    url: /notebooks/imputation-accuracy/
  results:
    url: https://github.com/example/missing-data/releases/tag/results-v1
    version: results-v1
---
```

- Every artifact is optional; the panel lists the ones given, in the order above. An artifact that is only a URL can be written as one: `notebook: /notebooks/imputation-accuracy/`.
- `code.ref` is shown apart from the URL, as `at 4f2c1ab`, and linked to that tree on GitHub or GitLab. `environment.file` is a path in the repository, linked at that ref (or at `HEAD` without one); a site path or a URL is linked as itself.
- `data.doi` (or `results.doi`) is shown as `DOI 10.5281/zenodo.1234567` and, without a `url`, linked at `doi.org`. `version` is shown as `version v2`.
- A `label` on any artifact replaces the link text, which is otherwise the address without its scheme.
- A URL must be `http(s)://…`, a site path starting with `/` (which takes the site's baseurl) or `doi:…`; anything else, such as `github.com/example/missing-data` without its scheme or a `javascript:` address, stops the build and names the page and the field.
- On a research page, `reproducibility` as free text is still the notes under "Code and reproducibility"; as a map it is the panel, and `reproducibility_notes` keeps the notes.

### What Renders

A `<section>` headed "Reproduce this analysis", after the article body (and the series links) and before the revision history, with a description list: "Source code", "Data", "Notebook", "Environment" and "Results", each with its link and identifiers. External links carry `rel="external noopener"`; refs, files and container images are in `<code>`. In print, every link keeps its address.

### Styling

```scss
.reproduce { }                 // the panel
.reproduce__item--code { }     // one artifact; --data, --notebook, --environment, --results
.reproduce__link { }           // the artifact's link
.reproduce__detail { }         // "at 4f2c1ab", "version v2", "DOI …"
```

---

## Reading Mode and Print

### What It Does

Long technical articles get read without the site around them, saved as PDFs and printed. Two things serve that:

- **Reading mode**, a button under the post's metadata. It hides the site's navigation and footer, the breadcrumbs, the sharing buttons, the interactive panel, the comments, the citation tools, the badges, the author card, the related posts and the chronological pagination, and leaves the article with its metadata, its table of contents, its equations, figures, code and footnotes, and the panels that belong to it (the series, the reproducibility panel, the revision history, the licence). The reader turns it on; nothing is remembered unless the site asks for it; the button stays in reach as the article scrolls; and Escape leaves the mode. The same article is shown with less around it: no second copy is made, and the light or dark theme is untouched.
- **Print styles**, applied when the browser prints or saves a PDF. The chrome and the controls that only work on a screen go; the article prints black on white whatever the theme, with code wrapped to the page on a white background; headings stay with what follows them; figures, tables, code blocks, statements and display equations are kept on one page where the browser can; every external link in the text is followed by its address; the article's own address and DOI are printed under the metadata, with the published and updated dates, the authors, the revision notice and the licence; and an interactive embed becomes a note that the content is in the online article, while a visualization's table fallback is printed.

### Usage

Both are on for every post. In `_config.yml`:

```yaml
theme_options:
  reading_mode:
    enabled: true      # false removes the button
    remember: false    # true keeps a reader's choice from one post to the next
```

Nothing is needed for print. To print a page other than a post, the same rules apply wherever the classes match: the site chrome, `.post-content` links, code blocks and equations.

### Customization

The rules live in `_sass/_print.scss`, loaded last. `body.reading-mode` carries the reading-mode rules, so a site's own stylesheet can hide or show more:

```scss
body.reading-mode .my-sidebar { display: none; }
@media print { .my-widget { display: none; } }
```

### Styling

```scss
.reading-mode-bar { }             // holds the button; sticky in reading mode
.reading-mode-toggle { }          // the button; [aria-pressed="true"] while reading
.post-print-source { }            // the address line, print only
.print-only { }                   // anything shown on paper alone
```

---

## Bookmarks, Progress and Private Highlights

### What It Does

Long technical articles are read over several sittings and annotated. Every post offers three things that work without an account or a server, kept in the reader's browser:

- **Save for later.** A bookmark button next to the reading-mode control. The saved articles are listed on a page of the site (`/saved/` in the demo), with each one's progress and highlights.
- **Resume where you left off.** As the reader scrolls a long article, their position is saved, as a ratio of the article and the nearest heading. When they come back, some way in and not at the end, a prompt under the metadata offers to resume; it is not shown for a short article, at the start or the end, or when the page was opened at an anchor.
- **Private highlights and notes.** Selecting a passage brings up a toolbar with "Highlight" and "Highlight with a note"; `Alt+Shift+H` and `Alt+Shift+N` do the same from the keyboard. The panel under the article lists the highlights with their section, a note to edit, "Go to" and "Remove". The panel says what it is: the reader's own notes, not comments, and never sent anywhere.

### Privacy

Everything lives in `localStorage`, under one key per article, and nothing leaves the browser: no account, no request, no telemetry about what was saved or highlighted. The panel's "Your reading data" offers **Export as JSON**, **Import JSON**, **Erase this article's data** and **Erase all reading data** (after a confirmation), and the saved-articles page offers export, import and erase all. A browser that blocks storage (a private window, cleared or blocked site data) shows a message and disables the controls; the article reads as before.

A later sync across devices, through the dynamic services proposed in #259, would be a separate capability the reader opts into; the local layer never needs it.

### How Highlights Survive Edits

A highlight is not a pair of DOM offsets. It is saved as the quoted text with 32 characters of what comes before and after it, and the section heading it sits under, the way a text quote selector does. On each visit the theme looks for the quote in the article's current text (the exact text first, then the same words with any whitespace) and, when it appears more than once, takes the occurrence whose surroundings agree most with the saved context. A passage that was reworded is listed as "Not found in the current text" and can be removed; the rest are unaffected.

Where the browser has the CSS Custom Highlight API, highlights are painted without touching the DOM, so selecting and copying the text are exactly as they were. Elsewhere the text is wrapped in `<mark>` elements, one per text node.

### Usage

Everything is on for posts. In `_config.yml`:

```yaml
theme_options:
  reading_state:
    enabled: true        # false turns the whole layer off
    bookmarks: true      # each part can be turned off on its own
    progress: true
    highlights: true
    list_url: /saved/    # the page that lists the saved articles; leave it out to have no link
```

The saved-articles page is any page that includes the list:

```markdown
---
layout: page
title: Saved articles
permalink: /saved/
---

{% include components/reading-list.html %}
```

### Data Format

An export is JSON, `{ "format": 1, "exported_at": "…", "articles": [ … ] }`, each article as:

```json
{
  "article": "/2024/04/05/sql-optimization-guide/",
  "title": "SQL Optimization Playbook for Warehouse Analysts",
  "bookmarked": true,
  "saved_at": "2026-09-17T16:00:00Z",
  "progress": { "ratio": 0.63, "anchor": "optimization-checklist", "updated_at": "2026-09-17T16:05:00Z" },
  "annotations": [
    {
      "id": "…",
      "quote": "Cluster the fact table on purchase_ts",
      "prefix": "incremental model.\n",
      "suffix": " to prune partitions.\n",
      "section": "optimization-checklist",
      "note": "Check the clustering key.",
      "created_at": "2026-09-17T16:02:00Z"
    }
  ]
}
```

### Styling

```scss
.post-tools { }                   // the bar with the bookmark and reading-mode buttons
.bookmark-toggle { }              // [aria-pressed="true"] when saved
.reading-resume { }               // the resume prompt
.reading-toolbar { }              // the toolbar over a selection
::highlight(datalog-annotation)   // a highlight, with the Custom Highlight API
mark.reading-highlight { }        // a highlight, without it
.reading-notes { }                // the panel of highlights and notes
.reading-list { }                 // the saved articles on a page
```

---

## Correction Reports

### What It Does

A reader who finds a mathematical or factual error, a broken citation, outdated code, a reproducibility failure, a typo that changes the meaning or an accessibility problem can report it, as structured feedback apart from comments. "Report an error or suggest a correction" sits under the article, before the revision history: a collapsed block with a category, the section (filled from the article's headings), the message, an optional email for a reply, and, when the reader had text selected as they opened it, that passage attached. The article's address and title go with the report.

The report goes to the site's backend through the [dynamic services](dynamic-services.md) and is **never shown on the page**. It is an incoming claim; the [revision history](#revision-history) is what the author publishes after looking into it. Nothing turns a report into a public notice on its own.

### Usage

The form renders on a site with a backend that offers the feature (`dynamic_services.base_url` set, `dynamic_services.features.corrections` not `false`), and:

```yaml
corrections:
  enabled: true                   # false removes the form from every post
  categories:                     # the choices, in this order; the labels are in _data/i18n under corrections.categories
    - mathematical-error
    - factual-error
    - citation
    - code
    - reproducibility
    - typo
    - accessibility
    - other
```

A post opts out with `corrections: false` in its front matter. A site that adds a category adds its label under `corrections.categories.<key>` in `_data/i18n/<lang>.yml`.

### What the Service Receives

`POST /v1/corrections`, JSON, with an `Idempotency-Key` header per submission:

```json
{
  "category": "code",
  "section": "optimization-checklist",
  "message": "The clustering step names purchase_ts but the table clusters on customer_id.",
  "contact_email": "reader@example.org",
  "quote": "Cluster the fact table on purchase_ts",
  "article": { "url": "https://example.org/2024/04/05/sql-optimization-guide/", "title": "SQL Optimization Playbook" }
}
```

`section`, `contact_email` and `quote` are present only when given. The service answers `202` (or `200`) with JSON; a `422` with `error.errors` marks the fields; a `429` with `Retry-After` and a `5xx` show as such, with the request id for reference. The backend validates and sanitizes everything, keeps the email private, rate-limits, and may store the report, mail it, open an issue or feed a moderation queue; the reference deployment in [dynamic-services.md](dynamic-services.md#reference-deployment-serverless-functions-and-mongodb-atlas) does the first.

### States

The form is one `<form>` with `data-state`: `idle`, `pending` (submit disabled, `aria-busy`), `success` (the fields cleared, the message announced), `invalid` (the fields named by the site's checks or the service's `422` marked `aria-invalid` with their messages, the first focused), `error` (the message for the failure, as an alert, with "Reference: …" when the service gave a request id), and `disabled` (no backend, the feature off, the service not offering it, or an API version mismatch, each with its message). Before anything is sent, the message must be 20 characters long and an email, if given, look like one; a hidden honeypot field catches bots without a request.

### From a Report to a Revision

A report is private and unverified. The workflow the theme supports: the report arrives in the backend's store or inbox; the author checks it; if the article changes, the author edits it and adds a `revisions:` entry (`correction`, `update` or `editorial`) with a summary, which is what readers then see, dated, under the metadata and in the revision history. The reporter's email, if any, is for a reply; it never appears on the site.

### Styling

```scss
.correction-report { }             // the collapsed block
.service-form { }                  // the form, shared with the contact form; [data-state="…"]
.service-form__field { }           // a label, its control, hint and error
.service-form__status { }          // the announced state
```

---

## Contact Form

### What It Does

A research site gets structured requests a `mailto:` link handles badly: a collaboration, a consulting project, an invitation to speak or teach, mentoring, a question about a dataset or something that did not reproduce, a media request. The contact form takes them as one message with a category, the sender's name, email and optional affiliation, a subject and the message, and sends it to the site's backend through the [dynamic services](dynamic-services.md). The page it was sent from goes with it as `source_url`. The hint under the message follows the category, so a collaboration request is asked for the question, data or method and the timescale, a media request for the outlet, topic and deadline; the prompts are short and can be changed or removed.

Nothing the sender writes reaches the page, a feed or the comments: a message is private operational data for the author's inbox. Without a backend, or with the feature off, the form gives way to the site's email address (`contact_email`, else `author.email`), so the page is never empty; the demo's [/contact/](../_pages/contact.md) shows that.

### Usage

Any page rendered by the `page` layout gets the form after its content with:

```yaml
---
title: Contact
permalink: /contact/
layout: page
contact_form: true
---
```

Other layouts include it where they want it: `{% include components/contact-form.html %}`. The site's settings:

```yaml
contact:
  enabled: true                   # false removes the form and the fallback everywhere
  categories:                     # the choices, in this order; labels under contact.categories in _data/i18n
    - research-collaboration
    - consulting
    - speaking
    - mentoring
    - reproducibility
    - media
    - other
  prompts:                        # optional: a prompt per category, over contact.prompts in _data/i18n
    consulting: Say the scope, the budget range and when you need it.
  privacy_notice: ""              # optional: over contact.privacy in _data/i18n
  retention: ""                   # optional: appended to the notice, e.g. "Messages are deleted after a year."
```

The form renders when `dynamic_services.base_url` is set and `dynamic_services.features.contact` is not `false`. A site that adds a category adds its label under `contact.categories.<key>` and, if it wants one, its prompt under `contact.prompts.<key>` in `_data/i18n/<lang>.yml`.

### What the Service Receives

`POST /v1/contact`, JSON, with an `Idempotency-Key` header per submission:

```json
{
  "category": "research-collaboration",
  "name": "Jane Doe",
  "email": "jane@example.org",
  "affiliation": "Example University",
  "subject": "Potential collaboration on longitudinal models",
  "message": "We have adherence data over five years and would like to model it together.",
  "source_url": "https://example.org/contact/"
}
```

`affiliation` is present only when given. The service answers `202` (or `200`) with JSON; a `422` with `error.errors` marks the fields; a `429` with `Retry-After` and a `5xx` show as such, with the request id for reference. The backend validates and sanitizes everything, rate-limits, keeps the sender's address private, and may store the message, mail it to the author, send the sender a confirmation, or feed an inbox with its own access control; it never publishes a message. No mail, database or API credential is in the browser: the site holds only the service's address ([dynamic-services.md](dynamic-services.md#the-security-boundary)). Attachments are out of scope; a secure upload would be its own contract.

### States

The form is one `<form>` with `data-state`: `idle`, `pending` (submit disabled, `aria-busy`), `success` (the fields cleared, the message announced), `invalid` (the fields the site's checks or the service's `422` name, marked `aria-invalid` with their messages, the first focused), `error` (the message for the failure, as an alert, with "Reference: …" when the service gave a request id), and `disabled` (the feature off on the service, or an API version mismatch, with its message). Before anything is sent, the name, a plausible email, the subject and a message of 20 characters are required; a hidden honeypot field catches bots without a request. The service is asked once whether it takes messages, the first time the reader reaches into the form.

### Styling

```scss
.contact-form { }                  // the block; .contact-form--fallback holds the email address
.service-form { }                  // the form, shared with the correction report; [data-state="…"]
.service-form__row { }             // name and email side by side from the medium breakpoint
.service-form__privacy { }         // the privacy notice
```

---

## Comments

### What It Does

The `datalog-comments` plugin embeds Giscus, utterances or Disqus under a post ([configuration-guide.md](configuration-guide.md#5-analytics-and-comments)). Its fourth provider, `api`, keeps the discussion on the site's own backend: the thread is read from and written to the [dynamic services](dynamic-services.md), so the author owns the data, applies their own moderation and privacy policy, and ties comments to no GitHub account and no ad or tracking platform. MongoDB is one store such a backend can use ([reference model](#reference-model)); the theme knows only the HTTP contract below and needs no database.

Under the article, the thread loads when the reader gets near it, not with the article. It shows loading, empty and error states (the error with a "Try again"), then the comments oldest first, replies nested under their parent when `replies` is on. Everything the service returns is put on the page as text: a comment's body is never parsed as HTML, an author's link is kept only when it is an `http(s)` address and carries `rel="nofollow noopener ugc"`, and a missing name reads "Anonymous". The form under the list posts a comment or a reply with a name, an optional email (never shown) and website, and the text; a comment the service holds for moderation appears to its author with an "Awaiting moderation" badge and to nobody else until it is approved.

### Usage

```yaml
datalog_plugins:
  enabled:
    - datalog-search
    - datalog-comments
  options:
    datalog-comments:
      provider: api
      replies: true             # replies nest under their parent; false lists every comment flat
      moderation: true          # the note under the form says comments are read before they appear
      # endpoint: https://comments.example.org   # only when comments live apart from dynamic_services.base_url
      enabled_by_default: false

dynamic_services:
  base_url: https://api.example.org
  features:
    comments: true
```

A post shows the thread with `comments: true` in its front matter (or every post with `enabled_by_default: true`), hides it with `comments: false`, and can choose the provider for itself with a `comments:` hash (`provider: api` on a site that otherwise uses Giscus, or the reverse). The service keys the thread by the page's `url`. Without a backend (`endpoint` and `dynamic_services.base_url` both unset) the build warns and the post shows the plugin's "missing settings" note, as for a Giscus setup without a repository. `endpoint`, site-wide or on a page, is added to the Content Security Policy's `connect-src` by the theme; no other origin is reachable.

### The Contract

Reading, `GET /v1/comments?path=/2024/04/07/plotly-showcase/`:

```json
{
  "comments": [
    { "id": "c1", "parent_id": null, "author": { "name": "Alice", "url": "https://alice.example" }, "body": "Clear charts.", "created_at": "2026-09-16T15:30:00Z" },
    { "id": "c2", "parent_id": "c1", "author": { "name": "Bob" }, "body": "Agreed.", "created_at": "2026-09-16T16:00:00Z" }
  ]
}
```

Only approved comments, and only public author fields: never the email, never an IP. `id` and `parent_id` are opaque strings; `created_at` is ISO 8601; a reply whose parent is gone is shown at the top level.

Writing, `POST /v1/comments` with `Content-Type: application/json` and an `Idempotency-Key`:

```json
{
  "path": "/2024/04/07/plotly-showcase/",
  "parent_id": "c1",
  "author": { "name": "Dana", "email": "dana@example.org", "url": "https://dana.example" },
  "body": "One question about the export step."
}
```

`email` and `url` are present only when given. The service answers `201` with `{ "comment": { … }, "status": "published" }` when the comment is up, or `202` with `"status": "pending"` when it is held for moderation (the theme then shows it to its author with the badge); a `422` with `error.errors` keyed `name`, `email`, `url` or `body` marks the fields; `429` with `Retry-After` and `5xx` show as in the [error model](dynamic-services.md#the-error-model), with the request id.

What the backend does, and the theme cannot: validate and limit the size of every field; strip or escape markup (the theme renders text, but another consumer of the store may not); hash or drop the email; rate-limit by IP or token; restrict CORS to the site's origin; keep a `status` (`pending`, `approved`, `spam`, `deleted`) and serve only `approved` on `GET`; run whatever anti-spam challenge it likes before storing, the theme's own defence being a honeypot field that bots fill and readers never see.

### Reference Model

A document in MongoDB, or a row anywhere else:

```json
{
  "_id": "c1",
  "page_id": "/2024/04/07/plotly-showcase/",
  "parent_id": null,
  "author": { "name": "Alice", "email_hash": "sha256:…", "url": "https://alice.example" },
  "body": "Clear charts.",
  "created_at": "2026-09-16T15:30:00Z",
  "updated_at": null,
  "status": "approved",
  "idempotency_key": "…"
}
```

An index on `(page_id, status, created_at)` serves the `GET`; `idempotency_key` keeps a retried `POST` from storing twice. The [reference deployment](dynamic-services.md#reference-deployment-serverless-functions-and-mongodb-atlas) shows the handler shape and where the credential lives (in the function's environment, never in the site). MongoDB is not required: the contract is HTTP and JSON.

### States

The thread carries `data-state`: `idle` (before the reader gets near), `loading`, `loaded`, `empty`, `error` (the message as an alert, with a retry) and `disabled` (no backend, the feature off, the service not offering it, or an API version mismatch; the form is hidden). The form is a `.service-form` with the same states as the [contact form](#states-1); before anything is sent, a name and some text are required, and an email or a website, if given, must look like one.

### Styling

```scss
.comments-thread { }               // the thread; [data-state="…"]
.comments-thread__status { }       // loading, empty, error
.comment { }                       // one comment; .comment--pending while held
.comment__card, .comment__meta, .comment__author, .comment__time, .comment__body, .comment__reply { }
.comments-thread__replies { }      // the nested list under a parent
.comments-form { }                 // the form, a .service-form
```

---

## Reactions

### What It Does

"Was this useful?" after the article, with a small set of answers a reader can give without writing a comment: useful, clear, interesting, needs clarification, or whatever `reactions.types` lists. It is a quiet strip, not a competitor to the article, and a real signal: the counts on the buttons are the ones the service returns, and only those. Without a backend, with the feature off, or when the service cannot be read, no count is shown; a placeholder or a made-up number never is. The theme once carried simulated social-proof numbers and removed them; this is the honest replacement.

A reaction goes to the site's backend through the [dynamic services](dynamic-services.md) as the page and the reaction, nothing else. The reader's own choice is kept in their browser (`localStorage`, `datalog-reaction:<path>`) so their device shows it pressed on the next visit; that is all the theme keeps, and it never reaches the service.

### Usage

```yaml
reactions:
  enabled: true                   # false removes the strip from every post
  counts: true                    # false hides the counts; readers see only their own choice
  types:                          # the answers, in order; labels under reactions.types in _data/i18n
    - useful
    - clear
    - interesting
    - needs-clarification

dynamic_services:
  base_url: https://api.example.org
  features:
    reactions: true
```

The strip renders under the article, after the series navigation, on a site whose services offer the feature. A post opts out with `reactions: false`. A site that adds a type adds its label under `reactions.types.<key>` in `_data/i18n/<lang>.yml`.

### The Contract

Reading, `GET /v1/reactions?path=/2024/04/05/sql-optimization-guide/`:

```json
{ "counts": { "useful": 42, "needs-clarification": 3 } }
```

A type absent from `counts` shows no count. An answer that is not an object of non-negative integers is treated as no counts at all: the strip stays usable and shows nothing invented.

Writing, `POST /v1/reactions` with an `Idempotency-Key`:

```json
{ "path": "/2024/04/05/sql-optimization-guide/", "reaction": "useful" }
```

The service answers `201` with `{ "counts": { … }, "reaction": "useful" }`; returning the counts is what lets the strip update them, and without them it keeps the ones it had rather than adding one itself. A `409` means the service already holds this reader's reaction, shown as counted; `429` with `Retry-After` and `5xx` show as in the [error model](dynamic-services.md#the-error-model), and change nothing.

### Honesty and Privacy

Duplicate votes are the backend's problem, solved however it likes: a rate limit per address, a salted hash of address and day, a cookie it sets itself, or nothing. The theme does not fingerprint readers, no canvas, font or plugin enumeration, no stored identifier beyond the reader's own choice, and a site should not add that on its own. What the strip shows is what the service counted; a site that publishes the numbers elsewhere should publish only that. They are evidence for the author about which articles help, not a ranking.

### States

The strip carries `data-state`: `idle` (before the reader gets near), `loading`, `loaded`, `unavailable` (the service could not be read: no counts, the buttons still work), `pending` (a reaction on its way; `aria-busy`, the buttons disabled), `selected` (the reader's choice pressed, the thanks announced) and `disabled` (no backend, the feature off or not offered, or an API version mismatch; the buttons disabled and the reason announced). The reader's choice is `aria-pressed="true"` on its button. A failure to send is announced as an alert and changes nothing.

### Styling

```scss
.reactions { }                     // the strip; [data-state="…"]
.reactions__prompt { }
.reactions__choice { }             // a button; [aria-pressed="true"] is the reader's choice
.reactions__count { }              // the service's count, hidden when there is none
.reactions__status { }             // the announced state
```

---

## Webmentions

### What It Does

[Webmention](https://www.w3.org/TR/webmention/) is the W3C standard by which one website tells another that it linked to it. For a research site, a mention from elsewhere is often worth more than a reaction: another article cites a post, a researcher answers from their own site, a tutorial links to a derivation, a replication note references an analysis. The theme does two things with it, both optional and both independent of any one receiver or store:

- **Discovery.** With `webmentions.endpoint` set, every page's head carries `<link rel="webmention" href="…">`, the HTML form of the standard's discovery (GitHub Pages cannot send the HTTP `Link` header form). A site that links here can then notify that receiver: the site's own, or a hosted one such as webmention.io.
- **"Mentioned elsewhere."** On a site whose [dynamic services](dynamic-services.md) offer the feature, a post carries a section after its comments that reads the mentions of its canonical URL from `GET /v1/webmentions?target=…` and lists them: the kind (mention, reply, repost, like), the source's title as a link, the author, the source's host, the date and a short excerpt. It is kept apart from the comments, which are hosted here, and says so.

Inbound mentions are untrusted external content. The theme shows only entries the receiver marked `verified`, only from `http(s)` sources, only of the kinds the site lists, and everything as text: no markup from the source is ever parsed, titles and excerpts are trimmed and cut, and links carry `rel="nofollow noopener ugc"`. Likes are off by default; the emphasis is on mentions, citations and replies, not on counts.

### Usage

```yaml
webmentions:
  enabled: true                   # false removes the discovery link and the section
  endpoint: https://mentions.example.org/webmention   # the receiver to advertise; empty advertises nothing
  types:                          # the kinds shown; likes and reposts are opt-in
    - mention
    - reply

dynamic_services:
  base_url: https://api.example.org
  features:
    webmentions: true
```

The section renders on posts when the services offer the feature; a post opts out with `webmentions: false` in its front matter. The discovery link needs only `endpoint`.

### The Contract

`GET /v1/webmentions?target=https://example.org/2024/04/05/sql-optimization-guide/`:

```json
{
  "mentions": [
    {
      "id": "m1",
      "source": "https://example.org/bootstrap-uncertainty",
      "target": "https://example.org/2024/04/05/sql-optimization-guide/",
      "type": "reply",
      "author": { "name": "Jane Doe", "url": "https://example.org" },
      "title": "Bootstrap uncertainty in small samples",
      "excerpt": "Building on the clustering notes here…",
      "published_at": "2026-09-16T14:00:00Z",
      "verified": true
    }
  ]
}
```

`type` is `mention` (the default), `reply`, `repost` or `like`. An entry without `verified: true`, without an `http(s)` `source`, or of a kind the site does not list is not shown; an answer of another shape is treated as no mentions. Mentions are listed newest first by `published_at`.

The receiver and the read API, not the theme, verify that the source really links to the target (and re-verify when told of an update or a deletion), extract and sanitize the title, author and excerpt into plain text, reject targets outside the site, rate-limit submissions, hold entries for moderation when the site wants (`verified: false`, or not returned at all, keeps them off the page), and never proxy the source's HTML. "Moderation-hidden" is therefore the receiver's `verified` flag or its absence from the answer, and the page shows nothing about it.

### Reference Deployment

One shape, none of it required: a receiver route (`POST /webmention` with `source` and `target`, answering `202` and queueing the check) that fetches the source, confirms the link to the target, extracts the [h-entry](https://microformats.org/wiki/h-entry) or the page title and a text excerpt, and stores a document such as

```json
{ "_id": "m1", "source": "…", "target": "…", "type": "reply", "author": { "name": "…", "url": "…" }, "title": "…", "excerpt": "…", "published_at": "…", "received_at": "…", "verified": true, "status": "approved" }
```

in MongoDB or any store, with an index on `(target, status, published_at)`; and a read route under the dynamic services that returns the approved, verified entries of a target in the shape above. A hosted receiver (webmention.io) with a small read proxy that normalizes its answer into that shape works just as well. The [reference deployment](dynamic-services.md#reference-deployment-serverless-functions-and-mongodb-atlas) shows where the credentials live.

### States

The section carries `data-state`: `idle` (before the reader gets near), `loading`, `loaded`, `empty` ("No mentions from other websites yet"), `error` (the message as an alert, with a retry) and `disabled` (no backend, the feature off or not offered, or an API version mismatch: the section hides itself, having nothing to say to the reader).

### Styling

```scss
.webmentions { }                   // the section; [data-state="…"]
.webmentions__intro, .webmentions__status { }
.webmention { }                    // one mention; .webmention--reply, --mention, --repost, --like
.webmention__type, .webmention__title, .webmention__meta, .webmention__author, .webmention__host, .webmention__time, .webmention__excerpt { }
```

---

## Front Matter

The components read these keys from a post's front matter:

```yaml
---
title: My Post
difficulty: advanced   # the badge level
toc: true              # show the table of contents
toc_label: On this page
toc_h_min: 2           # the heading levels the table of contents lists
toc_h_max: 3
author: custom_author  # a key in _data/authors.yml, or a name
revisions: []          # what changed since publication; see Revision History
license: CC-BY-4.0     # the reuse terms of the text and figures; see License Notice
code_license: MIT      # the reuse terms of the code samples
series:                # the article's series and its place in it; see Series Navigation
  id: missing-data
  order: 2
reproducibility:       # the code, data and environment behind it; see Reproducibility Panel
  code: {url: https://github.com/example/missing-data, ref: 4f2c1ab}
corrections: false     # no correction-report form on this post; see Correction Reports
---
```

There are no site-wide switches for the components. To leave one out, copy `_layouts/post.html` into your site and remove its include.

---

## Customization

### Your Stylesheet

A site replaces the theme's stylesheet by providing its own `assets/css/main.scss`. Copy the theme's file into your site (`bundle info --path datalog-theme` prints where the gem is installed) and add your rules after its contents, so the theme's styles load first and yours override them. The examples in this guide go there.

### Colors

All components use CSS variables defined in the theme's `_sass/_theme.scss`; redefine them in your stylesheet:

```scss
:root {
  --color-accent: #3277f6;
  --color-background: #ffffff;
  --color-text-primary: #0b1d3d;
  --color-border: #e0e4ed;
}
```

### Typography

Change font sizes:

```scss
.social-share__button {
  font-size: 0.875rem;  // 14px
}

.author-bio__name {
  font-size: 1.5rem;  // 24px
}
```

### Spacing

Adjust margins and padding:

```scss
.breadcrumbs {
  margin: 1rem 0 2rem;  // top, sides, bottom
  padding: 0.75rem 0;
}
```

### Mobile Responsiveness

Components are mobile-first. Customize breakpoints:

```scss
@media (max-width: 768px) {
  .author-bio__inner {
    flex-direction: column;
  }
}
```

---

## Troubleshooting

### Social Sharing Not Appearing

**Check:**
1. Is the post using the `post` layout?
2. View page source - is the include being called?
3. Check browser console for JavaScript errors

**Solution:**
Ensure `_layouts/post.html` includes:
```liquid
{% include components/social-share.html %}
```

### Breadcrumbs Showing Wrong Path

**Issue:** Breadcrumbs don't match your site structure

**Solution:**
1. Check the post's `categories`: breadcrumbs link to the category archive, `/categories/` unless `category_archive.path` sets another path
2. Make sure the collection's index page exists (e.g., `/blog/index.html`), since breadcrumbs link to it

### Author Bio Not Showing

**Check:**
1. Author info in `_config.yml` is properly formatted
2. YAML syntax is valid (use a YAML validator)
3. Author name matches exactly (case-sensitive)

**Solution:**
```yaml
author:
  name: "Your Name"  # Use quotes if name has special characters
  biography: "Your bio"
```

### TOC Not Sticky

**Issue:** TOC doesn't stick when scrolling

**Solution:**
Adjust the sticky top position based on your header height:

```scss
.enhanced-toc.is-sticky {
  top: 80px;  // Match your header height
}
```

### Difficulty Badge Wrong Color

**Issue:** Badge shows wrong color for difficulty level

**Solution:**
Verify difficulty value in front matter:
```yaml
difficulty: intermediate  # Use lowercase, check spelling
```

### JavaScript Features Not Working

**Check:**
1. JavaScript is enabled in browser
2. No console errors
3. Scripts are loading correctly

**Solution:**
The components' scripts come from the bundles in `assets/js/dist/`, which the published gem includes. A site built from the theme repository has to build them first with `npm run build:js`.

---

## Performance Tips

### Optimize Images

For author avatars:
- Use WebP format when possible
- Resize to 160x160px (displayed at 80x80)
- Compress with tools like ImageOptim

### Lazy Loading

Author avatars already use `loading="lazy"`. For other images:
```html
<img src="image.jpg" loading="lazy" alt="Description">
```

### Minimize Repaints

The enhanced TOC uses `requestAnimationFrame` for smooth scrolling. Avoid adding heavy computations in scroll handlers.

---

## Accessibility

All components follow WCAG 2.1 AA guidelines:

- **Keyboard navigation** - All interactive elements accessible via keyboard
- **Screen readers** - ARIA labels and semantic HTML
- **Color contrast** - Minimum 4.5:1 ratio
- **Focus indicators** - Visible focus states
- **Alternative text** - Images have descriptive alt text

### Testing

Use these tools to verify accessibility:
- [WAVE Browser Extension](https://wave.webaim.org/extension/)
- [axe DevTools](https://www.deque.com/axe/devtools/)
- [Lighthouse](https://developers.google.com/web/tools/lighthouse)

---

## Examples

### Academic Research Post

```yaml
---
layout: post
title: "Deep Learning for Climate Modeling"
author: jane_smith
difficulty: advanced
toc: true
toc_label: "Research Overview"
categories: [Research, Machine Learning]
tags: [deep-learning, climate-science, neural-networks]
excerpt: "Exploring novel deep learning approaches for climate prediction"
---
```

### Tutorial Post

```yaml
---
layout: post
title: "Getting Started with Python Data Analysis"
difficulty: beginner
toc: true
categories: [Tutorials, Python]
tags: [python, pandas, data-analysis, beginners]
excerpt: "Learn the basics of data analysis with Python and pandas"
---
```

### Technical Deep Dive

```yaml
---
layout: post
title: "Understanding Transformer Architectures"
difficulty: expert
toc: true
toc_h_min: 2
toc_h_max: 5  # Include H5 for detailed sections
categories: [Deep Learning]
tags: [transformers, attention, NLP, architecture]
excerpt: "A comprehensive technical analysis of transformer models"
---
```

---

## Further Customization

### Add Custom Social Platforms

Copy `_includes/components/social-share.html` into your site's `_includes/components/` and add:

```html
<a href="https://yourplatform.com/share?url={{ share_url | uri_escape }}"
   class="social-share__button social-share__button--custom"
   target="_blank"
   rel="noopener noreferrer">
  <!-- Your platform icon SVG -->
  <span class="social-share__label">Custom Platform</span>
</a>
```

### Custom Difficulty Levels

Copy `_includes/components/difficulty-badge.html` into your site and add new levels:

```liquid
{%- when "expert-plus" -%}
  {%- assign normalized_level = "expert-plus" -%}
  {%- assign level_label = "Expert+" -%}
  {%- assign level_color = "purple" -%}
```

And style them in your stylesheet:

```scss
.difficulty-badge--expert-plus {
  background-color: #F3E5F5;
  color: #6A1B9A;
  border-color: #CE93D8;
}
```

---

## Support

For issues, questions, or contributions:
- Open an issue on [GitHub](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/issues)
- Check the [documentation index](README.md)
- Review the [Jekyll documentation](https://jekyllrb.com/docs/)
