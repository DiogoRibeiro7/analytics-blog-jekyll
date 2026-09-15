import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { initCopyButtons } from '../../assets/js/core/copy-buttons.js';

// The citation tools on posts, datasets and projects used to rely on the
// academic bundle for their Copy buttons, which those pages never load.
describe('Copy buttons', () => {
  beforeEach(() => {
    global.navigator.clipboard = { writeText: vi.fn(() => Promise.resolve()) };
    initCopyButtons();
  });

  afterEach(() => {
    delete global.navigator.clipboard;
    document.body.innerHTML = '';
  });

  it('copies the text of the target when a citation button is clicked', () => {
    document.body.innerHTML = `
      <textarea id="bibtex-sample">@article{sample2024}</textarea>
      <button type="button" data-copy-citation data-target="bibtex-sample">Copy</button>
    `;

    document.querySelector('[data-copy-citation]').click();

    expect(navigator.clipboard.writeText).toHaveBeenCalledWith('@article{sample2024}');
  });

  it('handles bibliography buttons and buttons added after it started listening', () => {
    const textarea = document.createElement('textarea');
    textarea.id = 'bibliography';
    textarea.value = 'Doe, J. (2024).';
    const button = document.createElement('button');
    button.dataset.copyBibliography = '';
    button.dataset.target = 'bibliography';
    document.body.append(textarea, button);

    button.click();

    expect(navigator.clipboard.writeText).toHaveBeenCalledWith('Doe, J. (2024).');
  });

  it('confirms the copy on the button', async () => {
    document.body.innerHTML = `
      <textarea id="ris-sample">TY  - JOUR</textarea>
      <button type="button" data-copy-citation data-target="ris-sample">Copy</button>
    `;
    const trigger = document.querySelector('[data-copy-citation]');

    trigger.click();

    await vi.waitFor(() => expect(trigger.textContent).toBe('Copied!'), { timeout: 1000 });
    expect(trigger.dataset.copied).toBe('true');
  });

  it('ignores a button whose target is missing', () => {
    document.body.innerHTML = `
      <button type="button" data-copy-citation data-target="nowhere">Copy</button>
      <button type="button" data-copy-citation>Copy</button>
    `;

    document.querySelectorAll('[data-copy-citation]').forEach((button) => button.click());

    expect(navigator.clipboard.writeText).not.toHaveBeenCalled();
  });

  it('listens once however often it is started', () => {
    initCopyButtons();
    initCopyButtons();
    document.body.innerHTML = `
      <textarea id="endnote-sample">%0 Journal Article</textarea>
      <button type="button" data-copy-citation data-target="endnote-sample">Copy</button>
    `;

    document.querySelector('[data-copy-citation]').click();

    expect(navigator.clipboard.writeText).toHaveBeenCalledTimes(1);
  });
});
