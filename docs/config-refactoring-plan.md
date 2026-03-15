---
layout: doc
title: Configuration Refactoring Plan
nav_order: 11
---

# Configuration Refactoring Plan

## Current State

The `_config.yml` file is **703 lines** long with multiple concerns mixed together:
- Jekyll core settings
- Theme customization
- Author/site metadata
- Feature flags
- Integration credentials
- Plugin configurations
- Build settings

## Problems

1. **Hard to Navigate** - New users struggle to find relevant settings
2. **Mixed Concerns** - Jekyll settings mixed with theme options
3. **No Clear Priority** - Critical vs optional settings not distinguished
4. **Poor Maintainability** - Changes risk breaking unrelated features
5. **Difficult Onboarding** - Overwhelming for first-time setup

## Proposed Solution

### Phase 1: Reorganize Current File (Immediate)

Restructure `_config.yml` with clear sections and better documentation:

```yaml
# =============================================================================
# SECTION 1: REQUIRED JEKYLL CORE SETTINGS
# =============================================================================
# These settings are required for Jekyll to function properly.
# Do not modify unless you know what you're doing.

title: DataLog | Data Science & Research Theme
url: "https://diogoribeiro7.github.io"
baseurl: ""
markdown: kramdown
# ... (essential Jekyll settings only)

# =============================================================================
# SECTION 2: SITE IDENTITY & BRANDING
# =============================================================================
# Customize these to match your site's identity

name: DataLog
locale: en_US
brand:
  tagline: "..."
# ... (site-specific branding)

# =============================================================================
# SECTION 3: AUTHOR PROFILE
# =============================================================================
# Your professional profile and social links

author:
  name: Your Name
  # ... (author details)

# =============================================================================
# SECTION 4: THEME FEATURES (OPTIONAL)
# =============================================================================
# Enable/disable theme features. All are optional.

features:
  math_rendering: true
  # ... (feature flags)

# =============================================================================
# SECTION 5: INTEGRATIONS (OPTIONAL)
# =============================================================================
# Third-party service configurations

integrations:
  google_analytics: ""
  # ... (API keys, service IDs)

# =============================================================================
# SECTION 6: BUILD & DEVELOPMENT
# =============================================================================
# Advanced build settings - modify only if needed

collections:
  # ... (collections config)
```

**Benefits:**
- Clear section boundaries with visual separators
- Comments explain what each section is for
- Easy to jump to relevant section
- Distinguishes required vs optional settings

### Phase 2: Extract to Data Files (Medium Term)

Move non-Jekyll data to `_data/` directory:

#### `_data/theme_config.yml`
```yaml
# Theme-specific settings that don't affect Jekyll core
features:
  math_rendering:
    enabled: true
    engine: mathjax
  syntax_highlighting:
    enabled: true
    style: monokai
  # ... all feature flags

visual:
  color_scheme: default
  typography:
    base_font: system-ui
    code_font: "JetBrains Mono"
  # ... visual customization
```

#### `_data/integrations.yml`
```yaml
# Third-party service configurations
analytics:
  google_analytics: ""
  plausible: ""

social:
  twitter_username: ""
  github_username: ""

academic:
  google_scholar: ""
  orcid: ""
```

#### `_data/author.yml`
```yaml
# Author profile (can have multiple authors in the future)
name: Diogo Ribeiro
affiliation: ESMAD
email: dfr@esmad.ipp.pt
social:
  github: DiogoRibeiro7
  twitter: DiogoRibeiro7
  linkedin: diogoribeiro
```

**Benefits:**
- Smaller, focused `_config.yml`
- Easier to manage theme data separately
- Better for version control (can .gitignore sensitive data)
- Allows multiple profiles/configurations

### Phase 3: Create Configuration Presets (Long Term)

Provide preset configuration files for common use cases:

```
config/
├── presets/
│   ├── academic.yml          # Academic/research site
│   ├── blog.yml              # Personal blog
│   ├── portfolio.yml         # Project portfolio
│   ├── documentation.yml     # Technical documentation
│   └── minimal.yml           # Minimal setup
├── development.yml           # Dev overrides
└── production.yml            # Prod overrides
```

Users can build with: `jekyll build --config _config.yml,config/presets/academic.yml`

### Phase 4: Configuration Validator & Generator

Create tools to help users:

#### `bin/config-wizard`
```bash
$ bin/config-wizard

Welcome to DataLog Theme Configuration Wizard!

What type of site are you building?
1) Academic Research
2) Data Science Blog
3) Project Portfolio
4) Technical Documentation

[Selection generates optimized _config.yml]
```

#### `bin/config-validate`
```bash
$ bin/config-validate

✓ Required settings present
✓ URLs properly formatted
✗ Google Analytics ID invalid format
⚠ No social media links configured
```

## Implementation Roadmap

### Week 1: Reorganization
- [ ] Create section headers in `_config.yml`
- [ ] Group related settings
- [ ] Add inline documentation
- [ ] Create `docs/configuration-sections.md` guide

### Week 2: Data Extraction
- [ ] Create `_data/theme_config.yml`
- [ ] Create `_data/integrations.yml`
- [ ] Create `_data/author.yml`
- [ ] Update theme code to read from `_data/`
- [ ] Test thoroughly

### Week 3: Preset Creation
- [ ] Create `config/presets/` directory
- [ ] Develop academic.yml preset
- [ ] Develop blog.yml preset
- [ ] Develop portfolio.yml preset
- [ ] Document preset usage

### Week 4: Tooling
- [ ] Create config wizard script
- [ ] Create config validator
- [ ] Add validation to CI/CD
- [ ] Update documentation

## Migration Guide for Users

When we ship these changes, users need clear migration instructions:

### Option 1: Keep Current Setup (No Changes)
```yaml
# Your existing _config.yml continues to work
# No action required
```

### Option 2: Migrate to New Structure (Recommended)
```bash
$ bin/migrate-config
# Automatically splits your config into new structure
# Creates backup of old config
```

### Option 3: Start Fresh with Preset
```bash
$ cp config/presets/academic.yml _config.yml
# Edit with your details
```

## Backwards Compatibility

- Keep reading from both old and new locations
- Deprecation warnings for old format
- Full removal only in major version bump
- Clear migration timeline (6-12 months)

## Testing Strategy

1. **Automated Tests**
   - Test both old and new config formats
   - Validate all presets build successfully
   - Check validator catches common errors

2. **Documentation**
   - Update all docs to reference new structure
   - Create video tutorial for migration
   - FAQ for common issues

3. **User Feedback**
   - Beta test with current users
   - Gather feedback on usability
   - Iterate based on real usage

## Success Metrics

- **Reduce `_config.yml` to < 200 lines** (core Jekyll + theme settings)
- **90% of users** can set up site in < 10 minutes using wizard
- **Zero breaking changes** for existing users
- **Improved docs** rated 4.5+ stars by users

## Related Issues

- Configuration complexity (#XX)
- New user onboarding difficulty (#XX)
- Hard to find settings (#XX)

## Questions to Resolve

1. Should we use YAML anchors/aliases for DRY config?
2. Do we support environment-specific configs by default?
3. Should sensitive data (API keys) go in ENV vars instead?
4. Do we need a config schema (JSON Schema/Cerberus)?

## References

- [Jekyll Configuration Docs](https://jekyllrb.com/docs/configuration/)
- [Minimal Mistakes Theme Config](https://github.com/mmistakes/minimal-mistakes)
- [Just the Docs Config](https://github.com/just-the-docs/just-the-docs)

---

**Document Status:** Draft
**Author:** System Analysis
**Date:** 2025-11-21
**Review:** Pending maintainer approval
