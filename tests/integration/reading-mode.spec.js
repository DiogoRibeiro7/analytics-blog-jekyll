import { expect, test } from '@playwright/test';

/**
 * Reading mode and print (#248).
 *
 * Reading mode is a class on the body that hides the site's chrome and the
 * panels around the article; the button is reachable from the keyboard, its
 * state is in aria-pressed, Escape leaves the mode, and the article is not
 * duplicated. Print emulation checks the stylesheet: the chrome goes, the
 * page is black on white even in dark mode, and code loses its background.
 */

const baseUrl = process.env.PLAYWRIGHT_BASE_URL;
const longPost = '/2024/04/05/sql-optimization-guide/';
const mathPost = '/2024/04/08/mathematical-proof-numbered-equations/';

test.describe('Reading mode', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  test('the keyboard turns it on, Escape turns it off, and the article stays single', async ({ page }) => {
    await page.goto(new URL(longPost, baseUrl).href, { waitUntil: 'load' });
    const toggle = page.locator('[data-reading-mode-toggle]');

    await expect(toggle).toHaveAttribute('aria-pressed', 'false');
    await expect(page.locator('.site-header')).toBeVisible();

    await toggle.focus();
    await page.keyboard.press('Enter');

    await expect(page.locator('body')).toHaveClass(/reading-mode/);
    await expect(toggle).toHaveAttribute('aria-pressed', 'true');
    await expect(toggle).toHaveText(/Exit reading mode/);
    await expect(page.locator('.site-header')).toBeHidden();
    await expect(page.locator('.social-share')).toBeHidden();
    await expect(page.locator('.post-content')).toBeVisible();
    await expect(page.locator('.enhanced-toc')).toBeVisible();
    expect(await page.locator('.post-content').count()).toBe(1);

    await page.keyboard.press('Escape');

    await expect(page.locator('body')).not.toHaveClass(/reading-mode/);
    await expect(toggle).toHaveAttribute('aria-pressed', 'false');
    await expect(toggle).toBeFocused();
    await expect(page.locator('.site-header')).toBeVisible();
  });

  test('Escape leaves note editing, composition and handled keys to their controls', async ({ page }) => {
    await page.goto(new URL(longPost, baseUrl).href);
    await page.locator('[data-reading-mode-toggle]').click();
    await page.evaluate(() => {
      const note = document.createElement('textarea');
      document.querySelector('.post-content').append(note);
      note.focus();
      note.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true }));
      note.remove();
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', isComposing: true }));
      const handled = new KeyboardEvent('keydown', { key: 'Escape', cancelable: true });
      handled.preventDefault();
      document.dispatchEvent(handled);
    });
    await expect(page.locator('body')).toHaveClass(/reading-mode/);
    await page.keyboard.press('Escape');
    await expect(page.locator('body')).not.toHaveClass(/reading-mode/);
  });

  test('the choice is not remembered across pages by default', async ({ page }) => {
    await page.goto(new URL(longPost, baseUrl).href, { waitUntil: 'load' });
    await page.locator('[data-reading-mode-toggle]').click();
    await expect(page.locator('body')).toHaveClass(/reading-mode/);

    await page.goto(new URL(mathPost, baseUrl).href, { waitUntil: 'load' });
    await expect(page.locator('body')).not.toHaveClass(/reading-mode/);
  });
});

test.describe('Print', () => {
  test.skip(!baseUrl, 'PLAYWRIGHT_BASE_URL must be provided to run integration tests.');

  for (const theme of ['light', 'dark']) {
    test(`a post with code and tables prints black on white from ${theme} mode`, async ({ page }) => {
      await page.addInitScript((mode) => {
        window.localStorage.setItem('datalog-color-mode', mode);
      }, theme);
      await page.goto(new URL(longPost, baseUrl).href, { waitUntil: 'load' });
      await expect(page.locator('body')).toHaveAttribute('data-theme', theme);
      await page.emulateMedia({ media: 'print' });

      const styles = await page.evaluate(() => {
        const style = (selector) => getComputedStyle(document.querySelector(selector));
        return {
          header: style('.site-header').display,
          footer: style('.site-footer').display,
          share: style('.social-share').display,
          toggle: style('.reading-mode-bar').display,
          body: style('body').backgroundColor,
          text: style('.post-content p').color,
          pre: style('.post-content pre').backgroundColor,
          preWrap: style('.post-content pre').whiteSpace,
          source: style('.post-print-source').display,
        };
      });

      expect(styles.header).toBe('none');
      expect(styles.footer).toBe('none');
      expect(styles.share).toBe('none');
      expect(styles.toggle).toBe('none');
      expect(styles.body).toBe('rgb(255, 255, 255)');
      expect(styles.text).toBe('rgb(0, 0, 0)');
      expect(styles.pre).toBe('rgb(255, 255, 255)');
      expect(styles.preWrap).toBe('pre-wrap');
      expect(styles.source).toBe('block');
      await expect(page.locator('.post-print-source')).toContainText(longPost);
    });
  }

  test('display equations print whole and unclipped', async ({ page }) => {
    await page.goto(new URL(mathPost, baseUrl).href, { waitUntil: 'load' });
    await expect(page.locator('mjx-container[display="true"]').first()).toBeAttached();
    await page.emulateMedia({ media: 'print' });

    const equation = await page.evaluate(() => {
      const style = getComputedStyle(document.querySelector('mjx-container[display="true"]'));
      return { overflow: style.overflowX, breakInside: style.breakInside };
    });

    expect(equation.overflow).toBe('visible');
    expect(equation.breakInside).toBe('avoid');
  });
});
