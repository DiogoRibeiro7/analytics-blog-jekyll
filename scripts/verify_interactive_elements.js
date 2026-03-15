#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const visualizations = fs.readFileSync(path.join(__dirname, '..', 'assets', 'js', 'visualizations.js'), 'utf8');
const notebookBundle = fs.readFileSync(path.join(__dirname, '..', 'assets', 'js', 'notebook.js'), 'utf8');

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
