# Configuration Guide

This document explains how the DataLog theme's configuration is organized for easy customization.

## Overview

Configuration has been split into modular files for easier maintenance:

| File | Purpose |
|------|---------|
| `_config.yml` | Core Jekyll settings (required) |
| `_data/config/site.yml` | Brand, contact, SEO, analytics |
| `_data/config/author.yml` | Author profile and academic info |
| `_data/config/theme.yml` | Visual settings, math, syntax, images |
| `_data/config/integrations.yml` | External service connections |
| `_data/config/features.yml` | Feature flags organized by phase |

## Quick Start

### 1. Update Your Profile

Edit `_data/config/author.yml`:

```yaml
name: Your Name
affiliation: Your Institution
email: your@email.com

profiles:
  orcid: https://orcid.org/YOUR-ORCID
  github: yourusername
  twitter: yourhandle
```

### 2. Configure Site Branding

Edit `_data/config/site.yml`:

```yaml
brand:
  tagline: "Your site tagline"
  accent_symbol: "Your symbol"

contact:
  collaboration: your@email.com
```

### 3. Enable/Disable Features

Edit `_data/config/features.yml`:

```yaml
core:
  dark_mode_toggle: true
  search: true
  mathjax: true

comments:
  enabled: true
  provider: giscus
```

## File Details

### _config.yml (Core Settings)

This file contains settings that Jekyll requires:
- Site title, URL, description
- Build settings (markdown, plugins)
- Collections and defaults
- Exclusions

**Note:** Some settings are duplicated here for Jekyll compatibility while the full config is in data files.

### _data/config/site.yml

Brand and site-wide settings:

```yaml
brand:
  tagline: "Your tagline"
  accent_symbol: "∀ data · Σ insights"

contact:
  collaboration: email@example.com
  media: press@example.com

seo:
  type: "ResearchProject"
  name: "Your Site"

analytics:
  ga4_property_id: ""  # Add your GA4 ID
```

### _data/config/author.yml

Your professional profile:

```yaml
name: Your Name
affiliation: Your Institution
biography: Short bio for author cards

profiles:
  orcid: https://orcid.org/...
  github: username
  twitter: handle
  linkedin: profile
  google_scholar: ""
  researchgate: ""

research_areas:
  - id: machine-learning
    title: Machine Learning
    url: /tags/machine-learning/
```

### _data/config/theme.yml

Visual and behavioral settings:

```yaml
# Color scheme
academic:
  color_schemes:
    light: "#0b1d3d"
    dark: "#f5f7ff"
    accent: "#3277f6"

# Math rendering
math:
  engine: mathjax  # or katex
  equation_numbering: true
  accessibility: true

# Code highlighting
syntax_highlighting:
  engine: prism
  themes:
    light: prism-coy
    dark: prism-tomorrow
```

### _data/config/integrations.yml

External service connections:

```yaml
github:
  enabled: true
  owner: yourusername

binder:
  enabled: true

colab:
  enabled: true

scholar:
  enabled: false  # Enable when configured
  profile_id: ""

orcid:
  enabled: true
  profile: https://orcid.org/...
```

### _data/config/features.yml

Feature toggles organized by phase:

```yaml
# Core features
core:
  mathjax: true
  search: true
  dark_mode_toggle: true

# Social sharing
social_sharing:
  enabled: true
  platforms:
    - twitter
    - linkedin
    - email

# Comments
comments:
  enabled: true
  provider: giscus
  giscus:
    repo: "owner/repo"
    repo_id: ""  # Get from giscus.app
```

## Accessing Configuration in Templates

In Liquid templates, access configuration via:

```liquid
<!-- From _config.yml -->
{{ site.title }}
{{ site.author.name }}

<!-- From data files -->
{{ site.data.config.author.name }}
{{ site.data.config.theme.math.engine }}
{{ site.data.config.features.comments.enabled }}
```

## Migration from Previous Versions

If you're upgrading from a previous version:

1. Your existing `_config.yml` settings will continue to work
2. Gradually move custom settings to the appropriate data files
3. The theme checks both locations for backward compatibility

## Common Configuration Tasks

### Enable Dark Mode

In `_config.yml` or `_data/config/features.yml`:
```yaml
dark_mode_toggle: true
```

### Add Google Analytics

In `_data/config/site.yml`:
```yaml
analytics:
  ga4_property_id: "G-XXXXXXXXXX"
```

### Enable Comments

In `_data/config/features.yml`:
```yaml
comments:
  enabled: true
  provider: giscus
  giscus:
    repo: "your-username/your-repo"
    repo_id: ""  # Get from https://giscus.app
    category_id: ""
```

### Configure Math Rendering

In `_data/config/theme.yml`:
```yaml
math:
  engine: mathjax  # or katex
  equation_numbering: true
  accessibility: true
```

## Need Help?

- [Full Documentation](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/docs)
- [Report Issues](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/issues)
