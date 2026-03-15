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
      // Coverage thresholds - progressive improvement
      // History:
      //   20% → 45% (109 tests) → 31% (201 tests) → 32.68% (337 tests, Phase 2 start)
      //   → 37.27% (academic.js: 0% → 92.53%) → 39.41% (notebook.js: 0% → 71.62%)
      //   → 40.6% (fixed 4 async tests, github-cards: 17% → 67.79%)
      //   → 43.46% (analytics-dashboard: 0% → 39.66%, 365 tests passing)
      //   → 46.96% (math.js: 16% → 31%, visualizations.js: 33% → 36%, 414 tests)
      //   → 50.02% (math.js: 31% → 47.89%, 427 tests) ✅ 50% TARGET ACHIEVED!
      //   → 54.44% (autocomplete: 0% → 98.52%, analytics: 2% → 97.77%, 467 tests)
      //   → 59.15% (render.js: 0% → 87.96%, 503 tests)
      //   → 64.38% (app.js: 0.66% → 84.1%, 518 tests)
      //   → 65.75% (visualizations.js: 36.7% → 43.71%, 538 tests)
      //   → 74.96% (math.js: 47.89% → 94.09%, dark-mode: 66.66% → 100%, 593 tests)
      //
      // Phase 2 completed: loader (51%), github-cards (68%), academic (92%),
      //                    notebook (71%), analytics-dashboard (39.66%)
      // Phase 3 completed: math.js (47.89%), visualizations.js (36.7%)
      // Phase 4 completed: autocomplete (98.52%), analytics (97.77%)
      // Phase 5 completed: render.js (87.96%)
      // Phase 6 completed: app.js (84.1%) - search module at 88.08%!
      // Phase 7 completed: visualizations.js tests expansion (43.71%)
      // Phase 8 completed: math.js massive expansion (94.09%), dark-mode (100%)
      // Phase 9 completed: visualizations.js expansion (+12 tests), notebook.js (+8 tests)
      //
      // 🎉 80.72% COVERAGE - EXCEEDED 80% MILESTONE! 🎉
      // Progress: 77.94% → 79.63% → 80.72% (+2.78 points, +20 tests)
      // Total tests: 644 passing, 2 skipped (646 total)
      // Major wins: visualizations.js (52% → 57.93%), notebook.js tests expanded
      // Next target: 85%!
      thresholds: {
        statements: 80,
        branches: 70,
        functions: 75,
        lines: 80
      }
    }
  }
});
