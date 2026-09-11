export const viewports = [
  { width: 375, height: 667, name: 'mobile' },
  { width: 768, height: 1024, name: 'tablet' },
  { width: 1920, height: 1080, name: 'desktop' }
];

/**
 * Placeholder for a snapshot service. The visual specs assert page structure
 * with Playwright; no image comparison is wired up. Hook a service in here if
 * one is adopted again.
 */
export async function captureSnapshot(_page, _name, _options = {}) {
  return;
}

export async function waitForFonts(page) {
  await page.evaluate(async () => {
    if (!document.fonts || document.fonts.status === 'loaded') {
      return;
    }

    try {
      await document.fonts.ready;
    } catch (error) {
      console.warn('Font loading wait failed in visual test', error);
    }
  });
}

export async function waitForMath(page) {
  const hasMath = await page.evaluate(() => {
    return Boolean(
      document.querySelector('[data-math-alt], .mjx-container, .katex, script[type^="math/"]')
    );
  });

  if (!hasMath) {
    return;
  }

  await page.evaluate(async () => {
    const mathJax = window.MathJax;
    if (mathJax?.startup?.promise) {
      try {
        await mathJax.startup.promise;
      } catch (error) {
        console.warn('MathJax startup promise rejected in visual test', error);
      }
    } else if (mathJax?.typesetPromise) {
      try {
        await mathJax.typesetPromise();
      } catch (error) {
        console.warn('MathJax typeset promise rejected in visual test', error);
      }
    }
  });

  try {
    await page.waitForSelector('.mjx-container, .katex', { timeout: 15000 });
  } catch (error) {
    // Allow screenshots to proceed even if math never renders to avoid hanging the suite
    console.warn('Timed out waiting for math rendering in visual test');
  }
}

export async function waitForViz(page) {
  const hasViz = await page.evaluate(() => Boolean(document.querySelector('.viz-block')));

  if (!hasViz) {
    return;
  }

  await page.waitForFunction(
    () => {
      return Array.from(document.querySelectorAll('.viz-block')).every((block) => {
        if (block.classList.contains('is-loading')) {
          return false;
        }

        if (block.querySelector('canvas, svg, iframe, table, [data-observablehq]')) {
          return true;
        }

        return false;
      });
    },
    undefined,
    { polling: 250, timeout: 15000 }
  ).catch(() => {
    console.warn('Visualization readiness check timed out in visual test');
  });
}

export async function hideAnimations(page) {
  const css = `
      *, *::before, *::after {
        transition: none !important;
        animation: none !important;
      }
    `;
  await page.evaluate((styleContent) => {
    const meta = document.querySelector('meta[http-equiv="Content-Security-Policy"]');
    let nonce = '';
    if (meta) {
      const match = meta.content.match(/'nonce-([^']+)'/);
      if (match && match[1]) {
        nonce = match[1];
      }
    }

    const style = document.createElement('style');
    if (nonce) {
      style.setAttribute('nonce', nonce);
    }
    style.textContent = styleContent;
    document.head.appendChild(style);
  }, css);
}

export async function stabilizePage(page) {
  await hideAnimations(page);
  await waitForFonts(page);
  await waitForMath(page);
  await waitForViz(page);
}
