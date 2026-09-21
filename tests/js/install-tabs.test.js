import { beforeEach, describe, expect, it } from 'vitest';
import { initInstallTabs, selectTab } from '../../assets/js/core/install-tabs.js';

function buildPanel(names = ['pip', 'conda', 'git']) {
  document.body.innerHTML = `
    <div class="package-install" id="install-statflow">
      <div class="package-install__tabs" data-install-tabs>
        <div class="package-install__tab-buttons" role="tablist">
          ${names
            .map(
              (name, index) => `<button type="button" role="tab" data-tab="${name}"
                 id="install-statflow-tab-${name}"
                 aria-controls="install-statflow-panel-${name}"
                 aria-selected="${index === 0}"
                 tabindex="${index === 0 ? 0 : -1}">${name}</button>`
            )
            .join('')}
        </div>
        ${names
          .map(
            (name, index) => `<div role="tabpanel" data-tab-content="${name}"
               id="install-statflow-panel-${name}" ${index === 0 ? '' : 'hidden'}></div>`
          )
          .join('')}
      </div>
    </div>
  `;
  return document.querySelector('[data-install-tabs]');
}

function press(element, key) {
  const event = new window.KeyboardEvent('keydown', { key, bubbles: true, cancelable: true });
  element.dispatchEvent(event);
  return event;
}

describe('installation tabs', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
  });

  it('shows the first panel and marks its tab as selected', () => {
    const container = buildPanel();
    initInstallTabs(container);

    const [pip, conda] = container.querySelectorAll('[data-tab]');
    expect(pip.getAttribute('aria-selected')).toBe('true');
    expect(conda.getAttribute('aria-selected')).toBe('false');
    expect(container.querySelector('[data-tab-content="pip"]').hidden).toBe(false);
    expect(container.querySelector('[data-tab-content="conda"]').hidden).toBe(true);
  });

  it('is one tab stop, not three', () => {
    // The arrow keys move within a tablist; Tab moves past it.
    const container = buildPanel();
    initInstallTabs(container);

    const stops = Array.from(container.querySelectorAll('[data-tab]')).filter((tab) => tab.tabIndex === 0);
    expect(stops).toHaveLength(1);
  });

  it('switches on a click', () => {
    const container = buildPanel();
    initInstallTabs(container);

    container.querySelector('[data-tab="conda"]').click();

    expect(container.querySelector('[data-tab="conda"]').getAttribute('aria-selected')).toBe('true');
    expect(container.querySelector('[data-tab-content="conda"]').hidden).toBe(false);
    expect(container.querySelector('[data-tab-content="pip"]').hidden).toBe(true);
  });

  it('moves with the arrow keys, and wraps', () => {
    const container = buildPanel();
    initInstallTabs(container);
    const [pip, conda, git] = container.querySelectorAll('[data-tab]');

    const right = press(pip, 'ArrowRight');
    expect(right.defaultPrevented).toBe(true);
    expect(conda.getAttribute('aria-selected')).toBe('true');
    expect(document.activeElement).toBe(conda);

    press(conda, 'ArrowRight');
    expect(git.getAttribute('aria-selected')).toBe('true');

    press(git, 'ArrowRight');
    expect(pip.getAttribute('aria-selected')).toBe('true');

    press(pip, 'ArrowLeft');
    expect(git.getAttribute('aria-selected')).toBe('true');
  });

  it('reaches the ends with Home and End', () => {
    const container = buildPanel();
    initInstallTabs(container);
    const [pip, , git] = container.querySelectorAll('[data-tab]');

    press(pip, 'End');
    expect(git.getAttribute('aria-selected')).toBe('true');

    press(git, 'Home');
    expect(pip.getAttribute('aria-selected')).toBe('true');
  });

  it('leaves other keys to the browser', () => {
    const container = buildPanel();
    initInstallTabs(container);
    const pip = container.querySelector('[data-tab]');

    expect(press(pip, 'Tab').defaultPrevented).toBe(false);
  });

  it('wires nothing when there are no tabs', () => {
    document.body.innerHTML = '<div data-install-tabs></div>';
    expect(initInstallTabs(document.querySelector('[data-install-tabs]'))).toBeNull();
  });

  it('selects without moving focus unless asked', () => {
    const container = buildPanel();
    const tabs = Array.from(container.querySelectorAll('[data-tab]'));
    const panels = Array.from(container.querySelectorAll('[data-tab-content]'));

    selectTab(tabs, panels, tabs[1]);
    expect(document.activeElement).not.toBe(tabs[1]);

    selectTab(tabs, panels, tabs[1], true);
    expect(document.activeElement).toBe(tabs[1]);
  });
});
