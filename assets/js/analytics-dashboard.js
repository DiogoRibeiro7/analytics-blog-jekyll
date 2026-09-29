/**
 * @fileoverview Analytics dashboard for displaying site metrics.
 * Renders visitor charts, engagement stats, and search term reports.
 * @module analytics-dashboard
 */

/**
 * Retrieves analytics data from global window object.
 * @returns {Object} Analytics data object
 */
function getAnalyticsData() {
  return window.__DATALOG_ANALYTICS__ || {};
}

/**
 * Executes callback when DOM is ready.
 * @param {function} callback - Function to execute
 * @returns {void}
 */
export function onReady(callback) {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", callback, { once: true });
  } else {
    callback();
  }
}

/**
 * Parses rows from an analytics report.
 * @param {Object} report - Report object with rows array
 * @returns {Array} Array of row objects
 */
export function parseRows(report) {
  if (!report || !Array.isArray(report.rows)) {
    return [];
  }
  return report.rows;
}

/**
 * Formats a number for display using locale settings.
 * @param {number} value - Number to format
 * @param {Object} [options] - Intl.NumberFormat options
 * @returns {string} Formatted number string
 */
export function formatNumber(value, options) {
  const formatter = new Intl.NumberFormat(undefined, options || { maximumFractionDigits: 0 });
  return formatter.format(value || 0);
}

/**
 * Displays a placeholder message in a table container.
 * @param {HTMLElement} container - Table body element
 * @param {string} message - Message to display
 * @param {number} [columns] - Number of columns to span
 * @returns {void}
 */
export function ensurePlaceholder(container, message, columns) {
  if (!container) return;
  const colSpan = columns || container.closest("table")?.querySelectorAll("th").length || 1;
  const tr = document.createElement("tr");
  tr.className = "placeholder";
  const td = document.createElement("td");
  td.setAttribute("colspan", colSpan);
  td.textContent = message;
  tr.appendChild(td);
  container.replaceChildren(tr);
}

/**
 * Renders the top posts table with page view and engagement data.
 * @returns {void}
 */
export function renderTopPosts() {
  const tbody = document.getElementById("analytics-top-posts");
  const rows = parseRows(getAnalyticsData().top_posts);
  if (!tbody) return;

  if (!rows.length) {
    ensurePlaceholder(tbody, tbody.dataset.emptyMessage || "No data available", 3);
    return;
  }

  tbody.replaceChildren();
  rows.forEach((row) => {
    const dimensions = row.dimensionValues || [];
    const metrics = row.metricValues || [];
    const path = dimensions[0]?.value || "";
    const views = Number(metrics[0]?.value || 0);
    const engagement = Number(metrics[1]?.value || 0);
    const tr = document.createElement("tr");
    const link = document.createElement("a");
    link.href = path.startsWith("/") ? path : `/${path}`;
    link.textContent = path || "—";
    link.rel = "noopener";
    link.className = "analytics-link";

    const pathCell = document.createElement("td");
    pathCell.appendChild(link);

    const viewsCell = document.createElement("td");
    viewsCell.textContent = formatNumber(views);

    const engagementCell = document.createElement("td");
    engagementCell.textContent = formatNumber(engagement, { maximumFractionDigits: 0 });

    tr.append(pathCell, viewsCell, engagementCell);
    tbody.appendChild(tr);
  });
}

export function renderSearchTerms() {
  const tbody = document.getElementById("analytics-search-terms");
  if (!tbody) return;
  const rows = parseRows(getAnalyticsData().search_terms);

  if (!rows.length) {
    ensurePlaceholder(tbody, tbody.dataset.emptyMessage || "No search queries recorded", 2);
    return;
  }

  tbody.replaceChildren();
  rows.forEach((row) => {
    const dimensions = row.dimensionValues || [];
    const metrics = row.metricValues || [];
    const term = dimensions[0]?.value || "(not provided)";
    const sessions = Number(metrics[0]?.value || 0);
    const tr = document.createElement("tr");
    const termCell = document.createElement("td");
    termCell.textContent = term;
    const countCell = document.createElement("td");
    countCell.textContent = formatNumber(sessions);
    tr.append(termCell, countCell);
    tbody.appendChild(tr);
  });
}

export function formatDateLabel(value) {
  if (!value) return value;
  if (value.includes("-")) return value;
  if (value.length === 8) {
    return `${value.slice(0, 4)}-${value.slice(4, 6)}-${value.slice(6, 8)}`;
  }
  return value;
}

/** Read the effective theme tokens at chart creation time. */
function chartColors() {
  const root = document.querySelector('.analytics-dashboard') || document.body;
  const style = window.getComputedStyle(root);
  const token = (name, fallback) => style.getPropertyValue(name).trim() || fallback;
  return {
    text: token('--color-text-secondary', '#64748b'),
    grid: token('--color-border', '#cbd5e1'),
    series: [
      token('--analytics-series-1', '#2155a6'),
      token('--analytics-series-2', '#0c756b'),
      token('--analytics-series-3', '#6b48a5'),
      token('--analytics-series-4', '#9c4d13'),
    ],
  };
}

/**
 * Keep chart data available as an accessible table and explain empty charts.
 * @param {HTMLCanvasElement} canvas - Chart element
 * @param {string} category - Label for the first table column
 * @param {Array<string|number>} labels - Chart categories
 * @param {Array<{label: string, data: number[]}>} datasets - Plotted values
 */
function renderChartData(canvas, category, labels, datasets) {
  const dashboard = canvas.closest('.analytics-dashboard');
  const status = canvas.parentElement?.querySelector('.analytics-chart-status');
  const details = canvas.closest('.analytics-card')?.querySelector('.analytics-chart-data');
  const hasData = labels.length > 0;
  const hasChart = typeof Chart !== 'undefined';

  canvas.hidden = !hasData || !hasChart;
  if (status) {
    status.hidden = hasData && hasChart;
    status.textContent = hasData
      ? dashboard?.dataset.chartUnavailable || 'Chart unavailable; use the data table below.'
      : dashboard?.dataset.noChartData || 'No chart data available.';
  }
  if (!details) return;

  details.hidden = !hasData;
  if (!hasData) return;
  const head = details.querySelector('thead');
  const body = details.querySelector('tbody');
  if (!head || !body) return;
  const heading = document.createElement('tr');
  [category, ...datasets.map((dataset) => dataset.label)].forEach((label) => {
    const th = document.createElement('th');
    th.scope = 'col';
    th.textContent = label;
    heading.appendChild(th);
  });
  head.replaceChildren(heading);
  body.replaceChildren();
  labels.forEach((label, index) => {
    const row = document.createElement('tr');
    const th = document.createElement('th');
    th.scope = 'row';
    th.textContent = String(label);
    row.appendChild(th);
    datasets.forEach((dataset) => {
      const cell = document.createElement('td');
      cell.textContent = formatNumber(dataset.data[index]);
      row.appendChild(cell);
    });
    body.appendChild(row);
  });
}

/** Replace an existing Chart.js instance when the theme changes. */
function replaceChart(canvas, config) {
  Chart.getChart?.(canvas)?.destroy();
  new Chart(canvas, config);
}

export function renderVisitorChart() {
  const canvas = document.getElementById("analytics-visitors-chart");
  if (!canvas) return;

  const rows = parseRows(getAnalyticsData().visitor_trends);
  if (!rows.length) {
    renderChartData(canvas, 'Date', [], []);
    return;
  }

  const labels = rows.map((row) => formatDateLabel(row.dimensionValues?.[0]?.value));
  const totalUsers = rows.map((row) => Number(row.metricValues?.[0]?.value || 0));
  const newUsers = rows.map((row) => Number(row.metricValues?.[1]?.value || 0));
  const sessions = rows.map((row) => Number(row.metricValues?.[2]?.value || 0));
  const pageViews = rows.map((row) => Number(row.metricValues?.[3]?.value || 0));
  const colors = chartColors();
  const datasets = [
    { label: 'Total users', data: totalUsers, borderColor: colors.series[0], tension: 0.35, fill: false },
    { label: 'New users', data: newUsers, borderColor: colors.series[1], tension: 0.35, fill: false },
    { label: 'Sessions', data: sessions, borderColor: colors.series[2], tension: 0.35, fill: false },
    { label: 'Page views', data: pageViews, borderColor: colors.series[3], borderDash: [6, 6], tension: 0.35, fill: false },
  ];
  renderChartData(canvas, 'Date', labels, datasets);
  if (typeof Chart === 'undefined') return;

  replaceChart(canvas, {
    type: "line",
    data: { labels, datasets },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: "index", intersect: false },
      scales: {
        y: {
          beginAtZero: true,
          ticks: { color: colors.text, callback: (val) => formatNumber(val) },
          grid: { color: colors.grid },
        },
        x: { ticks: { color: colors.text }, grid: { color: colors.grid } },
      },
      plugins: {
        legend: { position: "top", labels: { color: colors.text } },
      },
    },
  });
}

export function renderEngagementChart() {
  const canvas = document.getElementById("analytics-engagement-chart");
  if (!canvas) return;
  const rows = parseRows(getAnalyticsData().engagement_by_page).slice(0, 10);
  if (!rows.length) {
    renderChartData(canvas, 'Post', [], []);
    return;
  }

  const labels = rows.map((row) => row.dimensionValues?.[0]?.value || "—");
  const engagedSessions = rows.map((row) => Number(row.metricValues?.[2]?.value || 0));
  const views = rows.map((row) => Number(row.metricValues?.[0]?.value || 0));
  const colors = chartColors();
  const datasets = [
    { label: 'Engaged sessions', data: engagedSessions, backgroundColor: colors.series[0] },
    { label: 'Page views', data: views, backgroundColor: colors.series[1] },
  ];
  renderChartData(canvas, 'Post', labels, datasets);
  if (typeof Chart === 'undefined') return;

  replaceChart(canvas, {
    type: "bar",
    data: { labels, datasets },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      indexAxis: "y",
      scales: {
        x: { beginAtZero: true, ticks: { color: colors.text, callback: (val) => formatNumber(val) }, grid: { color: colors.grid } },
        y: { ticks: { color: colors.text }, grid: { color: colors.grid } },
      },
      plugins: {
        legend: { position: "top", labels: { color: colors.text } },
      },
    },
  });
}

export function renderKeyEvents() {
  const container = document.getElementById("analytics-key-events");
  if (!container) return;
  const rows = parseRows(getAnalyticsData().key_events);
  if (!rows.length) {
    const li = document.createElement("li");
    li.className = "placeholder";
    li.textContent = "No tracked events in the selected window.";
    container.replaceChildren(li);
    return;
  }

  container.replaceChildren();
  rows.forEach((row) => {
    const name = row.dimensionValues?.[0]?.value || "event";
    const count = Number(row.metricValues?.[0]?.value || 0);
    const li = document.createElement("li");
    const strong = document.createElement("strong");
    strong.textContent = formatNumber(count);
    li.appendChild(strong);
    li.appendChild(document.createTextNode(` ${name.replace(/_/g, " ")}`));
    container.appendChild(li);
  });
}

export function renderScholar() {
  const metrics = getAnalyticsData().scholar || {};
  const totalField = document.querySelector('[data-field="scholar-total"]');
  const hIndexField = document.querySelector('[data-field="scholar-h-index"]');
  const i10Field = document.querySelector('[data-field="scholar-i10-index"]');
  if (totalField) totalField.textContent = metrics.total ? formatNumber(Number(metrics.total)) : "—";
  if (hIndexField) hIndexField.textContent = metrics.h_index ? formatNumber(Number(metrics.h_index)) : "—";
  if (i10Field) i10Field.textContent = metrics.i10_index ? formatNumber(Number(metrics.i10_index)) : "—";

  const canvas = document.getElementById("analytics-scholar-chart");
  if (!canvas) return;
  const yearly = metrics.yearly_totals || {};
  const entries = Object.entries(yearly)
    .map(([year, value]) => [Number(year), Number(value)])
    .sort((a, b) => a[0] - b[0]);
  if (!entries.length) {
    renderChartData(canvas, 'Year', [], []);
    return;
  }
  const colors = chartColors();
  const labels = entries.map((item) => item[0]);
  const datasets = [{ label: 'Citations', data: entries.map((item) => item[1]), backgroundColor: colors.series[2] }];
  renderChartData(canvas, 'Year', labels, datasets);
  if (typeof Chart === 'undefined') return;

  replaceChart(canvas, {
    type: "bar",
    data: { labels, datasets },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: { beginAtZero: true, ticks: { color: colors.text, callback: (val) => formatNumber(val) }, grid: { color: colors.grid } },
        x: { ticks: { color: colors.text }, grid: { color: colors.grid } },
      },
      plugins: { legend: { labels: { color: colors.text } } },
    },
  });
}

export function renderMonthlyReports() {
  const tbody = document.getElementById("analytics-monthly-reports");
  if (!tbody) return;
  const reports = Array.isArray(getAnalyticsData().monthly_reports) ? getAnalyticsData().monthly_reports : [];
  if (!reports.length) {
    ensurePlaceholder(tbody, tbody.dataset.emptyMessage || "No monthly reports available", 5);
    return;
  }

  tbody.replaceChildren();
  reports.forEach((report) => {
    const tr = document.createElement("tr");
    const month = document.createElement("td");
    month.textContent = report.month || "—";
    const total = document.createElement("td");
    total.textContent = formatNumber(report.total_users || 0);
    const news = document.createElement("td");
    news.textContent = formatNumber(report.new_users || 0);
    const sessions = document.createElement("td");
    sessions.textContent = formatNumber(report.sessions || 0);
    const views = document.createElement("td");
    views.textContent = formatNumber(report.page_views || 0);
    tr.append(month, total, news, sessions, views);
    tbody.appendChild(tr);
  });
}

export function render() {
  const status = getAnalyticsData().status;
  if (status !== "ok") {
    ["analytics-top-posts", "analytics-search-terms", "analytics-monthly-reports"].forEach((id) => {
      const el = document.getElementById(id);
      if (el) {
        ensurePlaceholder(el, getAnalyticsData().message || "Analytics data unavailable.");
      }
    });
    const events = document.getElementById("analytics-key-events");
    if (events) {
      const li = document.createElement("li");
      li.className = "placeholder";
      li.textContent = getAnalyticsData().message || "Analytics data unavailable.";
      events.replaceChildren(li);
    }
    renderVisitorChart();
    renderEngagementChart();
    renderScholar();
    return;
  }

  const data = getAnalyticsData();
  const hasResults = ['top_posts', 'search_terms', 'visitor_trends', 'engagement_by_page', 'key_events']
    .some((name) => parseRows(data[name]).length > 0)
    || (Array.isArray(data.monthly_reports) && data.monthly_reports.length > 0);
  const dashboard = document.querySelector('.analytics-dashboard');
  if (dashboard) {
    dashboard.dataset.state = hasResults ? 'populated' : 'empty';
    const state = dashboard.querySelector('.analytics-state');
    if (!hasResults && dashboard.dataset.stale !== 'true' && state) {
      state.textContent = state.dataset.emptyLabel || 'No results yet';
    }
  }

  renderTopPosts();
  renderSearchTerms();
  renderVisitorChart();
  renderEngagementChart();
  renderKeyEvents();
  renderScholar();
  renderMonthlyReports();
}

// Auto-initialize when module loads (backward compatibility)
// Skip auto-init in test environment
if (typeof window !== 'undefined' && !window.__VITEST__) {
  onReady(() => {
    render();
    if (!document.querySelector('.analytics-dashboard')) return;
    // Chart.js paints colours into the canvas, so rebuild charts when the
    // effective theme changes. Other dashboard content stays in place.
    new MutationObserver(() => {
      renderVisitorChart();
      renderEngagementChart();
      renderScholar();
    }).observe(document.body, { attributes: true, attributeFilter: ['class'] });
  });
}
