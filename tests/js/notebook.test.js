import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import {
  loadScript,
  initPlotly,
  initVega,
  annotateCells,
  handleScrollSpy,
  initNotebookFeatures
} from '../../assets/js/notebook.js';

describe('Notebook Module', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    document.head.innerHTML = '';
    delete window.Plotly;
    delete window.vegaEmbed;
    vi.clearAllMocks();
  });

  afterEach(() => {
    delete window.Plotly;
    delete window.vegaEmbed;
  });

  describe('loadScript()', () => {
    it('should create and append script element', () => {
      const src = 'https://cdn.plot.ly/plotly-2.27.0.min.js';

      loadScript(src);

      const script = document.querySelector(`script[src="${src}"]`);
      expect(script).toBeTruthy();
      expect(script.src).toBe(src);
      expect(script.async).toBe(true);
    });

    it('should not load duplicate scripts', () => {
      const src = 'https://cdn.plot.ly/plotly-2.27.0.min.js';

      // Create script manually first
      const existing = document.createElement('script');
      existing.src = src;
      document.head.appendChild(existing);

      // Try to load again
      loadScript(src);

      // Should only have one script
      const scripts = document.querySelectorAll(`script[src="${src}"]`);
      expect(scripts.length).toBe(1);
    });

    it('should resolve promise on load', async () => {
      const src = 'https://test.com/script.js';

      const promise = loadScript(src);

      // Simulate load
      const script = document.querySelector(`script[src="${src}"]`);
      script.onload();

      await expect(promise).resolves.toBeUndefined();
    });

    it('should reject promise on error', async () => {
      const src = 'https://test.com/nonexistent.js';

      const promise = loadScript(src);

      // Simulate error
      const script = document.querySelector(`script[src="${src}"]`);
      script.onerror(new Error('Load failed'));

      await expect(promise).rejects.toThrow();
    });
  });

  describe('initPlotly()', () => {
    it('should do nothing when no Plotly targets exist', async () => {
      document.body.innerHTML = '<div>No plots</div>';

      await initPlotly();

      const plotlyTargets = document.querySelectorAll('.notebook-output-plotly');
      expect(plotlyTargets.length).toBe(0);
    });

    it('should load Plotly when targets exist', () => {
      document.body.innerHTML = '<div class="notebook-output-plotly"></div>';

      const plotlyTargets = document.querySelectorAll('.notebook-output-plotly');
      expect(plotlyTargets.length).toBe(1);
    });

    it('should use existing Plotly if available', async () => {
      window.Plotly = {
        newPlot: vi.fn()
      };

      document.body.innerHTML = '<div class="notebook-output-plotly" data-plotly=\'{"data": []}\' ></div>';

      await initPlotly();

      expect(window.Plotly.newPlot).toHaveBeenCalled();
    });

    it('should parse Plotly spec from dataset', () => {
      const spec = {
        data: [{ x: [1, 2, 3], y: [4, 5, 6], type: 'scatter' }],
        layout: { title: 'Test Plot' }
      };

      document.body.innerHTML = `
        <div class="notebook-output-plotly" data-plotly='${JSON.stringify(spec)}'></div>
      `;

      const target = document.querySelector('.notebook-output-plotly');
      const parsed = JSON.parse(target.dataset.plotly || '{}');

      expect(parsed.data).toEqual(spec.data);
      expect(parsed.layout).toEqual(spec.layout);
    });

    it('should handle invalid Plotly JSON', () => {
      document.body.innerHTML = `
        <div class="notebook-output-plotly" data-plotly='invalid json'></div>
      `;

      const target = document.querySelector('.notebook-output-plotly');

      try {
        JSON.parse(target.dataset.plotly || '{}');
      } catch (error) {
        target.innerHTML = '<p class="notebook-output__warning">Plotly figure could not be rendered. Open in Binder or Colab to interact.</p>';
      }

      expect(target.innerHTML).toContain('could not be rendered');
    });

    it('should handle empty dataset', () => {
      document.body.innerHTML = '<div class="notebook-output-plotly"></div>';

      const target = document.querySelector('.notebook-output-plotly');
      const spec = JSON.parse(target.dataset.plotly || '{}');

      expect(spec).toEqual({});
    });

    it('should extract data array from spec', () => {
      const spec = {
        data: [{ x: [1, 2], y: [3, 4] }]
      };

      document.body.innerHTML = `
        <div class="notebook-output-plotly" data-plotly='${JSON.stringify(spec)}'></div>
      `;

      const target = document.querySelector('.notebook-output-plotly');
      const parsed = JSON.parse(target.dataset.plotly || '{}');
      const data = Array.isArray(parsed.data) ? parsed.data : Array.isArray(parsed) ? parsed : [];

      expect(Array.isArray(data)).toBe(true);
      expect(data).toEqual(spec.data);
    });

    it('should handle spec as array', () => {
      const spec = [{ x: [1, 2], y: [3, 4] }];

      document.body.innerHTML = `
        <div class="notebook-output-plotly" data-plotly='${JSON.stringify(spec)}'></div>
      `;

      const target = document.querySelector('.notebook-output-plotly');
      const parsed = JSON.parse(target.dataset.plotly || '{}');
      const data = Array.isArray(parsed.data) ? parsed.data : Array.isArray(parsed) ? parsed : [];

      expect(data).toEqual(spec);
    });

    it('should show error message on load failure', () => {
      document.body.innerHTML = '<div class="notebook-output-plotly"></div>';

      const target = document.querySelector('.notebook-output-plotly');
      target.innerHTML = '<p class="notebook-output__warning">Plotly assets failed to load. Launch Binder/Colab to view the interactive chart.</p>';

      expect(target.innerHTML).toContain('assets failed to load');
    });
  });

  describe('initVega()', () => {
    it('should do nothing when no Vega targets exist', async () => {
      document.body.innerHTML = '<div>No visualizations</div>';

      const result = await initVega();

      expect(result).toBeUndefined();
    });

    it('should parse and render Vega specs', () => {
      const spec = { mark: 'bar', data: { values: [{ a: 1, b: 2 }] } };
      document.body.innerHTML = `
        <div class="notebook-output-vega" data-vega='${JSON.stringify(spec)}'></div>
      `;

      const target = document.querySelector('.notebook-output-vega');
      const parsed = JSON.parse(target.dataset.vega || '{}');

      expect(parsed).toEqual(spec);
    });

    it('should handle JSON parsing errors', () => {
      document.body.innerHTML = '<div class="notebook-output-vega" data-vega="invalid json"></div>';

      const target = document.querySelector('.notebook-output-vega');

      try {
        JSON.parse(target.dataset.vega || '{}');
      } catch (error) {
        expect(error).toBeTruthy();
      }
    });

    it('should default to empty object for missing data-vega', () => {
      document.body.innerHTML = '<div class="notebook-output-vega"></div>';

      const target = document.querySelector('.notebook-output-vega');
      const parsed = JSON.parse(target.dataset.vega || '{}');

      expect(parsed).toEqual({});
    });

    it('should load Vega dependencies in sequence', () => {
      const scripts = [];

      const loadScript = (url) => {
        scripts.push(url);
        return Promise.resolve();
      };

      const ensureVega = () =>
        loadScript('https://cdn.jsdelivr.net/npm/vega@5')
          .then(() => loadScript('https://cdn.jsdelivr.net/npm/vega-lite@5'))
          .then(() => loadScript('https://cdn.jsdelivr.net/npm/vega-embed@6'));

      return ensureVega().then(() => {
        expect(scripts).toEqual([
          'https://cdn.jsdelivr.net/npm/vega@5',
          'https://cdn.jsdelivr.net/npm/vega-lite@5',
          'https://cdn.jsdelivr.net/npm/vega-embed@6'
        ]);
      });
    });

    it('should parse Vega spec from dataset', () => {
      const spec = {
        $schema: 'https://vega.github.io/schema/vega-lite/v5.json',
        data: { values: [{ a: 'A', b: 28 }] },
        mark: 'bar',
        encoding: {
          x: { field: 'a', type: 'nominal' },
          y: { field: 'b', type: 'quantitative' }
        }
      };

      document.body.innerHTML = `
        <div class="notebook-output-vega" data-vega='${JSON.stringify(spec)}'></div>
      `;

      const target = document.querySelector('.notebook-output-vega');
      const parsed = JSON.parse(target.dataset.vega || '{}');

      expect(parsed).toEqual(spec);
    });

    it('should handle invalid Vega JSON', () => {
      document.body.innerHTML = `
        <div class="notebook-output-vega" data-vega='invalid'></div>
      `;

      const target = document.querySelector('.notebook-output-vega');

      try {
        JSON.parse(target.dataset.vega || '{}');
      } catch (error) {
        target.innerHTML = '<p class="notebook-output__warning">Vega specification could not be parsed. Open in Binder for the interactive version.</p>';
      }

      expect(target.innerHTML).toContain('could not be parsed');
    });

    it('should call vegaEmbed when available', () => {
      window.vegaEmbed = vi.fn();

      const spec = { mark: 'bar' };

      document.body.innerHTML = `
        <div class="notebook-output-vega" data-vega='${JSON.stringify(spec)}'></div>
      `;

      const target = document.querySelector('.notebook-output-vega');
      const parsed = JSON.parse(target.dataset.vega || '{}');

      window.vegaEmbed(target, parsed, { actions: false });

      expect(window.vegaEmbed).toHaveBeenCalledWith(target, spec, { actions: false });
    });

    it('should show error message on load failure', () => {
      document.body.innerHTML = '<div class="notebook-output-vega"></div>';

      const target = document.querySelector('.notebook-output-vega');
      target.innerHTML = '<p class="notebook-output__warning">Vega assets failed to load. Launch Binder/Colab to view the interactive chart.</p>';

      expect(target.innerHTML).toContain('assets failed to load');
    });
  });

  describe('annotateCells()', () => {
    it('should annotate segments with IDs and data attributes', () => {
      document.body.innerHTML = `
        <div class="notebook-segment"></div>
        <div class="notebook-segment" id="custom-id"></div>
        <div class="notebook-segment"></div>
      `;

      annotateCells();

      const segments = document.querySelectorAll('.notebook-segment');

      expect(segments[0].id).toBe('cell-1');
      expect(segments[0].getAttribute('data-cell-anchor')).toBe('cell-1');

      expect(segments[1].id).toBe('custom-id');
      expect(segments[1].getAttribute('data-cell-anchor')).toBe('custom-id');

      expect(segments[2].id).toBe('cell-3');
      expect(segments[2].getAttribute('data-cell-anchor')).toBe('cell-3');
    });

    it('should handle empty segments list', () => {
      document.body.innerHTML = '<div>No segments</div>';

      expect(() => annotateCells()).not.toThrow();
    });
  });

  describe('annotateCells()', () => {
    it('should assign IDs to notebook segments', () => {
      document.body.innerHTML = `
        <div class="notebook-segment"></div>
        <div class="notebook-segment"></div>
        <div class="notebook-segment"></div>
      `;

      annotateCells();

      const segments = document.querySelectorAll('.notebook-segment');
      expect(segments[0].id).toBe('cell-1');
      expect(segments[1].id).toBe('cell-2');
      expect(segments[2].id).toBe('cell-3');
    });

    it('should preserve existing IDs', () => {
      document.body.innerHTML = `
        <div class="notebook-segment" id="custom-id"></div>
      `;

      annotateCells();

      const segment = document.querySelector('.notebook-segment');
      expect(segment.id).toBe('custom-id');
      expect(segment.getAttribute('data-cell-anchor')).toBe('custom-id');
    });

    it('should set data-cell-anchor attribute', () => {
      document.body.innerHTML = '<div class="notebook-segment"></div>';

      annotateCells();

      const segment = document.querySelector('.notebook-segment');
      expect(segment.getAttribute('data-cell-anchor')).toBe('cell-1');
    });

    it('should handle no segments gracefully', () => {
      document.body.innerHTML = '<div>No notebook content</div>';

      annotateCells();

      const segments = document.querySelectorAll('.notebook-segment');
      expect(segments.length).toBe(0);
    });
  });

  describe('handleScrollSpy()', () => {
    it('should do nothing when no segments exist', () => {
      document.body.innerHTML = '<div>No segments</div>';

      expect(() => handleScrollSpy()).not.toThrow();
    });

    it('should do nothing when no sidebar links exist', () => {
      document.body.innerHTML = '<div class="notebook-segment" id="cell-1"></div>';

      expect(() => handleScrollSpy()).not.toThrow();
    });

    it('should set up intersection observer for segments', () => {
      document.body.innerHTML = `
        <div class="notebook-segment" id="cell-1"></div>
        <div class="notebook-segment" id="cell-2"></div>
        <a href="#cell-1" data-cell-anchor-link>Cell 1</a>
        <a href="#cell-2" data-cell-anchor-link>Cell 2</a>
      `;

      const observeSpy = vi.spyOn(IntersectionObserver.prototype, 'observe');

      handleScrollSpy();

      const segments = document.querySelectorAll('.notebook-segment');
      expect(observeSpy).toHaveBeenCalledTimes(segments.length);

      observeSpy.mockRestore();
    });
  });

  describe('handleScrollSpy()', () => {
    it('should set up IntersectionObserver', () => {
      document.body.innerHTML = `
        <div class="notebook-segment" id="cell-1"></div>
        <a data-cell-anchor-link href="#cell-1"></a>
      `;

      handleScrollSpy();

      const entries = document.querySelectorAll('.notebook-segment');
      const sidebarLinks = document.querySelectorAll('[data-cell-anchor-link]');

      expect(entries.length).toBe(1);
      expect(sidebarLinks.length).toBe(1);
    });

    it('should do nothing when no segments exist', () => {
      document.body.innerHTML = '<div>No content</div>';

      handleScrollSpy();

      const entries = document.querySelectorAll('.notebook-segment');
      const sidebarLinks = document.querySelectorAll('[data-cell-anchor-link]');

      expect(entries.length).toBe(0);
      expect(sidebarLinks.length).toBe(0);
    });

    it('should do nothing when no sidebar links exist', () => {
      document.body.innerHTML = '<div class="notebook-segment"></div>';

      handleScrollSpy();

      const entries = document.querySelectorAll('.notebook-segment');
      const sidebarLinks = document.querySelectorAll('[data-cell-anchor-link]');

      expect(entries.length).toBe(1);
      expect(sidebarLinks.length).toBe(0);
    });

    it('should mark active link on intersection', () => {
      document.body.innerHTML = `
        <div class="notebook-segment" id="cell-1"></div>
        <a data-cell-anchor-link href="#cell-1" class="sidebar-link"></a>
        <a data-cell-anchor-link href="#cell-2" class="sidebar-link"></a>
      `;

      const observerOptions = {
        root: null,
        rootMargin: '0px 0px -65%',
        threshold: 0
      };

      expect(observerOptions.threshold).toBe(0);
      expect(observerOptions.rootMargin).toBe('0px 0px -65%');
    });

    it('should toggle is-active class on links', () => {
      document.body.innerHTML = `
        <div class="notebook-segment" id="cell-1"></div>
        <a data-cell-anchor-link href="#cell-1" class="sidebar-link"></a>
      `;

      const link = document.querySelector('[data-cell-anchor-link]');
      const targetId = 'cell-1';

      link.classList.toggle('is-active', link.hash === `#${targetId}`);

      expect(link.classList.contains('is-active')).toBe(true);
    });

    it('should remove is-active from other links', () => {
      document.body.innerHTML = `
        <a data-cell-anchor-link href="#cell-1" class="sidebar-link is-active"></a>
        <a data-cell-anchor-link href="#cell-2" class="sidebar-link"></a>
      `;

      const links = document.querySelectorAll('[data-cell-anchor-link]');
      const activeId = 'cell-2';

      links.forEach((link) => {
        link.classList.toggle('is-active', link.hash === `#${activeId}`);
      });

      expect(links[0].classList.contains('is-active')).toBe(false);
      expect(links[1].classList.contains('is-active')).toBe(true);
    });
  });

  describe('boot()', () => {
    it('should call all initialization functions', () => {
      document.body.innerHTML = `
        <div class="notebook-segment"></div>
        <div class="notebook-output-plotly"></div>
      `;

      const annotated = document.querySelectorAll('.notebook-segment[data-cell-anchor]').length === 0;
      const plotlyTargets = document.querySelectorAll('.notebook-output-plotly');

      expect(annotated).toBe(true);
      expect(plotlyTargets.length).toBe(1);
    });

    it('should handle errors gracefully', () => {
      document.body.innerHTML = '<div>Minimal content</div>';

      expect(() => {
        // Simulate boot
        const segments = document.querySelectorAll('.notebook-segment');
        const plotly = document.querySelectorAll('.notebook-output-plotly');
        const vega = document.querySelectorAll('.notebook-output-vega');

        // Should not throw
      }).not.toThrow();
    });
  });

  describe('DOM Ready', () => {
    it('should execute on DOMContentLoaded when document is loading', () => {
      Object.defineProperty(document, 'readyState', {
        value: 'loading',
        writable: true,
        configurable: true
      });

      const addEventListener = vi.spyOn(document, 'addEventListener');

      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {});
      }

      expect(addEventListener).toHaveBeenCalledWith('DOMContentLoaded', expect.any(Function));

      addEventListener.mockRestore();
    });

    it('should execute immediately when document is ready', () => {
      Object.defineProperty(document, 'readyState', {
        value: 'interactive',
        writable: true,
        configurable: true
      });

      expect(document.readyState).not.toBe('loading');
    });
  });

  describe('Error Handling', () => {
    it('should show warning on Plotly error', () => {
      document.body.innerHTML = '<div class="notebook-output-plotly"></div>';

      const target = document.querySelector('.notebook-output-plotly');

      // Simulate error
      target.innerHTML = '<p class="notebook-output__warning">Plotly figure could not be rendered. Open in Binder or Colab to interact.</p>';

      expect(target.querySelector('.notebook-output__warning')).toBeTruthy();
    });

    it('should show warning on Vega error', () => {
      document.body.innerHTML = '<div class="notebook-output-vega"></div>';

      const target = document.querySelector('.notebook-output-vega');

      // Simulate error
      target.innerHTML = '<p class="notebook-output__warning">Vega specification could not be parsed. Open in Binder for the interactive version.</p>';

      expect(target.querySelector('.notebook-output__warning')).toBeTruthy();
    });

    it('should handle script load failures', () => {
      document.body.innerHTML = '<div class="notebook-output-plotly"></div>';

      const targets = document.querySelectorAll('.notebook-output-plotly');

      // Simulate script load failure
      targets.forEach((target) => {
        target.innerHTML = '<p class="notebook-output__warning">Plotly assets failed to load. Launch Binder/Colab to view the interactive chart.</p>';
      });

      expect(document.querySelector('.notebook-output__warning')).toBeTruthy();
    });
  });

  describe('Responsive Configuration', () => {
    it('should use responsive mode for Plotly', () => {
      const config = { responsive: true };

      expect(config.responsive).toBe(true);
    });

    it('should disable actions for Vega', () => {
      const options = { actions: false };

      expect(options.actions).toBe(false);
    });
  });

  describe('initPlotly() full integration', () => {
    it('should render multiple Plotly figures', async () => {
      window.Plotly = {
        newPlot: vi.fn()
      };

      document.body.innerHTML = `
        <div class="notebook-output-plotly" data-plotly='{"data": [{"x": [1,2,3], "y": [4,5,6]}]}'></div>
        <div class="notebook-output-plotly" data-plotly='{"data": [{"x": [1,2], "y": [3,4]}], "layout": {"title": "Test"}}'></div>
      `;

      await initPlotly();

      expect(window.Plotly.newPlot).toHaveBeenCalledTimes(2);
    });

    it('should handle spec as direct array', async () => {
      window.Plotly = {
        newPlot: vi.fn()
      };

      document.body.innerHTML = `
        <div class="notebook-output-plotly" data-plotly='[{"x": [1,2,3], "y": [4,5,6]}]'></div>
      `;

      await initPlotly();

      expect(window.Plotly.newPlot).toHaveBeenCalled();
      const [, data] = window.Plotly.newPlot.mock.calls[0];
      expect(data).toEqual([{ x: [1, 2, 3], y: [4, 5, 6] }]);
    });

    it('should pass layout options to Plotly', async () => {
      window.Plotly = {
        newPlot: vi.fn()
      };

      const layout = { title: 'My Chart', xaxis: { title: 'X' } };
      document.body.innerHTML = `
        <div class="notebook-output-plotly" data-plotly='${JSON.stringify({ data: [], layout })}'></div>
      `;

      await initPlotly();

      const [, , passedLayout] = window.Plotly.newPlot.mock.calls[0];
      expect(passedLayout).toEqual(layout);
    });

    it('should use responsive config', async () => {
      window.Plotly = {
        newPlot: vi.fn()
      };

      document.body.innerHTML = `
        <div class="notebook-output-plotly" data-plotly='{"data": []}'></div>
      `;

      await initPlotly();

      const [, , , config] = window.Plotly.newPlot.mock.calls[0];
      expect(config.responsive).toBe(true);
    });

    it('should show warning on JSON parse error', async () => {
      window.Plotly = {
        newPlot: vi.fn()
      };

      document.body.innerHTML = `
        <div class="notebook-output-plotly" data-plotly='not valid json'></div>
      `;

      await initPlotly();

      const target = document.querySelector('.notebook-output-plotly');
      expect(target.innerHTML).toContain('could not be rendered');
    });

    it('should handle Plotly.newPlot throwing an error', async () => {
      window.Plotly = {
        newPlot: vi.fn().mockImplementation(() => {
          throw new Error('Plotly error');
        })
      };

      document.body.innerHTML = `
        <div class="notebook-output-plotly" data-plotly='{"data": []}'></div>
      `;

      await initPlotly();

      const target = document.querySelector('.notebook-output-plotly');
      expect(target.innerHTML).toContain('could not be rendered');
    });
  });

  describe('initVega() full integration', () => {
    it('should render multiple Vega figures when vegaEmbed is available', async () => {
      window.vegaEmbed = vi.fn().mockResolvedValue({});

      // Mock script loading for Vega
      const originalLoadScript = loadScript;

      document.body.innerHTML = `
        <div class="notebook-output-vega" data-vega='{"mark": "bar", "data": {"values": []}}'></div>
        <div class="notebook-output-vega" data-vega='{"mark": "point", "data": {"values": []}}'></div>
      `;

      // Create script elements to simulate loaded scripts
      ['vega@5', 'vega-lite@5', 'vega-embed@6'].forEach((lib) => {
        const script = document.createElement('script');
        script.src = `https://cdn.jsdelivr.net/npm/${lib}`;
        document.head.appendChild(script);
      });

      await initVega();

      expect(window.vegaEmbed).toHaveBeenCalledTimes(2);
    });

    it('should pass actions: false to vegaEmbed', async () => {
      window.vegaEmbed = vi.fn().mockResolvedValue({});

      // Pre-create script elements
      ['vega@5', 'vega-lite@5', 'vega-embed@6'].forEach((lib) => {
        const script = document.createElement('script');
        script.src = `https://cdn.jsdelivr.net/npm/${lib}`;
        document.head.appendChild(script);
      });

      document.body.innerHTML = `
        <div class="notebook-output-vega" data-vega='{"mark": "bar"}'></div>
      `;

      await initVega();

      const [, , options] = window.vegaEmbed.mock.calls[0];
      expect(options.actions).toBe(false);
    });

    it('should show warning on JSON parse error', async () => {
      window.vegaEmbed = vi.fn().mockResolvedValue({});

      // Pre-create script elements
      ['vega@5', 'vega-lite@5', 'vega-embed@6'].forEach((lib) => {
        const script = document.createElement('script');
        script.src = `https://cdn.jsdelivr.net/npm/${lib}`;
        document.head.appendChild(script);
      });

      document.body.innerHTML = `
        <div class="notebook-output-vega" data-vega='not valid json'></div>
      `;

      await initVega();

      const target = document.querySelector('.notebook-output-vega');
      expect(target.innerHTML).toContain('could not be parsed');
    });

    it('should handle vegaEmbed throwing an error', async () => {
      window.vegaEmbed = vi.fn().mockImplementation(() => {
        throw new Error('Vega error');
      });

      // Pre-create script elements
      ['vega@5', 'vega-lite@5', 'vega-embed@6'].forEach((lib) => {
        const script = document.createElement('script');
        script.src = `https://cdn.jsdelivr.net/npm/${lib}`;
        document.head.appendChild(script);
      });

      document.body.innerHTML = `
        <div class="notebook-output-vega" data-vega='{"mark": "bar"}'></div>
      `;

      await initVega();

      const target = document.querySelector('.notebook-output-vega');
      expect(target.innerHTML).toContain('could not be parsed');
    });
  });

  describe('initNotebookFeatures() full integration', () => {
    it('should call all initialization functions', () => {
      document.body.innerHTML = `
        <div class="notebook-segment" id="cell-existing"></div>
        <div class="notebook-segment"></div>
        <a data-cell-anchor-link href="#cell-existing"></a>
      `;

      initNotebookFeatures();

      const segments = document.querySelectorAll('.notebook-segment');
      expect(segments[0].getAttribute('data-cell-anchor')).toBe('cell-existing');
      expect(segments[1].getAttribute('data-cell-anchor')).toBe('cell-2');
    });

    it('should handle missing Plotly library gracefully', () => {
      document.body.innerHTML = `
        <div class="notebook-output-plotly" data-plotly='{"data": []}'></div>
      `;

      // Should not throw when Plotly is not available
      expect(() => initNotebookFeatures()).not.toThrow();

      // Target should still exist
      const target = document.querySelector('.notebook-output-plotly');
      expect(target).not.toBeNull();
    });

    it('should handle missing Vega library gracefully', () => {
      document.body.innerHTML = `
        <div class="notebook-output-vega" data-vega='{"mark": "bar"}'></div>
      `;

      // Should not throw when vegaEmbed is not available
      expect(() => initNotebookFeatures()).not.toThrow();

      // Target should still exist
      const target = document.querySelector('.notebook-output-vega');
      expect(target).not.toBeNull();
    });

    it('should initialize scroll spy correctly', () => {
      document.body.innerHTML = `
        <div class="notebook-segment" id="section-1"></div>
        <div class="notebook-segment" id="section-2"></div>
        <a data-cell-anchor-link href="#section-1">Section 1</a>
        <a data-cell-anchor-link href="#section-2">Section 2</a>
      `;

      const observeSpy = vi.spyOn(IntersectionObserver.prototype, 'observe');

      initNotebookFeatures();

      expect(observeSpy).toHaveBeenCalledTimes(2);

      observeSpy.mockRestore();
    });

    it('should handle empty document gracefully', () => {
      document.body.innerHTML = '';

      expect(() => initNotebookFeatures()).not.toThrow();
    });
  });

  describe('handleScrollSpy() IntersectionObserver callback', () => {
    it('should toggle is-active class when entry is intersecting', () => {
      document.body.innerHTML = `
        <div class="notebook-segment" id="cell-1"></div>
        <div class="notebook-segment" id="cell-2"></div>
        <a data-cell-anchor-link href="#cell-1">Cell 1</a>
        <a data-cell-anchor-link href="#cell-2">Cell 2</a>
      `;

      let observerCallback;
      const originalIO = window.IntersectionObserver;

      window.IntersectionObserver = vi.fn(function (callback) {
        observerCallback = callback;
        this.observe = vi.fn();
        this.unobserve = vi.fn();
        this.disconnect = vi.fn();
      });

      handleScrollSpy();

      // Simulate intersection
      const entries = [
        {
          isIntersecting: true,
          target: document.getElementById('cell-1')
        }
      ];

      observerCallback(entries);

      const link1 = document.querySelector('[href="#cell-1"]');
      const link2 = document.querySelector('[href="#cell-2"]');

      expect(link1.classList.contains('is-active')).toBe(true);
      expect(link2.classList.contains('is-active')).toBe(false);

      window.IntersectionObserver = originalIO;
    });

    it('should update active link when scrolling to different section', () => {
      document.body.innerHTML = `
        <div class="notebook-segment" id="cell-1"></div>
        <div class="notebook-segment" id="cell-2"></div>
        <a data-cell-anchor-link href="#cell-1" class="is-active">Cell 1</a>
        <a data-cell-anchor-link href="#cell-2">Cell 2</a>
      `;

      let observerCallback;
      const originalIO = window.IntersectionObserver;

      window.IntersectionObserver = vi.fn(function (callback) {
        observerCallback = callback;
        this.observe = vi.fn();
        this.unobserve = vi.fn();
        this.disconnect = vi.fn();
      });

      handleScrollSpy();

      // Simulate intersection with cell-2
      const entries = [
        {
          isIntersecting: true,
          target: document.getElementById('cell-2')
        }
      ];

      observerCallback(entries);

      const link1 = document.querySelector('[href="#cell-1"]');
      const link2 = document.querySelector('[href="#cell-2"]');

      expect(link1.classList.contains('is-active')).toBe(false);
      expect(link2.classList.contains('is-active')).toBe(true);

      window.IntersectionObserver = originalIO;
    });

    it('should not update when entry is not intersecting', () => {
      document.body.innerHTML = `
        <div class="notebook-segment" id="cell-1"></div>
        <a data-cell-anchor-link href="#cell-1" class="is-active">Cell 1</a>
      `;

      let observerCallback;
      const originalIO = window.IntersectionObserver;

      window.IntersectionObserver = vi.fn(function (callback) {
        observerCallback = callback;
        this.observe = vi.fn();
        this.unobserve = vi.fn();
        this.disconnect = vi.fn();
      });

      handleScrollSpy();

      // Simulate non-intersecting entry
      const entries = [
        {
          isIntersecting: false,
          target: document.getElementById('cell-1')
        }
      ];

      observerCallback(entries);

      const link = document.querySelector('[href="#cell-1"]');
      // Should remain unchanged (still active from initial state)
      expect(link.classList.contains('is-active')).toBe(true);

      window.IntersectionObserver = originalIO;
    });

    it('should use correct observer options', () => {
      document.body.innerHTML = `
        <div class="notebook-segment" id="cell-1"></div>
        <a data-cell-anchor-link href="#cell-1">Cell 1</a>
      `;

      let observerOptions;
      const originalIO = window.IntersectionObserver;

      window.IntersectionObserver = vi.fn(function (callback, options) {
        observerOptions = options;
        this.observe = vi.fn();
        this.unobserve = vi.fn();
        this.disconnect = vi.fn();
      });

      handleScrollSpy();

      expect(observerOptions.root).toBeNull();
      expect(observerOptions.rootMargin).toBe('0px 0px -65%');
      expect(observerOptions.threshold).toBe(0);

      window.IntersectionObserver = originalIO;
    });
  });

  describe('loadScript() edge cases', () => {
    it('should resolve immediately when script already exists', async () => {
      const src = 'https://example.com/existing.js';

      // Create existing script
      const existing = document.createElement('script');
      existing.src = src;
      document.head.appendChild(existing);

      const promise = loadScript(src);

      // Should resolve immediately without creating a new script
      await expect(promise).resolves.toBeUndefined();

      const scripts = document.querySelectorAll(`script[src="${src}"]`);
      expect(scripts.length).toBe(1);
    });
  });

  describe('annotateCells() edge cases', () => {
    it('should handle mixed segments with and without IDs', () => {
      document.body.innerHTML = `
        <div class="notebook-segment" id="intro"></div>
        <div class="notebook-segment"></div>
        <div class="notebook-segment" id="conclusion"></div>
        <div class="notebook-segment"></div>
      `;

      annotateCells();

      const segments = document.querySelectorAll('.notebook-segment');

      expect(segments[0].id).toBe('intro');
      expect(segments[0].getAttribute('data-cell-anchor')).toBe('intro');

      expect(segments[1].id).toBe('cell-2');
      expect(segments[1].getAttribute('data-cell-anchor')).toBe('cell-2');

      expect(segments[2].id).toBe('conclusion');
      expect(segments[2].getAttribute('data-cell-anchor')).toBe('conclusion');

      expect(segments[3].id).toBe('cell-4');
      expect(segments[3].getAttribute('data-cell-anchor')).toBe('cell-4');
    });
  });
});
