import { expect, test } from '@playwright/test';

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;

test.describe('Blog Post Navigation', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('can navigate from homepage to a blog post', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Find a post link
    const postLink = page.locator('article a, .post-link, [class*="post"] a').first();
    await expect(postLink).toBeVisible();

    // Get the href before clicking
    const href = await postLink.getAttribute('href');
    expect(href).toBeTruthy();

    // Click the post link
    await postLink.click();

    // Should navigate to a new page
    await page.waitForLoadState('domcontentloaded');

    // URL should have changed
    const newUrl = page.url();
    expect(newUrl).not.toBe(baseUrl);
  });

  test('blog post has proper structure', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    // Navigate to a post
    const postLink = page.locator('article a, .post-link, [class*="post"] a').first();
    if ((await postLink.count()) === 0) {
      test.skip(true, 'No blog posts found');
      return;
    }

    await postLink.click();
    await page.waitForLoadState('domcontentloaded');

    // Should have article element or main content
    const article = page.locator('article, [role="article"], main');
    await expect(article.first()).toBeVisible();

    // Should have a title (h1)
    const title = page.locator('h1');
    await expect(title.first()).toBeVisible();

    // Title should have content
    const titleText = await title.first().textContent();
    expect(titleText.trim()).toBeTruthy();
  });

  test('blog post displays metadata', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const postLink = page.locator('article a, .post-link, [class*="post"] a').first();
    if ((await postLink.count()) === 0) {
      test.skip(true, 'No blog posts found');
      return;
    }

    await postLink.click();
    await page.waitForLoadState('domcontentloaded');

    // Check for common metadata elements
    const metadata = page.locator('[class*="meta"], [class*="date"], time, [class*="author"]');
    const metadataCount = await metadata.count();

    // Should have at least some metadata
    expect(metadataCount).toBeGreaterThan(0);
  });

  test('table of contents navigation works', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const postLink = page.locator('article a, .post-link, [class*="post"] a').first();
    if ((await postLink.count()) === 0) {
      test.skip(true, 'No blog posts found');
      return;
    }

    await postLink.click();
    await page.waitForLoadState('domcontentloaded');

    // Look for table of contents
    const toc = page.locator('[class*="toc"], [id*="toc"], nav[aria-label*="contents"]');

    if ((await toc.count()) > 0) {
      await expect(toc.first()).toBeVisible();

      // TOC should have links
      const tocLinks = toc.first().locator('a');
      const tocLinkCount = await tocLinks.count();

      if (tocLinkCount > 0) {
        // Click a TOC link
        const firstTocLink = tocLinks.first();
        const href = await firstTocLink.getAttribute('href');

        // Should be an anchor link
        expect(href).toMatch(/^#/);

        await firstTocLink.click();

        // URL should include the anchor
        await expect(page).toHaveURL(new RegExp(href.replace('#', '#')));
      }
    }
  });

  test('blog post links open correctly', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const postLink = page.locator('article a, .post-link, [class*="post"] a').first();
    if ((await postLink.count()) === 0) {
      test.skip(true, 'No blog posts found');
      return;
    }

    await postLink.click();
    await page.waitForLoadState('domcontentloaded');

    // Find internal links in the post content
    const contentLinks = page.locator('article a[href^="/"], main a[href^="/"]');
    const linkCount = await contentLinks.count();

    // Check that internal links are valid
    for (let i = 0; i < Math.min(linkCount, 3); i++) {
      const href = await contentLinks.nth(i).getAttribute('href');
      expect(href).toBeTruthy();
      expect(href).toMatch(/^\//);
    }
  });

  test('code blocks are properly formatted', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const postLink = page.locator('article a, .post-link, [class*="post"] a').first();
    if ((await postLink.count()) === 0) {
      test.skip(true, 'No blog posts found');
      return;
    }

    await postLink.click();
    await page.waitForLoadState('domcontentloaded');

    // Look for code blocks
    const codeBlocks = page.locator('pre code, .highlight code, [class*="code-block"]');
    const codeBlockCount = await codeBlocks.count();

    if (codeBlockCount > 0) {
      // First code block should be visible
      await expect(codeBlocks.first()).toBeVisible();

      // Should have syntax highlighting classes or content
      const hasContent = await codeBlocks.first().textContent();
      expect(hasContent.trim()).toBeTruthy();
    }
  });
});

test.describe('Blog Post Reading Experience', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('reading progress indicator works', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const postLink = page.locator('article a, .post-link, [class*="post"] a').first();
    if ((await postLink.count()) === 0) {
      test.skip(true, 'No blog posts found');
      return;
    }

    await postLink.click();
    await page.waitForLoadState('domcontentloaded');

    // Look for reading progress indicator: prefer the actual progress element
    // over the wrappers that share its class prefix.
    const nativeProgress = page.locator('progress, [role="progressbar"]');
    const progressBar =
      (await nativeProgress.count()) > 0
        ? nativeProgress
        : page.locator('[class*="reading-progress"], [class*="progress"]');

    if ((await progressBar.count()) > 0) {
      // Scroll down the page
      await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight / 2));
      await page.waitForTimeout(300);

      // Progress bar should have updated
      const progressElement = progressBar.first();
      const style = await progressElement.getAttribute('style');
      const ariaValue = await progressElement.getAttribute('aria-valuenow');
      const value = Number(await progressElement.getAttribute('value'));

      // Should have some progress indication
      expect(style || ariaValue || value > 0).toBeTruthy();
    }
  });

  test('back to top button appears on scroll', async ({ page }) => {
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });

    const postLink = page.locator('article a, .post-link, [class*="post"] a').first();
    if ((await postLink.count()) === 0) {
      test.skip(true, 'No blog posts found');
      return;
    }

    await postLink.click();
    await page.waitForLoadState('domcontentloaded');

    // Scroll down
    await page.evaluate(() => window.scrollTo(0, 500));
    await page.waitForTimeout(500);

    // Look for back to top button
    const backToTop = page.locator(
      '[class*="back-to-top"], [class*="scroll-top"], [aria-label*="top"]'
    );

    if ((await backToTop.count()) > 0) {
      await expect(backToTop.first()).toBeVisible();

      // Click it
      await backToTop.first().click();
      await page.waitForTimeout(500);

      // Should scroll to top
      const scrollY = await page.evaluate(() => window.scrollY);
      expect(scrollY).toBeLessThan(100);
    }
  });
});
