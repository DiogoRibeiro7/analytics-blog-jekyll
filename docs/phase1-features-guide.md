# Phase 1 Features Guide

Complete guide to using and customizing the new Phase 1 enhancement features in the DataLog theme.

## Table of Contents

1. [Overview](#overview)
2. [Social Sharing Buttons](#social-sharing-buttons)
3. [Breadcrumb Navigation](#breadcrumb-navigation)
4. [Author Bio Cards](#author-bio-cards)
5. [Enhanced Table of Contents](#enhanced-table-of-contents)
6. [Difficulty Badges](#difficulty-badges)
7. [Configuration](#configuration)
8. [Customization](#customization)
9. [Troubleshooting](#troubleshooting)

---

## Overview

Phase 1 introduces 5 major feature enhancements designed to improve user engagement, navigation, and content discoverability:

- **Social Sharing** - Beautiful, icon-based sharing buttons
- **Breadcrumbs** - Improved navigation and SEO
- **Author Bio** - Professional author presentation
- **Enhanced TOC** - Sticky, interactive table of contents
- **Difficulty Badges** - Visual content difficulty indicators

All features are:
- ✅ **Mobile-responsive** - Optimized for all screen sizes
- ✅ **Accessible** - WCAG 2.1 AA compliant with ARIA labels
- ✅ **SEO-friendly** - Structured data for search engines
- ✅ **Dark mode ready** - Uses CSS variables
- ✅ **Performance optimized** - Minimal JavaScript, lazy loading

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

### Customization

To customize which platforms appear, edit `_includes/components/social-share.html` and comment out unwanted platforms.

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

Edit `_sass/_phase1-enhancements.scss` under the `.social-share` section to customize:

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

Edit the `.breadcrumbs` section in `_sass/_phase1-enhancements.scss`:

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
{% include components/author-bio.html
   author="Author Name"
   show_avatar=true
   show_social=true
   compact=false %}
```

**Parameters:**
- `author` - Author name (default: page.author or site.author.name)
- `show_avatar` - Show author avatar (default: true)
- `show_social` - Show social links (default: true)
- `compact` - Use compact layout (default: false)

### Multiple Authors

Create `_data/authors.yml`:

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
- **Smooth scrolling** - Elegant navigation to sections
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

Edit `.enhanced-toc` in `_sass/_phase1-enhancements.scss`:

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

Add difficulty to your post front matter:

```yaml
---
title: Understanding Neural Networks
difficulty: intermediate
---
```

The badge will automatically appear in the post metadata section.

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

### Customization

Edit `.difficulty-badge` in `_sass/_phase1-enhancements.scss`:

```scss
.difficulty-badge--beginner {
  background-color: #ECFDF5;
  color: #047857;
  border-color: #A7F3D0;
}
```

---

## Configuration

### Global Settings

Add to your `_config.yml`:

```yaml
# Phase 1 Features Configuration
phase1_features:
  # Social sharing
  social_sharing:
    enabled: true
    platforms:
      - twitter
      - linkedin
      - facebook
      - reddit
      - email

  # Breadcrumbs
  breadcrumbs:
    enabled: true
    separator: " / "
    show_home: true

  # Author bio
  author_bio:
    enabled: true
    position: after_content  # or "before_content"
    show_avatar: true
    show_social: true
    compact: false

  # Enhanced TOC
  enhanced_toc:
    enabled: true
    sticky: true
    show_progress: true
    collapsible: true
    h_min: 2
    h_max: 4

  # Difficulty badges
  difficulty_badges:
    enabled: true
    default_level: beginner
```

### Per-Post Overrides

Override settings in post front matter:

```yaml
---
title: My Post
difficulty: advanced
toc: true
toc_h_min: 2
toc_h_max: 3
author: custom_author
---
```

---

## Customization

### Colors

All components use CSS variables defined in `_sass/_theme.scss`:

```scss
:root {
  --color-accent: #3277f6;
  --color-background: #ffffff;
  --color-text-primary: #0b1d3d;
  --color-border: #e0e4ed;
}
```

### Typography

Modify font sizes in `_sass/_phase1-enhancements.scss`:

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
1. Verify post has correct `collection` in front matter
2. Check category is properly set
3. Ensure collection pages exist (e.g., `/blog/index.html`)

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
Add to `_includes/scripts.html` if not already present:
```html
<script src="{{ '/assets/js/main.js' | relative_url }}"></script>
```

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

Edit `_includes/components/social-share.html` and add:

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

Add new levels in `_includes/components/difficulty-badge.html`:

```liquid
{%- when "expert-plus" -%}
  {%- assign normalized_level = "expert-plus" -%}
  {%- assign level_label = "Expert+" -%}
  {%- assign level_color = "purple" -%}
```

And add styling in `_sass/_phase1-enhancements.scss`:

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
- Check existing documentation in `/docs/`
- Review the [Jekyll documentation](https://jekyllrb.com/docs/)

---

**Last Updated:** 2025-11-21
**Version:** 1.0.0 (Phase 1)
