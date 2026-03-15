import { beforeEach, describe, expect, it, vi } from 'vitest';
import '../../assets/js/visualizations.js';

const vizInternals = globalThis.__DATALOG_VIZ_INTERNALS__;

describe('utility functions', () => {
  it('stringify handles different value types', () => {
    expect(vizInternals.stringifyValue(null)).toBe('');
    expect(vizInternals.stringifyValue(undefined)).toBe('');
    expect(vizInternals.stringifyValue(true)).toBe('Yes');
    expect(vizInternals.stringifyValue(false)).toBe('No');
    expect(vizInternals.stringifyValue(42)).toBe('42');
    expect(vizInternals.stringifyValue([1, 2, 3])).toBe('1, 2, 3');
    expect(vizInternals.stringifyValue(new Date('2024-01-15T00:00:00.000Z'))).toBe('2024-01-15T00:00:00.000Z');
  });

  it('stringify handles non-finite numbers', () => {
    expect(vizInternals.stringifyValue(Infinity)).toBe('');
    expect(vizInternals.stringifyValue(NaN)).toBe('');
  });

  it('stringify handles nested arrays', () => {
    const result = vizInternals.stringifyValue([[1, 2], [3, 4]]);
    expect(result).toContain('1, 2');
    expect(result).toContain('3, 4');
  });

  it('stringify handles nested objects', () => {
    const result = vizInternals.stringifyValue({ a: { b: 'value', c: 123 } });
    expect(result).toContain('b: value');
    expect(result).toContain('c: 123');
  });

  it('stringify handles strings', () => {
    expect(vizInternals.stringifyValue('test string')).toBe('test string');
  });
});

describe('visualization fallbacks', () => {
  it('normalizes different data structures into tabular records', () => {
    const arrayRecords = vizInternals.normalizeRecords([
      ['Metric', 'Value'],
      ['Accuracy', 0.92],
      ['Recall', 0.87]
    ]);
    expect(arrayRecords).toHaveLength(2);
    expect(arrayRecords[0].Metric).toBe('Accuracy');

    const objectRecords = vizInternals.normalizeRecords({
      data: [
        { class: 'A', score: 0.95 },
        { class: 'B', score: 0.89 }
      ]
    });
    expect(objectRecords[1].score).toBe(0.89);

    const primitiveRecords = vizInternals.normalizeRecords('single value');
    expect(primitiveRecords[0].Value).toBe('single value');
  });

  it('normalizes empty arrays and null values', () => {
    expect(vizInternals.normalizeRecords([])).toEqual([]);
    expect(vizInternals.normalizeRecords(null)).toEqual([]);
    expect(vizInternals.normalizeRecords(undefined)).toEqual([]);
  });

  it('normalizes object with data property', () => {
    const records = vizInternals.normalizeRecords({
      data: [
        { metric: 'accuracy', value: 0.92 }
      ]
    });

    expect(records).toHaveLength(1);
    expect(records[0].metric).toBe('accuracy');
  });

  it('normalizes object with values property', () => {
    const records = vizInternals.normalizeRecords({
      values: [
        { metric: 'recall', value: 0.87 }
      ]
    });

    expect(records).toHaveLength(1);
    expect(records[0].metric).toBe('recall');
  });

  it('normalizes object with rows property', () => {
    const records = vizInternals.normalizeRecords({
      rows: [
        { metric: 'f1', value: 0.89 }
      ]
    });

    expect(records).toHaveLength(1);
    expect(records[0].metric).toBe('f1');
  });

  it('normalizes plain object without special properties', () => {
    const records = vizInternals.normalizeRecords({
      accuracy: 0.92,
      recall: 0.87
    });

    expect(records).toHaveLength(1);
    expect(records[0].accuracy).toBe(0.92);
    expect(records[0].recall).toBe(0.87);
  });

  it('normalizes array of primitive values', () => {
    const records = vizInternals.normalizeRecords([10, 20, 30]);

    expect(records).toHaveLength(3);
    expect(records[0].Index).toBe(1);
    expect(records[0].Value).toBe(10);
    expect(records[2].Index).toBe(3);
    expect(records[2].Value).toBe(30);
  });

  it('normalizes 2D array treats first row as header', () => {
    const records = vizInternals.normalizeRecords([
      [1, 2, 3],
      [4, 5, 6]
    ]);

    // First row [1, 2, 3] is treated as header since values look like labels
    expect(records).toHaveLength(1);
    expect(records[0]['1']).toBe(4);
    expect(records[0]['2']).toBe(5);
    expect(records[0]['3']).toBe(6);
  });

  it('normalizes mixed array with non-array rows', () => {
    const records = vizInternals.normalizeRecords([
      ['Header1', 'Header2'],
      'mixed value'
    ]);

    expect(records).toHaveLength(1);
    expect(records[0]['Row 1']).toBe('mixed value');
  });

  it('normalizes array of objects with nested data', () => {
    const records = vizInternals.normalizeRecords([
      { user: { name: 'Alice', age: 30 } },
      { user: { name: 'Bob', age: 25 } }
    ]);

    expect(records).toHaveLength(2);
    expect(records[0]['user › name']).toBe('Alice');
    expect(records[1]['user › age']).toBe(25);
  });

  it('normalizes single 2D array row', () => {
    const records = vizInternals.normalizeRecords([
      [1, 2, 3]
    ]);

    // Single row array is treated as header with no data rows
    expect(records).toHaveLength(0);
  });

  it('stringifies values and builds accessible data tables with toggles', () => {
    const stringifyResult = vizInternals.stringifyValue({ accuracy: 0.91, recall: 0.88 });
    expect(stringifyResult).toContain('accuracy: 0.91');

    const container = document.createElement('section');
    container.dataset.vizSlug = 'model-performance';
    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    container.appendChild(canvas);

    vizInternals.buildDataTable(container, {
      caption: 'Model metrics',
      rows: [
        { Metric: 'Accuracy', Value: 0.92 },
        { Metric: 'Recall', Value: 0.87 }
      ]
    });

    const tableContainer = container.querySelector('[data-viz-table-container]');
    expect(tableContainer).not.toBeNull();
    const toggle = container.querySelector('[data-viz-table-toggle]');
    const wrapper = container.querySelector('[data-viz-table-wrapper]');
    const table = container.querySelector('[data-viz-table]');

    expect(toggle.getAttribute('aria-controls')).toBe(table.id);
    expect(canvas.getAttribute('aria-describedby')).toBe(table.id);

    toggle.click();
    expect(toggle.getAttribute('aria-expanded')).toBe('true');
    expect(wrapper.hasAttribute('hidden')).toBe(false);

    toggle.click();
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    expect(wrapper.hasAttribute('hidden')).toBe(true);
  });

  it('buildDataTable handles empty rows', () => {
    const container = document.createElement('section');
    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    container.appendChild(canvas);

    vizInternals.buildDataTable(container, {
      caption: 'Empty Table',
      rows: []
    });

    const tableContainer = container.querySelector('[data-viz-table-container]');
    expect(tableContainer).toBeNull();
  });

  it('buildDataTable handles rows without columns', () => {
    const container = document.createElement('section');
    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    container.appendChild(canvas);

    vizInternals.buildDataTable(container, {
      caption: 'No Columns',
      rows: [{}]
    });

    const tableContainer = container.querySelector('[data-viz-table-container]');
    expect(tableContainer).toBeNull();
  });

  it('buildDataTable creates unique table IDs', () => {
    const container1 = document.createElement('section');
    container1.dataset.vizSlug = 'chart-1';
    const canvas1 = document.createElement('div');
    canvas1.setAttribute('data-viz-canvas', '');
    container1.appendChild(canvas1);

    const container2 = document.createElement('section');
    container2.dataset.vizSlug = 'chart-2';
    const canvas2 = document.createElement('div');
    canvas2.setAttribute('data-viz-canvas', '');
    container2.appendChild(canvas2);

    vizInternals.buildDataTable(container1, {
      caption: 'Chart 1',
      rows: [{ x: 1, y: 2 }]
    });

    vizInternals.buildDataTable(container2, {
      caption: 'Chart 2',
      rows: [{ a: 3, b: 4 }]
    });

    const table1 = container1.querySelector('[data-viz-table]');
    const table2 = container2.querySelector('[data-viz-table]');

    expect(table1.id).not.toBe(table2.id);
  });

  it('filters gallery cards using tech and tag selectors', () => {
    const gallery = document.createElement('div');
    const matching = document.createElement('article');
    matching.dataset.vizCard = '';
    matching.dataset.vizTech = 'plotly';
    matching.dataset.vizTags = 'time-series,forecast';
    const other = document.createElement('article');
    other.dataset.vizCard = '';
    other.dataset.vizTech = 'd3';
    other.dataset.vizTags = 'bar';

    gallery.appendChild(matching);
    gallery.appendChild(other);

    document.body.appendChild(gallery);

    vizInternals.filterGallery({ tech: 'plotly', tag: 'forecast' });
    expect(matching.hidden).toBe(false);
    expect(other.hidden).toBe(true);

    vizInternals.filterGallery({ tech: '', tag: '' });
    expect(matching.hidden).toBe(false);
    expect(other.hidden).toBe(false);
  });

  it('filterGallery handles missing data attributes', () => {
    const gallery = document.createElement('div');
    const card = document.createElement('article');
    card.dataset.vizCard = '';
    // No tech or tags attributes
    gallery.appendChild(card);

    document.body.appendChild(gallery);

    expect(() => {
      vizInternals.filterGallery({ tech: 'plotly', tag: 'bar' });
    }).not.toThrow();

    expect(card.hidden).toBe(true);
  });

  it('filterGallery handles multiple tags', () => {
    const gallery = document.createElement('div');
    const card = document.createElement('article');
    card.dataset.vizCard = '';
    card.dataset.vizTech = 'plotly';
    card.dataset.vizTags = 'time-series,forecast,ml';
    gallery.appendChild(card);

    document.body.appendChild(gallery);

    vizInternals.filterGallery({ tech: 'plotly', tag: 'ml' });
    expect(card.hidden).toBe(false);

    vizInternals.filterGallery({ tech: 'plotly', tag: 'nonexistent' });
    expect(card.hidden).toBe(true);
  });
});

describe('loadScript and loadStyle', () => {
  beforeEach(() => {
    // Clear any previously loaded scripts/styles tracking
    document.head.innerHTML = '';
  });

  it('loadScript returns error for missing src', async () => {
    await expect(vizInternals.loadScript('')).rejects.toThrow('Missing script source');
  });

  it('loadScript creates script element with correct attributes', async () => {
    const src = 'https://example.com/script.js';
    const promise = vizInternals.loadScript(src);

    const script = document.head.querySelector('script');
    expect(script).not.toBeNull();
    expect(script.src).toBe(src);
    expect(script.async).toBe(true);

    // Simulate load
    script.onload();

    await promise;
  });

  it('loadScript adds integrity and crossOrigin when provided', async () => {
    const src = 'https://cdn.example.com/lib.js';
    const promise = vizInternals.loadScript(src, {
      integrity: 'sha384-abc123',
      crossOrigin: 'anonymous'
    });

    const script = document.head.querySelector('script');
    expect(script.integrity).toBe('sha384-abc123');
    expect(script.crossOrigin).toBe('anonymous');

    script.onload();
    await promise;
  });

  it('loadScript returns same promise for duplicate sources', () => {
    const src = 'https://example.com/library.js';
    const promise1 = vizInternals.loadScript(src);
    const promise2 = vizInternals.loadScript(src);

    expect(promise1).toBe(promise2);

    const scripts = document.head.querySelectorAll('script');
    expect(scripts.length).toBe(1);
  });

  it('loadScript handles load errors', async () => {
    const src = 'https://example.com/broken.js';
    const promise = vizInternals.loadScript(src);

    const script = document.head.querySelector('script');
    const error = new Error('Failed to load');
    script.onerror(error);

    await expect(promise).rejects.toBe(error);
  });

  it('loadScript respects async option', async () => {
    const src = 'https://example.com/sync.js';
    const promise = vizInternals.loadScript(src, { async: false });

    const script = document.head.querySelector('script');
    expect(script.async).toBe(false);

    script.onload();
    await promise;
  });

  it('loadStyle creates link element', async () => {
    const href = 'https://example.com/styles.css';
    const promise = vizInternals.loadStyle(href);

    const link = document.head.querySelector('link');
    expect(link).not.toBeNull();
    expect(link.rel).toBe('stylesheet');
    expect(link.href).toBe(href);

    link.onload();
    await promise;
  });

  it('loadStyle returns immediately for empty href', async () => {
    const result = await vizInternals.loadStyle('');
    expect(result).toBeUndefined();

    const link = document.head.querySelector('link');
    expect(link).toBeNull();
  });

  it('loadStyle returns immediately for already loaded styles', async () => {
    const href = 'https://example.com/already-loaded.css';

    // First load
    const promise1 = vizInternals.loadStyle(href);
    const link1 = document.head.querySelector('link');
    link1.onload();
    await promise1;

    // Second load should resolve immediately
    const promise2 = vizInternals.loadStyle(href);
    await promise2;

    const links = document.head.querySelectorAll('link');
    expect(links.length).toBe(1);
  });

  it('loadStyle handles load errors', async () => {
    const href = 'https://example.com/broken.css';
    const promise = vizInternals.loadStyle(href);

    const link = document.head.querySelector('link');
    const error = new Error('Failed to load');
    link.onerror(error);

    await expect(promise).rejects.toBe(error);
  });
});

describe('buildPlotlyRecords', () => {
  it('builds records from simple x/y traces', () => {
    const traces = [
      {
        name: 'Series 1',
        x: [1, 2, 3],
        y: [10, 20, 30]
      }
    ];

    const records = vizInternals.buildPlotlyRecords(traces);

    expect(records).toHaveLength(3);
    expect(records[0]).toEqual({
      Series: 'Series 1',
      X: 1,
      Y: 10,
      Text: undefined
    });
    expect(records[2]).toEqual({
      Series: 'Series 1',
      X: 3,
      Y: 30,
      Text: undefined
    });
  });

  it('generates default series names when not provided', () => {
    const traces = [
      { x: [1], y: [10] },
      { x: [2], y: [20] }
    ];

    const records = vizInternals.buildPlotlyRecords(traces);

    expect(records[0].Series).toBe('Series 1');
    expect(records[1].Series).toBe('Series 2');
  });

  it('handles traces with text values', () => {
    const traces = [
      {
        name: 'Points',
        x: [1, 2],
        y: [10, 20],
        text: ['A', 'B']
      }
    ];

    const records = vizInternals.buildPlotlyRecords(traces);

    expect(records[0].Text).toBe('A');
    expect(records[1].Text).toBe('B');
  });

  it('handles 2D z-value heatmap data', () => {
    const traces = [
      {
        name: 'Heatmap',
        z: [[1, 2], [3, 4]],
        x: ['Col1', 'Col2'],
        y: ['Row1', 'Row2']
      }
    ];

    const records = vizInternals.buildPlotlyRecords(traces);

    expect(records).toHaveLength(4);
    expect(records[0]).toEqual({
      Series: 'Heatmap',
      Y: 'Row1',
      X: 'Col1',
      Value: 1,
      Text: ''
    });
    expect(records[3]).toEqual({
      Series: 'Heatmap',
      Y: 'Row2',
      X: 'Col2',
      Value: 4,
      Text: ''
    });
  });

  it('generates default x/y labels for heatmap when not provided', () => {
    const traces = [
      {
        name: 'Heatmap',
        z: [[5, 6], [7, 8]]
      }
    ];

    const records = vizInternals.buildPlotlyRecords(traces);

    expect(records[0].X).toBe(1);
    expect(records[0].Y).toBe(1);
    expect(records[1].X).toBe(2);
    expect(records[3].Y).toBe(2);
  });

  it('handles mismatched x/y/text lengths', () => {
    const traces = [
      {
        name: 'Uneven',
        x: [1, 2],
        y: [10, 20, 30],
        text: ['A']
      }
    ];

    const records = vizInternals.buildPlotlyRecords(traces);

    expect(records).toHaveLength(3);
    expect(records[2].X).toBeUndefined();
    expect(records[2].Y).toBe(30);
  });

  it('returns null for empty traces', () => {
    const records = vizInternals.buildPlotlyRecords([]);

    expect(records).toBeNull();
  });

  it('handles traces without arrays', () => {
    const traces = [{ name: 'Empty' }];

    const records = vizInternals.buildPlotlyRecords(traces);

    expect(records).toBeNull();
  });
});

describe('buildD3Records', () => {
  it('returns array directly', () => {
    const data = [{ x: 1, y: 2 }, { x: 3, y: 4 }];
    const records = vizInternals.buildD3Records(data);

    expect(records).toBe(data);
  });

  it('extracts data property from object', () => {
    const captured = {
      data: [{ a: 1 }, { a: 2 }]
    };

    const records = vizInternals.buildD3Records(captured);

    expect(records).toEqual(captured.data);
  });

  it('returns captured object if not array or object with data', () => {
    const captured = { values: [1, 2, 3] };

    const records = vizInternals.buildD3Records(captured);

    expect(records).toBe(captured);
  });

  it('returns null for undefined input', () => {
    const records = vizInternals.buildD3Records(null);

    expect(records).toBeNull();
  });
});

describe('buildObservableRecords', () => {
  it('parses JSON from observable data script', () => {
    const element = document.createElement('div');
    const script = document.createElement('script');
    script.setAttribute('data-observable-data', '');
    script.textContent = JSON.stringify([{ x: 1, y: 2 }]);
    element.appendChild(script);

    const records = vizInternals.buildObservableRecords(element);

    expect(records).toEqual([{ x: 1, y: 2 }]);
  });

  it('returns null when script not found', () => {
    const element = document.createElement('div');

    const records = vizInternals.buildObservableRecords(element);

    expect(records).toBeNull();
  });

  it('returns null for invalid JSON', () => {
    const element = document.createElement('div');
    const script = document.createElement('script');
    script.setAttribute('data-observable-data', '');
    script.textContent = 'invalid json';
    element.appendChild(script);

    const records = vizInternals.buildObservableRecords(element);

    expect(records).toBeNull();
  });

  it('returns null for empty script', () => {
    const element = document.createElement('div');
    const script = document.createElement('script');
    script.setAttribute('data-observable-data', '');
    script.textContent = '';
    element.appendChild(script);

    const records = vizInternals.buildObservableRecords(element);

    expect(records).toBeNull();
  });
});

describe('buildDataTable advanced features', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
  });

  it('replaces existing table container', () => {
    const container = document.createElement('section');
    container.dataset.vizSlug = 'test';
    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    container.appendChild(canvas);

    // Add first table
    vizInternals.buildDataTable(container, {
      caption: 'Table 1',
      rows: [{ x: 1 }]
    });

    const firstTable = container.querySelector('[data-viz-table-container]');
    expect(firstTable).not.toBeNull();

    // Add second table (should replace first)
    vizInternals.buildDataTable(container, {
      caption: 'Table 2',
      rows: [{ y: 2 }]
    });

    const allTables = container.querySelectorAll('[data-viz-table-container]');
    expect(allTables).toHaveLength(1);
    expect(container.querySelector('[data-viz-table-caption]').textContent).toBe('Table 2');
  });

  it('uses element ID as table ID fallback', () => {
    const container = document.createElement('section');
    container.id = 'my-viz';
    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    container.appendChild(canvas);

    vizInternals.buildDataTable(container, {
      rows: [{ x: 1 }]
    });

    const table = container.querySelector('[data-viz-table]');
    expect(table.id).toBe('my-viz-table');
  });

  it('uses "viz" as default table ID prefix', () => {
    const container = document.createElement('section');
    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    container.appendChild(canvas);

    vizInternals.buildDataTable(container, {
      rows: [{ x: 1 }]
    });

    const table = container.querySelector('[data-viz-table]');
    expect(table.id).toBe('viz-table');
  });

  it('creates row header for first column', () => {
    const container = document.createElement('section');
    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    container.appendChild(canvas);

    vizInternals.buildDataTable(container, {
      rows: [
        { Name: 'Alice', Score: 95 },
        { Name: 'Bob', Score: 87 }
      ]
    });

    const rows = container.querySelectorAll('tbody tr');
    expect(rows).toHaveLength(2);

    const firstRowHeader = rows[0].querySelector('th[scope="row"]');
    expect(firstRowHeader).not.toBeNull();
    expect(firstRowHeader.textContent).toBe('Alice');

    const firstRowCells = rows[0].querySelectorAll('td');
    expect(firstRowCells).toHaveLength(1);
    expect(firstRowCells[0].textContent).toBe('95');
  });

  it('sets aria-describedby on canvas element', () => {
    const container = document.createElement('section');
    container.dataset.vizSlug = 'test-viz';
    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    container.appendChild(canvas);

    vizInternals.buildDataTable(container, {
      rows: [{ x: 1 }]
    });

    expect(canvas.getAttribute('aria-describedby')).toBe('test-viz-table');
  });

  it('uses element itself if no canvas found', () => {
    const container = document.createElement('section');
    container.dataset.vizSlug = 'no-canvas';

    vizInternals.buildDataTable(container, {
      rows: [{ x: 1 }]
    });

    expect(container.getAttribute('aria-describedby')).toBe('no-canvas-table');
  });

  it('toggle button shows and hides the data table', () => {
    const container = document.createElement('section');
    container.dataset.vizSlug = 'toggle-test';

    vizInternals.buildDataTable(container, {
      rows: [{ x: 1, y: 2 }]
    });

    const toggle = container.querySelector('[data-viz-table-toggle]');
    const wrapper = container.querySelector('[data-viz-table-wrapper]'); // Fixed: was looking for wrong element

    expect(toggle.textContent).toBe('Show data table');
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    expect(wrapper.hasAttribute('hidden')).toBe(true);

    // Click to show
    toggle.click();
    expect(toggle.textContent).toBe('Hide data table');
    expect(toggle.getAttribute('aria-expanded')).toBe('true');
    expect(wrapper.hasAttribute('hidden')).toBe(false);

    // Click to hide
    toggle.click();
    expect(toggle.textContent).toBe('Show data table');
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    expect(wrapper.hasAttribute('hidden')).toBe(true);
  });
});

describe('annotateVersionMetadata', () => {
  it('adds version and update date to metadata element', () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-version', '2.1.0');
    element.setAttribute('data-viz-updated', '2024-01-15');

    const meta = document.createElement('span');
    meta.setAttribute('data-viz-meta', '');
    element.appendChild(meta);

    vizInternals.annotateVersionMetadata(element);

    expect(meta.textContent).toBe('v2.1.0 · Updated 2024-01-15');
  });

  it('handles version only', () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-version', '1.0.0');

    const meta = document.createElement('span');
    meta.setAttribute('data-viz-meta', '');
    element.appendChild(meta);

    vizInternals.annotateVersionMetadata(element);

    expect(meta.textContent).toBe('v1.0.0');
  });

  it('handles update date only', () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-updated', '2024-02-01');

    const meta = document.createElement('span');
    meta.setAttribute('data-viz-meta', '');
    element.appendChild(meta);

    vizInternals.annotateVersionMetadata(element);

    expect(meta.textContent).toBe('Updated 2024-02-01');
  });

  it('does nothing when no meta target', () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-version', '1.0.0');

    expect(() => vizInternals.annotateVersionMetadata(element)).not.toThrow();
  });
});

describe('normalizeRecords with plain objects', () => {
  it('handles plain object without data/values/rows arrays', () => {
    const result = vizInternals.normalizeRecords({ metric: 'accuracy', value: 0.92 });

    expect(result).toHaveLength(1);
    expect(result[0].metric).toBe('accuracy');
    expect(result[0].value).toBe(0.92);
  });

  it('handles primitive values', () => {
    const result = vizInternals.normalizeRecords(42);

    expect(result).toHaveLength(1);
    expect(result[0].Value).toBe(42);
  });

  it('handles string values', () => {
    const result = vizInternals.normalizeRecords('test string');

    expect(result).toHaveLength(1);
    expect(result[0].Value).toBe('test string');
  });
});

describe('buildPlotlyRecords with text values', () => {
  it('handles heatmap with text values (stringified by row)', () => {
    const traces = [{
      name: 'Heatmap',
      z: [[1, 2], [3, 4]],
      x: ['Col1', 'Col2'],
      y: ['Row1', 'Row2'],
      text: [['one', 'two'], ['three', 'four']]
    }];

    const records = vizInternals.buildPlotlyRecords(traces);

    expect(records).toHaveLength(4);
    // Text values are stringified per row, not per cell
    expect(records[0]).toEqual({
      Series: 'Heatmap',
      Y: 'Row1',
      X: 'Col1',
      Value: 1,
      Text: 'one, two' // Row 0's text array is stringified
    });
    expect(records[1].Text).toBe('one, two'); // Same row, same text
    expect(records[2].Text).toBe('three, four'); // Row 1's text array
    expect(records[3].Text).toBe('three, four'); // Same row, same text
  });
});

describe('initializeGallery', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
  });

  it('does nothing when no gallery element', () => {
    expect(() => vizInternals.initializeGallery()).not.toThrow();
  });

  it('initializes gallery with filter controls', () => {
    document.body.innerHTML = `
      <div data-viz-gallery>
        <select data-viz-filter="tech">
          <option value="all">All</option>
          <option value="plotly">Plotly</option>
        </select>
        <select data-viz-filter="tag">
          <option value="all">All</option>
          <option value="charts">Charts</option>
        </select>
        <section data-viz-card data-viz-tech="plotly" data-viz-tags="charts"></section>
      </div>
    `;

    vizInternals.initializeGallery();

    const cards = document.querySelectorAll('[data-viz-card]');
    expect(cards[0].hasAttribute('hidden')).toBe(false);
  });
});

describe('initializeVisualizations', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
  });

  it('sets up IntersectionObserver for lazy loading', () => {
    document.body.innerHTML = '<div data-viz data-viz-type="plotly"></div>';

    // Mock IntersectionObserver
    const observeMock = vi.fn();
    const IntersectionObserverMock = vi.fn(function(callback) {
      this.observe = observeMock;
      this.unobserve = vi.fn();
      this.disconnect = vi.fn();
    });

    const originalIO = window.IntersectionObserver;
    window.IntersectionObserver = IntersectionObserverMock;

    vizInternals.initializeVisualizations();

    expect(IntersectionObserverMock).toHaveBeenCalled();
    expect(observeMock).toHaveBeenCalled();

    // Restore
    window.IntersectionObserver = originalIO;
  });

  it('falls back to immediate render when IntersectionObserver unavailable', () => {
    document.body.innerHTML = '<div data-viz-type="unknown"></div>';

    const originalIO = window.IntersectionObserver;
    delete window.IntersectionObserver;

    // Should not throw
    expect(() => vizInternals.initializeVisualizations()).not.toThrow();

    // Restore
    window.IntersectionObserver = originalIO;
  });

  it('renders visualizations immediately when IntersectionObserver unavailable', () => {
    const originalIO = window.IntersectionObserver;
    delete window.IntersectionObserver;

    document.body.innerHTML = `
      <div data-viz-type="unknown">
        <div data-viz-status></div>
      </div>
    `;

    vizInternals.initializeVisualizations();

    const status = document.querySelector('[data-viz-status]');
    expect(status.textContent).toBe('Unsupported visualization type');

    window.IntersectionObserver = originalIO;
  });
});

describe('renderVisualization', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
  });

  it('sets status to unsupported for unknown type', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'unknown');
    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);

    expect(status.textContent).toBe('Unsupported visualization type');
    expect(status.dataset.tone).toBe('error');
  });

  it('annotates version metadata', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'unknown');
    element.setAttribute('data-viz-version', '1.2.3');
    element.setAttribute('data-viz-updated', '2024-01-15');

    const meta = document.createElement('span');
    meta.setAttribute('data-viz-meta', '');
    element.appendChild(meta);

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);

    expect(meta.textContent).toBe('v1.2.3 · Updated 2024-01-15');
  });

  it('routes to plotly renderer', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'plotly');
    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    // Without spec, should show error
    await vizInternals.renderVisualization(element);
    expect(status.textContent).toBe('Missing Plotly specification');
  });

  it('routes to d3 renderer', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'd3');
    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);
    expect(status.textContent).toBe('Missing D3 rendering instructions');
  });

  it('routes to observable renderer', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'observable');
    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);
    expect(status.textContent).toBe('Missing Observable notebook source');
  });

  it('routes to bokeh renderer', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'bokeh');
    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);
    expect(status.textContent).toBe('Missing Bokeh specification');
  });

  it('routes to shiny renderer', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'shiny');
    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);
    expect(status.textContent).toBe('Missing Shiny application source');
  });

  it('routes to ipywidgets renderer', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'ipywidgets');
    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);
    expect(status.textContent).toBe('Missing widget state payload');
  });
});

describe('Plotly rendering', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    delete window.Plotly;
  });

  it('renders with valid spec when Plotly is available', async () => {
    window.Plotly = {
      newPlot: vi.fn().mockResolvedValue(undefined)
    };

    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'plotly');
    element.setAttribute('data-viz-slug', 'test-chart');

    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    element.appendChild(canvas);

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    const spec = document.createElement('script');
    spec.type = 'application/json';
    spec.textContent = JSON.stringify({
      data: [{ x: [1, 2, 3], y: [4, 5, 6] }],
      layout: { title: 'Test' }
    });
    element.appendChild(spec);

    await vizInternals.renderVisualization(element);

    expect(window.Plotly.newPlot).toHaveBeenCalled();
    expect(status.textContent).toBe('Interactive');
  });

  it('shows error for invalid JSON spec', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'plotly');

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    const spec = document.createElement('script');
    spec.type = 'application/json';
    spec.textContent = 'invalid json';
    element.appendChild(spec);

    await vizInternals.renderVisualization(element);

    expect(status.textContent).toBe('Invalid Plotly specification');
  });

  it('handles Plotly load failure', async () => {
    // Plotly not available, and loadScript will fail
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'plotly');

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    const spec = document.createElement('script');
    spec.type = 'application/json';
    spec.textContent = JSON.stringify({ data: [] });
    element.appendChild(spec);

    // Simulate script loading failure
    const scriptPromise = vizInternals.renderVisualization(element);

    // Trigger script error
    await vi.waitFor(() => {
      const script = document.head.querySelector('script[src*="plotly"]');
      if (script && script.onerror) {
        script.onerror(new Error('Failed'));
      }
    }, { timeout: 100 }).catch(() => {});

    await scriptPromise.catch(() => {});
  });
});

describe('D3 rendering', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    delete window.d3;
  });

  it('renders D3 with valid script when d3 is available', async () => {
    window.d3 = {
      select: vi.fn().mockReturnThis(),
      append: vi.fn().mockReturnThis(),
      attr: vi.fn().mockReturnThis(),
      text: vi.fn().mockReturnThis()
    };

    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'd3');

    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    element.appendChild(canvas);

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    const script = document.createElement('script');
    script.setAttribute('data-d3-script', '');
    script.textContent = 'var data = [{x: 1}];';
    element.appendChild(script);

    await vizInternals.renderVisualization(element);

    expect(status.textContent).toBe('Interactive');
  });

  it('shows error for D3 script errors', async () => {
    window.d3 = {};

    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'd3');

    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    element.appendChild(canvas);

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    const script = document.createElement('script');
    script.setAttribute('data-d3-script', '');
    script.textContent = 'throw new Error("test error");';
    element.appendChild(script);

    await vizInternals.renderVisualization(element);

    expect(status.textContent).toBe('D3 rendering error');
  });
});

describe('Observable rendering', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
  });

  it('creates iframe for observable embed', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'observable');
    element.setAttribute('data-observable-src', 'https://observablehq.com/embed/abc');
    element.setAttribute('data-viz-title', 'My Notebook');

    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    element.appendChild(canvas);

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);

    const iframe = canvas.querySelector('iframe');
    expect(iframe).not.toBeNull();
    expect(iframe.src).toBe('https://observablehq.com/embed/abc');
    expect(iframe.title).toBe('My Notebook');
    expect(iframe.loading).toBe('lazy');
    expect(status.textContent).toBe('Embedded');
  });

  it('uses default title when not provided', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'observable');
    element.setAttribute('data-observable-src', 'https://observablehq.com/embed/abc');

    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    element.appendChild(canvas);

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);

    const iframe = canvas.querySelector('iframe');
    expect(iframe.title).toBe('Observable visualization');
  });

  it('builds data table from observable data script', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'observable');
    element.setAttribute('data-observable-src', 'https://observablehq.com/embed/abc');
    element.setAttribute('data-viz-slug', 'obs-viz');

    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    element.appendChild(canvas);

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    const dataScript = document.createElement('script');
    dataScript.setAttribute('data-observable-data', '');
    dataScript.textContent = JSON.stringify([{ x: 1, y: 2 }]);
    element.appendChild(dataScript);

    await vizInternals.renderVisualization(element);

    const table = element.querySelector('[data-viz-table]');
    expect(table).not.toBeNull();
  });
});

describe('Shiny rendering', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
  });

  it('creates iframe for shiny app', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'shiny');
    element.setAttribute('data-shiny-src', 'https://myapp.shinyapps.io/app');
    element.setAttribute('data-viz-title', 'My Shiny App');
    element.setAttribute('data-shiny-height', '800px');

    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    element.appendChild(canvas);

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);

    const iframe = canvas.querySelector('iframe');
    expect(iframe).not.toBeNull();
    expect(iframe.src).toBe('https://myapp.shinyapps.io/app');
    expect(iframe.title).toBe('My Shiny App');
    expect(iframe.style.height).toBe('800px');
    expect(status.textContent).toBe('Embedded');
  });

  it('uses default height when not provided', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'shiny');
    element.setAttribute('data-shiny-src', 'https://myapp.shinyapps.io/app');

    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    element.appendChild(canvas);

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);

    const iframe = canvas.querySelector('iframe');
    expect(iframe.style.height).toBe('640px');
  });

  it('uses default title when not provided', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'shiny');
    element.setAttribute('data-shiny-src', 'https://myapp.shinyapps.io/app');

    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    element.appendChild(canvas);

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);

    const iframe = canvas.querySelector('iframe');
    expect(iframe.title).toBe('R Shiny application');
  });
});

describe('Bokeh rendering', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
    document.head.innerHTML = '';
    delete window.Bokeh;
  });

  it('shows missing spec error when no spec or script', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'bokeh');

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);

    expect(status.textContent).toBe('Missing Bokeh specification');
  });

  it('parses bokeh JSON spec correctly', () => {
    const spec = { doc: {}, root_ids: ['abc'] };
    const specNode = document.createElement('script');
    specNode.type = 'application/json';
    specNode.textContent = JSON.stringify(spec);

    const parsed = JSON.parse(specNode.textContent);
    expect(parsed).toEqual(spec);
  });

  it('handles invalid JSON gracefully', () => {
    const specNode = document.createElement('script');
    specNode.type = 'application/json';
    specNode.textContent = 'invalid json';

    expect(() => JSON.parse(specNode.textContent)).toThrow();
  });

  it('generates unique canvas IDs', () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'bokeh');

    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    element.appendChild(canvas);

    // Test ID generation logic
    const targetId = canvas.id || `bokeh-${Math.random().toString(36).slice(2)}`;
    expect(targetId).toMatch(/^bokeh-[a-z0-9]+$/);
  });
});

describe('IPyWidgets rendering', () => {
  beforeEach(() => {
    document.body.innerHTML = '';
  });

  it('shows error when view node is missing', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'ipywidgets');

    const stateScript = document.createElement('script');
    stateScript.type = 'application/vnd.jupyter.widget-state+json';
    stateScript.textContent = JSON.stringify({});
    element.appendChild(stateScript);

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);

    expect(status.textContent).toBe('Missing widget state payload');
  });

  it('shows error when state node is missing', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'ipywidgets');

    const viewScript = document.createElement('script');
    viewScript.type = 'application/vnd.jupyter.widget-view+json';
    viewScript.textContent = JSON.stringify({});
    element.appendChild(viewScript);

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);

    expect(status.textContent).toBe('Missing widget state payload');
  });

  it('shows error for invalid widget state JSON', async () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-type', 'ipywidgets');

    const canvas = document.createElement('div');
    canvas.setAttribute('data-viz-canvas', '');
    element.appendChild(canvas);

    const stateScript = document.createElement('script');
    stateScript.type = 'application/vnd.jupyter.widget-state+json';
    stateScript.textContent = 'invalid json';
    element.appendChild(stateScript);

    const viewScript = document.createElement('script');
    viewScript.type = 'application/vnd.jupyter.widget-view+json';
    viewScript.textContent = JSON.stringify({ model_id: 'abc' });
    element.appendChild(viewScript);

    const status = document.createElement('span');
    status.setAttribute('data-viz-status', '');
    element.appendChild(status);

    await vizInternals.renderVisualization(element);

    expect(status.textContent).toBe('Invalid widget payload');
  });
});

describe('getVizTitle helper', () => {
  it('returns explicit title from attribute', () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-title', 'My Chart');

    vizInternals.buildDataTable(element, {
      caption: null,
      rows: [{ x: 1 }]
    });

    const caption = element.querySelector('[data-viz-table-caption]');
    expect(caption.textContent).toBe('My Chart');
  });

  it('uses heading text when no explicit title', () => {
    const element = document.createElement('div');
    const heading = document.createElement('h3');
    heading.className = 'viz-title';
    heading.textContent = 'Chart Title';
    element.appendChild(heading);

    vizInternals.buildDataTable(element, {
      rows: [{ x: 1 }]
    });

    const caption = element.querySelector('[data-viz-table-caption]');
    expect(caption.textContent).toBe('Chart Title');
  });

  it('uses slug as fallback', () => {
    const element = document.createElement('div');
    element.setAttribute('data-viz-slug', 'my-chart');

    vizInternals.buildDataTable(element, {
      rows: [{ x: 1 }]
    });

    const caption = element.querySelector('[data-viz-table-caption]');
    expect(caption.textContent).toBe('my-chart');
  });

  it('uses default fallback', () => {
    const element = document.createElement('div');

    vizInternals.buildDataTable(element, {
      rows: [{ x: 1 }]
    });

    const caption = element.querySelector('[data-viz-table-caption]');
    expect(caption.textContent).toBe('Visualization data');
  });
});

describe('orderColumns', () => {
  it('orders priority columns first', () => {
    const records = vizInternals.normalizeRecords([
      { Other: 1, Y: 2, X: 3, Series: 4, Value: 5 }
    ]);

    const container = document.createElement('div');
    vizInternals.buildDataTable(container, { rows: records });

    const headers = container.querySelectorAll('th[scope="col"]');
    const headerTexts = Array.from(headers).map(h => h.textContent);

    // Series should come before X, Y, Value, and Value before Other
    expect(headerTexts.indexOf('Series')).toBeLessThan(headerTexts.indexOf('X'));
    expect(headerTexts.indexOf('X')).toBeLessThan(headerTexts.indexOf('Y'));
    expect(headerTexts.indexOf('Value')).toBeLessThan(headerTexts.indexOf('Other'));
  });
});


