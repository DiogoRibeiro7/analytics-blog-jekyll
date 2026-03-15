import { beforeEach, describe, expect, it, vi } from 'vitest';
import { initDarkModeToggle } from '../../assets/js/core/dark-mode.js';
import { initNavigation } from '../../assets/js/core/navigation.js';

describe('theme controls', () => {
  beforeEach(() => {
    if (typeof globalThis.matchMedia.mockReset === 'function') {
      globalThis.matchMedia.mockReset();
    }
    localStorage.clear();
    document.body.classList.remove('dark-mode'); // Reset dark mode state
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

  it('falls back to system preference when no stored preference', () => {
    document.body.innerHTML = '<button data-toggle-dark-mode></button>';
    // No stored preference

    const mediaQuery = {
      matches: true, // System prefers dark
      media: '(prefers-color-scheme: dark)',
      addEventListener: vi.fn(),
      removeEventListener: vi.fn()
    };
    globalThis.matchMedia.mockReturnValue(mediaQuery);

    initDarkModeToggle();

    expect(document.body.classList.contains('dark-mode')).toBe(true);
  });

  it('falls back to light when system prefers light and no stored preference', () => {
    document.body.innerHTML = '<button data-toggle-dark-mode></button>';
    // No stored preference

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

  it('responds to system theme changes when no stored preference', () => {
    document.body.innerHTML = '<button data-toggle-dark-mode></button>';
    // No stored preference

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

  it('responds to system theme changes to light when no stored preference', () => {
    document.body.innerHTML = '<button data-toggle-dark-mode></button>';
    // No stored preference

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
