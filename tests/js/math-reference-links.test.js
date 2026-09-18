import { afterEach, describe, expect, it } from 'vitest';
import '../../assets/js/math.js';

const toolkit = globalThis.__DATALOG_MATH_INTERNALS__;

/**
 * MathJax draws \eqref and \ref as a link inside aria-hidden output. The
 * drawn link must leave the tab order, and the same address must follow the
 * expression as a link a keyboard and a screen reader can use.
 */

function typeset(markup) {
  document.body.innerHTML = `<p>As shown in ${markup} the energy is conserved.</p>`;
  return document.querySelector('mjx-container');
}

const EQREF = `
<mjx-container class="MathJax" jax="CHTML">
  <mjx-math class="MJX-TEX" aria-hidden="true"><a href="#mjx-eqn%3Aeq%3Aenergy"><mjx-mrow><mjx-c class="mjx-c28"></mjx-c><mjx-c class="mjx-c33"></mjx-c><mjx-c class="mjx-c29"></mjx-c></mjx-mrow></a></mjx-math>
  <mjx-assistive-mml unselectable="on" display="inline"><math xmlns="http://www.w3.org/1998/Math/MathML"><mrow href="#mjx-eqn%3Aeq%3Aenergy" class="MathJax_ref"><mtext>(3)</mtext></mrow></math></mjx-assistive-mml>
</mjx-container>`;

describe('equation references', () => {
  afterEach(() => {
    document.body.innerHTML = '';
  });

  it('takes the drawn link out of the tab order and offers a real one after the expression', () => {
    const container = typeset(EQREF);
    toolkit.exposeReferenceLinks(container);

    const drawn = container.querySelector('[aria-hidden="true"] a');
    expect(drawn.getAttribute('tabindex')).toBe('-1');
    expect(drawn.getAttribute('href')).toBe('#mjx-eqn%3Aeq%3Aenergy');

    const link = container.nextElementSibling;
    expect(link.matches('a.math-reference-link')).toBe(true);
    expect(link.getAttribute('href')).toBe('#mjx-eqn%3Aeq%3Aenergy');
    expect(link.textContent).toBe('Equation (3)');
    expect(link.closest('[aria-hidden="true"]')).toBeNull();
  });

  it('does it once, however often the expression is decorated', () => {
    const container = typeset(EQREF);
    toolkit.exposeReferenceLinks(container);
    toolkit.exposeReferenceLinks(container);

    expect(document.querySelectorAll('.math-reference-link')).toHaveLength(1);
  });

  it('keeps several references in their order, and leaves other links and other math alone', () => {
    const container = typeset(`
<mjx-container class="MathJax" jax="CHTML">
  <mjx-math aria-hidden="true"><a href="#mjx-eqn%3A1"></a><a href="#mjx-eqn%3A2"></a><a href="https://example.org/paper"></a></mjx-math>
  <mjx-assistive-mml><math><mrow href="#mjx-eqn%3A1"><mtext>(1)</mtext></mrow><mrow href="#mjx-eqn%3A2"><mtext>(2)</mtext></mrow></math></mjx-assistive-mml>
</mjx-container>`);
    toolkit.exposeReferenceLinks(container);

    expect(Array.from(document.querySelectorAll('.math-reference-link')).map((link) => link.textContent)).toEqual(['Equation (1)', 'Equation (2)']);
    expect(container.querySelector('a[href="https://example.org/paper"]').getAttribute('tabindex')).toBe('-1');

    const plain = typeset('<mjx-container><mjx-math aria-hidden="true"></mjx-math></mjx-container>');
    toolkit.exposeReferenceLinks(plain);
    expect(document.querySelector('.math-reference-link')).toBeNull();
    expect(() => toolkit.exposeReferenceLinks(null)).not.toThrow();
  });

  it('handles every expression on the page when MathJax says it is done', () => {
    document.body.innerHTML = `<p>${EQREF}</p><p>${EQREF.split('energy').join('mass')}</p>`;
    document.dispatchEvent(new CustomEvent('datalog:math-ready'));

    expect(Array.from(document.querySelectorAll('.math-reference-link')).map((link) => link.getAttribute('href'))).toEqual([
      '#mjx-eqn%3Aeq%3Aenergy',
      '#mjx-eqn%3Aeq%3Amass',
    ]);
    expect(document.querySelectorAll('[aria-hidden="true"] a:not([tabindex="-1"])')).toHaveLength(0);

    document.dispatchEvent(new CustomEvent('datalog:math-ready'));
    expect(document.querySelectorAll('.math-reference-link')).toHaveLength(2);
  });

  it('still names the link when the assistive MathML is missing', () => {
    const container = typeset('<mjx-container><mjx-math aria-hidden="true"><a href="#mjx-eqn%3A7"></a></mjx-math></mjx-container>');
    toolkit.exposeReferenceLinks(container);

    expect(container.nextElementSibling.textContent).toBe('Equation');
  });
});
