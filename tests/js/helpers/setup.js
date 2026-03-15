import { TextDecoder, TextEncoder } from 'util';
import { afterEach, beforeEach, vi } from 'vitest';

if (typeof process !== 'undefined') {
  process.env.VITEST = 'true';
}

class MockIntersectionObserver {
  static instances = [];

  constructor(callback) {
    this.callback = callback;
    this.elements = new Set();
    MockIntersectionObserver.instances.push(this);
  }

  observe(element) {
    this.elements.add(element);
  }

  unobserve(element) {
    this.elements.delete(element);
  }

  disconnect() {
    this.elements.clear();
  }

  trigger(entries) {
    this.callback(entries, this);
  }
}

globalThis.IntersectionObserver = MockIntersectionObserver;

globalThis.MockMutationObservers = [];

class MockMutationObserver {
  constructor(callback) {
    this.callback = callback;
    this.targets = new Set();
    globalThis.MockMutationObservers.push(this);
  }

  observe(target) {
    this.targets.add(target);
  }

  disconnect() {
    this.targets.clear();
  }

  takeRecords() {
    return [];
  }

  trigger(records = []) {
    this.callback(records.length ? records : [{ type: 'childList' }], this);
  }
}

globalThis.MutationObserver = MockMutationObserver;

if (!globalThis.fetch) {
  globalThis.fetch = vi.fn();
}

globalThis.scrollTo = vi.fn();

if (!globalThis.matchMedia) {
  globalThis.matchMedia = vi.fn().mockImplementation((query) => ({
    matches: false,
    media: query,
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    dispatchEvent: () => false
  }));
}

if (!Element.prototype.scrollIntoView) {
  Element.prototype.scrollIntoView = vi.fn();
}

globalThis.ResizeObserver = class {
  observe() {}
  unobserve() {}
  disconnect() {}
};

globalThis.TextEncoder = globalThis.TextEncoder || TextEncoder;
globalThis.TextDecoder = globalThis.TextDecoder || TextDecoder;

beforeEach(() => {
  document.body.innerHTML = '';
  vi.useFakeTimers();
  if (globalThis.fetch && typeof globalThis.fetch.mockReset === 'function') {
    globalThis.fetch.mockReset();
  }
  try {
    localStorage.clear();
  } catch (error) {
    // ignore when localStorage is unavailable
  }
});

afterEach(() => {
  vi.runAllTimers();
  vi.useRealTimers();
  vi.clearAllMocks();
  if (typeof vi.unstubAllGlobals === 'function') {
    vi.unstubAllGlobals();
  }
});
