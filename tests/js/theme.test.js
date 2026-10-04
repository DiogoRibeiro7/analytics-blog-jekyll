import { beforeEach, describe, expect, it, vi } from 'vitest';
import { initDarkModeToggle, syncDarkFigures } from '../../assets/js/core/dark-mode.js';
import { initNavigation } from '../../assets/js/core/navigation.js';

describe('theme controls', () => {
  beforeEach(() => {
    if (typeof globalThis.matchMedia.mockReset === 'function') {
      globalThis.matchMedia.mockReset();
    }
    localStorage.clear();
    document.body.classList.remove('dark-mode'); // Reset dark mode state
    delete document.body.dataset.defaultTheme;
  });

  it('initializes dark mode toggle and respects stored preferences', () => {
    document.body.innerHTML = '<button data-toggle-dark-mode></button>';
    localStorage.setItem('datalog-color-mode', 'dark');

    const mediaQuery = {
      matches: true,
      media: '(prefers-color-scheme: dark)',
      addEventListener: vi.fn(),
      removeEventListener: vi.fn()
    };
    globalThis.matchMedia.mockReturnValue(mediaQuery);

    initDarkModeToggle();

    const toggle = document.querySelector('[data-toggle-dark-mode]');
    expect(document.body.classList.contains('dark-mode')).toBe(true);
    expect(toggle.getAttribute('aria-pressed')).toBe('true');

    toggle.click();
    expect(document.body.classList.contains('dark-mode')).toBe(false);
    expect(localStorage.getItem('datalog-color-mode')).toBe('light');
  });

  it('respects stored light mode preference', () => {
    document.body.innerHTML = '<button data-toggle-dark-mode></button>';
    document.body.classList.add('dark-mode'); // Liquid preselects the dark site default
    localStorage.setItem('datalog-color-mode', 'light');

    const mediaQuery = {
      matches: true, // System prefers dark, but storage says light
      media: '(prefers-color-scheme: dark)',
      addEventListener: vi.fn(),
      removeEventListener: vi.fn()
    };
    globalThis.matchMedia.mockReturnValue(mediaQuery);

    initDarkModeToggle();

    expect(document.body.classList.contains('dark-mode')).toBe(false);
    const toggle = document.querySelector('[data-toggle-dark-mode]');
    expect(toggle.getAttribute('aria-pressed')).toBe('false');
  });

  it('starts dark on a first visit', () => {
    document.body.innerHTML = '<button data-toggle-dark-mode></button>';
    // No stored preference

    const mediaQuery = {
      matches: false, // A light system preference does not change the site default
      media: '(prefers-color-scheme: dark)',
      addEventListener: vi.fn(),
      removeEventListener: vi.fn()
    };
    globalThis.matchMedia.mockReturnValue(mediaQuery);

    initDarkModeToggle();

    expect(document.body.classList.contains('dark-mode')).toBe(true);
  });

  it('uses a site-configured light default when there is no saved choice', () => {
    document.body.innerHTML = '<button data-toggle-dark-mode></button>';
    document.body.dataset.defaultTheme = 'light';

    const mediaQuery = {
      matches: false, // System prefers light
      media: '(prefers-color-scheme: dark)',
      addEventListener: vi.fn(),
      removeEventListener: vi.fn()
    };
    globalThis.matchMedia.mockReturnValue(mediaQuery);

    initDarkModeToggle();

    expect(document.body.classList.contains('dark-mode')).toBe(false);
  });

  it('works without toggle button', () => {
    document.body.innerHTML = ''; // No toggle button
    localStorage.setItem('datalog-color-mode', 'dark');

    const mediaQuery = {
      matches: false,
      media: '(prefers-color-scheme: dark)',
      addEventListener: vi.fn(),
      removeEventListener: vi.fn()
    };
    globalThis.matchMedia.mockReturnValue(mediaQuery);

    expect(() => initDarkModeToggle()).not.toThrow();
    expect(document.body.classList.contains('dark-mode')).toBe(true);
  });

  it('responds to system theme changes when the site chooses system mode', () => {
    document.body.innerHTML = '<button data-toggle-dark-mode></button>';
    document.body.dataset.defaultTheme = 'system';

    let changeHandler;
    const mediaQuery = {
      matches: false,
      media: '(prefers-color-scheme: dark)',
      addEventListener: vi.fn((event, handler) => {
        if (event === 'change') {
          changeHandler = handler;
        }
      }),
      removeEventListener: vi.fn()
    };
    globalThis.matchMedia.mockReturnValue(mediaQuery);

    initDarkModeToggle();

    expect(document.body.classList.contains('dark-mode')).toBe(false);

    // Simulate system theme changing to dark
    changeHandler({ matches: true });

    expect(document.body.classList.contains('dark-mode')).toBe(true);
    const toggle = document.querySelector('[data-toggle-dark-mode]');
    expect(toggle.getAttribute('aria-pressed')).toBe('true');
  });

  it('responds to system theme changes to light in system mode', () => {
    document.body.innerHTML = '<button data-toggle-dark-mode></button>';
    document.body.dataset.defaultTheme = 'system';

    let changeHandler;
    const mediaQuery = {
      matches: true,
      media: '(prefers-color-scheme: dark)',
      addEventListener: vi.fn((event, handler) => {
        if (event === 'change') {
          changeHandler = handler;
        }
      }),
      removeEventListener: vi.fn()
    };
    globalThis.matchMedia.mockReturnValue(mediaQuery);

    initDarkModeToggle();

    expect(document.body.classList.contains('dark-mode')).toBe(true);

    // Simulate system theme changing to light
    changeHandler({ matches: false });

    expect(document.body.classList.contains('dark-mode')).toBe(false);
    const toggle = document.querySelector('[data-toggle-dark-mode]');
    expect(toggle.getAttribute('aria-pressed')).toBe('false');
  });

  it('ignores system theme changes when user has explicit preference', () => {
    document.body.innerHTML = '<button data-toggle-dark-mode></button>';
    localStorage.setItem('datalog-color-mode', 'light');

    let changeHandler;
    const mediaQuery = {
      matches: false,
      media: '(prefers-color-scheme: dark)',
      addEventListener: vi.fn((event, handler) => {
        if (event === 'change') {
          changeHandler = handler;
        }
      }),
      removeEventListener: vi.fn()
    };
    globalThis.matchMedia.mockReturnValue(mediaQuery);

    initDarkModeToggle();

    expect(document.body.classList.contains('dark-mode')).toBe(false);

    // Simulate system theme changing to dark
    changeHandler({ matches: true });

    // Should still be light because user has explicit preference
    expect(document.body.classList.contains('dark-mode')).toBe(false);
  });

  it('ignores system changes with the dark site default', () => {
    document.body.innerHTML = '<button data-toggle-dark-mode></button>';
    let changeHandler;
    globalThis.matchMedia.mockReturnValue({
      matches: false,
      media: '(prefers-color-scheme: dark)',
      addEventListener: vi.fn((_event, handler) => { changeHandler = handler; }),
      removeEventListener: vi.fn()
    });

    initDarkModeToggle();
    expect(document.body.classList.contains('dark-mode')).toBe(true);
    changeHandler({ matches: false });
    expect(document.body.classList.contains('dark-mode')).toBe(true);
  });

  it('manages navigation disclosure state and keyboard shortcuts', () => {
    document.body.innerHTML = `
      <button class="nav-toggle" aria-expanded="false"></button>
      <nav id="site-nav" data-open="false">
        <a class="nav-link" href="#section-one">Section</a>
      </nav>
      <section id="section-one"></section>
    `;

    const listeners = [];
    globalThis.matchMedia.mockImplementation(() => ({
      matches: false,
      media: '(min-width: 48rem)',
      addEventListener: (_event, handler) => listeners.push(handler),
      removeEventListener: vi.fn()
    }));

    const scrollSpy = vi.spyOn(Element.prototype, 'scrollIntoView').mockImplementation(() => {});

    initNavigation();

    const nav = document.getElementById('site-nav');
    const toggle = document.querySelector('.nav-toggle');
    const link = document.querySelector('.nav-link');

    toggle.click();
    expect(nav.dataset.open).toBe('true');
    expect(document.body.classList.contains('nav-open')).toBe(true);

    link.click();
    expect(nav.dataset.open).toBe('false');
    expect(scrollSpy).toHaveBeenCalled();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    expect(nav.dataset.open).toBe('false');

    listeners.forEach((listener) => listener({ matches: true }));
    expect(nav.dataset.open).toBe('true');
  });
});

// A plot exported for a white page is unreadable on a dark one. The image
// pipeline offers the dark companion behind (prefers-color-scheme: dark),
// which follows the operating system; the toggle does not (#335).
describe('dark figures', () => {
  const DARK_MEDIA = '(prefers-color-scheme: dark)';
  const FIGURE = `<picture>
      <source media="${DARK_MEDIA}" data-dark-source type="image/webp" srcset="/power-dark.webp">
      <source media="${DARK_MEDIA}" data-dark-source type="image/png" srcset="/power-dark.png">
      <source type="image/webp" srcset="/power.webp">
      <img src="/power.png" alt="Power">
    </picture>`;

  const media = () =>
    Array.from(document.querySelectorAll('[data-dark-source]')).map((source) => source.getAttribute('media'));

  beforeEach(() => {
    localStorage.clear();
    document.body.classList.remove('dark-mode');
    delete document.body.dataset.defaultTheme;
    document.body.innerHTML = `<button data-toggle-dark-mode></button>${FIGURE}`;
  });

  it('leaves the query alone when the reader has not chosen', () => {
    syncDarkFigures(null);

    expect(media()).toEqual([DARK_MEDIA, DARK_MEDIA]);
  });

  it('serves the dark figure to a reader whose system is light but who chose dark', () => {
    syncDarkFigures('dark');

    expect(media()).toEqual(['all', 'all']);
  });

  it('serves the light figure to a reader whose system is dark but who chose light', () => {
    syncDarkFigures('light');

    expect(media()).toEqual(['not all', 'not all']);
  });

  it('restores the system query when the choice goes back to neither', () => {
    syncDarkFigures('light');
    syncDarkFigures(null);

    expect(media()).toEqual([DARK_MEDIA, DARK_MEDIA]);
  });

  it('leaves the light sources and the fallback image alone', () => {
    syncDarkFigures('dark');

    const light = document.querySelector('source:not([data-dark-source])');
    expect(light.getAttribute('media')).toBeNull();
    expect(document.querySelector('img').getAttribute('src')).toBe('/power.png');
  });

  it('follows the toggle, both on load and on every click', () => {
    localStorage.setItem('datalog-color-mode', 'dark');
    globalThis.matchMedia.mockReturnValue({
      matches: false,
      media: DARK_MEDIA,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn()
    });

    initDarkModeToggle();
    expect(media()).toEqual(['all', 'all']);

    document.querySelector('[data-toggle-dark-mode]').click();
    expect(media()).toEqual(['not all', 'not all']);
  });

  it('selects the dark companion on a first visit even with a light system setting', () => {
    globalThis.matchMedia.mockReturnValue({
      matches: false,
      media: DARK_MEDIA,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn()
    });

    initDarkModeToggle();

    expect(media()).toEqual(['all', 'all']);
  });

  it('does nothing on a page with no dark figures', () => {
    document.body.innerHTML = '<p>No figures here.</p>';

    expect(() => syncDarkFigures('dark')).not.toThrow();
  });
});
