import { beforeEach, describe, expect, it, vi } from 'vitest';
import { initCodeBlocks } from '../../assets/js/core/code-blocks.js';

describe('code blocks on posts and guides', () => {
  beforeEach(() => { document.body.innerHTML = ''; });

  it('uses the Rouge source column and keeps one copy control per block', async () => {
    document.body.innerHTML = `
      <div class="docs-content"><div class="language-yaml highlighter-rouge">
        <pre><code><span class="rouge-gutter">1</span><span class="rouge-code">search: true</span></code></pre>
      </div></div>`;
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(window.navigator, 'clipboard', { configurable: true, value: { writeText } });

    initCodeBlocks();
    initCodeBlocks();
    const button = document.querySelector('.docs-content .code-copy');
    expect(document.querySelectorAll('.docs-content .code-copy')).toHaveLength(1);
    expect(document.querySelector('.code-language').textContent).toBe('YAML');
    button.click();
    await vi.waitFor(() => expect(writeText).toHaveBeenCalledWith('search: true'));
    expect(button.textContent).toBe('Copied!');
  });

  it('does not add a dead copy action without clipboard support', () => {
    document.body.innerHTML = '<div class="post-content"><pre><code>console.log(1)</code></pre></div>';
    Object.defineProperty(window.navigator, 'clipboard', { configurable: true, value: undefined });
    initCodeBlocks();
    expect(document.querySelector('.post-content .code-copy').disabled).toBe(true);
  });
});
