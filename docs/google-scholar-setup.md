---
layout: doc
title: Google Scholar Integration Setup
nav_order: 10
---

# Google Scholar Integration Setup

This guide explains how to configure Google Scholar integration in the DataLog theme to display your academic publications, citations, and metrics.

## Overview

The theme supports Google Scholar integration in three areas:
1. **Author Profile** - Display your Google Scholar profile link
2. **Academic Integrations** - Auto-refresh and sync publication data
3. **Scholar Metrics** - Display citation counts and h-index

## Prerequisites

Before configuring Google Scholar integration:
- You must have a Google Scholar profile
- Your profile must be public
- You need your Google Scholar user ID

## Finding Your Google Scholar User ID

1. Go to your Google Scholar profile (e.g., `https://scholar.google.com/citations?user=XXXXXXXXXXXX`)
2. Look at the URL - your user ID is the value after `user=`
3. Example: If your URL is `https://scholar.google.com/citations?user=AbCdEfGhIjK`, your user ID is `AbCdEfGhIjK`

## Configuration Steps

### Step 1: Basic Author Profile Link

Add your Google Scholar profile URL to the author section:

```yaml
author:
  name: Your Name
  email: your.email@example.com
  google_scholar: "https://scholar.google.com/citations?user=YOUR_USER_ID"
```

This enables:
- Google Scholar icon in author bio sections
- Links to your profile from publications
- Social sharing metadata

### Step 2: Academic Integrations

Configure the academic integrations section for advanced features:

```yaml
academic_integrations:
  google_scholar:
    profile_url: "https://scholar.google.com/citations?user=YOUR_USER_ID"
    user_id: "YOUR_USER_ID"
    auto_refresh: true  # Enable automatic data refresh
```

**Configuration Options:**

- `profile_url`: Full URL to your public Google Scholar profile (required)
- `user_id`: Your Google Scholar user ID (required for auto-refresh)
- `auto_refresh`: When `true`, attempts to fetch fresh citation data during builds

**Important Notes:**
- Auto-refresh relies on Google Scholar's public API/scraping
- Rate limits may apply - use cached data for frequent builds
- Consider building citation data manually if auto-refresh fails

### Step 3: Scholar Metrics Display

Enable the scholar metrics feature to display citations, h-index, and i10-index:

```yaml
scholar:
  enabled: true
  profile_id: "YOUR_USER_ID"
  metrics_source: data/academic.yml  # Optional: use cached/manual data
```

**Configuration Options:**

- `enabled`: Set to `true` to activate scholar metrics features
- `profile_id`: Your Google Scholar user ID
- `metrics_source`: Path to YAML file with cached academic metrics (optional)

### Step 4: Academic Data File (Optional)

If auto-refresh is unreliable or you prefer manual control, create `_data/academic.yml`:

```yaml
google_scholar:
  user_id: "YOUR_USER_ID"
  profile_url: "https://scholar.google.com/citations?user=YOUR_USER_ID"
  metrics:
    citations: 1234
    h_index: 15
    i10_index: 20
    updated: "2025-11-21"

  recent_publications:
    - title: "Your Paper Title"
      authors: "Author1, Author2"
      venue: "Conference/Journal Name"
      year: 2024
      citations: 45
      url: "https://scholar.google.com/citations?view_op=view_citation&citation_for_view=..."
```

## Complete Example Configuration

Here's a complete example with all Google Scholar settings configured:

```yaml
# _config.yml

author:
  name: Dr. Jane Smith
  email: jane.smith@university.edu
  google_scholar: "https://scholar.google.com/citations?user=AbCdEfGhIjK"
  orcid: https://orcid.org/0000-0001-2345-6789

academic_integrations:
  google_scholar:
    profile_url: "https://scholar.google.com/citations?user=AbCdEfGhIjK"
    user_id: "AbCdEfGhIjK"
    auto_refresh: true
  orcid:
    profile_url: https://orcid.org/0000-0001-2345-6789
    auto_sync: true

scholar:
  enabled: true
  profile_id: "AbCdEfGhIjK"
  metrics_source: data/academic.yml
```

## Troubleshooting

### Auto-refresh not working

**Problem:** Citation data isn't updating automatically

**Solutions:**
1. Verify your profile is public (not private)
2. Check that `user_id` is correct
3. Use manual data file (`_data/academic.yml`) as fallback
4. Check build logs for rate limiting messages

### Profile link not appearing

**Problem:** Google Scholar icon/link doesn't show in author bio

**Solutions:**
1. Ensure `author.google_scholar` is a complete URL (not just user ID)
2. Verify URL format: `https://scholar.google.com/citations?user=YOUR_ID`
3. Check that your theme layout includes author social links

### Metrics not displaying

**Problem:** Citation metrics (h-index, etc.) don't appear

**Solutions:**
1. Confirm `scholar.enabled` is set to `true`
2. Verify `profile_id` matches your Google Scholar user ID
3. If using manual data, ensure `_data/academic.yml` exists and is valid YAML
4. Check that your layout includes the scholar metrics component

## Privacy Considerations

- Google Scholar profiles are public by default
- This integration only links to/displays publicly available data
- No authentication or API keys are required
- Data refresh happens during build time, not client-side
- Consider using cached data (`_data/academic.yml`) if you prefer not to fetch live data

## Disabling Google Scholar

To completely disable Google Scholar integration:

```yaml
author:
  google_scholar: ""  # Leave empty

academic_integrations:
  google_scholar:
    profile_url: ""
    user_id: ""
    auto_refresh: false

scholar:
  enabled: false
  profile_id: ""
```

## Scholarly Metadata on Articles

The profile integration above is about you; this section is about your articles. A page read as a research article carries the meta tags Google Scholar, Zotero and other reference managers read to index and cite it, and their Dublin Core equivalents. Not every post is a paper, so the tags are opt-in.

### Which pages get them

- A page with the `research` layout (or in a `research` collection) always does, unless its front matter says `scholarly: false`.
- Any other page does with `scholarly: true` in its front matter.
- `scholarly: true` in `_config.yml` covers every post as well; a list such as `scholarly: [posts, notebooks]` names the collections or layouts to cover.

Everything else (the home page, listings, the search page, a post that is a note rather than a paper) gets none of them.

### What they read

```yaml
---
title: Model diagnostics for normality
scholarly: true
date: 2026-09-16
authors:
  - name: Diogo Ribeiro
    affiliation: ESMAD - Instituto Politécnico do Porto
    orcid: 0009-0001-2022-7072
doi: 10.1234/example
pdf_url: /papers/normality.pdf
journal: Notes on Applied Statistics   # or conference:
volume: 3
number: 2                              # or issue:
pages: 12-34
keywords: [normality, diagnostics]
---
```

| Tag | From |
| --- | --- |
| `citation_title` | `citation_title`, else the title |
| `citation_author`, then that author's `citation_author_institution` and `citation_author_orcid` | the page's authors, the same list as the byline, the JSON-LD and the citation exports; `citation_authors` names the indexed authors alone |
| `citation_publication_date` | `date`, as `YYYY/MM/DD` |
| `citation_public_url`, `citation_fulltext_html_url` | the page's URL |
| `citation_pdf_url` | `pdf_url` (or `citation_pdf`), made absolute |
| `citation_doi` | `doi` |
| `citation_journal_title`, `citation_conference_title` | `journal` (or `publication`), `conference` |
| `citation_volume`, `citation_issue`, `citation_firstpage`, `citation_lastpage`, `citation_issn`, `citation_isbn` | `volume`, `issue` (or `number`), `pages` split at its dash, `issn`, `isbn` |
| `citation_publisher` | `publisher` on the page, else the site's publisher |
| `citation_language` | `lang`, else the site locale |
| `citation_keywords` | `keywords`, else `tags`, joined with `; ` |
| `DC.title`, `DC.creator`, `DC.date`, `DC.identifier`, `DC.type`, `DC.language`, `DC.publisher`, `DC.rights`, `DC.description` | the same fields; the identifier is the DOI as a URL, else the page's URL; the rights are the page's licence; the type is `Text` |

A field the page lacks leaves its tag out, so nothing is emitted empty.

### How they relate to the JSON-LD and the citation tools

The three describe the same article to different readers. The JSON-LD `TechnicalArticle` (or `ScholarlyArticle` on a research page) is for search engines; the Highwire and Dublin Core tags are for scholarly indexes and reference managers; the BibTeX, RIS and EndNote exports under "How to cite" are for a reader's own bibliography. All of them take the authors from `page | page_authors`, the DOI from `doi`, the publisher from `publisher` and the licence from `license`, so a change in front matter reaches every one of them.

## Related Documentation

- [Configuration Reference](configuration-reference.md) - All configuration options
- [Academic Features Guide](user-guide.md) - Using academic content types
- [ORCID Integration](environment-setup.md) - Setting up ORCID sync

## Support

If you encounter issues with Google Scholar integration:
1. Check the [GitHub Issues](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/issues)
2. Review build logs for error messages
3. Verify your configuration against this guide
4. Consider using manual data as a workaround
