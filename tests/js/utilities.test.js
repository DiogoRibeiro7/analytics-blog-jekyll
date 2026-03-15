import { beforeEach, describe, expect, it, vi } from 'vitest';

describe('Core Utilities', () => {
  describe('LocalStorage Utilities', () => {
    beforeEach(() => {
      localStorage.clear();
    });

    it('stores and retrieves data from localStorage', () => {
      const key = 'test-key';
      const value = 'test-value';

      localStorage.setItem(key, value);
      const retrieved = localStorage.getItem(key);

      expect(retrieved).toBe(value);
    });

    it('handles JSON data in localStorage', () => {
      const key = 'test-json';
      const data = { name: 'StatFlow', version: '1.2.3' };

      localStorage.setItem(key, JSON.stringify(data));
      const retrieved = JSON.parse(localStorage.getItem(key));

      expect(retrieved).toEqual(data);
      expect(retrieved.name).toBe('StatFlow');
      expect(retrieved.version).toBe('1.2.3');
    });

    it('returns null for non-existent keys', () => {
      const value = localStorage.getItem('nonexistent-key');
      expect(value).toBeNull();
    });

    it('removes items from localStorage', () => {
      const key = 'test-remove';
      localStorage.setItem(key, 'value');

      expect(localStorage.getItem(key)).toBe('value');

      localStorage.removeItem(key);

      expect(localStorage.getItem(key)).toBeNull();
    });

    it('clears all localStorage data', () => {
      localStorage.setItem('key1', 'value1');
      localStorage.setItem('key2', 'value2');

      expect(localStorage.length).toBeGreaterThan(0);

      localStorage.clear();

      expect(localStorage.length).toBe(0);
    });

    it('handles localStorage quota errors gracefully', () => {
      const setItemSpy = vi.spyOn(Storage.prototype, 'setItem');
      setItemSpy.mockImplementation(() => {
        throw new Error('QuotaExceededError');
      });

      try {
        localStorage.setItem('test', 'data');
      } catch (error) {
        expect(error.message).toBe('QuotaExceededError');
      }

      setItemSpy.mockRestore();
    });
  });

  describe('Clipboard Operations', () => {
    beforeEach(() => {
      // Mock clipboard API
      Object.assign(navigator, {
        clipboard: {
          writeText: vi.fn().mockResolvedValue(undefined),
          readText: vi.fn().mockResolvedValue('clipboard content')
        }
      });
    });

    it('copies text to clipboard', async () => {
      const text = 'pip install statflow';

      await navigator.clipboard.writeText(text);

      expect(navigator.clipboard.writeText).toHaveBeenCalledWith(text);
    });

    it('reads text from clipboard', async () => {
      const text = await navigator.clipboard.readText();

      expect(text).toBe('clipboard content');
      expect(navigator.clipboard.readText).toHaveBeenCalled();
    });

    it('handles clipboard permission denied', async () => {
      navigator.clipboard.writeText = vi.fn().mockRejectedValue(new Error('Permission denied'));

      try {
        await navigator.clipboard.writeText('test');
      } catch (error) {
        expect(error.message).toBe('Permission denied');
      }
    });

    it('provides feedback after successful copy', async () => {
      let feedbackMessage = '';

      const copyWithFeedback = async (text) => {
        try {
          await navigator.clipboard.writeText(text);
          feedbackMessage = 'Copied!';
          return true;
        } catch (error) {
          feedbackMessage = 'Failed to copy';
          return false;
        }
      };

      const success = await copyWithFeedback('test text');

      expect(success).toBe(true);
      expect(feedbackMessage).toBe('Copied!');
    });
  });

  describe('DOM Utilities', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <div class="container">
          <div class="item" data-id="1">Item 1</div>
          <div class="item" data-id="2">Item 2</div>
          <div class="item" data-id="3">Item 3</div>
        </div>
      `;
    });

    it('selects elements by class', () => {
      const items = document.querySelectorAll('.item');
      expect(items).toHaveLength(3);
    });

    it('selects elements by data attribute', () => {
      const item = document.querySelector('[data-id="2"]');
      expect(item).toBeTruthy();
      expect(item.textContent).toBe('Item 2');
    });

    it('adds classes to elements', () => {
      const item = document.querySelector('.item');
      item.classList.add('active', 'selected');

      expect(item.classList.contains('active')).toBe(true);
      expect(item.classList.contains('selected')).toBe(true);
    });

    it('removes classes from elements', () => {
      const item = document.querySelector('.item');
      item.classList.add('active');

      expect(item.classList.contains('active')).toBe(true);

      item.classList.remove('active');

      expect(item.classList.contains('active')).toBe(false);
    });

    it('toggles classes on elements', () => {
      const item = document.querySelector('.item');

      expect(item.classList.contains('active')).toBe(false);

      item.classList.toggle('active');
      expect(item.classList.contains('active')).toBe(true);

      item.classList.toggle('active');
      expect(item.classList.contains('active')).toBe(false);
    });

    it('gets and sets attributes', () => {
      const item = document.querySelector('.item');

      const id = item.getAttribute('data-id');
      expect(id).toBe('1');

      item.setAttribute('data-status', 'active');
      expect(item.getAttribute('data-status')).toBe('active');
    });

    it('creates and appends new elements', () => {
      const container = document.querySelector('.container');
      const newItem = document.createElement('div');
      newItem.className = 'item';
      newItem.setAttribute('data-id', '4');
      newItem.textContent = 'Item 4';

      container.appendChild(newItem);

      const items = document.querySelectorAll('.item');
      expect(items).toHaveLength(4);
      expect(items[3].textContent).toBe('Item 4');
    });

    it('removes elements from DOM', () => {
      const item = document.querySelector('[data-id="2"]');
      item.remove();

      const items = document.querySelectorAll('.item');
      expect(items).toHaveLength(2);

      const removedItem = document.querySelector('[data-id="2"]');
      expect(removedItem).toBeNull();
    });
  });

  describe('Event Handling', () => {
    beforeEach(() => {
      document.body.innerHTML = `
        <button id="test-button">Click me</button>
        <input id="test-input" type="text" />
      `;
    });

    it('attaches event listeners', () => {
      const button = document.getElementById('test-button');
      const handler = vi.fn();

      button.addEventListener('click', handler);
      button.click();

      expect(handler).toHaveBeenCalledTimes(1);
    });

    it('removes event listeners', () => {
      const button = document.getElementById('test-button');
      const handler = vi.fn();

      button.addEventListener('click', handler);
      button.click();
      expect(handler).toHaveBeenCalledTimes(1);

      button.removeEventListener('click', handler);
      button.click();
      expect(handler).toHaveBeenCalledTimes(1); // Still 1, not 2
    });

    it('handles keyboard events', () => {
      const input = document.getElementById('test-input');
      const handler = vi.fn();

      input.addEventListener('keydown', handler);
      input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }));

      expect(handler).toHaveBeenCalled();
    });

    it('handles input events', () => {
      const input = document.getElementById('test-input');
      const handler = vi.fn();

      input.addEventListener('input', handler);

      input.value = 'test';
      input.dispatchEvent(new Event('input'));

      expect(handler).toHaveBeenCalled();
      expect(input.value).toBe('test');
    });

    it('prevents default behavior', () => {
      document.body.innerHTML = '<a href="/test" id="link">Link</a>';

      const link = document.getElementById('link');
      const handler = vi.fn((e) => {
        e.preventDefault();
      });

      link.addEventListener('click', handler);

      const event = new MouseEvent('click', { bubbles: true, cancelable: true });
      link.dispatchEvent(event);

      expect(handler).toHaveBeenCalled();
      expect(event.defaultPrevented).toBe(true);
    });

    it('stops event propagation', () => {
      document.body.innerHTML = `
        <div id="parent">
          <button id="child">Click</button>
        </div>
      `;

      const parent = document.getElementById('parent');
      const child = document.getElementById('child');

      const parentHandler = vi.fn();
      const childHandler = vi.fn((e) => {
        e.stopPropagation();
      });

      parent.addEventListener('click', parentHandler);
      child.addEventListener('click', childHandler);

      child.click();

      expect(childHandler).toHaveBeenCalled();
      expect(parentHandler).not.toHaveBeenCalled();
    });
  });

  describe('URL Utilities', () => {
    it('parses URL parameters', () => {
      const url = new URL('https://example.com/packages/statflow?version=1.2.3&lang=python');

      const params = new URLSearchParams(url.search);

      expect(params.get('version')).toBe('1.2.3');
      expect(params.get('lang')).toBe('python');
    });

    it('builds URL with parameters', () => {
      const baseUrl = 'https://example.com/packages/statflow';
      const params = new URLSearchParams({
        version: '1.2.3',
        lang: 'python'
      });

      const fullUrl = `${baseUrl}?${params.toString()}`;

      expect(fullUrl).toBe('https://example.com/packages/statflow?version=1.2.3&lang=python');
    });

    it('extracts hash from URL', () => {
      const url = new URL('https://example.com/packages/statflow#installation');

      expect(url.hash).toBe('#installation');
    });

    it('handles URL encoding', () => {
      const text = 'Hello World & Special/Characters';
      const encoded = encodeURIComponent(text);

      expect(encoded).toBe('Hello%20World%20%26%20Special%2FCharacters');

      const decoded = decodeURIComponent(encoded);
      expect(decoded).toBe(text);
    });
  });

  describe('Array Utilities', () => {
    it('filters array elements', () => {
      const numbers = [1, 2, 3, 4, 5, 6];
      const evens = numbers.filter(n => n % 2 === 0);

      expect(evens).toEqual([2, 4, 6]);
    });

    it('maps array elements', () => {
      const numbers = [1, 2, 3];
      const doubled = numbers.map(n => n * 2);

      expect(doubled).toEqual([2, 4, 6]);
    });

    it('reduces array to single value', () => {
      const numbers = [1, 2, 3, 4, 5];
      const sum = numbers.reduce((acc, n) => acc + n, 0);

      expect(sum).toBe(15);
    });

    it('finds element in array', () => {
      const items = [
        { id: 1, name: 'Item 1' },
        { id: 2, name: 'Item 2' },
        { id: 3, name: 'Item 3' }
      ];

      const item = items.find(i => i.id === 2);

      expect(item).toBeTruthy();
      expect(item.name).toBe('Item 2');
    });

    it('checks if array includes value', () => {
      const tags = ['python', 'statistics', 'machine-learning'];

      expect(tags.includes('python')).toBe(true);
      expect(tags.includes('javascript')).toBe(false);
    });

    it('removes duplicates from array', () => {
      const numbers = [1, 2, 2, 3, 3, 3, 4];
      const unique = [...new Set(numbers)];

      expect(unique).toEqual([1, 2, 3, 4]);
    });
  });

  describe('String Utilities', () => {
    it('trims whitespace from strings', () => {
      const text = '  Hello World  ';
      const trimmed = text.trim();

      expect(trimmed).toBe('Hello World');
    });

    it('converts string to slug', () => {
      const title = 'StatFlow: A Modern Statistical Toolkit';
      const slug = title
        .toLowerCase()
        .replace(/[^\w\s-]/g, '')
        .replace(/\s+/g, '-');

      expect(slug).toBe('statflow-a-modern-statistical-toolkit');
    });

    it('capitalizes first letter', () => {
      const text = 'hello world';
      const capitalized = text.charAt(0).toUpperCase() + text.slice(1);

      expect(capitalized).toBe('Hello world');
    });

    it('checks string prefix', () => {
      const url = 'https://example.com';

      expect(url.startsWith('https://')).toBe(true);
      expect(url.startsWith('http://')).toBe(false);
    });

    it('checks string suffix', () => {
      const filename = 'package.json';

      expect(filename.endsWith('.json')).toBe(true);
      expect(filename.endsWith('.yaml')).toBe(false);
    });

    it('splits string into array', () => {
      const tags = 'python, statistics, machine-learning';
      const tagArray = tags.split(', ');

      expect(tagArray).toEqual(['python', 'statistics', 'machine-learning']);
      expect(tagArray).toHaveLength(3);
    });

    it('replaces text in string', () => {
      const text = 'Install with pip: pip install package';
      const updated = text.replace('pip', 'conda');

      expect(updated).toBe('Install with conda: pip install package');

      const allReplaced = text.replace(/pip/g, 'conda');
      expect(allReplaced).toBe('Install with conda: conda install package');
    });
  });

  describe('Date Utilities', () => {
    it('formats date strings', () => {
      const date = new Date('2025-01-15T12:00:00Z');

      const formatted = date.toISOString().split('T')[0];
      expect(formatted).toBe('2025-01-15');
    });

    it('calculates time differences', () => {
      const date1 = new Date('2025-01-01');
      const date2 = new Date('2025-01-15');

      const diff = date2.getTime() - date1.getTime();
      const days = Math.floor(diff / (1000 * 60 * 60 * 24));

      expect(days).toBe(14);
    });

    it('gets current timestamp', () => {
      const now = Date.now();

      expect(now).toBeGreaterThan(0);
      expect(typeof now).toBe('number');
    });
  });

  describe('Debounce and Throttle', () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    it('debounces function calls', () => {
      const func = vi.fn();
      let debounceTimer;

      const debounced = (...args) => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => func(...args), 300);
      };

      debounced('call 1');
      debounced('call 2');
      debounced('call 3');

      expect(func).not.toHaveBeenCalled();

      vi.advanceTimersByTime(300);

      expect(func).toHaveBeenCalledTimes(1);
      expect(func).toHaveBeenCalledWith('call 3');
    });

    it('throttles function calls', () => {
      const func = vi.fn();
      let lastCall = 0;

      const throttled = (...args) => {
        const now = Date.now();
        if (now - lastCall >= 100) {
          func(...args);
          lastCall = now;
        }
      };

      throttled('call 1');
      expect(func).toHaveBeenCalledTimes(1);

      vi.advanceTimersByTime(50);
      throttled('call 2');
      expect(func).toHaveBeenCalledTimes(1); // Throttled

      vi.advanceTimersByTime(60);
      throttled('call 3');
      expect(func).toHaveBeenCalledTimes(2); // Allowed
    });
  });
});
