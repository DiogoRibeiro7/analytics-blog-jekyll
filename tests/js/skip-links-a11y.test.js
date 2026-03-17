import { beforeEach, describe, expect, it, vi } from 'vitest';
import { initSkipLinks } from '../../assets/js/core/skip-links.js';

describe('skip-links accessibility', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
  });

  it('focuses target and adds temporary tabindex', () => {
    document.body.innerHTML = `
      <a href="#main" class="skip-link">Skip</a>
      <main id="main"><p>Content</p></main>
    `;
    initSkipLinks();

    const link = document.querySelector('.skip-link');
    const main = document.getElementById('main');
    const focusSpy = vi.spyOn(main, 'focus');

    link.click();

    expect(focusSpy).toHaveBeenCalled();
    expect(main.getAttribute('tabindex')).toBe('-1');
    expect(main.dataset.skipLinkTempTabindex).toBe('true');
  });

  it('removes temporary tabindex on blur', () => {
    document.body.innerHTML = `
      <a href="#content" class="skip-link">Skip</a>
      <div id="content">Hello</div>
    `;
    initSkipLinks();

    const link = document.querySelector('.skip-link');
    const target = document.getElementById('content');

    link.click();
    expect(target.getAttribute('tabindex')).toBe('-1');

    target.dispatchEvent(new Event('blur'));
    expect(target.hasAttribute('tabindex')).toBe(false);
    expect(target.dataset.skipLinkTempTabindex).toBeUndefined();
  });

  it('does not remove existing tabindex on blur', () => {
    document.body.innerHTML = `
      <a href="#widget" class="skip-link">Skip</a>
      <div id="widget" tabindex="0">Focusable widget</div>
    `;
    initSkipLinks();

    const link = document.querySelector('.skip-link');
    const target = document.getElementById('widget');

    link.click();
    // Should keep existing tabindex="0", not overwrite with -1
    expect(target.getAttribute('tabindex')).toBe('0');

    target.dispatchEvent(new Event('blur'));
    // Should still have its original tabindex
    expect(target.getAttribute('tabindex')).toBe('0');
  });

  it('handles click when target element does not exist', () => {
    document.body.innerHTML = `
      <a href="#nonexistent" class="skip-link">Skip</a>
    `;
    initSkipLinks();

    const link = document.querySelector('.skip-link');
    expect(() => link.click()).not.toThrow();
  });

  it('handles skip link with href="#" (empty target id)', () => {
    document.body.innerHTML = `
      <a href="#" class="skip-link">Skip</a>
    `;
    initSkipLinks();

    const link = document.querySelector('.skip-link');
    expect(() => link.click()).not.toThrow();
  });

  it('does nothing when no skip links exist', () => {
    document.body.innerHTML = '<p>No skip links</p>';
    expect(() => initSkipLinks()).not.toThrow();
  });

  it('works with multiple skip links', () => {
    document.body.innerHTML = `
      <a href="#main" class="skip-link">Skip to content</a>
      <a href="#nav" class="skip-link">Skip to nav</a>
      <nav id="nav">Nav</nav>
      <main id="main">Content</main>
    `;
    initSkipLinks();

    const navLink = document.querySelectorAll('.skip-link')[1];
    const nav = document.getElementById('nav');
    const focusSpy = vi.spyOn(nav, 'focus');

    navLink.click();
    expect(focusSpy).toHaveBeenCalled();
  });

  it('prevents default click behavior', () => {
    document.body.innerHTML = `
      <a href="#main" class="skip-link">Skip</a>
      <main id="main">Content</main>
    `;
    initSkipLinks();

    const link = document.querySelector('.skip-link');
    const event = new MouseEvent('click', { bubbles: true, cancelable: true });
    link.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(true);
  });

  it('does not prevent default when target is missing', () => {
    document.body.innerHTML = `
      <a href="#missing" class="skip-link">Skip</a>
    `;
    initSkipLinks();

    const link = document.querySelector('.skip-link');
    const event = new MouseEvent('click', { bubbles: true, cancelable: true });
    link.dispatchEvent(event);

    expect(event.defaultPrevented).toBe(false);
  });
});
