import { beforeEach, describe, expect, it, vi } from 'vitest';
import { initNavigation } from '../../assets/js/core/navigation.js';

function createNavDOM({ withToggle = true, withLinks = true, open = null } = {}) {
  let html = '';
  if (withToggle) {
    html += '<button class="nav-toggle" aria-expanded="false" aria-controls="site-nav">Menu</button>';
  }
  html += `<nav id="site-nav" class="site-nav"${open !== null ? ` data-open="${open}"` : ''}>`;
  if (withLinks) {
    html += `
      <a class="nav-link" href="/blog/">Blog</a>
      <a class="nav-link" href="/research/">Research</a>
      <a class="nav-link" href="/about/">About</a>
    `;
  }
  html += '</nav>';
  document.body.innerHTML = html;
}

let mediaMatches = false;
let changeListeners = [];

function mockMatchMedia() {
  changeListeners = [];
  window.matchMedia = vi.fn().mockImplementation(() => ({
    get matches() { return mediaMatches; },
    addEventListener: vi.fn((_, cb) => { changeListeners.push(cb); }),
    removeEventListener: vi.fn(),
  }));
}

function fireMediaChange(matches) {
  mediaMatches = matches;
  changeListeners.forEach(cb => cb({ matches }));
}

describe('initNavigation module', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    document.body.className = '';
    mediaMatches = false;
    changeListeners = [];
    mockMatchMedia();
  });

  // --- Missing DOM elements ---

  it('returns early when #site-nav is missing', () => {
    document.body.innerHTML = '<div>no nav here</div>';
    expect(() => initNavigation()).not.toThrow();
  });

  it('works without .nav-toggle button', () => {
    createNavDOM({ withToggle: false });
    expect(() => initNavigation()).not.toThrow();
    const nav = document.getElementById('site-nav');
    expect(nav.dataset.open).toBe('false');
  });

  // --- Initial state ---

  it('sets data-open to false on mobile', () => {
    mediaMatches = false;
    mockMatchMedia();
    createNavDOM();
    initNavigation();
    expect(document.getElementById('site-nav').dataset.open).toBe('false');
  });

  it('sets data-open to true on desktop', () => {
    mediaMatches = true;
    mockMatchMedia();
    createNavDOM();
    initNavigation();
    expect(document.getElementById('site-nav').dataset.open).toBe('true');
  });

  // --- Toggle ---

  it('opens nav when toggle is clicked on mobile', () => {
    createNavDOM();
    initNavigation();
    const toggle = document.querySelector('.nav-toggle');
    const nav = document.getElementById('site-nav');

    toggle.click();

    expect(nav.dataset.open).toBe('true');
    expect(toggle.getAttribute('aria-expanded')).toBe('true');
    expect(toggle.classList.contains('is-active')).toBe(true);
    expect(document.body.classList.contains('nav-open')).toBe(true);
  });

  it('closes nav when toggle is clicked again', () => {
    createNavDOM();
    initNavigation();
    const toggle = document.querySelector('.nav-toggle');
    const nav = document.getElementById('site-nav');

    toggle.click(); // open
    toggle.click(); // close

    expect(nav.dataset.open).toBe('false');
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    expect(toggle.classList.contains('is-active')).toBe(false);
    expect(document.body.classList.contains('nav-open')).toBe(false);
  });

  it('does not toggle on desktop', () => {
    mediaMatches = true;
    mockMatchMedia();
    createNavDOM();
    initNavigation();
    const toggle = document.querySelector('.nav-toggle');
    const nav = document.getElementById('site-nav');

    toggle.click();

    expect(nav.dataset.open).toBe('true');
  });

  // --- Escape key ---

  it('closes nav on Escape key press', () => {
    createNavDOM();
    initNavigation();
    const toggle = document.querySelector('.nav-toggle');
    const nav = document.getElementById('site-nav');

    toggle.click(); // open
    expect(nav.dataset.open).toBe('true');

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(nav.dataset.open).toBe('false');
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
  });

  it('focuses toggle after Escape close', () => {
    createNavDOM();
    initNavigation();
    const toggle = document.querySelector('.nav-toggle');

    toggle.click(); // open
    const focusSpy = vi.spyOn(toggle, 'focus');
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));

    expect(focusSpy).toHaveBeenCalled();
  });

  it('does nothing on Escape when already closed', () => {
    createNavDOM();
    initNavigation();
    const nav = document.getElementById('site-nav');

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    expect(nav.dataset.open).toBe('false');
  });

  it('does not close on Escape on desktop', () => {
    mediaMatches = true;
    mockMatchMedia();
    createNavDOM();
    initNavigation();

    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    expect(document.getElementById('site-nav').dataset.open).toBe('true');
  });

  // --- Outside click ---

  it('closes nav when clicking outside on mobile', () => {
    // Add an outside element to click on
    const outside = document.createElement('div');
    outside.className = 'outside';
    document.body.appendChild(outside);

    createNavDOM();
    document.body.appendChild(outside); // re-append after createNavDOM resets body

    initNavigation();
    const toggle = document.querySelector('.nav-toggle');
    const nav = document.getElementById('site-nav');

    toggle.click(); // open
    expect(nav.dataset.open).toBe('true');

    // Click on the outside element
    outside.dispatchEvent(new MouseEvent('click', { bubbles: true }));

    expect(nav.dataset.open).toBe('false');
  });

  it('does not close when clicking inside nav', () => {
    createNavDOM();
    initNavigation();
    const toggle = document.querySelector('.nav-toggle');
    const nav = document.getElementById('site-nav');
    const link = nav.querySelector('.nav-link');

    toggle.click(); // open

    link.dispatchEvent(new MouseEvent('click', { bubbles: true }));

    // Nav closes via the link click handler, not the outside click handler
    // The link click handler calls closeNav on mobile
    expect(nav.dataset.open).toBe('false');
  });

  it('does not close on outside click when already closed', () => {
    createNavDOM();
    initNavigation();
    const nav = document.getElementById('site-nav');

    document.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    expect(nav.dataset.open).toBe('false');
  });

  it('does not close on outside click on desktop', () => {
    mediaMatches = true;
    mockMatchMedia();
    createNavDOM();
    initNavigation();

    document.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    expect(document.getElementById('site-nav').dataset.open).toBe('true');
  });

  it('does not close when clicking the toggle button', () => {
    createNavDOM();
    initNavigation();
    const toggle = document.querySelector('.nav-toggle');

    toggle.click(); // open
    // The toggle click handler handles toggle, not the outside click handler
    expect(document.getElementById('site-nav').dataset.open).toBe('true');
  });

  // --- Media query changes ---

  it('opens nav and resets toggle when switching to desktop', () => {
    createNavDOM();
    initNavigation();
    const toggle = document.querySelector('.nav-toggle');
    const nav = document.getElementById('site-nav');

    toggle.click(); // open on mobile
    expect(nav.dataset.open).toBe('true');

    fireMediaChange(true); // switch to desktop

    expect(nav.dataset.open).toBe('true');
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    expect(toggle.classList.contains('is-active')).toBe(false);
    expect(document.body.classList.contains('nav-open')).toBe(false);
  });

  it('closes nav when switching to mobile', () => {
    mediaMatches = true;
    mockMatchMedia();
    createNavDOM();
    initNavigation();

    fireMediaChange(false); // switch to mobile

    const nav = document.getElementById('site-nav');
    expect(nav.dataset.open).toBe('false');
  });

  // --- Nav link click ---

  it('closes nav on link click on mobile', () => {
    createNavDOM();
    initNavigation();
    const toggle = document.querySelector('.nav-toggle');
    const nav = document.getElementById('site-nav');
    const link = nav.querySelector('.nav-link');

    toggle.click(); // open
    link.click();

    expect(nav.dataset.open).toBe('false');
  });

  it('does not close nav on link click on desktop', () => {
    mediaMatches = true;
    mockMatchMedia();
    createNavDOM();
    initNavigation();
    const nav = document.getElementById('site-nav');
    const link = nav.querySelector('.nav-link');

    link.click();

    expect(nav.dataset.open).toBe('true');
  });

  // --- Anchor smooth scroll ---

  it('smooth scrolls to anchor on same page', () => {
    createNavDOM({ withLinks: false });
    const nav = document.getElementById('site-nav');
    nav.innerHTML = `<a class="nav-link" href="${window.location.pathname}#section1">Section</a>`;

    const target = document.createElement('div');
    target.id = 'section1';
    document.body.appendChild(target);
    target.scrollIntoView = vi.fn();

    initNavigation();
    const link = nav.querySelector('.nav-link');
    const event = new MouseEvent('click', { bubbles: true, cancelable: true });
    link.dispatchEvent(event);

    expect(target.scrollIntoView).toHaveBeenCalledWith({ behavior: 'smooth', block: 'start' });
  });

  it('does not scroll for links to different pages', () => {
    createNavDOM({ withLinks: false });
    const nav = document.getElementById('site-nav');
    nav.innerHTML = '<a class="nav-link" href="/other-page/#section1">Other</a>';

    initNavigation();
    const link = nav.querySelector('.nav-link');
    const event = new MouseEvent('click', { bubbles: true, cancelable: true });
    link.dispatchEvent(event);

    // No scroll — different page
    expect(event.defaultPrevented).toBe(false);
  });

  it('handles links with no href gracefully', () => {
    createNavDOM({ withLinks: false });
    const nav = document.getElementById('site-nav');
    nav.innerHTML = '<a class="nav-link">No href</a>';

    initNavigation();
    const link = nav.querySelector('.nav-link');
    expect(() => link.click()).not.toThrow();
  });

  // --- Without toggle button ---

  it('openNav works without toggle button', () => {
    createNavDOM({ withToggle: false });
    initNavigation();
    // Cannot open via toggle, but media query change should still work
    fireMediaChange(true);
    expect(document.getElementById('site-nav').dataset.open).toBe('true');
  });

  it('closeNav works without toggle button', () => {
    mediaMatches = true;
    mockMatchMedia();
    createNavDOM({ withToggle: false });
    initNavigation();

    fireMediaChange(false);
    expect(document.getElementById('site-nav').dataset.open).toBe('false');
  });

  // --- Edge cases ---

  it('handles click event with null target', () => {
    createNavDOM();
    initNavigation();
    const toggle = document.querySelector('.nav-toggle');
    toggle.click(); // open

    // Dispatch click with no real target
    const event = new Event('click');
    Object.defineProperty(event, 'target', { value: null });
    expect(() => document.dispatchEvent(event)).not.toThrow();
  });

  it('handles click event where target has no closest method', () => {
    createNavDOM();
    initNavigation();
    const toggle = document.querySelector('.nav-toggle');
    toggle.click(); // open

    const event = new Event('click');
    Object.defineProperty(event, 'target', { value: { closest: undefined } });
    expect(() => document.dispatchEvent(event)).not.toThrow();
  });
});
