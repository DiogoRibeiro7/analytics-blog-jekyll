/** Add the theme's code-copy control to posts and documentation guides. */
export function initCodeBlocks(doc = document) {
  const blocks = doc.querySelectorAll('.post-content pre > code, .docs-content pre > code');
  blocks.forEach((codeBlock) => {
    const pre = codeBlock.parentElement;
    if (!pre || pre.parentElement?.classList.contains('code-block-wrapper')) return;

    const wrapper = doc.createElement('div');
    wrapper.className = 'code-block-wrapper';
    pre.parentNode.insertBefore(wrapper, pre);
    wrapper.appendChild(pre);

    const metaBar = doc.createElement('div');
    metaBar.className = 'code-block-meta';

    // Rouge may put its language on the wrapper; copy only the source column
    // when line numbers render as a table.
    const langHolder = codeBlock.matches('[class*="language-"]')
      ? codeBlock : codeBlock.closest('.highlighter-rouge');
    const lang = langHolder && langHolder.getAttribute('class');
    const source = codeBlock.querySelector('.rouge-code') || codeBlock;
    const match = lang && lang.match(/language-([a-z0-9+#]+)/i);
    if (match) {
      const badge = doc.createElement('span');
      badge.className = 'code-language';
      badge.textContent = match[1].toUpperCase();
      metaBar.appendChild(badge);
    }

    const button = doc.createElement('button');
    button.type = 'button';
    button.className = 'code-copy';
    button.setAttribute('aria-label', 'Copy code to clipboard');
    button.textContent = 'Copy';

    const clipboard = doc.defaultView?.navigator?.clipboard;
    if (clipboard && clipboard.writeText) {
      button.addEventListener('click', () => {
        clipboard.writeText(source.textContent).then(() => {
          button.textContent = 'Copied!';
          button.classList.add('is-copied');
          setTimeout(() => {
            button.textContent = 'Copy';
            button.classList.remove('is-copied');
          }, 2000);
        }).catch(() => { button.textContent = 'Error'; });
      });
    } else {
      button.disabled = true;
      button.title = 'Clipboard copying is not supported in this browser';
    }

    metaBar.appendChild(button);
    wrapper.insertBefore(metaBar, pre);
  });
}
