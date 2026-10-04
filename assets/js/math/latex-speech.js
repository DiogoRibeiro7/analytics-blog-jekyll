/**
 * @fileoverview Reads a LaTeX expression as words, for the label a screen
 * reader announces. Symbols are spoken as words, since a screen reader may
 * skip "∈" or "ℝ" at its usual settings. A command is read, or dropped when it
 * draws nothing, but never lost because no table knows it: an unknown one is
 * read by its name (#417).
 *
 * The build reads expressions the same way (lib/datalog/latex_speech.rb), from
 * the same table, and both test suites check tests/fixtures/latex-speech.json.
 * @module math/latex-speech
 */

import table from '../../../lib/datalog/latex_speech/words.json';

const capitalised = (name) => name[0].toUpperCase() + name.slice(1);
const WORDS = new Map([
  ...table.greek.map((name) => [name, name]),
  ...table.greek.map((name) => [capitalised(name), `capital ${name}`]),
  ...Object.entries(table.words),
]);
const BIG_OPERATORS = new Map(Object.entries(table.big_operators));
const LIMITS = new Map(Object.entries(table.limits));
const TEXT = new Set(table.text);
const TEXT_MODE = new Set(table.text_mode);
const STYLES = new Map(Object.entries(table.styles));
const ACCENTS = new Map(Object.entries(table.accents));
const SILENT_WITH_ARGUMENT = new Set(table.silent_with_argument);
const SIZES = new Set(table.sizes);
const MATRICES = new Set(table.matrices);
const WITH_COLUMNS = new Set(table.with_columns);
const SUPERSCRIPTS = new Map(Object.entries(table.superscripts));
const ROOTS = new Map(Object.entries(table.roots));
const MAX_DEPTH = 64;

const isLetter = (char) => (char >= 'a' && char <= 'z') || (char >= 'A' && char <= 'Z');

/**
 * Splits LaTeX into commands, brace groups and characters. It walks the text
 * once, keeping open groups on a stack rather than recursing, and drops an
 * unescaped % and the rest of its line.
 * @param {string} source
 * @returns {Array<Object>}
 */
export function tokenizeLatex(source) {
  const text = String(source || '');
  const root = [];
  const stack = [root];
  let index = 0;
  while (index < text.length) {
    const char = text[index];
    const current = stack[stack.length - 1];
    if (char === '\\') {
      let end = index + 1;
      while (end < text.length && isLetter(text[end])) {
        end += 1;
      }
      if (end === index + 1 && end < text.length) {
        end += 1;
      }
      if (end > index + 1) {
        current.push({ type: 'command', name: text.slice(index + 1, end) });
      }
      index = end;
    } else if (char === '{') {
      const group = { type: 'group', tokens: [] };
      current.push(group);
      stack.push(group.tokens);
      index += 1;
    } else if (char === '}') {
      if (stack.length > 1) {
        stack.pop();
      }
      index += 1;
    } else if (char === '%') {
      const newline = text.indexOf('\n', index);
      index = newline === -1 ? text.length : newline;
    } else if (char.trim() === '') {
      if (current.length === 0 || current[current.length - 1].type !== 'space') {
        current.push({ type: 'space' });
      }
      index += 1;
    } else {
      current.push({ type: 'char', value: char });
      index += 1;
    }
  }
  return root;
}

const plain = (tokens) =>
  tokens
    .map((token) => (token.type === 'char' ? token.value : ''))
    .join('')
    .trim();

const isChar = (token, value) => Boolean(token) && token.type === 'char' && token.value === value;
const isCommand = (token, name) => Boolean(token) && token.type === 'command' && token.name === name;

/**
 * Reads tokens as words. Words go in with spaces around them and characters
 * as they are, so "f(x)" stays together and "2\pi r" reads "2 pi r".
 * @param {Array<Object>} tokens
 * @param {Object} context - `depth`; `environments`, a stack the whole
 *   expression shares; `approaches` inside a limit; `text` inside \text{}
 * @returns {string}
 */
function speak(tokens, context) {
  if (context.depth > MAX_DEPTH) {
    return '';
  }
  const inner = { ...context, depth: context.depth + 1 };
  let out = '';
  let index = 0;

  const word = (value) => {
    if (value) {
      out += ` ${value} `;
    }
  };
  const skipSpaces = () => {
    while (tokens[index] && tokens[index].type === 'space') {
      index += 1;
    }
  };
  // The next argument: a group's tokens, or a single token.
  const argument = () => {
    skipSpaces();
    const token = tokens[index];
    if (!token) {
      return [];
    }
    index += 1;
    return token.type === 'group' ? token.tokens : [token];
  };
  const read = (tokensToRead, readContext = inner) => speak(tokensToRead, readContext).trim();
  const optional = () => {
    skipSpaces();
    if (!isChar(tokens[index], '[')) {
      return null;
    }
    const collected = [];
    index += 1;
    while (index < tokens.length && !isChar(tokens[index], ']')) {
      collected.push(tokens[index]);
      index += 1;
    }
    index += 1;
    return collected;
  };
  const star = () => {
    if (isChar(tokens[index], '*')) {
      index += 1;
    }
  };
  // The sub- and superscript after an operator, in either order.
  const limits = (lowerContext) => {
    const found = {};
    for (;;) {
      skipSpaces();
      const token = tokens[index];
      if (isCommand(token, 'limits') || isCommand(token, 'nolimits')) {
        index += 1;
      } else if (isChar(token, '_') && found.lower === undefined) {
        index += 1;
        found.lower = read(argument(), lowerContext);
      } else if (isChar(token, '^') && found.upper === undefined) {
        index += 1;
        found.upper = read(argument());
      } else {
        return found;
      }
    }
  };
  const superscript = (raised) => {
    const single = raised.length === 1 ? raised[0] : null;
    if (isCommand(single, 'circ')) {
      return 'degrees';
    }
    if (isCommand(single, 'top')) {
      return 'transpose';
    }
    const content = read(raised);
    return SUPERSCRIPTS.has(content) ? SUPERSCRIPTS.get(content) : `to the power ${content}`;
  };

  while (index < tokens.length) {
    const token = tokens[index];
    index += 1;

    if (token.type === 'space') {
      out += ' ';
    } else if (token.type === 'group') {
      out += speak(token.tokens, inner);
    } else if (token.type === 'char') {
      const char = token.value;
      if (context.text) {
        out += char;
      } else if (char === '^') {
        word(superscript(argument()));
      } else if (char === '_') {
        word(`sub ${read(argument())}`);
      } else if (char === "'") {
        let count = 1;
        while (isChar(tokens[index], "'")) {
          count += 1;
          index += 1;
        }
        word(table.primes[count] || Array(count).fill('prime').join(' '));
      } else if (char === '&') {
        const environment = context.environments[context.environments.length - 1];
        out += MATRICES.has(environment) || environment === 'cases' ? ', ' : ' ';
      } else if (char === '~') {
        out += ' ';
      } else {
        out += char;
      }
    } else {
      const { name } = token;
      if (name === 'frac' || name === 'dfrac' || name === 'tfrac' || name === 'cfrac') {
        const top = read(argument());
        word(`${top} over ${read(argument())}`);
      } else if (name === 'binom' || name === 'dbinom' || name === 'tbinom') {
        const top = read(argument());
        word(`${top} choose ${read(argument())}`);
      } else if (name === 'sqrt') {
        const degree = optional();
        const order = degree ? read(degree) : '2';
        word(`${ROOTS.get(order) || `${order}th root`} of ${read(argument())}`);
      } else if (BIG_OPERATORS.has(name)) {
        const { lower, upper } = limits(inner);
        let phrase = BIG_OPERATORS.get(name);
        if (lower && upper) {
          phrase += ` from ${lower} to ${upper}`;
        } else if (lower) {
          phrase += ` over ${lower}`;
        } else if (upper) {
          phrase += ` to ${upper}`;
        }
        word(phrase);
      } else if (LIMITS.has(name)) {
        const { lower, upper } = limits({ ...inner, approaches: true });
        word([LIMITS.get(name), lower && `as ${lower}`, upper && `to the power ${upper}`].filter(Boolean).join(' '));
      } else if (name === 'to' && context.approaches) {
        word('approaches');
      } else if (name === 'begin' || name === 'end') {
        const environment = plain(argument()).replace('*', '');
        if (name === 'begin') {
          context.environments.push(environment);
          if (WITH_COLUMNS.has(environment)) {
            argument();
          }
        } else {
          context.environments.pop();
        }
        const kind = environment === 'cases' ? 'cases' : MATRICES.has(environment) && 'matrix';
        if (kind) {
          word(name === 'begin' ? kind : `end ${kind}`);
        }
      } else if (name === '\\') {
        optional();
        word(';');
      } else if (name === 'pmod') {
        word(`mod ${read(argument())}`);
      } else if (name === 'textcolor') {
        argument();
        word(read(argument(), { ...inner, text: true }));
      } else if (name === 'overset' || name === 'stackrel' || name === 'underset') {
        const mark = read(argument());
        word(`${read(argument())} with ${mark} ${name === 'underset' ? 'below' : 'above'}`);
      } else if (TEXT.has(name)) {
        star();
        word(read(argument(), { ...inner, text: TEXT_MODE.has(name) }));
      } else if (STYLES.has(name)) {
        word(`${STYLES.get(name)} ${read(argument())}`);
      } else if (ACCENTS.has(name)) {
        word(`${read(argument())} ${ACCENTS.get(name)}`);
      } else if (SIZES.has(name)) {
        if (isChar(tokens[index], '.')) {
          index += 1;
        }
      } else if (SILENT_WITH_ARGUMENT.has(name)) {
        star();
        argument();
      } else if (WORDS.has(name)) {
        word(WORDS.get(name));
      } else if (isLetter(name[0])) {
        // A function name (\sin, \log) is read as written, and so is a command
        // nothing here knows, rather than lost.
        word(name);
      }
    }
  }
  return out;
}

// A line break or a separator at either end reads as nothing.
const isEdge = (char) => char === ' ' || char === ';' || char === ',';

/**
 * The words a LaTeX expression reads as, or '' when it has none.
 * @param {string} latex
 * @returns {string}
 */
export function speakLatex(latex) {
  // Single spaces, none inside brackets or before punctuation. After the
  // collapse each pattern matches a fixed character or two, so none backtracks.
  const words = speak(tokenizeLatex(latex), { depth: 0, environments: [] })
    .replace(/\s+/g, ' ')
    .replace(/ ([,;:.!?)\]}])/g, '$1')
    .replace(/([([{]) /g, '$1')
    .replace(/;(?=;)/g, '');
  let start = 0;
  let end = words.length;
  while (start < end && isEdge(words[start])) {
    start += 1;
  }
  while (end > start && isEdge(words[end - 1])) {
    end -= 1;
  }
  return words.slice(start, end);
}
