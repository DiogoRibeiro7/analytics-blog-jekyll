# Phase 1 Features - Quick Reference

Fast reference guide for using Phase 1 enhancement features.

## 🎯 Quick Start

### Enable All Features (Default)

Features are automatically enabled! Just add to your post front matter:

```yaml
---
layout: post
title: "Your Post Title"
difficulty: intermediate  # Optional: beginner, intermediate, advanced, expert
---
```

That's it! All Phase 1 features will automatically appear.

---

## 📋 Cheat Sheet

### Post Front Matter Options

```yaml
---
# Required
layout: post
title: "Your Title"
date: 2025-11-21

# Optional - Author
author: Diogo Ribeiro  # Or custom author from _data/authors.yml

# Optional - Difficulty Badge
difficulty: intermediate  # beginner, intermediate, advanced, expert

# Optional - Table of Contents
toc: true  # Enable TOC (default: true)
toc_label: "Contents"  # Custom heading
toc_h_min: 2  # Minimum heading level
toc_h_max: 4  # Maximum heading level

# Optional - Categories & Tags
categories: [Category1, Category2]
tags: [tag1, tag2, tag3]

# Optional - Excerpt for social sharing
excerpt: "Brief description for social media"
---
```

### Manual Component Usage

```liquid
{%- comment -%} Social Share {%- endcomment -%}
{% include components/social-share.html
   url=page.url
   title=page.title %}

{%- comment -%} Breadcrumbs {%- endcomment -%}
{% include components/breadcrumbs.html
   separator=" > " %}

{%- comment -%} Author Bio {%- endcomment -%}
{% include components/author-bio.html
   author="Author Name"
   compact=false %}

{%- comment -%} Enhanced TOC {%- endcomment -%}
{% include components/enhanced-toc.html
   html=content
   heading="Contents" %}

{%- comment -%} Difficulty Badge {%- endcomment -%}
{% include components/difficulty-badge.html
   level="intermediate" %}
```

---

## 🎨 Customization Quick Wins

### Change Breadcrumb Separator

```yaml
# _config.yml
phase1_features:
  breadcrumbs:
    separator: " → "  # or " > " or " | "
```

### Disable Specific Features

```yaml
# _config.yml
phase1_features:
  social_sharing:
    enabled: false  # Disable social sharing

  enhanced_toc:
    sticky: false  # Make TOC non-sticky
```

### Override Per Post

```yaml
---
title: "Special Post"
toc: false  # Disable TOC for this post only
difficulty: expert  # Override default difficulty
---
```

### Compact Author Bio

```yaml
# _config.yml
phase1_features:
  author_bio:
    compact: true  # Smaller author bio cards
```

---

## 🎯 Common Use Cases

### Academic Research Post

```yaml
---
layout: post
title: "Novel Deep Learning Approach"
author: jane_smith
difficulty: expert
categories: [Research, Deep Learning]
tags: [neural-networks, research-paper, AI]
toc: true
toc_label: "Research Overview"
---
```

### Tutorial for Beginners

```yaml
---
layout: post
title: "Getting Started with Python"
difficulty: beginner
categories: [Tutorials, Python]
tags: [python, beginners, tutorial]
toc: true
---
```

### Technical Deep Dive

```yaml
---
layout: post
title: "Understanding Transformers"
difficulty: advanced
toc: true
toc_h_max: 5  # Include more heading levels
categories: [Deep Learning, NLP]
---
```

---

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| Social share buttons not showing | Check `_layouts/post.html` includes the component |
| Breadcrumbs wrong path | Verify `categories` in front matter |
| TOC not sticky | Adjust `top` value in `_phase1-enhancements.scss` |
| Author bio missing | Check `_config.yml` has author info |
| Difficulty badge wrong color | Use lowercase: `beginner`, `intermediate`, etc. |

---

## 📱 Responsive Behavior

| Breakpoint | Changes |
|------------|---------|
| **< 640px** | Social buttons full-width, breadcrumbs condensed |
| **< 768px** | Social buttons 2-column, TOC non-sticky, author bio centered |
| **> 768px** | All features full functionality |

---

## ♿ Accessibility Features

✅ **Included:**
- ARIA labels on all interactive elements
- Keyboard navigation support
- Screen reader optimized
- Focus indicators (`:focus-visible`)
- High contrast mode support
- Reduced motion support
- Semantic HTML throughout

**Test with:**
- Tab navigation
- Screen readers (NVDA, JAWS, VoiceOver)
- Keyboard only (no mouse)

---

## 🖨️ Print Styles

When printing posts:
- ✅ Breadcrumbs included
- ✅ Difficulty badge included
- ✅ Author bio included
- ✅ TOC content included
- ❌ Social share hidden
- ❌ TOC progress/stats hidden

---

## 🎨 Style Customization

### CSS Variables (Quick Changes)

```scss
// In your custom CSS
:root {
  --color-accent: #your-color;  // Change accent color
  --color-background: #your-bg;  // Change background
}
```

### Component-Specific

```scss
// Social share button colors
.social-share__button--twitter:hover {
  background-color: #your-color;
}

// Difficulty badge custom level
.difficulty-badge--your-level {
  background-color: #color;
  color: #text-color;
  border-color: #border-color;
}
```

---

## 📊 Feature Status

| Feature | Status | Auto-enabled | Configurable |
|---------|--------|--------------|--------------|
| Social Sharing | ✅ Ready | Yes | Yes |
| Breadcrumbs | ✅ Ready | Yes | Yes |
| Author Bio | ✅ Ready | Yes | Yes |
| Enhanced TOC | ✅ Ready | Yes | Yes |
| Difficulty Badges | ✅ Ready | Yes | Yes |

---

## 🚀 Performance Tips

1. **Images:** Use WebP format, resize to 160x160 for avatars
2. **TOC:** Limit heading levels (h_min: 2, h_max: 4)
3. **Mobile:** Features automatically optimize for mobile
4. **Loading:** All features use progressive enhancement

---

## 📚 Documentation Links

- 📖 **Full Guide:** `/docs/phase1-features-guide.md`
- 👨‍💻 **Developer Guide:** `/docs/phase1-developer-guide.md`
- 📝 **Example Post:** `/docs/phase1-example-post.md`
- ⚙️ **Config:** `_config.yml` → `phase1_features`

---

## 💡 Pro Tips

1. **Always set difficulty** - Helps readers know what to expect
2. **Use descriptive excerpts** - Better for social sharing
3. **Organize with categories** - Improves breadcrumb navigation
4. **Add research areas** - Enhances author bio credibility
5. **Test on mobile** - Check responsive behavior

---

## 🆘 Quick Support

**Found a bug?**
- Check `/docs/phase1-features-guide.md#troubleshooting`
- Open issue on GitHub

**Need customization?**
- See `/docs/phase1-developer-guide.md`
- Check `_sass/_phase1-enhancements.scss`

**Questions?**
- Review full documentation
- Check example post

---

**Version:** 1.0.0 (Phase 1)
**Last Updated:** 2025-11-21
