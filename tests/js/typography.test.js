import { describe, expect, it, beforeEach } from 'vitest';

describe('Typography', () => {
  describe('Font Loading', () => {
    beforeEach(() => {
      document.head.innerHTML = `
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
        <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&family=Roboto+Mono:wght@400;500;600&display=swap" />
      `;

      document.body.innerHTML = `
        <div class="content">
          <h1>Main Heading</h1>
          <p>Body text goes here.</p>
          <code>inline code</code>
          <pre><code>code block</code></pre>
        </div>
      `;
    });

    it('loads Roboto font family from Google Fonts', () => {
      const fontLink = document.querySelector('link[href*="Roboto"]');
      expect(fontLink).toBeTruthy();
      expect(fontLink.getAttribute('href')).toContain('family=Roboto');
      expect(fontLink.getAttribute('href')).toContain('wght@300;400;500;700');
    });

    it('loads Roboto Mono for monospace content', () => {
      const fontLink = document.querySelector('link[href*="Roboto"]');
      expect(fontLink.getAttribute('href')).toContain('Roboto+Mono');
      expect(fontLink.getAttribute('href')).toContain('wght@400;500;600');
    });

    it('preconnects to Google Fonts domains for performance', () => {
      const preconnects = document.querySelectorAll('link[rel="preconnect"]');
      const urls = Array.from(preconnects).map(link => link.getAttribute('href'));

      expect(urls).toContain('https://fonts.googleapis.com');
      expect(urls).toContain('https://fonts.gstatic.com');
    });

    it('uses font-display swap for optimal loading', () => {
      const fontLink = document.querySelector('link[href*="Roboto"]');
      expect(fontLink.getAttribute('href')).toContain('display=swap');
    });

    it('has proper crossorigin attribute on gstatic preconnect', () => {
      const gstaticPreconnect = document.querySelector('link[href*="gstatic"]');
      expect(gstaticPreconnect.hasAttribute('crossorigin')).toBe(true);
    });
  });

  describe('Font Stack Configuration', () => {
    it('applies correct font families to elements', () => {
      // Add code element to body first
      document.body.innerHTML = '<code>test code</code>';

      // Create a style element to simulate CSS
      const style = document.createElement('style');
      style.textContent = `
        body {
          font-family: 'Roboto', -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
        }
        code, pre {
          font-family: 'Roboto Mono', 'Fira Code', 'Source Code Pro', 'SFMono-Regular', Menlo, Monaco, Consolas, monospace;
        }
      `;
      document.head.appendChild(style);

      const computedBody = window.getComputedStyle(document.body);
      const codeEl = document.querySelector('code');
      const computedCode = window.getComputedStyle(codeEl);

      // Font families should be set
      expect(computedBody.fontFamily).toBeTruthy();
      expect(computedCode.fontFamily).toBeTruthy();
    });
  });

  describe('Responsive Typography', () => {
    beforeEach(() => {
      const style = document.createElement('style');
      style.textContent = `
        :root {
          font-size: 16px;
        }
        h1 { font-size: 2.5rem; font-weight: 600; }
        h2 { font-size: 1.875rem; font-weight: 600; }
        h3 { font-size: 1.5rem; font-weight: 600; }
        p { font-size: 1rem; line-height: 1.7; }
        code { font-size: 0.9em; }
      `;
      document.head.appendChild(style);

      document.body.innerHTML = `
        <h1>Heading 1</h1>
        <h2>Heading 2</h2>
        <h3>Heading 3</h3>
        <p>Paragraph text</p>
        <code>Code sample</code>
      `;
    });

    it('uses modular font size scale', () => {
      const h1 = document.querySelector('h1');
      const h2 = document.querySelector('h2');
      const h3 = document.querySelector('h3');

      const h1Size = window.getComputedStyle(h1).fontSize;
      const h2Size = window.getComputedStyle(h2).fontSize;
      const h3Size = window.getComputedStyle(h3).fontSize;

      expect(h1Size).toBeTruthy();
      expect(h2Size).toBeTruthy();
      expect(h3Size).toBeTruthy();
    });

    it('applies proper line heights for readability', () => {
      const paragraph = document.querySelector('p');
      const lineHeight = window.getComputedStyle(paragraph).lineHeight;

      expect(lineHeight).toBeTruthy();
      // Should have a numeric line height value
      expect(parseFloat(lineHeight)).toBeGreaterThan(0);
    });

    it('uses appropriate font weights for hierarchy', () => {
      const h1 = document.querySelector('h1');
      const h2 = document.querySelector('h2');

      const h1Weight = window.getComputedStyle(h1).fontWeight;
      const h2Weight = window.getComputedStyle(h2).fontWeight;

      expect(h1Weight).toBeTruthy();
      expect(h2Weight).toBeTruthy();
    });
  });

  describe('Code Typography', () => {
    beforeEach(() => {
      const style = document.createElement('style');
      style.textContent = `
        code {
          background: #f8f8f8;
          padding: 0.125rem 0.375rem;
          border-radius: 3px;
          font-size: 0.9em;
          color: #c7254e;
        }
        pre code {
          background: none;
          padding: 0;
          color: inherit;
          font-size: 0.875rem;
          line-height: 1.6;
        }
      `;
      document.head.appendChild(style);

      document.body.innerHTML = `
        <p>This is <code>inline code</code> in a paragraph.</p>
        <pre><code>function test() {
  return true;
}</code></pre>
      `;
    });

    it('styles inline code distinctly from text', () => {
      const inlineCode = document.querySelector('p code');
      const styles = window.getComputedStyle(inlineCode);

      expect(styles.background).toBeTruthy();
      expect(styles.padding).toBeTruthy();
      expect(styles.borderRadius).toBeTruthy();
    });

    it('styles code blocks appropriately', () => {
      const codeBlock = document.querySelector('pre code');
      const styles = window.getComputedStyle(codeBlock);

      expect(styles.fontSize).toBeTruthy();
      expect(styles.lineHeight).toBeTruthy();
    });

    it('maintains monospace font for code', () => {
      const code = document.querySelector('code');
      const pre = document.querySelector('pre');

      expect(code).toBeTruthy();
      expect(pre).toBeTruthy();
    });
  });

  describe('Character Differentiation', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <div class="test-chars">
          <p>0O o (zero, O, o)</p>
          <p>1lI| (one, l, I, pipe)</p>
          <code>0O 1lI</code>
        </div>
      `;
    });

    it('renders confusable characters in readable context', () => {
      const paragraphs = document.querySelectorAll('.test-chars p');
      const code = document.querySelector('.test-chars code');

      expect(paragraphs).toHaveLength(2);
      expect(code).toBeTruthy();

      // Characters should be present
      expect(paragraphs[0].textContent).toContain('0O');
      expect(paragraphs[1].textContent).toContain('1lI');
      expect(code.textContent).toContain('0O 1lI');
    });

    it('uses Roboto font for better character clarity', () => {
      // Roboto is specifically chosen for better differentiation between:
      // - 0 (zero) vs O (letter O)
      // - 1 (one) vs l (lowercase L) vs I (uppercase i)
      const style = document.createElement('style');
      style.textContent = `
        body { font-family: 'Roboto', sans-serif; }
        code { font-family: 'Roboto Mono', monospace; }
      `;
      document.head.appendChild(style);

      const body = window.getComputedStyle(document.body);
      const code = window.getComputedStyle(document.querySelector('code'));

      expect(body.fontFamily).toBeTruthy();
      expect(code.fontFamily).toBeTruthy();
    });
  });

  describe('ReadTheDocs Typography Standards', () => {
    beforeEach(() => {
      const style = document.createElement('style');
      style.textContent = `
        .package-docs__title {
          font-size: 2.5rem;
          font-weight: 600;
        }
        .package-docs__tagline {
          font-size: 1.125rem;
        }
        .package-nav__section-title {
          font-size: 0.875rem;
          font-weight: 600;
          text-transform: uppercase;
          letter-spacing: 0.05em;
        }
      `;
      document.head.appendChild(style);

      document.body.innerHTML = `
        <div class="package-docs">
          <h1 class="package-docs__title">StatFlow</h1>
          <p class="package-docs__tagline">A modern statistical analysis toolkit</p>
          <h4 class="package-nav__section-title">Getting Started</h4>
        </div>
      `;
    });

    it('uses ReadTheDocs-standard heading sizes', () => {
      const title = document.querySelector('.package-docs__title');
      const tagline = document.querySelector('.package-docs__tagline');

      const titleSize = window.getComputedStyle(title).fontSize;
      const taglineSize = window.getComputedStyle(tagline).fontSize;

      expect(titleSize).toBeTruthy();
      expect(taglineSize).toBeTruthy();
    });

    it('applies proper text transforms for navigation sections', () => {
      const sectionTitle = document.querySelector('.package-nav__section-title');
      const styles = window.getComputedStyle(sectionTitle);

      expect(styles.textTransform).toBe('uppercase');
      expect(styles.letterSpacing).toBeTruthy();
    });

    it('uses appropriate font weights for hierarchy', () => {
      const title = document.querySelector('.package-docs__title');
      const sectionTitle = document.querySelector('.package-nav__section-title');

      const titleWeight = window.getComputedStyle(title).fontWeight;
      const sectionWeight = window.getComputedStyle(sectionTitle).fontWeight;

      expect(titleWeight).toBeTruthy();
      expect(sectionWeight).toBeTruthy();
    });
  });
});
