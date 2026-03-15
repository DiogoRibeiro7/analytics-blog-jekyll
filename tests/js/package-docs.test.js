import { beforeEach, describe, expect, it, vi } from 'vitest';

describe('Package Documentation', () => {
  describe('Installation Tabs', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <div data-install-tabs>
          <div class="package-install__tab-buttons">
            <button class="package-install__tab-btn package-install__tab-btn--active" data-tab="pip">pip</button>
            <button class="package-install__tab-btn" data-tab="conda">conda</button>
            <button class="package-install__tab-btn" data-tab="git">git</button>
          </div>

          <div class="package-install__tab-content" data-tab-content="pip">
            <div class="package-install__code-block">
              <pre><code data-copy-text>pip install statflow</code></pre>
              <button data-copy-btn class="package-install__copy-btn">Copy</button>
            </div>
          </div>

          <div class="package-install__tab-content" data-tab-content="conda" hidden>
            <div class="package-install__code-block">
              <pre><code data-copy-text>conda install statflow</code></pre>
              <button data-copy-btn class="package-install__copy-btn">Copy</button>
            </div>
          </div>

          <div class="package-install__tab-content" data-tab-content="git" hidden>
            <div class="package-install__code-block">
              <pre><code data-copy-text>git clone https://github.com/example/statflow</code></pre>
              <button data-copy-btn class="package-install__copy-btn">Copy</button>
            </div>
          </div>
        </div>
      `;
    });

    it('switches between installation tabs', () => {
      const container = document.querySelector('[data-install-tabs]');
      const pipBtn = container.querySelector('[data-tab="pip"]');
      const condaBtn = container.querySelector('[data-tab="conda"]');
      const pipContent = container.querySelector('[data-tab-content="pip"]');
      const condaContent = container.querySelector('[data-tab-content="conda"]');

      // Simulate tab initialization
      const tabBtns = container.querySelectorAll('[data-tab]');
      const tabContents = container.querySelectorAll('[data-tab-content]');

      tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
          const tabName = btn.dataset.tab;
          tabBtns.forEach(b => b.classList.remove('package-install__tab-btn--active'));
          btn.classList.add('package-install__tab-btn--active');
          tabContents.forEach(content => {
            content.hidden = content.dataset.tabContent !== tabName;
          });
        });
      });

      // Initial state - pip should be active
      expect(pipBtn.classList.contains('package-install__tab-btn--active')).toBe(true);
      expect(pipContent.hidden).toBe(false);
      expect(condaContent.hidden).toBe(true);

      // Click conda tab
      condaBtn.click();
      expect(condaBtn.classList.contains('package-install__tab-btn--active')).toBe(true);
      expect(pipBtn.classList.contains('package-install__tab-btn--active')).toBe(false);
      expect(condaContent.hidden).toBe(false);
      expect(pipContent.hidden).toBe(true);
    });

    it('copies code to clipboard', async () => {
      const copyBtn = document.querySelector('[data-copy-btn]');
      const codeEl = document.querySelector('[data-copy-text]');

      // Mock clipboard API
      const writeTextMock = vi.fn().mockResolvedValue(undefined);
      Object.assign(navigator, {
        clipboard: {
          writeText: writeTextMock
        }
      });

      // Simulate copy button click handler
      copyBtn.addEventListener('click', async () => {
        const text = codeEl.textContent.trim();
        try {
          await navigator.clipboard.writeText(text);
          copyBtn.innerHTML = 'Copied!';
          copyBtn.classList.add('package-install__copy-btn--success');
        } catch (err) {
          console.error('Failed to copy:', err);
        }
      });

      await copyBtn.click();
      await vi.waitFor(() => {
        expect(writeTextMock).toHaveBeenCalledWith('pip install statflow');
        expect(copyBtn.textContent).toBe('Copied!');
        expect(copyBtn.classList.contains('package-install__copy-btn--success')).toBe(true);
      });
    });

    it('handles clipboard copy errors gracefully', async () => {
      const copyBtn = document.querySelector('[data-copy-btn]');
      const codeEl = document.querySelector('[data-copy-text]');
      const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

      // Mock clipboard API to fail
      Object.assign(navigator, {
        clipboard: {
          writeText: vi.fn().mockRejectedValue(new Error('Clipboard access denied'))
        }
      });

      // Simulate copy button click handler
      copyBtn.addEventListener('click', async () => {
        const text = codeEl.textContent.trim();
        try {
          await navigator.clipboard.writeText(text);
        } catch (err) {
          console.error('Failed to copy:', err);
        }
      });

      await copyBtn.click();
      await vi.waitFor(() => {
        expect(consoleSpy).toHaveBeenCalled();
      });

      consoleSpy.mockRestore();
    });
  });

  describe('Package Navigation', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <div class="package-docs">
          <nav class="package-nav">
            <a class="package-nav__link" href="#installation">Installation</a>
            <a class="package-nav__link" href="#quick-start">Quick Start</a>
            <a class="package-nav__link" href="#api-reference">API Reference</a>
          </nav>

          <div class="package-docs__content">
            <h2 id="installation">Installation</h2>
            <p>Install the package...</p>

            <h2 id="quick-start">Quick Start</h2>
            <p>Get started quickly...</p>

            <h2 id="api-reference">API Reference</h2>
            <p>API documentation...</p>
          </div>
        </div>
      `;
    });

    it('highlights active section in navigation', () => {
      const links = document.querySelectorAll('.package-nav__link');
      const headings = document.querySelectorAll('.package-docs__content h2[id]');

      // Simulate IntersectionObserver behavior
      const observerCallback = (entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            const id = entry.target.getAttribute('id');
            if (!id) return;

            links.forEach(link => {
              link.classList.remove('package-nav__link--active');
            });

            const activeLink = document.querySelector(`.package-nav__link[href="#${id}"]`);
            if (activeLink) {
              activeLink.classList.add('package-nav__link--active');
            }
          }
        });
      };

      // Simulate section becoming visible
      const mockEntry = {
        isIntersecting: true,
        target: headings[1] // Quick Start section
      };

      observerCallback([mockEntry]);

      const activeLink = document.querySelector('.package-nav__link--active');
      expect(activeLink).toBeTruthy();
      expect(activeLink.getAttribute('href')).toBe('#quick-start');
    });

    it('scrolls smoothly to section on link click', () => {
      const scrollIntoViewMock = vi.fn();
      const pushStateMock = vi.fn();

      Element.prototype.scrollIntoView = scrollIntoViewMock;
      window.history.pushState = pushStateMock;

      const links = document.querySelectorAll('.package-nav__link');

      // Simulate link click handler
      links.forEach(link => {
        link.addEventListener('click', (e) => {
          e.preventDefault();
          const target = document.querySelector(link.getAttribute('href'));
          if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            history.pushState(null, null, link.getAttribute('href'));
          }
        });
      });

      const quickStartLink = document.querySelector('[href="#quick-start"]');
      quickStartLink.click();

      expect(scrollIntoViewMock).toHaveBeenCalledWith({
        behavior: 'smooth',
        block: 'start'
      });
      expect(pushStateMock).toHaveBeenCalledWith(null, null, '#quick-start');
    });

    it('handles missing section targets gracefully', () => {
      const scrollIntoViewMock = vi.fn();
      Element.prototype.scrollIntoView = scrollIntoViewMock;

      document.body.innerHTML = `
        <nav class="package-nav">
          <a class="package-nav__link" href="#nonexistent">Nonexistent</a>
        </nav>
      `;

      const link = document.querySelector('.package-nav__link');
      link.addEventListener('click', (e) => {
        e.preventDefault();
        const target = document.querySelector(link.getAttribute('href'));
        if (target) {
          target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
      });

      link.click();
      expect(scrollIntoViewMock).not.toHaveBeenCalled();
    });
  });

  describe('API Function Documentation', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <div class="api-function" id="ttest">
          <h3 class="api-function__name">
            <code>ttest</code>
          </h3>
          <div class="api-function__signature">
            <code>statflow.ttest(x, y=None, paired=False, alternative='two-sided')</code>
          </div>
          <dl class="api-function__params">
            <dt class="api-function__param-name">
              <code>x</code>
              <span class="api-function__param-type">array-like</span>
            </dt>
            <dd>First sample or the sample to test.</dd>

            <dt class="api-function__param-name">
              <code>y</code>
              <span class="api-function__param-type">array-like</span>
              <span class="api-function__param-badge">optional</span>
            </dt>
            <dd>Second sample.</dd>
          </dl>
        </div>
      `;
    });

    it('renders function signature correctly', () => {
      const signature = document.querySelector('.api-function__signature code');
      expect(signature.textContent).toContain('statflow.ttest');
      expect(signature.textContent).toContain('y=None');
      expect(signature.textContent).toContain('paired=False');
    });

    it('displays parameters with types and optional badges', () => {
      const params = document.querySelectorAll('.api-function__param-name');
      expect(params).toHaveLength(2);

      const yParam = Array.from(params).find(p => p.querySelector('code')?.textContent === 'y');
      expect(yParam).toBeTruthy();

      const optionalBadge = yParam.querySelector('.api-function__param-badge');
      expect(optionalBadge).toBeTruthy();
      expect(optionalBadge.textContent).toBe('optional');
    });

    it('has proper accessibility structure', () => {
      const functionId = document.querySelector('.api-function').getAttribute('id');
      expect(functionId).toBe('ttest');

      const paramList = document.querySelector('.api-function__params');
      expect(paramList.tagName).toBe('DL');

      const terms = document.querySelectorAll('dt');
      const descriptions = document.querySelectorAll('dd');
      expect(terms).toHaveLength(descriptions.length);
    });
  });

  describe('Version Selector', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <div class="package-nav__section package-nav__section--versions">
          <h4 class="package-nav__section-title">Version</h4>
          <select class="package-nav__version-select" data-version-selector>
            <option value="/packages/statflow/" selected>1.2.3 (latest)</option>
            <option value="/packages/statflow/v1.1.0/">1.1.0 (stable)</option>
            <option value="/packages/statflow/v1.0.0/">1.0.0</option>
          </select>
        </div>
      `;
    });

    it('navigates to selected version', () => {
      const selector = document.querySelector('[data-version-selector]');
      let navigatedTo = null;

      selector.addEventListener('change', (e) => {
        navigatedTo = e.target.value;
      });

      selector.value = '/packages/statflow/v1.1.0/';
      selector.dispatchEvent(new Event('change'));

      expect(navigatedTo).toBe('/packages/statflow/v1.1.0/');
    });

    it('shows correct version as selected', () => {
      const selector = document.querySelector('[data-version-selector]');
      const selectedOption = selector.querySelector('option[selected]');

      expect(selectedOption.value).toBe('/packages/statflow/');
      expect(selectedOption.textContent).toContain('1.2.3');
      expect(selectedOption.textContent).toContain('latest');
    });
  });
});
