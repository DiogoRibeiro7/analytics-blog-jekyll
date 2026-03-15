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
