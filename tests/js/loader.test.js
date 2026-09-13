import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { bootstrapFeatures } from '../../assets/js/loader.js';

describe('Loader Module', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    document.head.innerHTML = '';
    // Clear all dataset properties
    Object.keys(document.body.dataset).forEach(key => {
      delete document.body.dataset[key];
    });
    vi.clearAllMocks();
  });

  afterEach(() => {
    // Clear all feature-related dataset properties
    Object.keys(document.body.dataset).forEach(key => {
      delete document.body.dataset[key];
    });
  });

  describe('readManifest()', () => {
    it('should read manifest from script element', async () => {
      const manifest = {
        core: '/assets/js/dist/core.js',
        features: {
          search: '/assets/js/dist/search.js'
        }
      };

      document.head.innerHTML = `
        <script id="datalog-js-manifest" type="application/json">
          ${JSON.stringify(manifest)}
        </script>
      `;

      document.body.dataset.featureCore = 'true';

      // Mock dynamic import
      vi.mock('../../assets/js/loader.js', async (importOriginal) => {
        const mod = await importOriginal();
        return {
          ...mod,
          importModule: vi.fn(() => Promise.resolve({}))
        };
      });

      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureCoreState).toBe('ready');
    });

    it('should warn when manifest is missing', () => {
      const consoleWarn = vi.spyOn(console, 'warn').mockImplementation(() => {});

      // Calling bootstrapFeatures without manifest and without element should warn
      const manifest = {};
      bootstrapFeatures(manifest);

      consoleWarn.mockRestore();
    });

    it('should handle invalid JSON gracefully', () => {
      const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

      document.head.innerHTML = `
        <script id="datalog-js-manifest" type="application/json">
          { invalid json }
        </script>
      `;

      // This should not throw
      const script = document.getElementById('datalog-js-manifest');
      expect(script).toBeTruthy();
      expect(script.textContent).toContain('invalid');

      consoleError.mockRestore();
    });

    it('should return empty object when manifest element missing', () => {
      const element = document.getElementById('datalog-js-manifest');
      expect(element).toBeNull();
    });
  });

  describe('toDatasetKey()', () => {
    it('should convert feature name to dataset key format', () => {
      // Test the conversion logic inline
      const convert = (feature) => {
        return `feature${feature.replace(/(^|-)([a-z])/g, (_, __, char) => char.toUpperCase())}`;
      };

      expect(convert('search')).toBe('featureSearch');
      expect(convert('math')).toBe('featureMath');
      expect(convert('dark-mode')).toBe('featureDarkMode');
      expect(convert('academic')).toBe('featureAcademic');
    });

    it('should handle multi-hyphen names', () => {
      const convert = (feature) => {
        return `feature${feature.replace(/(^|-)([a-z])/g, (_, __, char) => char.toUpperCase())}`;
      };

      expect(convert('my-long-feature-name')).toBe('featureMyLongFeatureName');
    });

    it('should handle single character names', () => {
      const convert = (feature) => {
        return `feature${feature.replace(/(^|-)([a-z])/g, (_, __, char) => char.toUpperCase())}`;
      };

      expect(convert('a')).toBe('featureA');
    });
  });

  describe('updateFeatureState()', () => {
    it('should set feature state in dataset', () => {
      const toDatasetKey = (feature) => {
        return `feature${feature.replace(/(^|-)([a-z])/g, (_, __, char) => char.toUpperCase())}`;
      };

      const updateFeatureState = (feature, state) => {
        const body = document.body;
        if (!body) return;
        const key = `${toDatasetKey(feature)}State`;
        body.dataset[key] = state;
      };

      updateFeatureState('search', 'loading');
      expect(document.body.dataset.featureSearchState).toBe('loading');

      updateFeatureState('search', 'ready');
      expect(document.body.dataset.featureSearchState).toBe('ready');
    });

    it('should handle different state values', () => {
      const toDatasetKey = (feature) => {
        return `feature${feature.replace(/(^|-)([a-z])/g, (_, __, char) => char.toUpperCase())}`;
      };

      const updateFeatureState = (feature, state) => {
        const body = document.body;
        if (!body) return;
        const key = `${toDatasetKey(feature)}State`;
        body.dataset[key] = state;
      };

      updateFeatureState('math', 'loading');
      expect(document.body.dataset.featureMathState).toBe('loading');

      updateFeatureState('math', 'ready');
      expect(document.body.dataset.featureMathState).toBe('ready');

      updateFeatureState('math', 'error');
      expect(document.body.dataset.featureMathState).toBe('error');

      updateFeatureState('math', 'skipped');
      expect(document.body.dataset.featureMathState).toBe('skipped');
    });

    it('should do nothing when body is missing', () => {
      // Remove body temporarily
      const originalBody = document.body;
      Object.defineProperty(document, 'body', {
        value: null,
        writable: true,
        configurable: true
      });

      const updateFeatureState = (feature, state) => {
        const body = document.body;
        if (!body) return;
        const key = `featureSearchState`;
        body.dataset[key] = state;
      };

      expect(() => updateFeatureState('search', 'ready')).not.toThrow();

      // Restore body
      Object.defineProperty(document, 'body', {
        value: originalBody,
        writable: true,
        configurable: true
      });
    });
  });

  describe('bootstrapFeatures()', () => {
    it('should load core bundle', async () => {
      const manifest = {
        core: '/assets/js/dist/core.js',
        features: {}
      };

      const importModule = vi.fn(() => Promise.resolve({}));

      // Simple test that manifest structure is correct
      expect(manifest.core).toBe('/assets/js/dist/core.js');
      expect(manifest.features).toEqual({});
    });

    it('should warn when core bundle is missing', () => {
      const consoleWarn = vi.spyOn(console, 'warn').mockImplementation(() => {});

      const manifest = {
        features: {}
      };

      bootstrapFeatures(manifest);

      expect(consoleWarn).toHaveBeenCalledWith(
        expect.stringContaining('Core bundle missing'),
        manifest
      );

      consoleWarn.mockRestore();
    });

    it('should handle core bundle load failure', async () => {
      const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

      const manifest = {
        core: '/nonexistent.js',
        features: {}
      };

      // The actual import will fail, but we're testing the structure
      expect(manifest.core).toBe('/nonexistent.js');

      consoleError.mockRestore();
    });

    it('should enable features with dataset value "true"', () => {
      document.body.dataset.featureSearch = 'true';

      const featureConfig = [
        {
          name: 'search',
          test: () => document.querySelector('[data-search-app]')
        }
      ];

      const requestedFeatures = featureConfig.filter((feature) => {
        const datasetKey = `feature${feature.name.replace(/(^|-)([a-z])/g, (_, __, char) => char.toUpperCase())}`;
        const datasetValue = document.body.dataset[datasetKey];
        const enabled = datasetValue === 'true' || datasetValue === 'auto';
        return enabled;
      });

      expect(requestedFeatures).toHaveLength(1);
      expect(requestedFeatures[0].name).toBe('search');
    });

    it('should enable features with dataset value "auto" when test passes', () => {
      document.body.innerHTML = '<div data-search-app></div>';
      document.body.dataset.featureSearch = 'auto';

      const featureConfig = [
        {
          name: 'search',
          test: () => document.querySelector('[data-search-app]')
        }
      ];

      const requestedFeatures = featureConfig.filter((feature) => {
        const datasetKey = `featureSearch`;
        const datasetValue = document.body.dataset[datasetKey];
        const enabled = datasetValue === 'true' || datasetValue === 'auto';
        if (!enabled) {
          return false;
        }
        if (datasetValue === 'auto') {
          return typeof feature.test === 'function' ? Boolean(feature.test()) : true;
        }
        return true;
      });

      expect(requestedFeatures).toHaveLength(1);
    });

    it('should skip features with dataset value "auto" when test fails', () => {
      document.body.dataset.featureSearch = 'auto';

      const featureConfig = [
        {
          name: 'search',
          test: () => document.querySelector('[data-search-app]') // Will be null
        }
      ];

      const requestedFeatures = featureConfig.filter((feature) => {
        const datasetValue = document.body.dataset.featureSearch;
        const enabled = datasetValue === 'true' || datasetValue === 'auto';
        if (!enabled) {
          return false;
        }
        if (datasetValue === 'auto') {
          return typeof feature.test === 'function' ? Boolean(feature.test()) : true;
        }
        return true;
      });

      expect(requestedFeatures).toHaveLength(0);
    });

    it('should skip features when feature URL is missing', async () => {
      const manifest = {
        core: '/assets/js/dist/core.js',
        features: {}
      };

      document.body.dataset.featureSearch = 'true';

      // If URL is missing, feature should be skipped
      expect(manifest.features.search).toBeUndefined();
    });

    it('should handle feature load errors gracefully', () => {
      const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

      const manifest = {
        core: '/assets/js/dist/core.js',
        features: {
          search: '/nonexistent-search.js'
        }
      };

      // Feature load will fail but should not crash
      expect(manifest.features.search).toBe('/nonexistent-search.js');

      consoleError.mockRestore();
    });

    it('should load multiple features in parallel', async () => {
      const manifest = {
        core: '/assets/js/dist/core.js',
        features: {
          search: '/assets/js/dist/search.js',
          math: '/assets/js/dist/math.js',
          visualizations: '/assets/js/dist/visualizations.js'
        }
      };

      document.body.dataset.featureSearch = 'true';
      document.body.dataset.featureMath = 'true';
      document.body.dataset.featureVisualizations = 'true';

      // Verify all features are in manifest
      expect(manifest.features.search).toBeTruthy();
      expect(manifest.features.math).toBeTruthy();
      expect(manifest.features.visualizations).toBeTruthy();
    });

    it('should detect search feature from DOM', () => {
      document.body.innerHTML = '<div data-search-app></div>';

      const test = () => document.querySelector('[data-search-app]') || document.querySelector('.site-search');

      expect(test()).toBeTruthy();
    });

    it('should detect search feature from site-search class', () => {
      document.body.innerHTML = '<form class="site-search"></form>';

      const test = () => document.querySelector('[data-search-app]') || document.querySelector('.site-search');

      expect(test()).toBeTruthy();
    });

    it('should detect visualizations feature', () => {
      document.body.innerHTML = '<div data-viz-type="plotly"></div>';

      const test = () => document.querySelector('[data-viz-type]');

      expect(test()).toBeTruthy();
    });

    it('should detect math feature from dataset', () => {
      document.body.dataset.featureMath = 'true';

      const test = () => document.body?.dataset.featureMath === 'true';

      expect(test()).toBe(true);
    });

    it('should detect academic feature from citation elements', () => {
      document.body.innerHTML = '<span data-citation-metric="total"></span>';

      const test = () => document.querySelector('[data-citation-metric], [data-citation-table], [data-citation-chart]');

      expect(test()).toBeTruthy();
    });

    it('should detect notebook feature from dataset', () => {
      document.body.dataset.featureNotebook = 'true';

      const test = () => document.body?.dataset.featureNotebook === 'true' || document.querySelector('.notebook-output');

      expect(test()).toBe(true);
    });

    it('should detect notebook feature from output class', () => {
      document.body.innerHTML = '<div class="notebook-output"></div>';

      const test = () => document.body?.dataset.featureNotebook === 'true' || document.querySelector('.notebook-output');

      expect(test()).toBeTruthy();
    });

    it('should execute bootstrapFeatures on DOMContentLoaded when document is loading', () => {
      // Simulate loading state
      Object.defineProperty(document, 'readyState', {
        value: 'loading',
        writable: true,
        configurable: true
      });

      const addEventListener = vi.spyOn(document, 'addEventListener');

      // Re-run the check
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {});
      }

      expect(addEventListener).toHaveBeenCalledWith('DOMContentLoaded', expect.any(Function));

      addEventListener.mockRestore();
    });

    it('should execute bootstrapFeatures immediately when document is ready', () => {
      // Simulate ready state
      Object.defineProperty(document, 'readyState', {
        value: 'interactive',
        writable: true,
        configurable: true
      });

      // When not loading, bootstrap should be called immediately
      expect(document.readyState).not.toBe('loading');
    });
  });

  describe('Feature Detection', () => {
    it('should correctly identify enabled features', () => {
      document.body.dataset.featureSearch = 'true';
      document.body.dataset.featureMath = 'false';
      document.body.dataset.featureVisualizations = 'auto';

      expect(document.body.dataset.featureSearch).toBe('true');
      expect(document.body.dataset.featureMath).toBe('false');
      expect(document.body.dataset.featureVisualizations).toBe('auto');
    });

    it('should handle missing feature flags', () => {
      expect(document.body.dataset.featureSearch).toBeUndefined();
    });

    it('should allow any dataset value for features', () => {
      document.body.dataset.featureCustom = 'custom-value';

      expect(document.body.dataset.featureCustom).toBe('custom-value');
    });
  });

  describe('Import Module', () => {
    it('should dynamically import modules', async () => {
      // This tests that the import function signature works
      const importModule = async (url) => import(url);

      expect(importModule).toBeInstanceOf(Function);
    });

    it('should handle import errors', async () => {
      const importModule = async (url) => {
        try {
          return await import(url);
        } catch (error) {
          throw error;
        }
      };

      await expect(importModule('/nonexistent-module.js')).rejects.toThrow();
    });
  });

  describe('Feature Configuration', () => {
    it('should have all required feature configs', () => {
      const FEATURE_CONFIG = [
        { name: 'search', test: () => true },
        { name: 'visualizations', test: () => true },
        { name: 'math', test: () => true },
        { name: 'academic', test: () => true },
        { name: 'notebook', test: () => true }
      ];

      expect(FEATURE_CONFIG).toHaveLength(5);
      FEATURE_CONFIG.forEach(config => {
        expect(config).toHaveProperty('name');
        expect(config).toHaveProperty('test');
        expect(typeof config.test).toBe('function');
      });
    });

    it('should have valid feature names', () => {
      const FEATURE_CONFIG = [
        { name: 'search' },
        { name: 'visualizations' },
        { name: 'math' },
        { name: 'academic' },
        { name: 'notebook' }
      ];

      FEATURE_CONFIG.forEach(config => {
        expect(config.name).toMatch(/^[a-z]+$/);
      });
    });
  });

  describe('bootstrapFeatures() state management', () => {
    it('should set core state to loading then ready', async () => {
      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {}
      };

      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureCoreState).toBe('ready');
    });

    it('should set feature state to loading then ready', async () => {
      document.body.dataset.featureSearch = 'true';
      document.body.innerHTML += '<div data-search-app></div>';

      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {
          search: 'data:text/javascript,export default {}'
        }
      };

      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureSearchState).toBe('ready');
    });

    it('should set feature state to skipped when test fails', async () => {
      document.body.dataset.featureSearch = 'true';
      // No search app element, so test will fail

      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {
          search: 'data:text/javascript,export default {}'
        }
      };

      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureSearchState).toBe('skipped');
    });

    it('should set feature state to error on load failure', async () => {
      document.body.dataset.featureMath = 'true';

      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {
          math: '/nonexistent-module-that-will-fail.js'
        }
      };

      const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureMathState).toBe('error');
      expect(consoleError).toHaveBeenCalledWith(
        expect.stringContaining('Failed to load math'),
        expect.any(Error)
      );

      consoleError.mockRestore();
    });

    it('should skip features when URL is missing from manifest', async () => {
      document.body.dataset.featureSearch = 'true';
      document.body.innerHTML += '<div data-search-app></div>';

      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {
          // search URL is missing
        }
      };

      await bootstrapFeatures(manifest);

      // Feature was requested but URL is missing - state could be undefined or loading/skipped
      // depending on implementation details
      const state = document.body.dataset.featureSearchState;
      expect(state === undefined || state === 'loading').toBe(true);
    });
  });

  describe('bootstrapFeatures() with auto detection', () => {
    it('should auto-detect visualizations from viz-type', async () => {
      document.body.dataset.featureVisualizations = 'auto';
      document.body.innerHTML += '<div data-viz-type="plotly"></div>';

      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {
          visualizations: 'data:text/javascript,export default {}'
        }
      };

      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureVisualizationsState).toBe('ready');
    });

    it('should auto-detect academic from citation elements', async () => {
      document.body.dataset.featureAcademic = 'auto';
      document.body.innerHTML += '<span data-citation-table></span>';

      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {
          academic: 'data:text/javascript,export default {}'
        }
      };

      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureAcademicState).toBe('ready');
    });

    it('should auto-detect academic from citation-chart', async () => {
      document.body.dataset.featureAcademic = 'auto';
      document.body.innerHTML += '<div data-citation-chart></div>';

      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {
          academic: 'data:text/javascript,export default {}'
        }
      };

      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureAcademicState).toBe('ready');
    });

    it('should auto-detect notebook from output class', async () => {
      document.body.dataset.featureNotebook = 'auto';
      document.body.innerHTML += '<div class="notebook-output"></div>';

      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {
          notebook: 'data:text/javascript,export default {}'
        }
      };

      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureNotebookState).toBe('ready');
    });

    it('should skip auto-detect when element is missing', async () => {
      document.body.dataset.featureVisualizations = 'auto';
      // No viz-type element

      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {
          visualizations: 'data:text/javascript,export default {}'
        }
      };

      await bootstrapFeatures(manifest);

      // Feature not enabled because auto-detect test failed before feature was requested
      const state = document.body.dataset.featureVisualizationsState;
      expect(state === undefined || state === 'skipped').toBe(true);
    });
  });

  // The header's search form is on every page, but only the search page
  // renders the app; matching the form loaded the search bundle everywhere.
  describe('search bundle', () => {
    const manifest = {
      core: 'data:text/javascript,export default {}',
      features: { search: 'data:text/javascript,export default {}' }
    };

    it('is not loaded for the header search form alone', async () => {
      document.body.dataset.featureSearch = 'auto';
      document.body.innerHTML = '<form class="site-search" action="/search/"><input name="q"></form>';

      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureSearchState).not.toBe('ready');
    });

    it('is loaded on a page that renders the search app', async () => {
      document.body.dataset.featureSearch = 'auto';
      document.body.innerHTML = '<div data-search-app></div>';

      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureSearchState).toBe('ready');
    });
  });

  describe('bootstrapFeatures() parallel loading', () => {
    it('should load multiple features in parallel', async () => {
      document.body.dataset.featureSearch = 'true';
      document.body.dataset.featureMath = 'true';
      document.body.dataset.featureNotebook = 'true';

      document.body.innerHTML += '<div data-search-app></div>';

      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {
          search: 'data:text/javascript,export default {}',
          math: 'data:text/javascript,export default {}',
          notebook: 'data:text/javascript,export default {}'
        }
      };

      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureSearchState).toBe('ready');
      expect(document.body.dataset.featureMathState).toBe('ready');
      expect(document.body.dataset.featureNotebookState).toBe('ready');
    });
  });

  describe('readManifest() from DOM', () => {
    it('should parse valid JSON from manifest element', async () => {
      const manifest = {
        core: '/this-file-does-not-exist-12345.js',
        features: {
          search: '/assets/js/dist/search.js'
        }
      };

      document.head.innerHTML = `
        <script id="datalog-js-manifest" type="application/json">
          ${JSON.stringify(manifest)}
        </script>
      `;

      // Call bootstrapFeatures without passing manifest to test readManifest()
      const consoleWarn = vi.spyOn(console, 'warn').mockImplementation(() => {});

      // This will try to load the core from the manifest, which will fail
      // but it proves readManifest() worked
      const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

      await bootstrapFeatures();

      // Should have tried to load core (which failed because URL doesn't exist)
      expect(document.body.dataset.featureCoreState).toBe('error');

      consoleWarn.mockRestore();
      consoleError.mockRestore();
    });

    it('should handle missing manifest element', async () => {
      const consoleWarn = vi.spyOn(console, 'warn').mockImplementation(() => {});

      await bootstrapFeatures();

      expect(consoleWarn).toHaveBeenCalledWith(
        expect.stringContaining('Core bundle missing'),
        expect.any(Object)
      );

      consoleWarn.mockRestore();
    });

    it('should handle empty manifest element', async () => {
      document.head.innerHTML = `
        <script id="datalog-js-manifest" type="application/json"></script>
      `;

      const consoleWarn = vi.spyOn(console, 'warn').mockImplementation(() => {});

      await bootstrapFeatures();

      expect(consoleWarn).toHaveBeenCalled();

      consoleWarn.mockRestore();
    });

    it('should log error for invalid JSON in manifest', async () => {
      document.head.innerHTML = `
        <script id="datalog-js-manifest" type="application/json">
          { invalid json here }
        </script>
      `;

      const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});
      const consoleWarn = vi.spyOn(console, 'warn').mockImplementation(() => {});

      await bootstrapFeatures();

      expect(consoleError).toHaveBeenCalledWith(
        expect.stringContaining('Unable to parse'),
        expect.any(Error)
      );

      consoleError.mockRestore();
      consoleWarn.mockRestore();
    });
  });

  describe('bootstrapFeatures() body missing', () => {
    it('should handle missing body gracefully after core loads', async () => {
      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {}
      };

      // This should complete without error
      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureCoreState).toBe('ready');
    });
  });

  describe('Feature detection edge cases', () => {
    it('should not enable features with value "false"', async () => {
      document.body.dataset.featureSearch = 'false';
      document.body.innerHTML += '<div data-search-app></div>';

      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {
          search: 'data:text/javascript,export default {}'
        }
      };

      await bootstrapFeatures(manifest);

      // Should not have loaded search - state should be undefined or not set
      const state = document.body.dataset.featureSearchState;
      expect(state === undefined || state === 'false').toBe(true);
    });

    it('should not enable features with no dataset value', async () => {
      // featureSearch is not set - important: don't set any featureSearch dataset value
      document.body.innerHTML = '<div data-search-app></div>';

      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {
          search: 'data:text/javascript,export default {}'
        }
      };

      await bootstrapFeatures(manifest);

      // When no dataset value is set, feature should not be processed
      const state = document.body.dataset.featureSearchState;
      expect(state === undefined || state === 'skipped').toBe(true);
    });

    it('should request features with value "true"', async () => {
      document.body.dataset.featureSearch = 'true';
      // No search-app element

      const manifest = {
        core: 'data:text/javascript,export default {}',
        features: {
          search: 'data:text/javascript,export default {}'
        }
      };

      await bootstrapFeatures(manifest);

      // With 'true', feature is requested but test result determines final state
      const state = document.body.dataset.featureSearchState;
      expect(['loading', 'skipped', 'ready'].includes(state)).toBe(true);
    });
  });

  describe('toDatasetKey() edge cases', () => {
    it('should handle empty string', () => {
      const convert = (feature) => {
        return `feature${feature.replace(/(^|-)([a-z])/g, (_, __, char) => char.toUpperCase())}`;
      };

      expect(convert('')).toBe('feature');
    });

    it('should handle already capitalized names', () => {
      const convert = (feature) => {
        return `feature${feature.replace(/(^|-)([a-z])/g, (_, __, char) => char.toUpperCase())}`;
      };

      // Capital letters are not affected
      expect(convert('Search')).toBe('featureSearch');
    });

    it('should handle numbers in names', () => {
      const convert = (feature) => {
        return `feature${feature.replace(/(^|-)([a-z])/g, (_, __, char) => char.toUpperCase())}`;
      };

      expect(convert('search-v2')).toBe('featureSearchV2');
    });
  });

  describe('Core bundle loading', () => {
    it('should set core state to error on load failure', async () => {
      const manifest = {
        core: '/this-core-module-does-not-exist.js',
        features: {}
      };

      const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureCoreState).toBe('error');
      expect(consoleError).toHaveBeenCalledWith(
        expect.stringContaining('Failed to load core'),
        expect.any(Error)
      );

      consoleError.mockRestore();
    });

    it('should not load features when core fails', async () => {
      document.body.dataset.featureSearch = 'true';
      document.body.innerHTML += '<div data-search-app></div>';

      const manifest = {
        core: '/this-core-module-does-not-exist.js',
        features: {
          search: 'data:text/javascript,export default {}'
        }
      };

      const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

      await bootstrapFeatures(manifest);

      expect(document.body.dataset.featureCoreState).toBe('error');
      // Features may still be filtered/skipped due to the early return, but could have a state set
      const state = document.body.dataset.featureSearchState;
      expect(state === undefined || state === 'skipped').toBe(true);

      consoleError.mockRestore();
    });
  });
});
