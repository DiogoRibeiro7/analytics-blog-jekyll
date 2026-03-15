import { describe, it, expect, beforeEach, vi, afterEach } from 'vitest';
import { initSkipLinks } from '../../assets/js/core/skip-links.js';
import { initScrollProgress } from '../../assets/js/core/scroll-progress.js';
import { initSearchHotkeys } from '../../assets/js/core/search-hotkeys.js';
import { initLanguageFilter } from '../../assets/js/core/language-filter.js';

describe('Skip Links Module', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
  });

  it('should initialize skip links', () => {
    document.body.innerHTML = `
      <a href="#main-content" class="skip-link">Skip to content</a>
      <main id="main-content">Content</main>
    `;

    initSkipLinks();
    const skipLink = document.querySelector('.skip-link');
    expect(skipLink).toBeTruthy();
  });

  it('should focus target element when skip link is clicked', () => {
    document.body.innerHTML = `
      <a href="#main-content" class="skip-link">Skip to content</a>
      <main id="main-content">Content</main>
    `;

    initSkipLinks();
    const skipLink = document.querySelector('.skip-link');
    const target = document.getElementById('main-content');
    const focusSpy = vi.spyOn(target, 'focus');

    skipLink.click();

    expect(focusSpy).toHaveBeenCalled();
  });

  it('should set temporary tabindex on target without existing tabindex', () => {
    document.body.innerHTML = `
      <a href="#main-content" class="skip-link">Skip to content</a>
      <main id="main-content">Content</main>
    `;

    initSkipLinks();
    const skipLink = document.querySelector('.skip-link');
    const target = document.getElementById('main-content');

    skipLink.click();

    expect(target.getAttribute('tabindex')).toBe('-1');
    expect(target.dataset.skipLinkTempTabindex).toBe('true');
  });

  it('should preserve existing tabindex', () => {
    document.body.innerHTML = `
      <a href="#main-content" class="skip-link">Skip to content</a>
      <main id="main-content" tabindex="0">Content</main>
    `;

    initSkipLinks();
    const skipLink = document.querySelector('.skip-link');
    const target = document.getElementById('main-content');

    skipLink.click();

    expect(target.getAttribute('tabindex')).toBe('0');
    expect(target.dataset.skipLinkTempTabindex).toBeUndefined();
  });

  it('should remove temporary tabindex on blur', () => {
    document.body.innerHTML = `
      <a href="#main-content" class="skip-link">Skip to content</a>
      <main id="main-content">Content</main>
    `;

    initSkipLinks();
    const skipLink = document.querySelector('.skip-link');
    const target = document.getElementById('main-content');

    skipLink.click();
    target.blur();

    expect(target.hasAttribute('tabindex')).toBe(false);
    expect(target.dataset.skipLinkTempTabindex).toBeUndefined();
  });

  it('should handle missing target element', () => {
    document.body.innerHTML = `
      <a href="#nonexistent" class="skip-link">Skip to content</a>
    `;

    expect(() => initSkipLinks()).not.toThrow();
  });

  it('should handle skip link without href', () => {
    document.body.innerHTML = `
      <a class="skip-link">Skip to content</a>
    `;

    expect(() => initSkipLinks()).not.toThrow();
  });

  it('should do nothing when no skip links exist', () => {
    document.body.innerHTML = '<div>No skip links</div>';
    expect(() => initSkipLinks()).not.toThrow();
  });

  it('should prevent default event behavior', () => {
    document.body.innerHTML = `
      <a href="#main-content" class="skip-link">Skip to content</a>
      <main id="main-content">Content</main>
    `;

    initSkipLinks();
    const skipLink = document.querySelector('.skip-link');
    const event = new MouseEvent('click', { bubbles: true, cancelable: true });
    const preventDefaultSpy = vi.spyOn(event, 'preventDefault');

    skipLink.dispatchEvent(event);

    expect(preventDefaultSpy).toHaveBeenCalled();
  });
});

describe('Scroll Progress Module', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    vi.spyOn(window, 'addEventListener');
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('should initialize scroll progress bar', () => {
    document.body.innerHTML = `
      <div data-scroll-progress></div>
    `;

    initScrollProgress();
    expect(window.addEventListener).toHaveBeenCalledWith('scroll', expect.any(Function), { passive: true });
    expect(window.addEventListener).toHaveBeenCalledWith('resize', expect.any(Function));
  });

  it('should update progress bar with PROGRESS element', () => {
    document.body.innerHTML = `
      <progress data-scroll-progress max="100" value="0"></progress>
    `;

    // Mock scroll position
    Object.defineProperty(window, 'pageYOffset', { value: 500, writable: true });
    Object.defineProperty(document.documentElement, 'scrollTop', { value: 500, writable: true });
    Object.defineProperty(document.documentElement, 'scrollHeight', { value: 2000, writable: true });
    Object.defineProperty(window, 'innerHeight', { value: 1000, writable: true });

    initScrollProgress();
    const progressBar = document.querySelector('[data-scroll-progress]');

    // Progress should be (500 / (2000 - 1000)) * 100 = 50%
    expect(progressBar.value).toBe(50);
  });

  it('should update progress bar with CSS custom property', () => {
    document.body.innerHTML = `
      <div data-scroll-progress></div>
    `;

    Object.defineProperty(window, 'pageYOffset', { value: 250, writable: true });
    Object.defineProperty(document.documentElement, 'scrollHeight', { value: 1500, writable: true });
    Object.defineProperty(window, 'innerHeight', { value: 500, writable: true });

    initScrollProgress();
    const progressBar = document.querySelector('[data-scroll-progress]');

    // Progress should be (250 / (1500 - 500)) * 100 = 25%
    const customProp = progressBar.style.getPropertyValue('--progress');
    expect(customProp).toBe('25%');
  });

  it('should update progress value display', () => {
    document.body.innerHTML = `
      <div data-scroll-progress></div>
      <span data-scroll-progress-value></span>
    `;

    Object.defineProperty(window, 'pageYOffset', { value: 750, writable: true });
    Object.defineProperty(document.documentElement, 'scrollHeight', { value: 2500, writable: true });
    Object.defineProperty(window, 'innerHeight', { value: 500, writable: true });

    initScrollProgress();
    const progressValue = document.querySelector('[data-scroll-progress-value]');

    // Progress should be (750 / (2500 - 500)) * 100 = 37.5% → 38 (rounded)
    expect(progressValue.textContent).toBe('38');
  });

  it('should handle zero scroll height gracefully', () => {
    document.body.innerHTML = `
      <progress data-scroll-progress max="100" value="0"></progress>
    `;

    Object.defineProperty(window, 'pageYOffset', { value: 0, writable: true });
    Object.defineProperty(document.documentElement, 'scrollHeight', { value: 1000, writable: true });
    Object.defineProperty(window, 'innerHeight', { value: 1000, writable: true });

    initScrollProgress();
    const progressBar = document.querySelector('[data-scroll-progress]');

    expect(progressBar.value).toBe(0);
  });

  it('should cap progress at 100%', () => {
    document.body.innerHTML = `
      <progress data-scroll-progress max="100" value="0"></progress>
    `;

    Object.defineProperty(window, 'pageYOffset', { value: 10000, writable: true });
    Object.defineProperty(document.documentElement, 'scrollHeight', { value: 2000, writable: true });
    Object.defineProperty(window, 'innerHeight', { value: 1000, writable: true });

    initScrollProgress();
    const progressBar = document.querySelector('[data-scroll-progress]');

    expect(progressBar.value).toBe(100);
  });

  it('should do nothing when progress bar element does not exist', () => {
    document.body.innerHTML = '<div>No progress bar</div>';
    expect(() => initScrollProgress()).not.toThrow();
    expect(window.addEventListener).not.toHaveBeenCalled();
  });
});

describe('Search Hotkeys Module', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
  });

  it('should initialize search hotkeys', () => {
    document.body.innerHTML = `
      <form class="site-search" action="/search">
        <input type="search" name="q" />
      </form>
    `;

    initSearchHotkeys();
    expect(document.body.innerHTML).toContain('site-search');
  });

  it('should focus search input on "/" key press', () => {
    document.body.innerHTML = `
      <form class="site-search" action="/search">
        <input type="search" name="q" />
      </form>
    `;

    initSearchHotkeys();
    const searchInput = document.querySelector('input[type="search"]');
    const focusSpy = vi.spyOn(searchInput, 'focus');

    const event = new KeyboardEvent('keydown', { key: '/' });
    document.dispatchEvent(event);

    expect(focusSpy).toHaveBeenCalled();
  });

  it('should select search input text on focus', () => {
    document.body.innerHTML = `
      <form class="site-search" action="/search">
        <input type="search" name="q" value="test" />
      </form>
    `;

    initSearchHotkeys();
    const searchInput = document.querySelector('input[type="search"]');
    const selectSpy = vi.spyOn(searchInput, 'select');

    const event = new KeyboardEvent('keydown', { key: '/' });
    document.dispatchEvent(event);

    expect(selectSpy).toHaveBeenCalled();
  });

  it('should focus search on Ctrl+K', () => {
    document.body.innerHTML = `
      <form class="site-search" action="/search">
        <input type="search" name="q" />
      </form>
    `;

    initSearchHotkeys();
    const searchInput = document.querySelector('input[type="search"]');
    const focusSpy = vi.spyOn(searchInput, 'focus');

    const event = new KeyboardEvent('keydown', { key: 'k', ctrlKey: true });
    document.dispatchEvent(event);

    expect(focusSpy).toHaveBeenCalled();
  });

  it('should focus search on Cmd+K (Mac)', () => {
    document.body.innerHTML = `
      <form class="site-search" action="/search">
        <input type="search" name="q" />
      </form>
    `;

    initSearchHotkeys();
    const searchInput = document.querySelector('input[type="search"]');
    const focusSpy = vi.spyOn(searchInput, 'focus');

    const event = new KeyboardEvent('keydown', { key: 'k', metaKey: true });
    document.dispatchEvent(event);

    expect(focusSpy).toHaveBeenCalled();
  });

  it('should ignore hotkey when typing in input field', () => {
    document.body.innerHTML = `
      <input type="text" id="other-input" />
      <form class="site-search" action="/search">
        <input type="search" name="q" />
      </form>
    `;

    initSearchHotkeys();
    const otherInput = document.getElementById('other-input');
    const searchInput = document.querySelector('input[type="search"]');
    const focusSpy = vi.spyOn(searchInput, 'focus');

    otherInput.focus();
    const event = new KeyboardEvent('keydown', { key: '/' });
    Object.defineProperty(event, 'target', { value: otherInput, enumerable: true });
    document.dispatchEvent(event);

    // Should not focus search because we're in another input
    expect(document.activeElement).toBe(otherInput);
  });

  it('should ignore hotkey when typing in textarea', () => {
    document.body.innerHTML = `
      <textarea id="comments"></textarea>
      <form class="site-search" action="/search">
        <input type="search" name="q" />
      </form>
    `;

    initSearchHotkeys();
    const textarea = document.getElementById('comments');
    textarea.focus();

    const event = new KeyboardEvent('keydown', { key: '/' });
    document.dispatchEvent(event);

    expect(document.activeElement).toBe(textarea);
  });

  it('should navigate to search page if no search input exists', () => {
    document.body.innerHTML = `
      <form class="site-search" action="/search"></form>
    `;

    delete window.location;
    window.location = { href: '' };

    initSearchHotkeys();

    const event = new KeyboardEvent('keydown', { key: '/' });
    document.dispatchEvent(event);

    expect(window.location.href).toBe('/search');
  });

  it('should do nothing when no search form exists', () => {
    document.body.innerHTML = '<div>No search form</div>';
    expect(() => initSearchHotkeys()).not.toThrow();
  });

  it('should ignore "/" with modifier keys', () => {
    document.body.innerHTML = `
      <form class="site-search" action="/search">
        <input type="search" name="q" />
      </form>
    `;

    initSearchHotkeys();
    const searchInput = document.querySelector('input[type="search"]');
    const focusSpy = vi.spyOn(searchInput, 'focus');

    // Should ignore Ctrl+/
    const event = new KeyboardEvent('keydown', { key: '/', ctrlKey: true });
    document.dispatchEvent(event);

    expect(focusSpy).not.toHaveBeenCalled();
  });
});

describe('Language Filter Module', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    delete window.location;
    window.location = { href: '' };
  });

  it('should initialize language filter', () => {
    document.body.innerHTML = `
      <select data-language-filter>
        <option value="/en">English</option>
        <option value="/fr">French</option>
      </select>
    `;

    initLanguageFilter();
    const filter = document.querySelector('[data-language-filter]');
    expect(filter).toBeTruthy();
  });

  it('should navigate to selected language on change', () => {
    document.body.innerHTML = `
      <select data-language-filter>
        <option value="">Select language</option>
        <option value="/en">English</option>
        <option value="/fr">French</option>
      </select>
    `;

    initLanguageFilter();
    const filter = document.querySelector('[data-language-filter]');

    filter.value = '/fr';
    filter.dispatchEvent(new Event('change'));

    expect(window.location.href).toBe('/fr');
  });

  it('should not navigate when empty value is selected', () => {
    document.body.innerHTML = `
      <select data-language-filter>
        <option value="">Select language</option>
        <option value="/en">English</option>
      </select>
    `;

    const originalHref = window.location.href;
    initLanguageFilter();
    const filter = document.querySelector('[data-language-filter]');

    filter.value = '';
    filter.dispatchEvent(new Event('change'));

    expect(window.location.href).toBe(originalHref);
  });

  it('should do nothing when no language filter exists', () => {
    document.body.innerHTML = '<div>No language filter</div>';
    expect(() => initLanguageFilter()).not.toThrow();
  });

  it('should handle multiple language options', () => {
    document.body.innerHTML = `
      <select data-language-filter>
        <option value="/en">English</option>
        <option value="/es">Spanish</option>
        <option value="/de">German</option>
        <option value="/pt">Portuguese</option>
      </select>
    `;

    initLanguageFilter();
    const filter = document.querySelector('[data-language-filter]');

    filter.value = '/pt';
    filter.dispatchEvent(new Event('change'));

    expect(window.location.href).toBe('/pt');
  });
});
