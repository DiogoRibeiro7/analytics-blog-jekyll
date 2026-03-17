import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'jsdom',
    setupFiles: ['tests/js/helpers/setup.js'],
    globals: true,
    include: ['tests/js/**/*.test.js'],
    exclude: ['tests/integration/**'],
    coverage: {
      provider: 'v8',
      all: false, // Only include tested files to get accurate coverage
      reportsDirectory: 'coverage',
      reporter: ['text', 'lcov', 'json', 'html'],
      include: ['assets/js/**/*.js'],
      exclude: [
        'assets/js/**/__mocks__/**',
        'assets/js/dist/**', // Exclude bundled files
        'assets/js/main.js' // Entry point file
      ],
      // Coverage thresholds — recalibrated 2026-Q1
      // Baseline: 91% stmts, 82% branches, 86% functions, 91% lines (859 tests)
      // Set 3-5 points below baseline to catch regressions without false failures
      thresholds: {
        statements: 88,
        branches: 78,
        functions: 83,
        lines: 88
      }
    }
  }
});
