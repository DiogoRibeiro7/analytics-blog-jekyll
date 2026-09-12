# Phase 1 Developer Customization Guide

Technical guide for developers who want to customize and extend the Phase 1 enhancement features.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Structure](#component-structure)
3. [Styling System](#styling-system)
4. [JavaScript Functionality](#javascript-functionality)
5. [Creating Custom Variants](#creating-custom-variants)
6. [Integration Patterns](#integration-patterns)
7. [Performance Optimization](#performance-optimization)
8. [Testing](#testing)

---

## Architecture Overview

### Component Philosophy

Phase 1 components follow these principles:

1. **Progressive Enhancement** - Work without JavaScript
2. **Modularity** - Each component is self-contained
3. **Accessibility-First** - WCAG 2.1 AA compliance
4. **Performance** - Minimal DOM manipulation
5. **Customizability** - CSS variables and parameters

### File Structure

```
_includes/components/
├── social-share.html       # Social sharing buttons
├── breadcrumbs.html        # Breadcrumb navigation
├── author-bio.html         # Author bio cards
├── enhanced-toc.html       # Enhanced table of contents
└── difficulty-badge.html   # Difficulty badges

_sass/
└── _phase1-enhancements.scss  # All Phase 1 styles

_layouts/
└── post.html               # Integration point
```

---

## Component Structure

### Liquid Template Pattern

All components follow this structure:

```liquid
{%- comment -%}
Component documentation:
- Purpose
- Parameters
- Usage examples
{%- endcomment -%}

{%- assign param = include.param | default: default_value -%}

<div class="component" data-component-name>
  <!-- HTML structure -->
</div>

<script>
  // Progressive enhancement JavaScript (optional)
</script>
```

### Parameter Handling

**Good:**
```liquid
{%- assign show_icon = include.show_icon | default: true -%}
{%- assign level = include.level | default: page.difficulty | default: "beginner" | downcase -%}
```

**Bad:**
```liquid
{% if include.show_icon %}  <!-- Doesn't handle undefined -->
```

### Component Naming

Follow BEM (Block Element Modifier) methodology:

```scss
.component-name { }              // Block
.component-name__element { }     // Element
.component-name--modifier { }    // Modifier
.component-name.is-state { }     // State
```

**Example:**
```scss
.social-share { }
.social-share__button { }
.social-share__button--twitter { }
.social-share__button.is-copied { }
```

---

## Styling System

### CSS Variables

All components use CSS variables for theming:

```scss
:root {
  // Colors
  --color-accent: #3277f6;
  --color-background: #ffffff;
  --color-background-secondary: #f5f7ff;
  --color-text-primary: #0b1d3d;
  --color-text-secondary: #5a6c8a;
  --color-text-tertiary: #8995a8;
  --color-border: #e0e4ed;

  // Spacing (if needed)
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;
  --spacing-xl: 2rem;
}
```

### Creating Color Variants

**Example: Add a "pro" variant to difficulty badges**

```scss
.difficulty-badge--pro {
  background-color: #EDE9FE;
  color: #5B21B6;
  border-color: #C4B5FD;

  &:hover {
    background-color: #DDD6FE;
  }

  .difficulty-badge__icon {
    // Custom icon color if needed
  }
}
```

### Responsive Design Pattern

Use mobile-first approach:

```scss
.component {
  // Mobile styles (default)
  flex-direction: column;
  padding: 1rem;

  // Tablet and up
  @media (min-width: 768px) {
    flex-direction: row;
    padding: 1.5rem;
  }

  // Desktop and up
  @media (min-width: 1024px) {
    padding: 2rem;
  }
}
```

### Dark Mode Support

```scss
.component {
  background-color: var(--color-background);
  color: var(--color-text-primary);
}

// Dark mode handled automatically via CSS variables in _theme.scss
body.dark-mode {
  --color-background: #1a1a2e;
  --color-text-primary: #edf2f7;
}
```

---

## JavaScript Functionality

### Event Handling Pattern

**Enhanced TOC Example:**

```javascript
(function() {
  'use strict';

  document.addEventListener('DOMContentLoaded', function() {
    const toc = document.querySelector('[data-toc-enhanced]');
    if (!toc) return; // Early exit if component not present

    // Get elements
    const links = toc.querySelectorAll('a');

    // Add event listeners
    links.forEach(link => {
      link.addEventListener('click', handleClick);
    });

    // Event handler
    function handleClick(e) {
      // Handle event
    }

    // Cleanup (if needed)
    window.addEventListener('beforeunload', function() {
      links.forEach(link => {
        link.removeEventListener('click', handleClick);
      });
    });
  });
})();
```

### Performance Best Practices

#### 1. Throttle Scroll Events

```javascript
let scrollTimeout;
function throttledScroll() {
  if (scrollTimeout) {
    window.cancelAnimationFrame(scrollTimeout);
  }
  scrollTimeout = window.requestAnimationFrame(function() {
    updateScrollPosition();
  });
}

window.addEventListener('scroll', throttledScroll, { passive: true });
```

#### 2. Use Event Delegation

**Good:**
```javascript
document.addEventListener('click', function(e) {
  if (e.target.matches('.social-share__button')) {
    handleShare(e.target);
  }
});
```

**Bad:**
```javascript
document.querySelectorAll('.social-share__button').forEach(button => {
  button.addEventListener('click', handleShare);
});
```

#### 3. Cache DOM Queries

```javascript
const toc = document.querySelector('[data-toc-enhanced]');
const tocLinks = toc.querySelectorAll('a'); // Query once
const progressBar = toc.querySelector('[data-toc-progress]');
```

---

## Creating Custom Variants

### Example: Compact Social Share

**1. Add parameter handling:**

```liquid
{%- assign variant = include.variant | default: "default" -%}

<div class="social-share social-share--{{ variant }}">
  <!-- content -->
</div>
```

**2. Add styles:**

```scss
.social-share--compact {
  padding: 1rem;

  .social-share__button {
    padding: 0.375rem 0.75rem;
    font-size: 0.8125rem;

    .social-share__label {
      display: none; // Icon only
    }
  }
}
```

**3. Usage:**

```liquid
{% include components/social-share.html variant="compact" %}
```

---

## Integration Patterns

### Adding to New Layouts

**1. Include the component:**

```liquid
<!-- _layouts/custom.html -->
{% include components/breadcrumbs.html %}

<article>
  {{ content }}
</article>

{% include components/author-bio.html compact=true %}
```

**2. Add required CSS:**

Ensure `_sass/_phase1-enhancements.scss` is imported in your main stylesheet.

**3. Test responsive behavior:**

```bash
# Use browser DevTools responsive mode
# Test breakpoints: 320px, 768px, 1024px, 1440px
```

### Conditional Display

```liquid
{% if page.show_author_bio != false %}
  {% include components/author-bio.html %}
{% endif %}

{% if page.collection == "posts" %}
  {% include components/breadcrumbs.html %}
{% endif %}
```

### Multiple Instances

```liquid
<!-- Top of page -->
{% include components/difficulty-badge.html level=page.difficulty %}

<!-- Sidebar -->
{% include components/difficulty-badge.html
   level=page.difficulty
   show_description=true %}
```

---

## Performance Optimization

### CSS Optimization

#### 1. Minimize Specificity

**Good:**
```scss
.social-share__button { }
```

**Bad:**
```scss
.post-wrapper .social-share div.social-share__buttons a.social-share__button { }
```

#### 2. Use `will-change` Sparingly

```scss
.enhanced-toc {
  // Only when actually sticky
  &.is-sticky {
    will-change: transform;
  }
}
```

#### 3. Avoid Expensive Properties

```scss
// Prefer transform over top/left
.component {
  transform: translateY(-2px); // ✓ GPU-accelerated
  // top: -2px; // ✗ Triggers layout
}
```

### JavaScript Optimization

#### 1. Debounce Resize Events

```javascript
let resizeTimeout;
window.addEventListener('resize', function() {
  clearTimeout(resizeTimeout);
  resizeTimeout = setTimeout(handleResize, 250);
}, { passive: true });
```

#### 2. Intersection Observer for Visibility

```javascript
const observer = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      // Element is visible
      loadComponent(entry.target);
    }
  });
});

observer.observe(document.querySelector('.component'));
```

#### 3. Lazy Load Non-Critical Components

```javascript
if ('IntersectionObserver' in window) {
  // Use modern API
} else {
  // Fallback for older browsers
  loadComponentImmediately();
}
```

---

## Testing

### Manual Testing Checklist

#### Social Sharing
- [ ] All platform buttons visible
- [ ] Share URLs properly encoded
- [ ] Copy button works
- [ ] Mobile layout correct
- [ ] Keyboard navigation works

#### Breadcrumbs
- [ ] Correct path displayed
- [ ] Links navigate properly
- [ ] Schema.org markup valid
- [ ] Responsive on mobile

#### Author Bio
- [ ] Avatar displays (or initials fallback)
- [ ] All social links work
- [ ] Compact mode renders correctly
- [ ] Research areas display

#### Enhanced TOC
- [ ] Sticky positioning works
- [ ] Active section highlights
- [ ] Progress bar updates
- [ ] Collapsible toggle works
- [ ] Smooth scroll functions

#### Difficulty Badges
- [ ] All levels display correct colors
- [ ] Icons render properly
- [ ] Tooltips show on hover
- [ ] Accessibility labels present

### Automated Testing

Add to `tests/js/phase1.test.js`:

```javascript
import { describe, it, expect } from 'vitest';

describe('Social Share', () => {
  it('generates correct Twitter share URL', () => {
    const url = 'https://example.com/post';
    const title = 'Test Post';
    const twitterUrl = `https://twitter.com/intent/tweet?url=${encodeURIComponent(url)}&text=${encodeURIComponent(title)}`;

    expect(twitterUrl).toContain('twitter.com/intent/tweet');
  });
});

describe('Difficulty Badge', () => {
  it('normalizes difficulty levels', () => {
    const levels = ['easy', 'beginner', 'introductory'];
    levels.forEach(level => {
      expect(normalizeDifficulty(level)).toBe('beginner');
    });
  });
});
```

### Accessibility Testing

```javascript
// Use axe-core for automated a11y testing
import { injectAxe, checkA11y } from 'axe-playwright';

test('components are accessible', async ({ page }) => {
  await page.goto('/post-with-all-components');
  await injectAxe(page);
  await checkA11y(page);
});
```

### Visual Regression Testing

```javascript
// Playwright screenshot comparison
test('social share appears correctly', async ({ page }) => {
  await page.goto('/post');
  await page.screenshot({
    path: 'screenshots/social-share.png',
    fullPage: false
  });
});
```

---

## Advanced Customization

### Creating a New Component

**1. Create the template:**

```liquid
<!-- _includes/components/reading-time.html -->
{%- comment -%}
Reading time estimator with progress tracking
Parameters:
  - content: Content to analyze
  - wpm: Words per minute (default: 200)
{%- endcomment -%}

{%- assign words = include.content | strip_html | number_of_words -%}
{%- assign wpm = include.wpm | default: 200 -%}
{%- assign minutes = words | divided_by: wpm -%}

<div class="reading-time" data-reading-time="{{ minutes }}">
  <svg class="reading-time__icon"><!-- clock icon --></svg>
  <span class="reading-time__text">{{ minutes }} min read</span>
</div>
```

**2. Add styles:**

```scss
// In _sass/_phase1-enhancements.scss
.reading-time {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: var(--color-text-secondary);

  &__icon {
    width: 16px;
    height: 16px;
  }
}
```

**3. Integrate:**

```liquid
<!-- In _layouts/post.html -->
{% include components/reading-time.html content=content %}
```

### Extending Existing Components

**Example: Add WhatsApp to Social Share**

```liquid
<!-- In _includes/components/social-share.html, add: -->

{%- comment -%} WhatsApp Share {%- endcomment -%}
<a href="https://wa.me/?text={{ share_title | uri_escape }}%20{{ share_url | uri_escape }}"
   class="social-share__button social-share__button--whatsapp"
   target="_blank"
   rel="noopener noreferrer"
   aria-label="Share on WhatsApp"
   data-share-platform="whatsapp">
  <svg class="social-share__icon" xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
    <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L0 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/>
  </svg>
  <span class="social-share__label">WhatsApp</span>
</a>
```

Add styling:

```scss
.social-share__button--whatsapp:hover,
.social-share__button--whatsapp:focus {
  background-color: #25D366;
  border-color: #25D366;
}
```

---

## Debugging

### Common Issues

#### Component Not Rendering

**Check:**
1. Include path is correct
2. Component file exists in `_includes/components/`
3. No Liquid syntax errors
4. Required parameters are provided

**Debug:**
```liquid
{% comment %}Debug: Check if component exists{% endcomment %}
{% capture component_exists %}
  {% include components/component-name.html %}
{% endcapture %}
{{ component_exists | strip }}
```

#### Styles Not Applied

**Check:**
1. `_phase1-enhancements.scss` imported in `_theme.scss`
2. CSS built successfully (`jekyll build`)
3. Browser cache cleared
4. No CSS syntax errors

**Debug:**
```bash
# Build with trace
bundle exec jekyll build --trace

# Check compiled CSS
cat _site/assets/css/main.css | grep "social-share"
```

#### JavaScript Not Working

**Check:**
1. Scripts loaded in correct order
2. `DOMContentLoaded` event used
3. No console errors
4. Element selectors are correct

**Debug:**
```javascript
console.log('TOC element:', document.querySelector('[data-toc-enhanced]'));
console.log('TOC links:', document.querySelectorAll('[data-toc-enhanced] a'));
```

---

## Best Practices Summary

### ✅ Do

- Use semantic HTML
- Follow BEM naming
- Make components accessible
- Use CSS variables for theming
- Provide sensible defaults
- Document parameters
- Test on multiple devices
- Optimize for performance
- Use progressive enhancement

### ❌ Don't

- Use inline styles
- Hard-code colors/sizes
- Ignore accessibility
- Create tight coupling
- Forget mobile users
- Skip documentation
- Assume JavaScript is available
- Use heavy animations
- Violate naming conventions

---

## Resources

### Tools

- **SCSS Linter**: [stylelint](https://stylelint.io/)
- **Accessibility**: [axe DevTools](https://www.deque.com/axe/devtools/)
- **Performance**: [Lighthouse](https://developers.google.com/web/tools/lighthouse)

### Documentation

- [Jekyll Includes](https://jekyllrb.com/docs/includes/)
- [Liquid Template Language](https://shopify.github.io/liquid/)
- [BEM Methodology](http://getbem.com/)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)

---

**Last Updated:** 2025-11-21
**Version:** 1.0.0 (Phase 1)
