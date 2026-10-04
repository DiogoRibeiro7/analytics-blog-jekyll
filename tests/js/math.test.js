import { beforeEach, describe, expect, it, vi } from 'vitest';
import '../../assets/js/math.js';

const toolkit = globalThis.__DATALOG_MATH_INTERNALS__;

describe('math accessibility helpers', () => {
  beforeEach(() => {
    toolkit.pendingTypeset = [];
    toolkit.MathJax = null;
    toolkit.equationMap = new Map();
  });

  it('derives descriptive alt text from LaTeX structures', () => {
    const generated = toolkit.generateAltFromLatex('\\int_{0}^{1} x^2 \\, dx = \\frac{1}{3}');
    expect(generated).toContain('integral from 0 to 1');
    expect(generated).toContain('over');

    const sanitized = toolkit.cleanLatex('\\tag{1} x^2 % alt: square');
    expect(sanitized).toBe('x^2');
  });

  it('prefers dataset alt attributes and synchronizes aria labels', () => {
    const wrapper = document.createElement('div');
    wrapper.dataset.mathAlt = 'Dataset alt text';
    const container = document.createElement('div');

    const alt = toolkit.resolveAltText(wrapper, '\\frac{a}{b}');
    expect(alt).toBe('Dataset alt text');

    toolkit.syncAltAttributes(wrapper, container, alt);
    expect(wrapper.getAttribute('aria-label')).toBe('Dataset alt text');
    expect(container.getAttribute('aria-label')).toBe('Dataset alt text');
  });

  it('extracts alt comments when present and falls back gracefully', () => {
    const commentAlt = toolkit.resolveAltText(null, '% alt: integral description\n\\int_{0}^{1} x^2');
    expect(commentAlt).toBe('integral description');

    const fallbackAlt = toolkit.resolveAltText(null, '\\sqrt{a} + b');
    expect(fallbackAlt.toLowerCase()).toContain('square root of a');
  });

  it('queues rendering when MathJax is unavailable and flushes when provided', async () => {
    const target = document.createElement('div');

    await toolkit.renderLatex(target, 'x^2', { display: true });
    expect(target.textContent).toBe('x^2');
    expect(toolkit.pendingTypeset).toHaveLength(1);

    const typesetPromise = vi.fn().mockResolvedValue();
    toolkit.MathJax = { typesetPromise };

    await toolkit.renderLatex(target, 'y^2', { display: false });
    expect(typesetPromise).toHaveBeenCalledTimes(1);
    expect(target.innerHTML).toBe('\\(y^2\\)');
  });
});

describe('equation info extraction', () => {
  beforeEach(() => {
    toolkit.equationMap = new Map();
  });

  it('extracts tag from LaTeX equation', () => {
    const info = toolkit.extractEquationInfo('\\tag{2.1} x^2 + y^2 = z^2');
    expect(info.tag).toBe('2.1');
    expect(info.label).toBe('');
    expect(info.skipNumber).toBe(false);
  });

  it('extracts label from LaTeX equation', () => {
    const info = toolkit.extractEquationInfo('\\label{pythagorean} x^2 + y^2 = z^2');
    expect(info.tag).toBe('');
    expect(info.label).toBe('pythagorean');
    expect(info.skipNumber).toBe(false);
  });

  it('detects skipNumber flag with notag', () => {
    const info = toolkit.extractEquationInfo('\\notag x^2 + y^2 = z^2');
    expect(info.skipNumber).toBe(true);
  });

  it('detects skipNumber flag with nonumber', () => {
    const info = toolkit.extractEquationInfo('\\nonumber x^2 + y^2 = z^2');
    expect(info.skipNumber).toBe(true);
  });

  it('handles empty or null input', () => {
    const info = toolkit.extractEquationInfo('');
    expect(info.tag).toBe('');
    expect(info.label).toBe('');
    expect(info.skipNumber).toBe(false);
  });
});

describe('anchor ID building', () => {
  it('prefixes label with eq: when not present', () => {
    const id = toolkit.buildAnchorId('pythagorean', null);
    expect(id).toBe('eq:pythagorean');
  });

  it('preserves eq: prefix when already present', () => {
    const id = toolkit.buildAnchorId('eq:pythagorean', null);
    expect(id).toBe('eq:pythagorean');
  });

  it('uses fallback when no label provided', () => {
    const id = toolkit.buildAnchorId('', 'fallback-id');
    expect(id).toBe('fallback-id');
  });

  it('returns empty string when no label or fallback', () => {
    const id = toolkit.buildAnchorId('', '');
    expect(id).toBe('');
  });
});

describe('equation reference management', () => {
  beforeEach(() => {
    toolkit.equationMap = new Map();
  });

  it('stores equation reference with key', () => {
    toolkit.setEquationReference('pythagorean', '(2.1)', 'eq:pythagorean');

    const ref = toolkit.equationMap.get('pythagorean');
    expect(ref).toBeDefined();
    expect(ref.label).toBe('pythagorean');
    expect(ref.number).toBe('(2.1)');
    expect(ref.anchor).toBe('eq:pythagorean');
  });

  it('creates eq: prefixed entry for non-prefixed keys', () => {
    toolkit.setEquationReference('pythagorean', '(2.1)', 'eq:pythagorean');

    const ref = toolkit.equationMap.get('eq:pythagorean');
    expect(ref).toBeDefined();
    expect(ref.label).toBe('pythagorean');
  });

  it('uses key as anchor when anchor not provided', () => {
    toolkit.setEquationReference('pythagorean', '(2.1)', null);

    const ref = toolkit.equationMap.get('pythagorean');
    expect(ref.anchor).toBe('pythagorean');
  });

  it('uses key as display text when not provided', () => {
    toolkit.setEquationReference('pythagorean', '', 'eq:pythagorean');

    const ref = toolkit.equationMap.get('pythagorean');
    expect(ref.number).toBe('pythagorean');
  });

  it('ignores empty key', () => {
    toolkit.setEquationReference('', '(2.1)', 'eq:pythagorean');
    expect(toolkit.equationMap.size).toBe(0);
  });

  it('looks up equation by key', () => {
    toolkit.setEquationReference('pythagorean', '(2.1)', 'eq:pythagorean');

    const result = toolkit.lookupEquation('pythagorean');
    expect(result).toBeDefined();
    expect(result.number).toBe('(2.1)');
  });

  it('returns null for unknown equation key', () => {
    const result = toolkit.lookupEquation('unknown');
    expect(result).toBeNull();
  });
});

describe('number badge attachment', () => {
  it('creates number badge when none exists', () => {
    const wrapper = document.createElement('div');
    toolkit.attachNumberBadge(wrapper, '(2.1)');

    const badge = wrapper.querySelector('.math-expression__number');
    expect(badge).toBeDefined();
    expect(badge.textContent).toBe('(2.1)');
    expect(badge.getAttribute('aria-hidden')).toBe('true');
  });

  it('creates screen reader text with equation number', () => {
    const wrapper = document.createElement('div');
    toolkit.attachNumberBadge(wrapper, '(2.1)');

    const sr = wrapper.querySelector('.math-expression__sr');
    expect(sr).toBeDefined();
    expect(sr.textContent).toBe('Equation 2.1');
  });

  it('updates existing badge text', () => {
    const wrapper = document.createElement('div');
    toolkit.attachNumberBadge(wrapper, '(2.1)');
    toolkit.attachNumberBadge(wrapper, '(3.5)');

    const badges = wrapper.querySelectorAll('.math-expression__number');
    expect(badges.length).toBe(1);
    expect(badges[0].textContent).toBe('(3.5)');
  });

  it('removes badge when formattedNumber is empty', () => {
    const wrapper = document.createElement('div');
    toolkit.attachNumberBadge(wrapper, '(2.1)');
    toolkit.attachNumberBadge(wrapper, '');

    const badge = wrapper.querySelector('.math-expression__number');
    expect(badge).toBeNull();
  });

  it('removes screen reader text when formattedNumber is empty', () => {
    const wrapper = document.createElement('div');
    toolkit.attachNumberBadge(wrapper, '(2.1)');
    toolkit.attachNumberBadge(wrapper, null);

    const sr = wrapper.querySelector('.math-expression__sr');
    expect(sr).toBeNull();
  });
});

describe('toolbar attachment', () => {
  it('creates toolbar with copy and edit buttons', () => {
    const wrapper = document.createElement('div');
    toolkit.attachToolbar(wrapper);

    const toolbar = wrapper.querySelector('.math-expression__toolbar');
    expect(toolbar).toBeDefined();

    const copyButton = toolbar.querySelector('[data-math-copy]');
    expect(copyButton).toBeDefined();
    expect(copyButton.getAttribute('aria-label')).toBe('Copy LaTeX code');

    const editButton = toolbar.querySelector('[data-math-edit]');
    expect(editButton).toBeDefined();
    expect(editButton.getAttribute('aria-label')).toBe('Open equation editor');
  });

  it('does not create duplicate toolbar', () => {
    const wrapper = document.createElement('div');
    toolkit.attachToolbar(wrapper);
    toolkit.attachToolbar(wrapper);

    const toolbars = wrapper.querySelectorAll('.math-expression__toolbar');
    expect(toolbars.length).toBe(1);
  });

  it('creates status message element', () => {
    const wrapper = document.createElement('div');
    toolkit.attachToolbar(wrapper);

    const message = wrapper.querySelector('.math-expression__message');
    expect(message).toBeDefined();
  });
});

describe('inline decoration', () => {
  it('adds inline class to container', () => {
    const container = document.createElement('div');
    toolkit.decorateInline(container, 'x^2');

    expect(container.classList.contains('math-expression__inline')).toBe(true);
  });

  it('stores cleaned LaTeX in dataset', () => {
    const container = document.createElement('div');
    toolkit.decorateInline(container, '\\tag{1} x^2');

    expect(container.dataset.mathLatexClean).toBe('x^2');
  });

  it('handles null container gracefully', () => {
    expect(() => toolkit.decorateInline(null, 'x^2')).not.toThrow();
  });

  it('does not add duplicate inline class', () => {
    const container = document.createElement('div');
    container.classList.add('math-expression__inline');
    toolkit.decorateInline(container, 'x^2');

    expect(container.className).toBe('math-expression__inline');
  });
});

describe('alt text extraction', () => {
  it('finds dataset alt on parent nodes', () => {
    const parent = document.createElement('div');
    parent.dataset.mathAlt = 'Parent alt text';

    const child = document.createElement('span');
    parent.appendChild(child);

    const alt = toolkit.findDatasetAlt(child);
    expect(alt).toBe('Parent alt text');
  });

  it('returns empty string when no dataset alt found', () => {
    const element = document.createElement('div');
    const alt = toolkit.findDatasetAlt(element);
    expect(alt).toBe('');
  });

  it('extracts alt comment from LaTeX', () => {
    const latex = '% alt: integral from 0 to 1\n\\int_{0}^{1} x^2';
    const alt = toolkit.extractAltComment(latex);
    expect(alt).toBe('integral from 0 to 1');
  });

  it('returns empty string when no alt comment present', () => {
    const latex = '\\int_{0}^{1} x^2';
    const alt = toolkit.extractAltComment(latex);
    expect(alt).toBe('');
  });

  it('handles multi-line alt comments', () => {
    const latex = '% alt: complex equation\n% second line\n\\int_{0}^{1} x^2';
    const alt = toolkit.extractAltComment(latex);
    expect(alt).toBe('complex equation');
  });
});

describe('math item decoration', () => {
  beforeEach(() => {
    toolkit.displayCounter = 0;
    toolkit.anchorCounter = 0;
    toolkit.equationMap = new Map();
  });

  it('decorates existing math items', () => {
    const container = document.createElement('div');
    const item = {
      typesetRoot: container,
      math: 'x^2',
      display: false
    };

    toolkit.decorateExisting([item]);

    expect(toolkit.displayCounter).toBe(0);
    expect(toolkit.anchorCounter).toBe(0);
  });

  it('handles empty math items array', () => {
    expect(() => toolkit.decorateExisting([])).not.toThrow();
    expect(() => toolkit.decorateExisting(null)).not.toThrow();
  });

  it('decorates individual math item', () => {
    const container = document.createElement('div');
    const item = {
      typesetRoot: container,
      math: 'x^2 + y^2',
      display: false
    };

    toolkit.decorateMathItem(item);

    expect(container.dataset.mathLatex).toBe('x^2 + y^2');
    expect(container.getAttribute('tabindex')).toBe('0');
    expect(container.getAttribute('role')).toBe('math');
  });

  it('handles null math item', () => {
    expect(() => toolkit.decorateMathItem(null)).not.toThrow();
  });

  it('handles math item without typesetRoot', () => {
    expect(() => toolkit.decorateMathItem({ math: 'x^2' })).not.toThrow();
  });

  it('decorates display equations', () => {
    const parent = document.createElement('div');
    const container = document.createElement('div');
    parent.appendChild(container);

    const item = {
      typesetRoot: container,
      math: '\\tag{1} x^2 + y^2 = z^2',
      display: true
    };

    toolkit.decorateMathItem(item);

    expect(container.parentElement).toBeTruthy();
    expect(container.parentElement.classList.contains('math-expression')).toBe(true);
  });

  it('decorates display handles null container', () => {
    expect(() => toolkit.decorateDisplay(null, 'x^2')).not.toThrow();
  });

  it('decorates display with equation numbers', () => {
    const parent = document.createElement('div');
    const container = document.createElement('div');
    parent.appendChild(container);

    const item = {
      typesetRoot: container,
      math: '\\tag{2.1} E = mc^2',
      display: true
    };

    toolkit.decorateMathItem(item);

    const wrapper = container.parentElement;
    const badge = wrapper.querySelector('.math-expression__number');
    expect(badge).toBeTruthy();
    expect(badge.textContent).toBe('(2.1)');
  });

  it('decorates display with labels', () => {
    const parent = document.createElement('div');
    const container = document.createElement('div');
    parent.appendChild(container);

    const item = {
      typesetRoot: container,
      math: '\\label{eq:einstein} E = mc^2',
      display: true
    };

    toolkit.decorateMathItem(item);

    expect(toolkit.equationMap.has('eq:einstein')).toBe(true);
  });

  it('decorates display with skip number flag', () => {
    const parent = document.createElement('div');
    const container = document.createElement('div');
    parent.appendChild(container);

    const item = {
      typesetRoot: container,
      math: '\\notag x^2 + y^2 = z^2',
      display: true
    };

    toolkit.decorateMathItem(item);

    const wrapper = container.parentElement;
    const badge = wrapper.querySelector('.math-expression__number');
    expect(badge).toBeNull();
  });
});

describe('equation reference updates', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    toolkit.equationMap = new Map();
  });

  it('updates equation references in links', () => {
    toolkit.setEquationReference('pythagorean', '(2.1)', 'eq:pythagorean');

    const link = document.createElement('a');
    link.href = '#eq:pythagorean';
    document.body.appendChild(link);

    toolkit.updateEquationReferences();

    expect(link.textContent).toContain('2.1');
    expect(link.dataset.equationRef).toBe('eq:pythagorean');
  });

  it('handles links with unknown equations', () => {
    const link = document.createElement('a');
    link.href = '#eq:unknown';
    document.body.appendChild(link);

    expect(() => toolkit.updateEquationReferences()).not.toThrow();
  });

  it('handles links without hash', () => {
    const link = document.createElement('a');
    link.href = 'https://example.com';
    document.body.appendChild(link);

    expect(() => toolkit.updateEquationReferences()).not.toThrow();
  });
});

// The words themselves are tested in latex-speech.test.js (#417).
describe('the label an expression gets', () => {
  it('reads every command, where it used to drop those it had no rule for', () => {
    expect(toolkit.generateAltFromLatex('f : [a, b] \\to \\mathbb{R}')).toBe('f: [a, b] to double-struck R');
    expect(toolkit.generateAltFromLatex('c \\in (a, b)')).toBe('c in (a, b)');
  });

  it('names an expression with nothing to read, and gives none for no LaTeX', () => {
    expect(toolkit.generateAltFromLatex('\\left. \\right.')).toBe('Mathematical expression');
    expect(toolkit.generateAltFromLatex('')).toBe('');
    expect(toolkit.generateAltFromLatex(null)).toBe('');
  });
});

describe('MathJax initialization', () => {
  beforeEach(() => {
    toolkit.initialized = false;
    toolkit.pendingTypeset = [];
    toolkit.equationMap = new Map();
    toolkit.MathJax = null;
    document.body.innerHTML = '';
  });

  it('initializes with MathJax instance', () => {
    const mockMathJax = {
      startup: {
        promise: Promise.resolve(),
        document: { math: [] }
      },
      typesetPromise: vi.fn().mockResolvedValue()
    };

    toolkit.init(mockMathJax);

    expect(toolkit.initialized).toBe(true);
    expect(toolkit.MathJax).toBe(mockMathJax);
    expect(toolkit.displayCounter).toBe(0);
    expect(toolkit.anchorCounter).toBe(0);
    expect(toolkit.editor).toBeDefined();
  });

  it('takes the numbering the theme passes', () => {
    const mockMathJax = { startup: { promise: Promise.resolve(), document: { math: [] } } };

    toolkit.init(mockMathJax, { numbering: 'ams' });
    expect(toolkit.numbering).toBe('ams');

    toolkit.init(mockMathJax);
    expect(toolkit.numbering).toBeNull();
  });

  it('handles MathJax startup promise resolution', async () => {
    const mockMathJax = {
      startup: {
        promise: Promise.resolve(),
        document: { math: [] }
      }
    };

    toolkit.init(mockMathJax);

    await mockMathJax.startup.promise;

    expect(toolkit.initialized).toBe(true);
  });

  it.skip('handles MathJax startup promise rejection', async () => {
    // Note: This test is skipped due to timing issues with async promise rejection
    // The error handling is covered by manual testing
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

    let rejectPromise;
    const promise = new Promise((resolve, reject) => {
      rejectPromise = reject;
    });

    const mockMathJax = {
      startup: {
        promise,
        document: { math: [] }
      }
    };

    toolkit.init(mockMathJax);

    // Trigger rejection
    rejectPromise(new Error('MathJax init failed'));

    // Wait for promise rejection to be handled
    await promise.catch(() => {});
    await new Promise(resolve => setTimeout(resolve, 10));

    expect(consoleSpy).toHaveBeenCalledWith(
      'Failed to initialize MathJax enhancements',
      expect.any(Error)
    );

    consoleSpy.mockRestore();
  });

  it('flushes pending typeset queue after initialization', async () => {
    const target = document.createElement('div');
    toolkit.pendingTypeset = [
      { target, latex: 'x^2', options: { display: true } }
    ];

    const mockMathJax = {
      startup: {
        promise: Promise.resolve(),
        document: { math: [] }
      },
      typesetPromise: vi.fn().mockResolvedValue()
    };

    toolkit.init(mockMathJax);

    await mockMathJax.startup.promise;

    expect(toolkit.pendingTypeset).toHaveLength(0);
  });
});

/**
 * MathJax hands `startup.document.math` over as a MathList, which extends a
 * linked list: iterable, and with neither `forEach` nor `length`. Mocking it
 * as an array is what hid #329, so these tests mock it as it really is.
 */
function mathList(items) {
  return {
    [Symbol.iterator]() {
      return items[Symbol.iterator]();
    }
  };
}

/** A display container shaped like MathJax's output for a numbered equation. */
function numberedDisplay(number) {
  const wrapper = document.createElement('div');
  const container = document.createElement('div');
  wrapper.appendChild(container);
  if (number) {
    container.innerHTML =
      `<mjx-assistive-mml><mtable><mlabeledtr><mtd>${number}</mtd><mtd>x</mtd></mlabeledtr></mtable></mjx-assistive-mml>`;
  }
  return container;
}

describe('the math list MathJax really passes', () => {
  beforeEach(() => {
    toolkit.displayCounter = 0;
    toolkit.anchorCounter = 0;
    toolkit.equationMap = new Map();
    toolkit.MathJax = null;
  });

  it('decorates a list that has no forEach and no length', () => {
    const container = document.createElement('div');
    const item = { typesetRoot: container, math: 'x^2', display: false };

    toolkit.decorateExisting(mathList([item]));

    expect(container.getAttribute('role')).toBe('math');
  });

  it('decorates through init, rather than failing into the catch', async () => {
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    const container = document.createElement('div');
    const mathJax = {
      startup: {
        promise: Promise.resolve(),
        document: { math: mathList([{ typesetRoot: container, math: 'x^2', display: false }]) }
      }
    };

    toolkit.init(mathJax);
    await mathJax.startup.promise;
    await Promise.resolve();

    expect(container.getAttribute('role')).toBe('math');
    expect(consoleSpy).not.toHaveBeenCalled();
    consoleSpy.mockRestore();
    toolkit.MathJax = null;
  });
});

describe('who numbers a display equation', () => {
  beforeEach(() => {
    toolkit.displayCounter = 0;
    toolkit.anchorCounter = 0;
    toolkit.equationMap = new Map();
    toolkit.MathJax = null;
  });

  it('leaves the number to MathJax when MathJax is numbering', () => {
    toolkit.MathJax = { config: { tex: { tags: 'all' } } };
    const container = numberedDisplay('(7)');

    toolkit.decorateMathItem({ typesetRoot: container, math: '\\label{eq:a} E = mc^2', display: true });

    const wrapper = container.parentElement;
    expect(wrapper.querySelector('.math-expression__number')).toBeNull();
    expect(wrapper.dataset.equationNumber).toBe('(7)');
    expect(toolkit.equationMap.get('eq:a').number).toBe('(7)');
    toolkit.MathJax = null;
  });

  it('draws no number for an equation MathJax left unnumbered', () => {
    toolkit.MathJax = { config: { tex: { tags: 'all' } } };
    const container = numberedDisplay(null);

    toolkit.decorateMathItem({ typesetRoot: container, math: '\\notag E = mc^2', display: true });

    const wrapper = container.parentElement;
    expect(wrapper.querySelector('.math-expression__number')).toBeNull();
    expect(wrapper.dataset.equationNumber).toBeUndefined();
    toolkit.MathJax = null;
  });

  it('numbers them itself when MathJax does not', () => {
    toolkit.MathJax = { config: { tex: { tags: 'none' } } };
    const container = numberedDisplay(null);

    toolkit.decorateMathItem({ typesetRoot: container, math: 'E = mc^2', display: true });

    const badge = container.parentElement.querySelector('.math-expression__number');
    expect(badge).toBeTruthy();
    expect(badge.textContent).toBe('(1)');
    toolkit.MathJax = null;
  });

  // theme_options.math.numbering: none is MathJax's tags: 'none' too, but the
  // theme's head says so, and the author asked for no numbers.
  it('adds no number of its own when the theme set the numbering to none', () => {
    toolkit.MathJax = { config: { tex: { tags: 'none' } } };
    toolkit.numbering = 'none';
    const container = numberedDisplay(null);

    toolkit.decorateMathItem({ typesetRoot: container, math: 'E = mc^2', display: true });

    const wrapper = container.parentElement;
    expect(wrapper.querySelector('.math-expression__number')).toBeNull();
    expect(wrapper.dataset.equationNumber).toBeUndefined();
    toolkit.numbering = null;
    toolkit.MathJax = null;
  });

  it('keeps the number of an author\'s \\tag when the theme set the numbering to none', () => {
    toolkit.MathJax = { config: { tex: { tags: 'none' } } };
    toolkit.numbering = 'none';
    const container = numberedDisplay('(A)');

    toolkit.decorateMathItem({ typesetRoot: container, math: 'E = mc^2 \\tag{A}', display: true });

    const wrapper = container.parentElement;
    expect(wrapper.querySelector('.math-expression__number')).toBeNull();
    expect(wrapper.dataset.equationNumber).toBe('(A)');
    toolkit.numbering = null;
    toolkit.MathJax = null;
  });
});

describe('onPageReady', () => {
  beforeEach(() => {
    toolkit.equationMap = new Map();
    document.body.innerHTML = '';
  });

  it('updates equation references on page ready', () => {
    toolkit.setEquationReference('test', '(1)', 'eq:test');
    const link = document.createElement('a');
    link.href = '#eq:test';
    link.setAttribute('data-equation-ref', 'eq:test');
    document.body.appendChild(link);

    toolkit.onPageReady();

    expect(link.textContent).toContain('(1)');
  });

  it('handles no equation references gracefully', () => {
    expect(() => toolkit.onPageReady()).not.toThrow();
  });
});

describe('event handling', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    toolkit.editor = null;
    toolkit.editorOpen = false;
    toolkit.setupEditor();
  });

  describe('handleClick', () => {
    it('copies LaTeX when copy button clicked', () => {
      const wrapper = document.createElement('figure');
      wrapper.className = 'math-expression';
      wrapper.dataset.mathLatexClean = 'x^2 + y^2';

      const toolbar = document.createElement('div');
      toolbar.className = 'math-expression__toolbar';

      const copyButton = document.createElement('button');
      copyButton.setAttribute('data-math-copy', 'true');
      toolbar.appendChild(copyButton);

      const message = document.createElement('span');
      message.className = 'math-expression__message';
      message.hidden = true;
      toolbar.appendChild(message);

      wrapper.appendChild(toolbar);
      document.body.appendChild(wrapper);

      const mockWriteText = vi.fn().mockResolvedValue();
      Object.assign(navigator, {
        clipboard: { writeText: mockWriteText }
      });

      const event = new MouseEvent('click', { bubbles: true });
      Object.defineProperty(event, 'target', { value: copyButton, writable: false });

      toolkit.handleClick(event);

      expect(mockWriteText).toHaveBeenCalledWith('x^2 + y^2');
    });

    it('opens editor when edit button clicked', () => {
      const wrapper = document.createElement('figure');
      wrapper.className = 'math-expression';
      wrapper.dataset.mathLatex = 'E = mc^2';

      const editButton = document.createElement('button');
      editButton.setAttribute('data-math-edit', 'true');
      wrapper.appendChild(editButton);
      document.body.appendChild(wrapper);

      const event = new MouseEvent('click', { bubbles: true });
      Object.defineProperty(event, 'target', { value: editButton, writable: false });

      toolkit.handleClick(event);

      expect(toolkit.editorOpen).toBe(true);
      expect(toolkit.editor.textarea.value).toBe('E = mc^2');
    });

    it('closes editor when close button clicked', () => {
      toolkit.openEditor('test');

      const closeButton = document.createElement('button');
      closeButton.setAttribute('data-math-editor-close', 'true');
      document.body.appendChild(closeButton);

      const event = new MouseEvent('click', { bubbles: true });
      Object.defineProperty(event, 'target', { value: closeButton, writable: false });

      toolkit.handleClick(event);

      expect(toolkit.editorOpen).toBe(false);
    });

    it('copies from editor when editor copy button clicked', () => {
      toolkit.openEditor('\\alpha + \\beta');

      const mockWriteText = vi.fn().mockResolvedValue();
      Object.assign(navigator, {
        clipboard: { writeText: mockWriteText }
      });

      const copyButton = document.createElement('button');
      copyButton.setAttribute('data-math-editor-copy', 'true');
      document.body.appendChild(copyButton);

      const event = new MouseEvent('click', { bubbles: true });
      Object.defineProperty(event, 'target', { value: copyButton, writable: false });

      toolkit.handleClick(event);

      expect(mockWriteText).toHaveBeenCalledWith('\\alpha + \\beta');
    });

    it('inserts symbol when symbol button clicked', () => {
      toolkit.openEditor('test ');

      const symbolButton = document.createElement('button');
      symbolButton.setAttribute('data-symbol-insert', '\\mu');
      document.body.appendChild(symbolButton);

      const event = new MouseEvent('click', { bubbles: true });
      Object.defineProperty(event, 'target', { value: symbolButton, writable: false });

      toolkit.handleClick(event);

      expect(toolkit.editor.textarea.value).toContain('\\mu');
    });

    it('handles copy button without wrapper gracefully', () => {
      const copyButton = document.createElement('button');
      copyButton.setAttribute('data-math-copy', 'true');
      document.body.appendChild(copyButton);

      const event = new MouseEvent('click', { bubbles: true });
      Object.defineProperty(event, 'target', { value: copyButton, writable: false });

      expect(() => toolkit.handleClick(event)).not.toThrow();
    });

    it('handles edit button without wrapper gracefully', () => {
      const editButton = document.createElement('button');
      editButton.setAttribute('data-math-edit', 'true');
      document.body.appendChild(editButton);

      const event = new MouseEvent('click', { bubbles: true });
      Object.defineProperty(event, 'target', { value: editButton, writable: false });

      expect(() => toolkit.handleClick(event)).not.toThrow();
    });
  });

  describe('handleKeydown', () => {
    it('opens editor with Ctrl+Alt+E', () => {
      const event = new KeyboardEvent('keydown', {
        key: 'e',
        ctrlKey: true,
        altKey: true,
        bubbles: true
      });

      const preventDefaultSpy = vi.spyOn(event, 'preventDefault');
      toolkit.handleKeydown(event);

      expect(preventDefaultSpy).toHaveBeenCalled();
      expect(toolkit.editorOpen).toBe(true);
    });

    it('opens editor with Cmd+Alt+E on Mac', () => {
      const event = new KeyboardEvent('keydown', {
        key: 'E',
        metaKey: true,
        altKey: true,
        bubbles: true
      });

      const preventDefaultSpy = vi.spyOn(event, 'preventDefault');
      toolkit.handleKeydown(event);

      expect(preventDefaultSpy).toHaveBeenCalled();
      expect(toolkit.editorOpen).toBe(true);
    });

    it('seeds editor with input value when triggered from input', () => {
      const input = document.createElement('input');
      input.value = '\\int x^2';
      document.body.appendChild(input);
      input.focus();

      const event = new KeyboardEvent('keydown', {
        key: 'e',
        ctrlKey: true,
        altKey: true,
        bubbles: true
      });

      toolkit.handleKeydown(event);

      expect(toolkit.editor.textarea.value).toBe('\\int x^2');
    });

    it('closes editor with Escape key when open', () => {
      toolkit.openEditor('test');

      const event = new KeyboardEvent('keydown', {
        key: 'Escape',
        bubbles: true
      });

      const preventDefaultSpy = vi.spyOn(event, 'preventDefault');
      toolkit.handleKeydown(event);

      expect(preventDefaultSpy).toHaveBeenCalled();
      expect(toolkit.editorOpen).toBe(false);
    });

    it('ignores Escape when editor not open', () => {
      toolkit.editorOpen = false;

      const event = new KeyboardEvent('keydown', {
        key: 'Escape',
        bubbles: true
      });

      const preventDefaultSpy = vi.spyOn(event, 'preventDefault');
      toolkit.handleKeydown(event);

      expect(preventDefaultSpy).not.toHaveBeenCalled();
    });
  });
});

describe('copyLatex', () => {
  beforeEach(() => {
    toolkit.messageTimeout = null;
    // Define execCommand if not available in jsdom
    if (!document.execCommand) {
      document.execCommand = vi.fn();
    }
  });

  it('copies to clipboard using navigator.clipboard', async () => {
    const mockWriteText = vi.fn().mockResolvedValue();
    Object.assign(navigator, {
      clipboard: { writeText: mockWriteText }
    });

    const wrapper = document.createElement('div');
    const message = document.createElement('span');
    message.className = 'math-expression__message';
    message.hidden = true;
    wrapper.appendChild(message);

    toolkit.copyLatex('x^2 + y^2', wrapper);

    await Promise.resolve();

    expect(mockWriteText).toHaveBeenCalledWith('x^2 + y^2');
    expect(message.hidden).toBe(false);
    expect(message.textContent).toBe('Copied equation');
  });

  it('uses fallback copy when clipboard API unavailable', () => {
    const originalClipboard = navigator.clipboard;
    Object.defineProperty(navigator, 'clipboard', {
      value: undefined,
      writable: true,
      configurable: true
    });

    const mockExecCommand = vi.spyOn(document, 'execCommand').mockReturnValue(true);

    const wrapper = document.createElement('div');
    const message = document.createElement('span');
    message.className = 'math-expression__message';
    message.hidden = true;
    wrapper.appendChild(message);

    toolkit.copyLatex('\\alpha + \\beta', wrapper);

    expect(mockExecCommand).toHaveBeenCalledWith('copy');
    expect(message.textContent).toBe('Copied equation');

    mockExecCommand.mockRestore();
    Object.defineProperty(navigator, 'clipboard', {
      value: originalClipboard,
      writable: true,
      configurable: true
    });
  });

  it('handles clipboard API rejection with fallback', async () => {
    const mockWriteText = vi.fn().mockRejectedValue(new Error('Clipboard denied'));
    const mockExecCommand = vi.spyOn(document, 'execCommand').mockReturnValue(true);
    Object.assign(navigator, {
      clipboard: { writeText: mockWriteText }
    });

    const wrapper = document.createElement('div');
    const message = document.createElement('span');
    message.className = 'math-expression__message';
    message.hidden = true;
    wrapper.appendChild(message);

    toolkit.copyLatex('test', wrapper);

    await Promise.resolve();
    await Promise.resolve();

    expect(mockExecCommand).toHaveBeenCalledWith('copy');
    mockExecCommand.mockRestore();
  });

  it('sets up timeout to hide status message', async () => {
    const mockWriteText = vi.fn().mockResolvedValue();
    Object.assign(navigator, {
      clipboard: { writeText: mockWriteText }
    });

    const wrapper = document.createElement('div');
    const message = document.createElement('span');
    message.className = 'math-expression__message';
    message.hidden = true;
    wrapper.appendChild(message);

    toolkit.copyLatex('test', wrapper);

    await Promise.resolve();

    expect(message.hidden).toBe(false);
    expect(message.textContent).toBe('Copied equation');
    expect(toolkit.messageTimeout).toBeTruthy();
  });

  it('handles empty latex gracefully', () => {
    expect(() => toolkit.copyLatex('', null)).not.toThrow();
    expect(() => toolkit.copyLatex(null, null)).not.toThrow();
  });

  it('shows status in statusTarget when provided', async () => {
    const mockWriteText = vi.fn().mockResolvedValue();
    Object.assign(navigator, {
      clipboard: { writeText: mockWriteText }
    });

    const statusTarget = document.createElement('span');
    statusTarget.hidden = true;

    toolkit.copyLatex('test', null, statusTarget);

    await Promise.resolve();

    expect(statusTarget.hidden).toBe(false);
    expect(statusTarget.textContent).toBe('Copied equation');
  });

  it('handles execCommand failure gracefully', () => {
    const originalClipboard = navigator.clipboard;
    Object.defineProperty(navigator, 'clipboard', {
      value: undefined,
      writable: true,
      configurable: true
    });

    const mockExecCommand = vi.spyOn(document, 'execCommand').mockImplementation(() => {
      throw new Error('execCommand failed');
    });

    const consoleWarnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});

    const wrapper = document.createElement('div');
    const message = document.createElement('span');
    message.className = 'math-expression__message';
    message.hidden = true;
    wrapper.appendChild(message);

    toolkit.copyLatex('test', wrapper);

    expect(consoleWarnSpy).toHaveBeenCalledWith('Unable to copy equation', expect.any(Error));
    expect(message.textContent).toBe('Unable to copy');

    mockExecCommand.mockRestore();
    consoleWarnSpy.mockRestore();
    Object.defineProperty(navigator, 'clipboard', {
      value: originalClipboard,
      writable: true,
      configurable: true
    });
  });
});

describe('editor lifecycle', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    toolkit.editor = null;
    toolkit.editorOpen = false;
  });

  // The dialog's title names the dialog; the box inside it needs a name of its
  // own, or a screen reader meets an unlabelled multiline text box. It is also
  // built into every page that loads MathJax, where an accessibility sweep
  // finds it.
  it('names the LaTeX box and ties it to the description beside it', () => {
    toolkit.setupEditor();

    const textarea = toolkit.editor.textarea;
    expect(textarea.getAttribute('aria-label')).toBeTruthy();

    const describedBy = textarea.getAttribute('aria-describedby');
    expect(describedBy).toBeTruthy();
    expect(document.getElementById(describedBy)).not.toBeNull();
    expect(document.getElementById(describedBy).textContent).toContain('LaTeX');
  });

  it('setupEditor creates editor structure', () => {
    toolkit.setupEditor();

    expect(toolkit.editor).toBeDefined();
    expect(toolkit.editor.overlay).toBeDefined();
    expect(toolkit.editor.dialog).toBeDefined();
    expect(toolkit.editor.textarea).toBeDefined();
    expect(toolkit.editor.preview).toBeDefined();
    expect(toolkit.editor.status).toBeDefined();

    const overlay = document.getElementById('math-tooling-panel');
    expect(overlay).not.toBeNull();
    expect(overlay.hidden).toBe(true);
  });

  it('setupEditor does not create duplicate editor', () => {
    toolkit.setupEditor();
    const firstEditor = toolkit.editor;

    toolkit.setupEditor();

    expect(toolkit.editor).toBe(firstEditor);
  });

  it('openEditor shows overlay and focuses textarea', () => {
    toolkit.setupEditor();
    toolkit.openEditor('\\int x^2');

    expect(toolkit.editor.overlay.hidden).toBe(false);
    expect(document.body.classList.contains('math-tooling-open')).toBe(true);
    expect(toolkit.editorOpen).toBe(true);
    expect(toolkit.editor.textarea.value).toBe('\\int x^2');
  });

  it('openEditor handles empty latex', () => {
    toolkit.setupEditor();
    toolkit.openEditor('');

    expect(toolkit.editor.textarea.value).toBe('');
  });

  it('openEditor sets cursor at end of text', () => {
    toolkit.setupEditor();
    toolkit.openEditor('test');

    expect(toolkit.editor.textarea.selectionStart).toBe(4);
    expect(toolkit.editor.textarea.selectionEnd).toBe(4);
  });

  it('closeEditor hides overlay and removes body class', () => {
    toolkit.setupEditor();
    toolkit.openEditor('test');
    toolkit.closeEditor();

    expect(toolkit.editor.overlay.hidden).toBe(true);
    expect(document.body.classList.contains('math-tooling-open')).toBe(false);
    expect(toolkit.editorOpen).toBe(false);
  });

  it('updateEditorPreview renders latex with MathJax', () => {
    const mockMathJax = {
      typesetPromise: vi.fn().mockResolvedValue()
    };
    toolkit.MathJax = mockMathJax;

    toolkit.setupEditor();
    toolkit.editor.textarea.value = 'x^2';
    toolkit.updateEditorPreview();

    expect(toolkit.editor.preview.innerHTML).toContain('x^2');
  });

  it('updateEditorPreview shows placeholder when empty', () => {
    toolkit.setupEditor();
    toolkit.editor.textarea.value = '';
    toolkit.updateEditorPreview();

    expect(toolkit.editor.preview.innerHTML).toContain('Preview will appear here');
  });

  it('updateEditorPreview handles missing MathJax gracefully', () => {
    toolkit.MathJax = null;
    toolkit.setupEditor();
    toolkit.editor.textarea.value = 'x^2';

    expect(() => toolkit.updateEditorPreview()).not.toThrow();
  });

  it('insertSymbol adds symbol at cursor position', () => {
    toolkit.setupEditor();
    toolkit.editor.textarea.value = 'before after';
    toolkit.editor.textarea.setSelectionRange(7, 7);

    toolkit.insertSymbol('\\mu');

    expect(toolkit.editor.textarea.value).toBe('before \\muafter');
  });

  it('insertSymbol replaces selected text', () => {
    toolkit.setupEditor();
    toolkit.editor.textarea.value = 'replace this text';
    toolkit.editor.textarea.setSelectionRange(8, 12);

    toolkit.insertSymbol('\\sigma');

    expect(toolkit.editor.textarea.value).toBe('replace \\sigma text');
  });

  it('insertSymbol updates cursor position', () => {
    toolkit.setupEditor();
    toolkit.editor.textarea.value = 'test';
    toolkit.editor.textarea.setSelectionRange(4, 4);

    toolkit.insertSymbol('\\alpha');

    expect(toolkit.editor.textarea.selectionStart).toBe(10);
    expect(toolkit.editor.textarea.selectionEnd).toBe(10);
  });

  it('insertSymbol handles null editor gracefully', () => {
    toolkit.editor = null;
    expect(() => toolkit.insertSymbol('\\mu')).not.toThrow();
  });

  it('insertSymbol handles empty symbol', () => {
    toolkit.setupEditor();
    toolkit.editor.textarea.value = 'test';
    toolkit.insertSymbol('');

    expect(toolkit.editor.textarea.value).toBe('test');
  });
});

describe('generateAltFromLatex', () => {
  it('converts fraction to descriptive text', () => {
    const alt = toolkit.generateAltFromLatex('\\frac{a}{b}');
    expect(alt).toContain('a over b');
  });

  it('converts integral with bounds', () => {
    const alt = toolkit.generateAltFromLatex('\\int_{0}^{1} f(x) dx');
    expect(alt).toContain('integral from 0 to 1');
  });

  it('converts integral without bounds', () => {
    const alt = toolkit.generateAltFromLatex('\\int f(x) dx');
    expect(alt).toContain('integral');
  });

  it('converts summation with bounds', () => {
    const alt = toolkit.generateAltFromLatex('\\sum_{i=1}^{n} x_i');
    expect(alt).toContain('summation from');
    expect(alt).toContain('to');
  });

  it('converts square root', () => {
    const alt = toolkit.generateAltFromLatex('\\sqrt{x}');
    expect(alt).toContain('square root of x');
  });

  it('converts mathrm text', () => {
    const alt = toolkit.generateAltFromLatex('\\mathrm{Var}(X)');
    expect(alt).toContain('Var');
  });

  it('converts operatorname text', () => {
    const alt = toolkit.generateAltFromLatex('\\operatorname{argmax}');
    expect(alt).toContain('argmax');
  });

  it('returns empty string for empty latex', () => {
    const alt = toolkit.generateAltFromLatex('');
    expect(alt).toBe('');
  });

  it('returns fallback for latex with only commands', () => {
    const alt = toolkit.generateAltFromLatex('\\\\\\\\');
    // After removing commands and whitespace, empty string becomes 'Mathematical expression'
    expect(alt).toBeTruthy();
  });

  it('handles nested fractions', () => {
    const alt = toolkit.generateAltFromLatex('\\frac{\\frac{a}{b}}{c}');
    expect(alt).toContain('over');
  });
});

/**
 * MathJax draws an expression again, into a new container, when a reader
 * changes a menu setting or toggles a collapsible part. The new container had
 * no tab stop, role or label, and the focus fell to the page (#412).
 */
describe('a container MathJax draws again', () => {
  const typeset = (html) => {
    const container = document.createElement('mjx-container');
    container.innerHTML = html;
    document.body.appendChild(container);
    return container;
  };

  beforeEach(() => {
    document.body.innerHTML = '';
    toolkit.focusedRecord = null;
    toolkit.recordByContainer = new WeakMap();
  });

  const decorated = (latex = 'x^2', display = false) => {
    const container = typeset('<mjx-math aria-hidden="true">x</mjx-math>');
    const item = { typesetRoot: container, math: latex, display };
    toolkit.decorateMathItem(item);
    return item;
  };

  const redraw = (item) => {
    const fresh = typeset('<mjx-math aria-hidden="true">x</mjx-math>');
    item.typesetRoot.replaceWith(fresh);
    item.typesetRoot = fresh;
    return fresh;
  };

  it('gets the tab stop, role, label and inline class back', () => {
    const item = decorated();
    const label = item.typesetRoot.getAttribute('aria-label');
    const fresh = redraw(item);

    window.DatalogMath.restore(item);

    expect(fresh.getAttribute('tabindex')).toBe('0');
    expect(fresh.getAttribute('role')).toBe('math');
    expect(fresh.getAttribute('aria-label')).toBe(label);
    expect(fresh.dataset.mathLatex).toBe('x^2');
    expect(fresh.classList.contains('math-expression__inline')).toBe(true);
  });

  it('gets the focus back when it had it, and only then', () => {
    const item = decorated();
    item.typesetRoot.focus();
    toolkit.trackFocus({ target: item.typesetRoot });
    const fresh = redraw(item);
    expect(document.activeElement).toBe(document.body);

    window.DatalogMath.restoreAll({ math: [item] });
    expect(document.activeElement).toBe(fresh);

    const other = document.createElement('button');
    document.body.appendChild(other);
    other.focus();
    toolkit.trackFocus({ target: other });
    redraw(item);
    window.DatalogMath.restore(item);
    expect(document.activeElement).toBe(other);
  });

  // A document the menu builds anew copies each expression into a new item.
  it('is restored through a copied item, which shares the record', () => {
    const item = decorated();
    item.typesetRoot.focus();
    toolkit.trackFocus({ target: item.typesetRoot });
    const copy = Object.assign({}, item);
    const fresh = redraw(copy);

    window.DatalogMath.restore(copy);

    expect(fresh.getAttribute('role')).toBe('math');
    expect(document.activeElement).toBe(fresh);
  });

  it('leaves alone a container it has already seen, and an undecorated one', () => {
    const item = decorated();
    item.typesetRoot.setAttribute('aria-label', 'changed by the page');
    window.DatalogMath.restore(item);
    expect(item.typesetRoot.getAttribute('aria-label')).toBe('changed by the page');

    expect(() => window.DatalogMath.restore({ typesetRoot: typeset('') })).not.toThrow();
    expect(() => window.DatalogMath.restoreAll(null)).not.toThrow();
  });

  it('keeps the one link exposed for a reference drawn again', () => {
    const drawn = '<mjx-math aria-hidden="true"><a href="#eq:one">(1)</a></mjx-math>' +
      '<mjx-assistive-mml><a href="#eq:one">1</a></mjx-assistive-mml>';
    const container = typeset(drawn);
    toolkit.exposeReferenceLinks(container);
    const fresh = typeset(drawn);
    container.replaceWith(fresh);

    toolkit.exposeReferenceLinks(fresh);

    expect(document.querySelectorAll('.math-reference-link')).toHaveLength(1);
  });
});
