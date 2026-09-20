import { beforeEach, describe, expect, it, vi } from 'vitest';
import { currentHeading, initTocPanel, scrolledPercent } from '../../assets/js/core/toc.js';

/** jsdom lays nothing out, so each heading is told where it is. */
function place(element, top) {
  element.getBoundingClientRect = () => ({ top, bottom: top + 20, left: 0, right: 0, width: 0, height: 20 });
  return element;
}

function buildArticle(ids) {
  document.body.innerHTML = `
    <div class="post-body-wrapper">
      <nav class="enhanced-toc" data-toc-enhanced>
        <div class="enhanced-toc__progress"><div class="enhanced-toc__progress-bar" data-toc-progress></div></div>
        <button type="button" aria-expanded="true" aria-controls="toc-content" data-toc-toggle></button>
        <div class="enhanced-toc__content" id="toc-content">
          <ul>${ids.map((id) => `<li><a href="#${id}">${id}</a></li>`).join('')}</ul>
        </div>
        <div class="enhanced-toc__stats"><span data-progress-percent>0</span></div>
      </nav>
      <div class="post-content">
        ${ids.map((id) => `<h2 id="${id}">${id}</h2>`).join('')}
      </div>
    </div>
  `;
  const toc = document.querySelector('[data-toc-enhanced]');
  place(toc.parentElement, 0);
  return toc;
}

describe('reading position', () => {
  it('picks the last heading at or above the reading line', () => {
    const headings = [place(document.createElement('h2'), -300), place(document.createElement('h2'), 40),
      place(document.createElement('h2'), 800)];
    expect(currentHeading(headings)).toBe(headings[1]);
  });

  it('picks none while the reader is above the first heading', () => {
    expect(currentHeading([place(document.createElement('h2'), 500)])).toBeNull();
  });

  it('reports no progress through an article shorter than the viewport', () => {
    // The old code divided by this empty track and wrote "NaN%" to the bar.
    expect(scrolledPercent(0, 900, 900)).toBe(0);
    expect(scrolledPercent(0, 900, 400)).toBe(0);
  });

  it('reports progress as a whole percent, within bounds', () => {
    expect(scrolledPercent(500, 1000, 2000)).toBe(50);
    expect(scrolledPercent(0, 1000, 2000)).toBe(0);
    expect(scrolledPercent(5000, 1000, 2000)).toBe(100);
  });
});

describe('the contents panel', () => {
  beforeEach(() => {
    window.scrollY = 0;
    vi.spyOn(window, 'requestAnimationFrame').mockImplementation((callback) => {
      callback();
      return 1;
    });
  });

  it('leaves a link to a heading whose id starts with a digit alone', () => {
    // `document.querySelector('#1-introduction')` throws, and the handler that
    // called it had already cancelled the navigation.
    const toc = buildArticle(['1-introduction', '2-method']);
    initTocPanel(toc);

    const link = toc.querySelector('a[href="#1-introduction"]');
    const event = new window.MouseEvent('click', { bubbles: true, cancelable: true });
    expect(() => link.dispatchEvent(event)).not.toThrow();
    expect(event.defaultPrevented).toBe(false);
  });

  it('marks the section being read, for sight and for assistive technology', () => {
    const toc = buildArticle(['one', 'two']);
    const headings = document.querySelectorAll('.post-content h2');
    place(headings[0], -100);
    place(headings[1], 4000);

    const panel = initTocPanel(toc);
    panel.update();

    const first = toc.querySelector('a[href="#one"]');
    const second = toc.querySelector('a[href="#two"]');
    expect(first.classList.contains('is-active')).toBe(true);
    expect(first.getAttribute('aria-current')).toBe('location');
    expect(second.classList.contains('is-active')).toBe(false);
    expect(second.getAttribute('aria-current')).toBeNull();
  });

  it('writes a number to the progress bar, never NaN', () => {
    const toc = buildArticle(['one']);
    place(document.querySelector('.post-content h2'), -10);
    initTocPanel(toc).update();

    expect(toc.querySelector('[data-toc-progress]').style.width).toBe('0%');
    expect(toc.querySelector('[data-progress-percent]').textContent).toBe('0');
  });

  it('opens and closes, and says which it is', () => {
    const toc = buildArticle(['one']);
    initTocPanel(toc);
    const toggle = toc.querySelector('[data-toc-toggle]');
    const content = toc.querySelector('.enhanced-toc__content');

    toggle.click();
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    expect(content.hidden).toBe(true);
    expect(toc.classList.contains('is-collapsed')).toBe(true);

    toggle.click();
    expect(toggle.getAttribute('aria-expanded')).toBe('true');
    expect(content.hidden).toBe(false);
    expect(toc.classList.contains('is-collapsed')).toBe(false);
  });

  it('sticks once the reader is past the column it sits in', () => {
    const toc = buildArticle(['one']);
    place(document.querySelector('.post-content h2'), -10);
    const panel = initTocPanel(toc);

    place(toc.parentElement, -400);
    window.scrollY = 600;
    panel.update();
    expect(toc.classList.contains('is-sticky')).toBe(true);

    // Measured against the column, which does not move when the panel sticks.
    place(toc.parentElement, 600);
    window.scrollY = 0;
    panel.update();
    expect(toc.classList.contains('is-sticky')).toBe(false);
  });
});
