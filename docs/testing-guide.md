# Testing Guide

This guide covers all aspects of testing in the DataLog Jekyll Theme, from running tests to writing new ones.

## Table of Contents

- [Overview](#overview)
- [Test Types](#test-types)
- [Running Tests](#running-tests)
- [Writing Tests](#writing-tests)
- [Coverage Requirements](#coverage-requirements)
- [Continuous Integration](#continuous-integration)
- [Troubleshooting](#troubleshooting)

## Overview

DataLog uses a multi-layered testing strategy:

| Test Type | Framework | Purpose | Run Time |
|-----------|-----------|---------|----------|
| **Unit Tests** | Vitest | Test JavaScript modules in isolation | ~4s |
| **Integration Tests** | Playwright | Test interactions between components | ~30s |
| **Visual Tests** | Percy + Playwright | Detect visual regressions | ~45s |
| **Ruby Tests** | Minitest | Test Jekyll plugins and generators | ~10s |
| **E2E Tests** | Playwright | Test complete user workflows | ~60s |

### Test Coverage Goals

- **Unit Tests**: 80% statement coverage
- **Integration Tests**: All critical user paths
- **Visual Tests**: All major layouts and components
- **Ruby Tests**: All custom plugins

## Test Types

### 1. Unit Tests (JavaScript/Vitest)

**Location**: `tests/js/*.test.js`

**What They Test**:
- Individual JavaScript functions and modules
- Search engine logic
- Math rendering utilities
- Theme switching
- Visualization loaders

**Example**:
```javascript
// tests/js/search.test.js
import { describe, it, expect } from 'vitest';
import { debounce } from '../assets/js/search.js';

describe('Search utilities', () => {
  it('debounce delays function execution', async () => {
    let callCount = 0;
    const fn = debounce(() => callCount++, 100);

    fn();
    fn();
    fn();

    expect(callCount).toBe(0); // Not called yet

    await new Promise(resolve => setTimeout(resolve, 150));

    expect(callCount).toBe(1); // Called once after delay
  });
});
```

### 2. Integration Tests (Playwright)

**Location**: `tests/integration/*.spec.js`

**What They Test**:
- Navigation between pages
- Search workflow
- Visualization loading
- User interactions

**Example**:
```javascript
// tests/integration/navigation.spec.js
import { test, expect } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

test.describe('Site Navigation', () => {
  test('should navigate from home to about page', async ({ page }) => {
    await page.goto(baseUrl);
    await page.click('a[href="/about/"]');
    await expect(page).toHaveURL(`${baseUrl}/about/`);
    await expect(page.locator('h1')).toContainText('About');
  });
});
```

### 3. Visual Regression Tests (Percy)

**Location**: `tests/visual/*.spec.js`

**What They Test**:
- Layout consistency
- Dark mode variations
- Responsive breakpoints
- Component rendering

**Example**:
```javascript
// tests/visual/homepage.spec.js
import { test } from '@playwright/test';
import { percySnapshot } from '@percy/playwright';

test('homepage appears correctly', async ({ page }) => {
  await page.goto(process.env.PLAYWRIGHT_BASE_URL);
  await percySnapshot(page, 'Homepage');
});
```

### 4. Ruby Tests (Minitest)

**Location**: `tests/test_*.rb`

**What They Test**:
- Jekyll plugins
- Liquid filters
- Custom generators
- Build process

**Example**:
```ruby
# tests/test_filters.rb
require 'minitest/autorun'
require_relative '../_plugins/custom_filters'

class TestCustomFilters < Minitest::Test
  include CustomFilters

  def test_reading_time
    text = "word " * 250
    assert_equal "1 min read", reading_time(text)
  end
end
```

## Running Tests

### Quick Start

```bash
# Run all unit tests
npm test

# Run with coverage
npm run test:coverage

# Run integration tests
npm run test:integration

# Run visual tests (requires Percy token)
npm run test:visual:percy
```

### Detailed Commands

#### Unit Tests

```bash
# Run once
npm run test

# Watch mode (reruns on file changes)
npx vitest

# Run specific test file
npx vitest tests/js/search.test.js

# Run tests matching pattern
npx vitest --grep "search"

# Update snapshots
npx vitest -u
```

#### Coverage

```bash
# Generate coverage report
npm run test:coverage

# View HTML report
open coverage/index.html  # macOS
xdg-open coverage/index.html  # Linux
start coverage/index.html  # Windows
```

#### Integration Tests

```bash
# Run all integration tests
npm run test:integration

# Run specific test file
PLAYWRIGHT_BASE_URL=http://localhost:4000 npx playwright test tests/integration/navigation.spec.js

# Debug mode
PLAYWRIGHT_BASE_URL=http://localhost:4000 npx playwright test --debug

# Headed mode (see browser)
PLAYWRIGHT_BASE_URL=http://localhost:4000 npx playwright test --headed
```

#### Visual Tests

```bash
# With Percy (uploads to cloud)
PERCY_TOKEN=your_token npm run test:visual:percy

# Local only (no uploads)
npm run test:visual
```

#### Ruby Tests

```bash
# Run all Ruby tests
bundle exec ruby -Itests -e "Dir['tests/test_*.rb'].each { |f| require_relative f }"

# Run specific test
bundle exec ruby tests/test_filters.rb

# Run CI verification
bundle exec rake ci:verify
```

## Writing Tests

### Unit Test Best Practices

1. **Test one thing per test**:
   ```javascript
   // ✅ Good
   it('debounce delays function execution', () => {
     // Test only debounce behavior
   });

   // ❌ Bad
   it('search works', () => {
     // Tests debounce, filtering, rendering, etc.
   });
   ```

2. **Use descriptive names**:
   ```javascript
   // ✅ Good
   it('returns empty array when no results match query', () => {});

   // ❌ Bad
   it('works correctly', () => {});
   ```

3. **Arrange, Act, Assert**:
   ```javascript
   it('filters results by category', () => {
     // Arrange
     const results = [
       { title: 'Post 1', category: 'tech' },
       { title: 'Post 2', category: 'design' }
     ];

     // Act
     const filtered = filterByCategory(results, 'tech');

     // Assert
     expect(filtered).toHaveLength(1);
     expect(filtered[0].title).toBe('Post 1');
   });
   ```

4. **Mock external dependencies**:
   ```javascript
   import { vi } from 'vitest';

   it('calls API endpoint', async () => {
     const mockFetch = vi.fn().mockResolvedValue({ ok: true });
     global.fetch = mockFetch;

     await fetchData('/api/posts');

     expect(mockFetch).toHaveBeenCalledWith('/api/posts');
   });
   ```

### Integration Test Best Practices

1. **Test user workflows, not implementation**:
   ```javascript
   // ✅ Good
   test('user can search and filter results', async ({ page }) => {
     await page.goto(baseUrl);
     await page.fill('[data-search-input]', 'jekyll');
     await page.selectOption('[data-filter-category]', 'tech');
     await expect(page.locator('.search-result')).toHaveCount(3);
   });

   // ❌ Bad
   test('SearchEngine.filter() is called', async ({ page }) => {
     // Testing implementation details
   });
   ```

2. **Use data attributes for selectors**:
   ```javascript
   // ✅ Good
   await page.click('[data-nav-toggle]');

   // ❌ Bad (fragile)
   await page.click('.header > nav > button.menu-toggle');
   ```

3. **Wait for elements properly**:
   ```javascript
   // ✅ Good
   await page.waitForSelector('[data-search-results]');
   await expect(page.locator('.result')).toHaveCount(5);

   // ❌ Bad
   await page.waitForTimeout(1000); // Arbitrary wait
   ```

### Visual Test Best Practices

1. **Name snapshots descriptively**:
   ```javascript
   await percySnapshot(page, 'Homepage - Desktop - Light Mode');
   await percySnapshot(page, 'Search Results - Mobile - Dark Mode');
   ```

2. **Test critical breakpoints**:
   ```javascript
   const viewports = [
     { width: 375, name: 'Mobile' },
     { width: 768, name: 'Tablet' },
     { width: 1920, name: 'Desktop' }
   ];

   for (const viewport of viewports) {
     await page.setViewportSize(viewport);
     await percySnapshot(page, `Homepage - ${viewport.name}`);
   }
   ```

3. **Wait for dynamic content**:
   ```javascript
   await page.goto(url);
   await page.waitForLoadState('networkidle');
   await page.waitForSelector('[data-ready]');
   await percySnapshot(page, 'Page Name');
   ```

## Coverage Requirements

### Current Thresholds

From `vitest.config.js`:

```javascript
thresholds: {
  statements: 20,
  branches: 15,
  functions: 20,
  lines: 20
}
```

### Goal: 80% Coverage

We're working towards:
- **Statements**: 80%
- **Branches**: 60%
- **Functions**: 80%
- **Lines**: 80%

### How to Improve Coverage

1. **Identify uncovered code**:
   ```bash
   npm run test:coverage
   open coverage/index.html
   ```

2. **Write tests for red/yellow lines**:
   - Red = Not executed
   - Yellow = Partial branch coverage

3. **Focus on critical paths first**:
   - Search functionality
   - Navigation
   - User authentication (if any)
   - Data processing

4. **Don't test framework code**:
   - Test your code, not Jekyll or libraries

## Continuous Integration

### GitHub Actions

Tests run automatically on:
- **Push to main**: Full test suite
- **Pull requests**: Full test suite + visual regression
- **Scheduled**: Security audits daily

### Test Matrix

Unit tests run on multiple Node.js versions:
- Node 18 (LTS)
- Node 20 (LTS)
- Node 22 (Current)

### Workflow Files

- `.github/workflows/test.yml` - Main test suite
- `.github/workflows/dependency-review.yml` - Security audits
- `.github/workflows/codeql.yml` - Code security scanning
- `.github/workflows/percy.yml` - Visual regression

### Required Status Checks

Before merging:
- ✅ All unit tests pass
- ✅ Jekyll build succeeds
- ✅ No security vulnerabilities
- ✅ Code coverage meets threshold

## Troubleshooting

### Common Issues

#### "PLAYWRIGHT_BASE_URL is not set"

**Problem**: Integration tests fail with missing URL.

**Solution**:
```bash
# Option 1: Use helper script (recommended)
npm run test:integration

# Option 2: Set environment variable
export PLAYWRIGHT_BASE_URL=http://localhost:4000
npx playwright test
```

#### "Cannot find module" errors

**Problem**: Dependencies not installed.

**Solution**:
```bash
npm ci
bundle install
```

#### Tests timeout

**Problem**: Site not building or server not responding.

**Solution**:
```bash
# Build site first
bundle exec jekyll build

# Start server
bundle exec jekyll serve &

# Run tests
PLAYWRIGHT_BASE_URL=http://localhost:4000 npx playwright test
```

#### Coverage threshold not met

**Problem**: Coverage below threshold.

**Solution**:
1. Check coverage report: `open coverage/index.html`
2. Write tests for uncovered code
3. Or adjust thresholds temporarily in `vitest.config.js`

#### Percy tests skip

**Problem**: "Percy token not configured"

**Expected**: Visual tests skip without token (this is normal).

**To enable**:
```bash
# Sign up at percy.io
# Get project token
export PERCY_TOKEN=your_token
npm run test:visual:percy
```

### Debug Mode

#### Vitest Debug

```bash
# Run in watch mode
npx vitest

# Run with debug output
DEBUG=* npx vitest
```

#### Playwright Debug

```bash
# Debug mode with inspector
PLAYWRIGHT_BASE_URL=http://localhost:4000 npx playwright test --debug

# Headed mode
PLAYWRIGHT_BASE_URL=http://localhost:4000 npx playwright test --headed

# Trace viewer
npx playwright show-trace trace.zip
```

## Best Practices Summary

### DO

✅ Write tests before fixing bugs
✅ Test behavior, not implementation
✅ Use descriptive test names
✅ Keep tests fast and focused
✅ Mock external dependencies
✅ Use data attributes for selectors
✅ Wait for elements properly
✅ Run tests before committing (pre-commit hook does this)

### DON'T

❌ Test framework code
❌ Use arbitrary timeouts
❌ Test implementation details
❌ Write flaky tests
❌ Skip failing tests
❌ Commit without running tests
❌ Ignore coverage reports

## Resources

- [Vitest Documentation](https://vitest.dev/)
- [Playwright Documentation](https://playwright.dev/)
- [Percy Documentation](https://docs.percy.io/)
- [Minitest Documentation](https://github.com/seattlerb/minitest)
- [Testing Best Practices](https://kentcdodds.com/blog/common-mistakes-with-react-testing-library)

## Contributing

Found a bug? Want to add tests?

1. Check [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines
2. Write tests that demonstrate the bug
3. Fix the bug
4. Ensure all tests pass
5. Submit a pull request

---

**Questions?** Open an [issue](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/issues) or [discussion](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/discussions).
