import fs from 'fs';
import path from 'path';

const COVERAGE_FILE = path.resolve('coverage/coverage-final.json');

/**
 * Critical modules that must maintain minimum coverage thresholds.
 * Uses statement coverage as the primary metric since V8 coverage
 * doesn't reliably track method names in IIFEs/object literals.
 */
const CRITICAL_MODULES = [
  {
    label: 'Search module',
    relative: path.join('assets', 'js', 'search.js'),
    minStatementCoverage: 70
  },
  {
    label: 'Math module',
    relative: path.join('assets', 'js', 'math.js'),
    minStatementCoverage: 80
  },
  {
    label: 'Core modules (average)',
    relative: path.join('assets', 'js', 'core'),
    minStatementCoverage: 75,
    isDirectory: true
  }
];

if (!fs.existsSync(COVERAGE_FILE)) {
  console.error(`Coverage summary not found at ${COVERAGE_FILE}. Run vitest with --coverage first.`);
  process.exit(1);
}

const payload = JSON.parse(fs.readFileSync(COVERAGE_FILE, 'utf8'));
const failures = [];
const results = [];

/**
 * Calculate statement coverage percentage from coverage data
 */
function calculateStatementCoverage(coverageData) {
  const statements = coverageData.s || {};
  const total = Object.keys(statements).length;
  if (total === 0) return 0;
  const covered = Object.values(statements).filter(count => count > 0).length;
  return (covered / total) * 100;
}

for (const target of CRITICAL_MODULES) {
  if (target.isDirectory) {
    // Calculate average coverage for all files in directory
    const matchingEntries = Object.values(payload).filter((entry) => {
      if (!entry || typeof entry.path !== 'string') return false;
      const normalized = path.normalize(entry.path);
      return normalized.includes(path.normalize(target.relative));
    });

    if (matchingEntries.length === 0) {
      failures.push(`${target.label}: no coverage entries found for directory`);
      continue;
    }

    const coverages = matchingEntries.map(calculateStatementCoverage);
    const avgCoverage = coverages.reduce((a, b) => a + b, 0) / coverages.length;

    results.push({
      label: target.label,
      coverage: avgCoverage.toFixed(2),
      threshold: target.minStatementCoverage,
      passed: avgCoverage >= target.minStatementCoverage
    });

    if (avgCoverage < target.minStatementCoverage) {
      failures.push(
        `${target.label}: statement coverage ${avgCoverage.toFixed(2)}% is below minimum ${target.minStatementCoverage}%`
      );
    }
  } else {
    // Single file coverage check
    const match = Object.values(payload).find((entry) => {
      if (!entry || typeof entry.path !== 'string') return false;
      const normalized = path.normalize(entry.path);
      return normalized.endsWith(path.normalize(target.relative));
    });

    if (!match) {
      failures.push(`${target.label}: coverage entry not found`);
      continue;
    }

    const coverage = calculateStatementCoverage(match);

    results.push({
      label: target.label,
      coverage: coverage.toFixed(2),
      threshold: target.minStatementCoverage,
      passed: coverage >= target.minStatementCoverage
    });

    if (coverage < target.minStatementCoverage) {
      failures.push(
        `${target.label}: statement coverage ${coverage.toFixed(2)}% is below minimum ${target.minStatementCoverage}%`
      );
    }
  }
}

// Print results summary
console.log('\nCritical Module Coverage Report:');
console.log('─'.repeat(60));
for (const result of results) {
  const status = result.passed ? '✓' : '✗';
  const statusColor = result.passed ? '\x1b[32m' : '\x1b[31m';
  console.log(
    `${statusColor}${status}\x1b[0m ${result.label}: ${result.coverage}% (min: ${result.threshold}%)`
  );
}
console.log('─'.repeat(60));

if (failures.length) {
  console.error('\n\x1b[31mCritical coverage requirements not met:\x1b[0m');
  for (const message of failures) {
    console.error(` - ${message}`);
  }
  console.error('\nPlease improve test coverage for the failing modules.');
  process.exit(1);
}

console.log('\n\x1b[32m✓ All critical modules meet coverage requirements.\x1b[0m');
