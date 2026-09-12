# Post Components

The `post` layout adds five components to every post: social sharing buttons, breadcrumbs, an author card, an enhanced table of contents and a difficulty badge. This guide covers what each one shows, the front matter that controls it, how to include it in other layouts, and how to change its look.

## Table of Contents

1. [Social Sharing Buttons](#social-sharing-buttons)
2. [Breadcrumb Navigation](#breadcrumb-navigation)
3. [Author Bio Cards](#author-bio-cards)
4. [Enhanced Table of Contents](#enhanced-table-of-contents)
5. [Difficulty Badges](#difficulty-badges)
6. [Front Matter](#front-matter)
7. [Customization](#customization)
8. [Troubleshooting](#troubleshooting)

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
