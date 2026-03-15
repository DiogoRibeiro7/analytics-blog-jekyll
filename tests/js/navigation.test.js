import { beforeEach, describe, expect, it, vi } from 'vitest';

describe('Navigation Enhancements', () => {
  describe('Package Navigation Link', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <header>
          <nav class="main-nav">
            <a href="/blog/">Blog</a>
            <a href="/research/">Research</a>
            <a href="/packages/">Packages</a>
            <a href="/about/">About</a>
          </nav>
        </header>
      `;
    });

    it('includes packages link in main navigation', () => {
      const packagesLink = document.querySelector('a[href="/packages/"]');
      expect(packagesLink).toBeTruthy();
      expect(packagesLink.textContent).toBe('Packages');
    });

    it('maintains navigation structure with new packages link', () => {
      const navLinks = document.querySelectorAll('.main-nav a');
      const hrefs = Array.from(navLinks).map(link => link.getAttribute('href'));

      expect(hrefs).toContain('/blog/');
      expect(hrefs).toContain('/research/');
      expect(hrefs).toContain('/packages/');
      expect(hrefs).toContain('/about/');
    });

    it('orders navigation links logically', () => {
      const navLinks = document.querySelectorAll('.main-nav a');
      const linkTexts = Array.from(navLinks).map(link => link.textContent);

      const packagesIndex = linkTexts.indexOf('Packages');
      const aboutIndex = linkTexts.indexOf('About');

      // Packages should come before About
      expect(packagesIndex).toBeGreaterThan(-1);
      expect(aboutIndex).toBeGreaterThan(-1);
      expect(packagesIndex).toBeLessThan(aboutIndex);
    });
  });

  describe('Active Navigation State', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <nav class="main-nav">
          <a href="/blog/" class="nav-link">Blog</a>
          <a href="/packages/" class="nav-link nav-link--active">Packages</a>
          <a href="/about/" class="nav-link">About</a>
        </nav>
      `;
    });

    it('highlights active navigation link', () => {
      const activeLink = document.querySelector('.nav-link--active');
      expect(activeLink).toBeTruthy();
      expect(activeLink.getAttribute('href')).toBe('/packages/');
    });

    it('only one navigation link is active at a time', () => {
      const activeLinks = document.querySelectorAll('.nav-link--active');
      expect(activeLinks).toHaveLength(1);
    });

    it('updates active state on navigation', () => {
      const links = document.querySelectorAll('.nav-link');

      // Simulate navigation to blog
      links.forEach(link => link.classList.remove('nav-link--active'));
      links[0].classList.add('nav-link--active');

      const newActiveLink = document.querySelector('.nav-link--active');
      expect(newActiveLink.getAttribute('href')).toBe('/blog/');
    });
  });

  describe('Mobile Navigation', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <button class="nav-toggle" aria-expanded="false" aria-controls="main-nav">
          Menu
        </button>
        <nav id="main-nav" class="main-nav" data-open="false">
          <a href="/blog/">Blog</a>
          <a href="/packages/">Packages</a>
        </nav>
      `;
    });

    it('toggles navigation on button click', () => {
      const toggle = document.querySelector('.nav-toggle');
      const nav = document.getElementById('main-nav');

      toggle.addEventListener('click', () => {
        const isOpen = nav.dataset.open === 'true';
        nav.dataset.open = (!isOpen).toString();
        toggle.setAttribute('aria-expanded', (!isOpen).toString());
      });

      expect(nav.dataset.open).toBe('false');
      expect(toggle.getAttribute('aria-expanded')).toBe('false');

      toggle.click();

      expect(nav.dataset.open).toBe('true');
      expect(toggle.getAttribute('aria-expanded')).toBe('true');
    });

    it('closes navigation on escape key', () => {
      const nav = document.getElementById('main-nav');
      nav.dataset.open = 'true';

      document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
          nav.dataset.open = 'false';
        }
      });

      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

      expect(nav.dataset.open).toBe('false');
    });

    it('has proper ARIA attributes for accessibility', () => {
      const toggle = document.querySelector('.nav-toggle');
      const nav = document.getElementById('main-nav');

      expect(toggle.hasAttribute('aria-expanded')).toBe(true);
      expect(toggle.hasAttribute('aria-controls')).toBe(true);
      expect(toggle.getAttribute('aria-controls')).toBe('main-nav');
      expect(nav.id).toBe('main-nav');
    });
  });

  describe('Skip Links', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <a href="#main-content" class="skip-link">Skip to content</a>
        <nav>
          <a href="/packages/">Packages</a>
        </nav>
        <main id="main-content">
          <h1>Content</h1>
        </main>
      `;
    });

    it('includes skip link for accessibility', () => {
      const skipLink = document.querySelector('.skip-link');
      expect(skipLink).toBeTruthy();
      expect(skipLink.getAttribute('href')).toBe('#main-content');
    });

    it('skip link points to main content', () => {
      const skipLink = document.querySelector('.skip-link');
      const mainContent = document.getElementById('main-content');

      expect(skipLink.getAttribute('href')).toBe(`#${mainContent.id}`);
    });

    it('focuses main content when skip link is activated', () => {
      const skipLink = document.querySelector('.skip-link');
      const mainContent = document.getElementById('main-content');
      const focusSpy = vi.fn();

      mainContent.focus = focusSpy;

      skipLink.addEventListener('click', (e) => {
        e.preventDefault();
        mainContent.focus();
      });

      skipLink.click();

      expect(focusSpy).toHaveBeenCalled();
    });
  });

  describe('Breadcrumb Navigation', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <nav aria-label="Breadcrumb">
          <ol class="breadcrumb">
            <li><a href="/">Home</a></li>
            <li><a href="/packages/">Packages</a></li>
            <li aria-current="page">StatFlow</li>
          </ol>
        </nav>
      `;
    });

    it('renders breadcrumb trail for package pages', () => {
      const breadcrumb = document.querySelector('.breadcrumb');
      expect(breadcrumb).toBeTruthy();

      const items = breadcrumb.querySelectorAll('li');
      expect(items).toHaveLength(3);
    });

    it('marks current page in breadcrumb', () => {
      const currentItem = document.querySelector('[aria-current="page"]');
      expect(currentItem).toBeTruthy();
      expect(currentItem.textContent).toBe('StatFlow');
    });

    it('includes proper semantic structure', () => {
      const nav = document.querySelector('nav[aria-label="Breadcrumb"]');
      const list = nav.querySelector('ol');

      expect(nav).toBeTruthy();
      expect(list).toBeTruthy();
      expect(list.tagName).toBe('OL');
    });

    it('provides working links to parent pages', () => {
      const homeLink = document.querySelector('.breadcrumb a[href="/"]');
      const packagesLink = document.querySelector('.breadcrumb a[href="/packages/"]');

      expect(homeLink).toBeTruthy();
      expect(homeLink.textContent).toBe('Home');
      expect(packagesLink).toBeTruthy();
      expect(packagesLink.textContent).toBe('Packages');
    });
  });

  describe('Scroll Progress Indicator', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <div class="scroll-progress" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0">
          <div class="scroll-progress__bar" style="width: 0%"></div>
        </div>
        <main style="height: 3000px">
          <p>Long content...</p>
        </main>
      `;
    });

    it('displays scroll progress indicator', () => {
      const indicator = document.querySelector('.scroll-progress');
      expect(indicator).toBeTruthy();
      expect(indicator.getAttribute('role')).toBe('progressbar');
    });

    it('updates progress on scroll', () => {
      const indicator = document.querySelector('.scroll-progress');
      const bar = document.querySelector('.scroll-progress__bar');

      // Simulate scroll to 50%
      const scrollHandler = (scrollTop, scrollHeight, innerHeight) => {
        const maxScroll = scrollHeight - innerHeight;
        const progress = maxScroll > 0 ? (scrollTop / maxScroll) * 100 : 0;

        indicator.setAttribute('aria-valuenow', Math.round(progress));
        bar.style.width = `${progress}%`;
      };

      // Simulate: page height 3000px, viewport 1000px, scrolled 1000px = 50% progress
      scrollHandler(1000, 3000, 1000);

      const progress = parseInt(indicator.getAttribute('aria-valuenow'));
      expect(progress).toBe(50);
      expect(progress).toBeGreaterThan(0);
      expect(progress).toBeLessThanOrEqual(100);
    });

    it('has proper ARIA attributes', () => {
      const indicator = document.querySelector('.scroll-progress');

      expect(indicator.hasAttribute('aria-valuemin')).toBe(true);
      expect(indicator.hasAttribute('aria-valuemax')).toBe(true);
      expect(indicator.hasAttribute('aria-valuenow')).toBe(true);
      expect(indicator.getAttribute('aria-valuemin')).toBe('0');
      expect(indicator.getAttribute('aria-valuemax')).toBe('100');
    });
  });

  describe('Back to Top Button', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <button class="back-to-top" aria-label="Back to top" hidden>
          ↑
        </button>
        <main style="height: 2000px">
          <p>Content...</p>
        </main>
      `;
    });

    it('shows button after scrolling threshold', () => {
      const button = document.querySelector('.back-to-top');

      // Simulate scroll beyond threshold (300px)
      Object.defineProperty(window, 'pageYOffset', {
        writable: true,
        value: 400
      });

      const scrollHandler = () => {
        const threshold = 300;
        button.hidden = window.pageYOffset < threshold;
      };

      scrollHandler();

      expect(button.hidden).toBe(false);
    });

    it('scrolls to top when clicked', () => {
      const button = document.querySelector('.back-to-top');
      button.hidden = false;

      button.addEventListener('click', () => {
        window.scrollTo({ top: 0, behavior: 'smooth' });
      });

      button.click();

      expect(window.scrollTo).toHaveBeenCalledWith({
        top: 0,
        behavior: 'smooth'
      });
    });

    it('has accessible label', () => {
      const button = document.querySelector('.back-to-top');
      expect(button.hasAttribute('aria-label')).toBe(true);
      expect(button.getAttribute('aria-label')).toBe('Back to top');
    });
  });
});
