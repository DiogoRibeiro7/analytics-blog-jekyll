# Scripts Reference

This document provides a comprehensive overview of all utility scripts in the `/scripts` directory.

## Table of Contents

- [Overview](#overview)
- [Build & Optimization](#build--optimization)
- [Import & Export](#import--export)
- [Content Audit](#content-audit)
- [Utilities](#utilities)
- [Usage Examples](#usage-examples)
- [Development](#development)

## Overview

The `/scripts` directory contains utility scripts for building, testing, and maintaining the DataLog theme. All scripts are executable and include appropriate shebang lines.

### Script Categories

| Category | Count | Languages |
|----------|-------|-----------|
| Build & Optimization | 4 | JavaScript |
| Import & Export | 4 | Ruby |
| Utilities | 4 | Ruby, Python |

### Running Scripts

All scripts are executable and can be run directly:

```bash
# Ruby scripts
./scripts/visualize_plugins.rb

# JavaScript/Node scripts
./scripts/generate_sri.js

# Python scripts
./scripts/update_google_scholar.py

# Or explicitly with interpreter
ruby scripts/visualize_plugins.rb
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

### Critical CSS (`npm run build:critical`)

**Purpose**: Writes the critical CSS a production build inlines.

**Usage**:
```bash
npm run build:critical
# which runs
bundle exec datalog critical-css
```

**What it does**: builds the site for production into a temporary directory, extracts the critical CSS of a home page, a post and one other page with the `critical` npm package, and writes `_includes/critical-css/home.html`, `post.html` and `default.html`. The command is part of the gem, so a site using the theme runs the same one; `lib/datalog/critical_css.rb` implements it, and the [configuration guide](configuration-guide.md#critical-css) describes its settings.

**Requirements**: `critical_css.enabled: true` in `_config.yml`, and Node.js 22.13 or later with `critical` installed (`npm ci`), which downloads headless Chrome.
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

## Content Audit

### datalog audit

**Purpose**: Finds the pages and posts that would gain from the theme's newer authoring features, and the content problems no build reports. It gives the file and line of each finding. It reads the site and writes nothing.

**Usage**:
```bash
bundle exec datalog audit                        # a summary in the terminal
bundle exec datalog audit --strict               # exit 1 when there is a problem, for CI
bundle exec datalog audit --format json          # for tooling
bundle exec datalog audit --format markdown      # for an issue or a pull-request comment
bundle exec datalog audit --only statements,series --path _posts/statistics
```

**Opportunities** are advice. They are never an error, even with `--strict`:

| Check | Finds | Would use |
| --- | --- | --- |
| `statements` | A paragraph, list item or blockquote opening with a bold **Theorem**, **Lemma**, **Proposition**, **Corollary**, **Definition**, **Assumption**, **Example** or **Remark**, or a **Proof** (bold, or *Proof.* in italics) | `{% theorem %}` and its siblings, `{% proof %}` |
| `figures` | "Figure 3", "Fig. 3" or "Table 2" typed in the text | `{% figure %}`, `{% table %}` and `{% ref %}` |
| `series` | A post whose title or file name says "Part 2" (or "Part II"), or that links another part or the next or previous post by hand, with no `series:` | `series:` |
| `reproducibility` | A post that links a GitHub, GitLab, Bitbucket or Codeberg repository, a notebook (`.ipynb`, Colab, Binder, nbviewer) or a DOI, with no `reproducibility:` | the reproducibility panel |
| `revisions` | A post edited more than 30 days after its date, by `last_modified_at` or `updated`, or else by its last Git commit, with no `revisions:` | the revision history |
| `references` | A heading or bold line "References", "Bibliography", "Works cited" or "Sources" on a page that does not cite with `{% cite %}` | `{% cite %}` and a bibliography file |

The Git check ignores commits that touch more than ten files, since a reformat or a migration is not an edit of any one article.

**Problems** are warnings. `--strict` turns them into exit status 1:

| Check | Finds |
| --- | --- |
| `front-matter` | A front matter key that no layout, include or plugin reads, such as a typo (`descripton:`) or a field of another theme. The known keys are taken from the theme's layouts, includes, plugins and library, and from the site's own layouts, includes and plugins. They are never kept as a list. |
| `images` | A Markdown image with empty alt text, an `<img>` with no `alt` attribute, or alt text that is the image's file name. `alt=""` on an `<img>` is left alone, since it marks a decorative image. |
| `links` | A site-relative link (`/path/`, Markdown or HTML) to a page the site does not build |
| `math` | A post with `math: true` whose content has no math, or `math: false` whose content has some, by the same detection as `_plugins/math_preprocessor.rb` |

**What it reads**:
- **Content:** Jekyll's reader gives the site's pages and documents, with the site's own `exclude`, `include` and collections. Each finding comes from the file as written. Code (fenced blocks, `{% highlight %}` and `{% raw %}` blocks, `<pre>` and `<code>`, inline code, HTML comments) is left out, so an example in a code block is not reported.
- **Built pages:** besides the pages and documents, the audit runs the generators that only add pages in memory (feeds, the sitemap, pagination, redirects, the search page, notebook pages). It never runs the ones that fetch data, encode images or fill a cache, and it never renders or writes the site.

**Settings** (`_config.yml`):
```yaml
audit:
  known_keys: [legacy_id]        # front matter keys a site reads its own way
  ignore_links: [/api/]          # URL prefixes built outside Jekyll, such as a plugin's generated pages
  revision_after_days: 30        # an edit counts after this many days
```

**Exit codes**: 0, or 1 with `--strict` when there is a problem; 2 when the audit cannot run (no `_config.yml`, an unknown check in `--only`).

**Limitations**: links are checked when they are site-relative; relative links (`../post/`) and full URLs are not. Pages created by a site's own generators are not known to the audit, so links to them are reported unless `audit.ignore_links` names them.

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
- Builds the site with `_config.yml` and `tests/integration/site-config.yml` layered over it. The overlay points `dynamic_services` at `https://api.example.test`, an address the specs answer with `page.route`, so the forms that post to a backend (correction reports, contact) can be exercised without a server. The deploy workflow builds the site again without it.
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

# 3. Generate critical CSS, which the build inlines
npm run build:critical

# 4. Build Jekyll site
JEKYLL_ENV=production bundle exec jekyll build

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

# Ruby tests: builds the demo site, then runs the Minitest suite against it
bundle exec rake test
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
