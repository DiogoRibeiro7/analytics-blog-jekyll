# Contributing to DataLog

Thank you for your interest in improving the DataLog theme! This guide outlines our workflow for proposing updates, reporting issues, and sharing new resources with the community.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Quick Start](#quick-start)
- [Development Setup](#development-setup)
- [Contribution Types](#contribution-types)
- [Development Workflow](#development-workflow)
- [Testing Requirements](#testing-requirements)
- [Code Standards](#code-standards)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Community & Support](#community--support)

## Code of Conduct

The DataLog project follows an inclusive, respectful collaboration policy aligned with academic integrity guidelines. Be considerate, cite your sources, and document datasets, notebooks, and experiments thoroughly.

**Our Standards**:
- ✅ Use welcoming and inclusive language
- ✅ Respect differing viewpoints and experiences
- ✅ Accept constructive criticism gracefully
- ✅ Focus on what's best for the community
- ✅ Cite sources and give proper attribution

## Quick Start

### Prerequisites

- **Ruby**: 3.0+ (recommend 3.2)
- **Node.js**: 18+ (recommend 20 LTS)
- **Python**: 3.11+ (optional, for Jupyter support)
- **Git**: Latest version

### Automated Setup

We provide an automated setup script that checks dependencies and configures your environment:

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/analytics-blog-jekyll.git
cd analytics-blog-jekyll

# Run automated setup
./scripts/setup-dev.sh
```

This script will:
- ✓ Verify all dependencies
- ✓ Install Ruby and Node.js packages
- ✓ Set up git hooks (Husky)
- ✓ Create .env file from template
- ✓ Run security audit
- ✓ Build assets
- ✓ Run tests to verify setup

### Manual Setup

If you prefer manual setup:

```bash
# Install dependencies
bundle install
npm ci
python3 -m pip install nbformat jupyter

# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Build assets
npm run build:js

# Start development server
bundle exec jekyll serve
```

Visit http://localhost:4000 to see your local site.

## Development Setup

### Using Docker (Recommended for Beginners)

The easiest way to get started is with Docker:

```bash
# Start development environment
docker-compose up

# Or build and run manually
docker build -f Dockerfile.dev -t datalog-dev .
docker run -p 4000:4000 -v $(pwd):/app datalog-dev
```

The site will be available at http://localhost:4000 with hot-reload enabled.

### Local Development

For faster iteration, develop locally:

```bash
# Start Jekyll server with live reload
bundle exec jekyll serve --livereload

# In another terminal, watch and rebuild JavaScript
npm run build:js --watch
```

### IDE Setup

#### VS Code (Recommended)

Install these extensions:
- **Ruby** - Ruby language support
- **Jekyll Run** - Run Jekyll from VS Code
- **ESLint** - JavaScript linting
- **Prettier** - Code formatting

#### Other IDEs

- **RubyMine**: Full Ruby support out of the box
- **Atom**: Install `language-ruby` and `jekyll` packages
- **Vim**: Use `vim-ruby` and ALE for linting

## Getting Started (Detailed)

### 1. Fork and Clone

```bash
# Fork on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/analytics-blog-jekyll.git
cd analytics-blog-jekyll

# Add upstream remote
git remote add upstream https://github.com/DiogoRibeiro7/analytics-blog-jekyll.git
```

### 2. Create a Feature Branch

```bash
# Update your fork
git fetch upstream
git checkout develop
git merge upstream/develop

# Create feature branch
git checkout -b feature/your-feature-name
# Or for bug fixes
git checkout -b fix/issue-123-description
```

### 3. Make Changes

See [Development Workflow](#development-workflow) below.

### 4. Test Your Changes

```bash
# Run all tests
npm test
npm run test:coverage

# Build site
bundle exec jekyll build

# Verify no errors
bundle exec rake ci:verify
```

### 5. Commit and Push

```bash
git add .
git commit -m "feat: add new feature"
git push origin feature/your-feature-name
```

### 6. Open Pull Request

Go to GitHub and click "New Pull Request". Fill out the PR template completely.

## Academic Contribution Types

We encourage contributions in the following areas:

- **Research Content**: Sample posts, project templates, dataset showcases, and notebook workflows.
- **Visualization Enhancements**: New interactive embeds, gallery cards, or performance improvements.
- **Accessibility & Internationalization**: ARIA enhancements, translation resources, and localization fixes.
- **Tooling & Automation**: Scripts that improve reproducibility, testing, or theme distribution.

## Commit & PR Guidelines

- Reference related issues and link to publications or datasets when relevant.
- Include before/after screenshots for UI changes when possible.
- Update documentation (`README.md`, `docs/`, or inline comments) when behavior changes.
- Ensure new strings are translation-ready and avoid hard-coding locale-specific content.

## Citation & Licensing

By contributing, you agree to release your work under the MIT License and to respect academic citation practices. Include attribution for datasets, algorithms, and borrowed design patterns.

## Reporting Issues

When filing an issue, provide reproduction steps, environment details (OS, Ruby/Python/Node versions), and attach logs or screenshots as appropriate. Highlight any accessibility concerns or performance regressions.

## Community Channels

- GitHub Discussions and Issues for feature planning.
- Academic networking platforms (Google Scholar, ORCID, ResearchGate) for sharing publications built with the theme.

We appreciate your dedication to open, reproducible science and look forward to collaborating.
