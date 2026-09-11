# Scripts Reference

This document provides a comprehensive overview of all utility scripts in the `/scripts` directory.

## Table of Contents

- [Overview](#overview)
- [Build & Optimization](#build--optimization)
- [Testing Scripts](#testing-scripts)
- [Import & Export](#import--export)
- [Utilities](#utilities)
- [Usage Examples](#usage-examples)
- [Development](#development)

## Overview

The `/scripts` directory contains utility scripts for building, testing, and maintaining the DataLog theme. All scripts are executable and include appropriate shebang lines.

### Script Categories

| Category | Count | Languages |
|----------|-------|-----------|
| Build & Optimization | 4 | JavaScript |
| Testing | 11 | Ruby, JavaScript |
| Import & Export | 4 | Ruby |
| Utilities | 4 | Ruby, Python |

### Running Scripts

All scripts are executable and can be run directly:

```bash
# Ruby scripts
./scripts/test_security.rb

# JavaScript/Node scripts
./scripts/generate_sri.js

# Python scripts
./scripts/update_google_scholar.py

# Or explicitly with interpreter
ruby scripts/test_security.rb
node scripts/generate_sri.js
python3 scripts/update_google_scholar.py
```

## Build & Optimization

### build_js.mjs

**Purpose**: Bundles JavaScript modules using esbuild.

**Language**: JavaScript (ES Module)

**Usage**:
```bash
node scripts/build_js.mjs
# Or via npm script
npm run build:js
```

**What it does**:
- Bundles JavaScript files from `_assets/js/`
- Minifies for production
- Generates source maps
- Outputs to `assets/js/`

**Configuration**: See `package.json` build scripts

---

### extract_critical_css.js

**Purpose**: Extracts and inlines critical CSS for above-the-fold content.

**Language**: JavaScript (Node.js)

**Usage**:
```bash
./scripts/extract_critical_css.js
# Or via npm script
npm run build:critical
```

**What it does**:
- Analyzes built site's HTML
- Extracts critical CSS for key pages
- Generates inline CSS for faster page loads
- Outputs to `_includes/critical-css/`

**Requirements**:
- Built Jekyll site in `_site/`
- `critical` npm package

**Environment Variables**:
- `JEKYLL_ENV=production` (recommended)
- `NODE_ENV=production` (recommended)

---

### generate_sri.js

**Purpose**: Generates Subresource Integrity (SRI) hashes for CDN resources.

**Language**: JavaScript (Node.js)

**Usage**:
```bash
./scripts/generate_sri.js
# Or via npm script
npm run generate-sri
```

**What it does**:
- Scans site for external CDN resources
- Generates SHA-384 integrity hashes
- Creates `_data/cdn_integrity.yml`
- Ensures secure resource loading

**Output**: `_data/cdn_integrity.yml`

**Related**: See also `validate_sri.js`

---

### validate_sri.js

**Purpose**: Validates that all CDN resources have SRI hashes.

**Language**: JavaScript (Node.js)

**Usage**:
```bash
./scripts/validate_sri.js
# Or via npm script
npm run validate-sri
```

**What it does**:
- Checks built site for CDN resources
- Verifies integrity attributes exist
- Fails if resources lack SRI protection
- Reports missing hashes

**Exit codes**:
- `0`: All resources have SRI hashes
- `1`: Missing or invalid SRI hashes

**CI/CD**: Runs in GitHub Actions deploy workflow

---

## Testing Scripts

### test_security.rb

**Purpose**: Security validation tests.

**Language**: Ruby

**Usage**:
```bash
./scripts/test_security.rb
```

**What it tests**:
- Content Security Policy generation
- XSS prevention in templates
- Path traversal protection
- Safe HTML escaping

---

### test_accessibility.rb

**Purpose**: Accessibility compliance tests.

**Language**: Ruby

**Usage**:
```bash
./scripts/test_accessibility.rb
```

**What it tests**:
- WCAG 2.1 AA compliance
- ARIA attributes
- Semantic HTML
- Keyboard navigation
- Screen reader compatibility

**Standards**: WCAG 2.1 Level AA

**Related**: See also `.github/workflows/accessibility.yml`

---

### test_math_rendering.rb

**Purpose**: Mathematical content rendering tests.

**Language**: Ruby

**Usage**:
```bash
./scripts/test_math_rendering.rb
```

**What it tests**:
- MathJax/KaTeX integration
- LaTeX equation rendering
- Inline vs. display math
- Math escaping in code blocks

**Engines tested**: MathJax, KaTeX

---

### test_code_syntax.rb

**Purpose**: Syntax highlighting tests.

**Language**: Ruby

**Usage**:
```bash
./scripts/test_code_syntax.rb
```

**What it tests**:
- Rouge syntax highlighting
- Prism.js integration
- Language detection
- Line numbering
- Code block themes

---

### test_performance.rb

**Purpose**: Performance benchmarking.

**Language**: Ruby

**Usage**:
```bash
./scripts/test_performance.rb
```

**What it tests**:
- Build time performance
- Page load times
- Plugin execution time
- Asset optimization

**Metrics**: Build time, page size, asset count

---

### test_responsiveness.rb

**Purpose**: Responsive design validation.

**Language**: Ruby

**Usage**:
```bash
./scripts/test_responsiveness.rb
```

**What it tests**:
- Mobile viewport handling
- Breakpoint behavior
- Touch targets
- Flexible layouts

**Viewports tested**: Mobile (375px), Tablet (768px), Desktop (1920px)

---

### test_citations.rb

**Purpose**: Academic citation tests.

**Language**: Ruby

**Usage**:
```bash
./scripts/test_citations.rb
```

**What it tests**:
- BibTeX integration
- Citation formatting
- Bibliography generation
- ORCID links
- Google Scholar integration

---

### test_integrations.rb

**Purpose**: Third-party integration tests.

**Language**: Ruby

**Usage**:
```bash
./scripts/test_integrations.rb
```

**What it tests**:
- Binder integration
- Google Colab links
- Kaggle integration
- Giscus comments
- Analytics integration

---

### test_collaboration_workflows.rb

**Purpose**: Collaboration feature tests.

**Language**: Ruby

**Usage**:
```bash
./scripts/test_collaboration_workflows.rb
```

**What it tests**:
- GitHub repository metrics
- Contributor attribution
- Collaborative notebook editing
- Comment system integration

---

### test_search.js

**Purpose**: Search functionality tests.

**Language**: JavaScript (Node.js)

**Usage**:
```bash
./scripts/test_search.js
# Or via test suite
npm run test:unit
```

**What it tests**:
- Search index generation
- Query parsing
- Result ranking
- Keyboard navigation
- Filter functionality

**Framework**: Vitest

**Related**: See `tests/js/search.test.js`

---

### verify_interactive_elements.js

**Purpose**: Interactive element validation.

**Language**: JavaScript (Node.js)

**Usage**:
```bash
./scripts/verify_interactive_elements.js
```

**What it tests**:
- Button accessibility
- Form validation
- Modal dialogs
- Dropdown menus
- Interactive visualizations

---

## Import & Export

### import_medium.rb

**Purpose**: Import posts from Medium.

**Language**: Ruby

**Usage**:
```bash
./scripts/import_medium.rb [medium_url] [output_dir]
```

**Example**:
```bash
./scripts/import_medium.rb https://medium.com/@username/my-post _posts/
```

**What it does**:
- Fetches Medium post content
- Converts to Jekyll front matter format
- Downloads images
- Preserves formatting

**Requirements**: Medium post URL, write access to output directory

---

### import_notion.rb

**Purpose**: Import content from Notion.

**Language**: Ruby

**Usage**:
```bash
./scripts/import_notion.rb [notion_page_id] [output_dir]
```

**What it does**:
- Fetches Notion page via API
- Converts Notion blocks to Markdown
- Downloads embedded media
- Preserves hierarchy

**Requirements**: Notion API token (set in environment)

---

### import_wordpress.rb

**Purpose**: Import posts from WordPress.

**Language**: Ruby

**Usage**:
```bash
./scripts/import_wordpress.rb [wordpress_export.xml] [output_dir]
```

**What it does**:
- Parses WordPress WXR export file
- Converts posts to Jekyll format
- Handles attachments
- Preserves categories and tags

**Input**: WordPress XML export file

---

### export_pdf.rb

**Purpose**: Export posts to PDF format.

**Language**: Ruby

**Usage**:
```bash
./scripts/export_pdf.rb [post_file] [output.pdf]
```

**What it does**:
- Renders Jekyll post as PDF
- Includes images and styling
- Preserves formatting
- Generates table of contents

**Requirements**: `wkhtmltopdf` or `prince` installed

---

### export_epub.rb

**Purpose**: Export posts to EPUB format.

**Language**: Ruby

**Usage**:
```bash
./scripts/export_epub.rb [post_file] [output.epub]
```

**What it does**:
- Converts post to EPUB format
- Embeds images
- Generates metadata
- Creates table of contents

**Requirements**: `gepub` gem

---

## Utilities

### backup_to_git.rb

**Purpose**: Automated git backup utility.

**Language**: Ruby

**Usage**:
```bash
./scripts/backup_to_git.rb [branch_name]
```

**What it does**:
- Creates timestamped commits
- Pushes to specified branch
- Handles conflicts
- Logs backup history

**Use case**: Automated backups, content versioning

---

### update_google_scholar.py

**Purpose**: Sync citations from Google Scholar.

**Language**: Python

**Usage**:
```bash
./scripts/update_google_scholar.py
```

**What it does**:
- Fetches citation count from Google Scholar
- Updates `_data/publications.yml`
- Generates citation badges
- Updates author h-index

**Requirements**:
- `scholarly` Python package
- Google Scholar profile URL in `_config.yml`

**Automation**: Runs via GitHub Actions workflow

---

### notebook_validation.py

**Purpose**: Validate Jupyter notebooks.

**Language**: Python

**Usage**:
```bash
./scripts/notebook_validation.py [notebook.ipynb]
```

**What it validates**:
- Valid JSON structure
- nbformat version compatibility
- Cell output integrity
- Metadata completeness

**Requirements**: `nbformat` Python package

---

### visualize_plugins.rb

**Purpose**: Generate plugin dependency graph.

**Language**: Ruby

**Usage**:
```bash
./scripts/visualize_plugins.rb
```

**What it does**:
- Analyzes plugin dependencies
- Generates GraphViz DOT file
- Creates visual dependency graph
- Identifies circular dependencies

**Output**: `plugins_graph.dot` (convert with `dot -Tpng plugins_graph.dot -o plugins.png`)

**Requirements**: GraphViz for rendering

---

### script_support.rb

**Purpose**: Shared utility functions for Ruby scripts.

**Language**: Ruby

**Usage**: Required by other Ruby scripts (not run directly)

**Provides**:
- Common helper methods
- Logging utilities
- Configuration parsing
- Error handling

---

### check_coverage.js

**Purpose**: Verify test coverage thresholds.

**Language**: JavaScript (Node.js)

**Usage**:
```bash
./scripts/check_coverage.js
# Or via npm script
npm run test:coverage
```

**What it does**:
- Reads coverage reports
- Verifies against thresholds
- Fails if coverage insufficient
- Generates coverage badges

**Thresholds** (from `vitest.config.js`):
- Lines: 80%
- Functions: 80%
- Statements: 80%
- Branches: 60%

---

### run_playwright_suite.js

**Purpose**: Orchestrate Playwright test execution.

**Language**: JavaScript (Node.js)

**Usage**:
```bash
./scripts/run_playwright_suite.js
# Or via npm script
npm run test:integration
```

**What it does**:
- Builds Jekyll site
- Starts static server
- Runs Playwright tests
- Cleans up after tests

**Environment Variables**:
- `PLAYWRIGHT_BASE_URL`: Override default server URL

**Features**:
- Auto-detects running servers
- Graceful cleanup on failure
- Detailed progress logging

---

## Usage Examples

### Complete Build Process

```bash
# 1. Install dependencies
bundle install
npm install

# 2. Build JavaScript bundles
npm run build:js

# 3. Build Jekyll site
JEKYLL_ENV=production bundle exec jekyll build

# 4. Generate critical CSS
npm run build:critical

# 5. Generate SRI hashes
npm run generate-sri

# 6. Validate SRI coverage
npm run validate-sri
```

### Run All Tests

```bash
# Unit tests
npm run test

# Integration tests (builds site + runs Playwright)
npm run test:integration


# Ruby test scripts
./scripts/test_security.rb
./scripts/test_accessibility.rb
./scripts/test_math_rendering.rb
./scripts/test_code_syntax.rb
./scripts/test_performance.rb
./scripts/test_citations.rb
```

### Import Content

```bash
# From Medium
./scripts/import_medium.rb https://medium.com/@user/post _posts/

# From Notion (requires NOTION_TOKEN env var)
export NOTION_TOKEN=your_token
./scripts/import_notion.rb page-id _posts/

# From WordPress export
./scripts/import_wordpress.rb wordpress-export.xml _posts/
```

### Export Content

```bash
# To PDF (requires wkhtmltopdf)
./scripts/export_pdf.rb _posts/2024-01-01-my-post.md output.pdf

# To EPUB
./scripts/export_epub.rb _posts/2024-01-01-my-post.md output.epub
```

### Utilities

```bash
# Update Google Scholar citations
./scripts/update_google_scholar.py

# Validate Jupyter notebook
./scripts/notebook_validation.py _notebooks/analysis.ipynb

# Visualize plugin dependencies
./scripts/visualize_plugins.rb
dot -Tpng plugins_graph.dot -o plugins.png

# Backup to git
./scripts/backup_to_git.rb backup-branch
```

## Development

### Adding New Scripts

When adding a new script:

1. **Choose appropriate language**:
   - Ruby: Jekyll integration, plugin development
   - JavaScript: Build tools, testing, browser automation
   - Python: Data processing, API integration

2. **Add shebang line**:
   ```ruby
   #!/usr/bin/env ruby
   ```
   ```javascript
   #!/usr/bin/env node
   ```
   ```python
   #!/usr/bin/env python3
   ```

3. **Make executable**:
   ```bash
   chmod +x scripts/your_script.rb
   ```

4. **Add documentation**:
   - Usage instructions in script header
   - Update this reference document
   - Add examples to README if user-facing

5. **Test thoroughly**:
   - Test with various inputs
   - Handle errors gracefully
   - Add to CI/CD if appropriate

### Script Conventions

**Ruby Scripts**:
- Use `script_support.rb` for shared utilities
- Follow Jekyll plugin conventions
- Handle missing dependencies gracefully

**JavaScript Scripts**:
- Use ES modules (`.mjs`) for module scripts
- Use CommonJS (`.js`) for Node scripts
- Include clear error messages

**Python Scripts**:
- Python 3.11+ compatible
- Use type hints where appropriate
- Include requirements in docstring

### Testing Scripts

Test your scripts before committing:

```bash
# Syntax check (Ruby)
ruby -c scripts/your_script.rb

# Syntax check (JavaScript)
node --check scripts/your_script.js

# Syntax check (Python)
python3 -m py_compile scripts/your_script.py

# Lint (if configured)
rubocop scripts/your_script.rb
eslint scripts/your_script.js
pylint scripts/your_script.py
```

## Troubleshooting

### Permission Denied

**Problem**: `./scripts/script.rb: Permission denied`

**Solution**: Make script executable:
```bash
chmod +x scripts/script.rb
```

### Missing Dependencies

**Problem**: `LoadError: cannot load such file -- xyz`

**Solution**: Install dependencies:
```bash
# Ruby
bundle install

# JavaScript
npm install

# Python
pip install -r requirements.txt
```

### Environment Variables

**Problem**: Script fails with "Configuration not found"

**Solution**: Set required environment variables:
```bash
export VARIABLE_NAME=value
./scripts/script.rb
```

Or use `.env` file (see [Environment Setup Guide](environment-setup.md))

### Build Failures

**Problem**: Build scripts fail with "Site not found"

**Solution**: Build Jekyll site first:
```bash
bundle exec jekyll build
# Then run script
./scripts/your_script.js
```

## See Also

- [Environment Setup Guide](environment-setup.md) - Configure environment variables
- [User Guide](user-guide.md) - General usage instructions
- [Plugin Development Guide](plugin-development.md) - Creating custom plugins
- [Contributing Guidelines](../CONTRIBUTING.md) - Contribution workflow

## Questions?

For script-related questions:
- Check script header comments for usage
- Review this reference document
- Open a [GitHub Discussion](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/discussions)
- Report issues with [bug report template](../.github/ISSUE_TEMPLATE/bug_report.yml)
