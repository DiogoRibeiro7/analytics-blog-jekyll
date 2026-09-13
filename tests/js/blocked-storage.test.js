import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { initDarkModeToggle } from '../../assets/js/core/dark-mode.js';
import { initializeCore } from '../../assets/js/main.js';

// Storage access throws in Safari with all cookies blocked, in sandboxed
// iframes and under some privacy extensions. An exception from the dark mode
// toggle used to reject the core bundle's import, which stopped every feature.
describe('with storage blocked', () => {
  const originalMatchMedia = window.matchMedia;
  const blocked = () => {
    throw new DOMException('The operation is insecure.', 'SecurityError');
  };

  const prefersDark = (matches) => {
    window.matchMedia = vi.fn().mockReturnValue({
      matches,
      media: '(prefers-color-scheme: dark)',
      addEventListener: vi.fn(),
      removeEventListener: vi.fn()
    });
  };

  beforeEach(() => {
    document.body.className = '';
    document.body.innerHTML = '<button data-toggle-dark-mode aria-pressed="false"></button>';
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(blocked);
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(blocked);
  });

  afterEach(() => {
    vi.restoreAllMocks();
    window.matchMedia = originalMatchMedia;
  });

  it('follows the system color scheme instead of throwing', () => {
    prefersDark(true);

    expect(() => initDarkModeToggle()).not.toThrow();
    expect(document.body.classList.contains('dark-mode')).toBe(true);
  });

  it('still switches the theme when the choice cannot be saved', () => {
    prefersDark(false);
    initDarkModeToggle();

    document.querySelector('[data-toggle-dark-mode]').click();

    expect(document.body.classList.contains('dark-mode')).toBe(true);
  });

  it('runs the other core initializers when one throws', () => {
    const logged = vi.spyOn(console, 'error').mockImplementation(() => {});
    const before = vi.fn();
    const after = vi.fn();
    function failing() {
      throw new Error('storage blocked');
    }

    expect(() => initializeCore([before, failing, after])).not.toThrow();
    expect(before).toHaveBeenCalled();
    expect(after).toHaveBeenCalled();
    expect(logged).toHaveBeenCalledWith('failing failed', expect.any(Error));
  });
});
