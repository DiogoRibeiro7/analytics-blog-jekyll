import { fileURLToPath } from 'url';
import path from 'path';
import fs from 'fs';
import assert from 'assert';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

const vizJsPath = path.resolve(rootDir, 'assets', 'js', 'visualizations.js');
const vizScssPath = path.resolve(rootDir, '_sass', '_visualizations.scss');
const vizTemplatePath = path.resolve(rootDir, '_includes', 'components', 'viz-table-fallback.html');

const vizJs = fs.readFileSync(vizJsPath, 'utf8');
const vizScss = fs.readFileSync(vizScssPath, 'utf8');
const vizTemplate = fs.readFileSync(vizTemplatePath, 'utf8');

const contains = (source, needle, message) => {
  assert.ok(source.includes(needle), message);
};

const ensureTemplateStructure = () => {
  contains(vizTemplate, 'viz-table-toggle', 'Template must expose toggle button.');
  contains(vizTemplate, 'viz-table-wrapper', 'Template must wrap table for scrolling.');
  contains(vizTemplate, '<caption', 'Template must provide caption slot.');
};

const ensureRenderersAttachTables = () => {
  contains(vizJs, 'buildPlotlyRecords', 'Plotly data extraction missing.');
  contains(vizJs, 'buildD3Records', 'D3 data extraction missing.');
  contains(vizJs, 'buildObservableRecords', 'Observable data extraction missing.');
  contains(vizJs, 'buildDataTable(element, {', 'Data table builder must be invoked.');
  contains(vizJs, 'canvas.setAttribute(\'aria-describedby\'', 'Visualization canvas must announce table.');
};

const ensurePlotlySpecifics = () => {
  contains(vizJs, 'Plotly.newPlot', 'Plotly renderer missing.');
  contains(vizJs, 'buildPlotlyRecords(data)', 'Plotly fallback should build tabular records.');
  contains(vizJs, 'layout && layout.title', 'Plotly tables should inherit captions from layout titles.');
};

const ensureD3Instrumentation = () => {
  contains(vizJs, 'captureData(data)', 'D3 renderer must capture inline data arrays.');
  contains(vizJs, 'new Function(\'d3\', \'element\', \'captureData\'', 'D3 renderer must expose capture hook.');
};

const ensureObservableExtraction = () => {
  contains(vizJs, 'script[data-observable-data]', 'Observable renderer must look for embedded data.');
  contains(vizJs, 'buildDataTable(element, { rows: records })', 'Observable renderer must hydrate data table.');
};

const ensureTableSemantics = () => {
  contains(vizJs, 'th.scope = \'col\'', 'Column headers must set scope attribute.');
  contains(vizJs, 'th.scope = \'row\'', 'Row headers must set scope attribute.');
  contains(vizJs, 'aria-controls', 'Toggle must announce controlled table.');
  contains(vizJs, 'Hide data table', 'Toggle must reflect expanded state.');
};

const ensureVisualStyles = () => {
  contains(vizScss, '.viz-table-toggle:focus-visible', 'Toggle requires focus-visible styling.');
  contains(vizScss, 'tbody tr:nth-of-type(even)', 'Tables should expose zebra striping.');
  contains(vizScss, 'outline: 3px solid', 'Focus outlines must be visible.');
  contains(vizScss, 'background: rgba($color-accent-primary, 0.16)', 'Hover state should provide sufficient contrast.');
};

(function run() {
  ensureTemplateStructure();
  ensureRenderersAttachTables();
  ensurePlotlySpecifics();
  ensureD3Instrumentation();
  ensureObservableExtraction();
  ensureTableSemantics();
  ensureVisualStyles();
  console.log('Visualization accessibility fallbacks verified.');
})();
