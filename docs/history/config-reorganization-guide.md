---
layout: doc
title: Configuration Reorganization Guide
nav_order: 12
---

# Configuration Reorganization Guide

## Overview

> **Status:** the section layout below describes `_config.yml` as it is today. The companion data files this plan once proposed (`_data/config/site.yml`, `theme.yml`, `features.yml`) were never read by the theme and have been removed; only `_data/config/author.yml` exists, for the author profile. Treat any mention of those three files below as historical.

The DataLog theme configuration has been reorganized into **11 clear sections** to improve maintainability and ease of use. This guide explains the new structure and how to migrate.

## New Structure

### Section Breakdown

| Section | Lines | Purpose | Required? |
|---------|-------|---------|-----------|
| **1. Jekyll Core** | ~130 | Jekyll build settings, collections, plugins | ✅ Required |
| **2. Site Identity** | ~20 | Branding, SEO, social defaults | ✅ Required |
| **3. Author Profile** | ~40 | Author bio and social links | ✅ Required |
| **4. Core Features** | ~20 | Main feature flags | ⚠️ Optional |
| **5. Theme Customization** | ~200 | Visual design, typography, integrations | ⚠️ Optional |
| **6. Integrations** | ~60 | Third-party services | ⚠️ Optional |
| **7. Notebooks** | ~15 | Jupyter notebook settings | ⚠️ Optional |
| **8. DataLog Plugins** | ~20 | Custom plugin configs | ⚠️ Optional |
| **9. Phase Features** | ~180 | Progressive enhancements | ⚠️ Optional |
| **10. Performance** | ~10 | Build optimization | ⚠️ Optional |
| **11. Development** | ~5 | Dev-only settings | ⚠️ Optional |

## What Changed?

### Before (Old Structure)
```yaml
# Mixed configuration with unclear boundaries
name: DataLog
author:
  name: ...
markdown: kramdown
features:
  ...
integrations:
  ...
# (Settings scattered throughout 703 lines)
```

### After (New Structure)
```yaml
# ==============================================================================
# SECTION 1: REQUIRED JEKYLL CORE SETTINGS
# ==============================================================================
# Clear section headers with descriptions
# Grouped by concern
# Required vs optional clearly marked

name: DataLog
# ... (all core Jekyll settings together)

# ==============================================================================
# SECTION 2: SITE IDENTITY & BRANDING
# ==============================================================================
# ... (all branding together)
```

## Benefits

✅ **Easy Navigation** - Jump to relevant section instantly
✅ **Clear Boundaries** - Visual separators between concerns
✅ **Better Documentation** - Inline comments explain each section
✅ **Reduced Errors** - Clear grouping prevents misconfiguration
✅ **Faster Onboarding** - New users understand structure immediately
✅ **Maintenance** - Easier to update related settings together

## Migration Options

### Option 1: Use Reorganized Config (Recommended)

Replace your current `_config.yml` with the reorganized version:

```bash
# Backup current config
cp _config.yml _config.yml.backup

# Use reorganized version
cp _config.reorganized.yml _config.yml

# Test build
bundle exec jekyll build

# If successful, commit
git add _config.yml
git commit -m "Migrate to reorganized configuration structure"
```

### Option 2: Manual Reorganization

Apply the section headers to your existing config:

1. Add section header comments
2. Group related settings under each section
3. Add inline documentation
4. Test thoroughly

### Option 3: Keep Current (No Changes)

Your existing `_config.yml` continues to work without changes. The reorganized version is optional.

## Section Details

### Section 1: Jekyll Core Settings (Required)

Contains settings Jekyll needs to function:
- Site identity (name, title, url)
- Build configuration (markdown, highlighter)
- Collections and permalinks
- Plugins
- Defaults and exclusions

**⚠️ Warning:** Changes here can break your build. Only modify if you understand Jekyll internals.

### Section 2: Site Identity & Branding (Required)

Your site's public face:
- Brand tagline and accent symbol
- SEO metadata
- Social media defaults

**Action needed:** Customize with your branding

### Section 3: Author Profile (Required)

Your professional profile:
- Name, affiliation, bio
- Academic profiles (ORCID, Google Scholar, ResearchGate)
- Social links (GitHub, Twitter, LinkedIn)
- Research areas and methodologies

**Action needed:** Fill in your details

### Section 4: Core Features (Optional)

High-level feature toggles:
- Math rendering
- Search
- Dark mode
- Notebooks
- Visualizations

**Default:** All enabled. Disable features you don't need.

### Section 5: Theme Customization (Optional)

Deep customization options:
- Colors and typography
- Math and syntax highlighting engines
- Visualization libraries
- Academic integrations
- Taxonomies and filters

**Default:** Sensible defaults provided. Customize as needed.

### Section 6: Integrations (Optional)

Third-party services:
- Analytics (Google Analytics, GA4)
- GitHub integration
- Binder/Colab for notebooks
- Data platforms (Kaggle, Zenodo)
- Academic profiles

**Setup required:** Add API keys and profile URLs

### Section 7: Notebook Integration (Optional)

Jupyter notebook specific settings:
- Source and output directories
- Repository links
- Binder and Colab URLs

**Default:** Configured for standard setup

### Section 8: DataLog Plugins (Optional)

Custom theme plugins:
- Search
- Citations
- Slides
- Comments (Giscus)

**Default:** Enabled with standard config

### Section 9: Phase Features (Optional)

Progressive enhancements organized by development phase:
- **Phase 1:** Social sharing, breadcrumbs, author bio, TOC
- **Phase 2:** Sidebar, series, search facets, newsletter
- **Phase 3:** Archives, reading progress, recommendations, comments
- **Phase 4:** User preferences, popular posts, navigation
- **Phase 5:** i18n, advanced search, bookmarks, performance tracking

**Default:** Most enabled. Disable unwanted features.

### Section 10: Performance & Optimization (Optional)

Build optimizations:
- Critical CSS generation
- Performance dimensions

**Default:** Optimized for production

### Section 11: Development Settings (Optional)

Local development only:
- Livereload

**Note:** Not used in production builds

## Quick Reference

### Finding Settings

| What you need | Section | Line range (approx) |
|---------------|---------|---------------------|
| Change site title | Section 1 | Lines 1-130 |
| Update author bio | Section 3 | Lines 150-190 |
| Enable/disable features | Section 4 | Lines 200-220 |
| Customize colors | Section 5 | Lines 230-430 |
| Add analytics | Section 6 | Lines 440-500 |
| Configure notebooks | Section 7 | Lines 510-530 |
| Setup comments | Section 9 (Phase 3) | Lines 600-650 |

### Common Tasks

**Add Google Scholar:**
1. Go to Section 3 (Author Profile)
2. Fill in `google_scholar` URL
3. Go to Section 6 (Integrations)
4. Enable `scholar.enabled: true`
5. Add `profile_id`

**Disable a feature:**
1. Find feature in Section 4 or Section 9
2. Set `enabled: false`

**Change colors:**
1. Go to Section 5 → `theme_options.academic.color_schemes`
2. Update hex values

**Add analytics:**
1. Go to Section 6
2. Fill in `google_analytics` or `analytics.ga4_property_id`

## Validation

After migration, validate your config:

```bash
# Check YAML syntax
ruby -ryaml -e "YAML.load_file('_config.yml')"

# Test build
bundle exec jekyll build --verbose

# Check for warnings
grep -i "warning\|error" _jekyll.log
```

## Rollback

If anything goes wrong:

```bash
# Restore backup
cp _config.yml.backup _config.yml

# Rebuild
bundle exec jekyll build
```

## FAQ

**Q: Do I have to migrate?**
A: No. Your current config continues to work. Migration is optional but recommended.

**Q: Will this break my site?**
A: No. The reorganized config has the same settings, just better organized.

**Q: Can I customize the section headers?**
A: Yes! They're just comments. Modify as you like.

**Q: What if I have custom settings?**
A: Add them to the relevant section or create a new Section 12 for custom options.

**Q: Can I remove sections I don't use?**
A: Yes, but keep Section 1 (Jekyll Core) and Section 2-3 (Site/Author). Others are optional.

## Next Steps

1. **Review** the reorganized config: `_config.reorganized.yml`
2. **Test** build with new structure
3. **Migrate** when ready (or stay with current)
4. **Customize** your settings
5. **Document** any custom additions

## Resources

- **Full refactoring plan:** `docs/config-refactoring-plan.md`
- **Configuration reference:** `docs/configuration-reference.md`
- **Google Scholar setup:** `docs/google-scholar-setup.md`

## Feedback

If you have suggestions for improving this structure:
1. Open an issue on GitHub
2. Propose alternative section groupings
3. Request additional documentation

---

**Document Version:** 1.0
**Date:** 2025-11-21
**Status:** Ready for review
