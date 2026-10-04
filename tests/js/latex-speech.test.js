import { describe, expect, it } from 'vitest';
import cases from '../fixtures/latex-speech.json';
import { speakLatex, tokenizeLatex } from '../../assets/js/math/latex-speech.js';

// The same cases tests/test_latex_speech.rb checks against the build's reader.
const examples = cases.filter((entry) => 'latex' in entry);

describe('reading LaTeX as words (#417)', () => {
  it.each(examples.map((entry) => [entry.latex, entry.label]))('%j reads %j', (latex, label) => {
    expect(speakLatex(latex)).toBe(label);
  });

  it('leaves no backslash, label key or environment name in a label', () => {
    for (const { latex } of examples) {
      expect(speakLatex(latex)).not.toMatch(/\\|eq:|\b(?:equation|align|pmatrix|array)\b/);
    }
  });

  it('splits commands, groups and characters, and drops a comment', () => {
    expect(tokenizeLatex('\\frac{a}{b} % note\n\\,')).toEqual([
      { type: 'command', name: 'frac' },
      { type: 'group', tokens: [{ type: 'char', value: 'a' }] },
      { type: 'group', tokens: [{ type: 'char', value: 'b' }] },
      { type: 'space' },
      { type: 'command', name: ',' },
    ]);
  });

  // Labels come from page content, so neither depth nor length may hang the
  // page: the tokenizer keeps a stack rather than recursing, and the reader
  // stops descending past a fixed depth.
  it('reads deeply nested and very long input without failing', () => {
    const nested = `${'{'.repeat(5000)}x${'}'.repeat(5000)}`;
    expect(() => speakLatex(nested)).not.toThrow();

    const started = performance.now();
    expect(speakLatex('x + \\alpha '.repeat(20000))).toMatch(/^x \+ alpha x/);
    expect(speakLatex(`${' '.repeat(50000)};`)).toBe('');
    expect(performance.now() - started).toBeLessThan(2000);
  });
});
