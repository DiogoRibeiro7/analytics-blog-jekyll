#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const visualizations = fs.readFileSync(path.join(root, 'assets', 'js', 'visualizations.js'), 'utf8');
const notebookBundle = fs.readFileSync(path.join(root, 'assets', 'js', 'notebook.js'), 'utf8');

const requiredHooks = [
  'renderPlotly',
  'renderObservable',
  'renderBokeh',
  'renderShiny',
  'renderWidget',
  'renderD3',
  'initializeGallery'
];

const missingHooks = requiredHooks.filter((hook) => !visualizations.includes(hook));
if (missingHooks.length) {
  throw new Error(`Visualization bundle missing integrations: ${missingHooks.join(', ')}`);
}

const notebookHooks = ['annotateCells', 'initPlotly', 'initVega'];
const missingNotebook = notebookHooks.filter((hook) => !notebookBundle.includes(hook));
if (missingNotebook.length) {
  throw new Error(`Notebook bundle missing integrations: ${missingNotebook.join(', ')}`);
}

if (!visualizations.includes('IntersectionObserver')) {
  throw new Error('Visualization bundle missing IntersectionObserver support for lazy loading');
}

if (!visualizations.includes('sandbox')) {
  throw new Error('Embedded visualization sandboxing not enforced');
}

console.log('Interactive elements verified for Plotly, D3, Observable, Bokeh, Shiny, widgets, gallery filters, sandboxing, and notebook tooling.');
