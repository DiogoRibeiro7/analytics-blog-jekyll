# Environment Setup Guide

This guide explains how to configure environment variables and secrets for DataLog Jekyll Theme.

## Table of Contents

- [Quick Start](#quick-start)
- [Environment Variables Overview](#environment-variables-overview)
- [Local Development Setup](#local-development-setup)
- [GitHub Actions Setup](#github-actions-setup)
- [Analytics Configuration](#analytics-configuration)
- [Testing Configuration](#testing-configuration)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)

## Quick Start

1. **Copy the example environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` and fill in your values:**
   ```bash
   # Open in your preferred editor
   nano .env
   # or
   code .env
   ```

3. **Verify `.env` is in `.gitignore`:**
   ```bash
   grep -q "^\.env$" .gitignore && echo "✓ .env is gitignored" || echo "✗ Add .env to .gitignore!"
   ```

## Environment Variables Overview

### Required for Core Functionality

**None** - DataLog works out of the box without any environment variables. All variables are optional and enable additional features.

### Optional Feature Variables

| Variable | Purpose | Required For | Default |
|----------|---------|--------------|---------|
| `GA4_PROPERTY_ID` | Google Analytics 4 property | Analytics dashboard | - |
| `GA4_CREDENTIALS_JSON` | GA4 service account credentials | Analytics dashboard | - |
| `GA4_CREDENTIALS_PATH` | Path to GA4 credentials file | Analytics dashboard | - |
| `PLAYWRIGHT_BASE_URL` | Base URL for tests | Integration/visual tests | `http://127.0.0.1:4173` |
| `CODECOV_TOKEN` | Codecov project token | Coverage reporting | - |
| `JEKYLL_ENV` | Jekyll environment | Production builds | `development` |
| `NODE_ENV` | Node environment | Build optimization | `development` |

## Local Development Setup

### Basic Setup (No Environment Variables)

For basic development, you don't need any environment variables:

```bash
# Install dependencies
bundle install
npm install

# Start development server
bundle exec jekyll serve

# Open http://localhost:4000
```

### With Analytics (Optional)

If you want to test the analytics dashboard locally:

1. **Create a Google Cloud Project:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select existing one

2. **Enable Google Analytics Data API:**
   - Navigate to APIs & Services → Library
   - Search for "Google Analytics Data API"
   - Click "Enable"

3. **Create Service Account:**
   - Go to APIs & Services → Credentials
   - Click "Create Credentials" → "Service Account"
   - Fill in details and click "Create"
   - Grant "Viewer" role
   - Click "Done"

4. **Generate Service Account Key:**
   - Click on the created service account
   - Go to "Keys" tab
   - Click "Add Key" → "Create new key"
   - Choose JSON format
   - Download the key file

5. **Get GA4 Property ID:**
   - Go to [Google Analytics](https://analytics.google.com/)
   - Select your property
   - Navigate to Admin → Property Settings
   - Copy the "Property ID" (format: `123456789`)

6. **Configure Environment:**

   **Option 1: Using JSON string**
   ```bash
   # In .env file
   GA4_PROPERTY_ID=123456789
   GA4_CREDENTIALS_JSON='{"type":"service_account","project_id":"...",...}'
   ```

   **Option 2: Using file path**
   ```bash
   # In .env file
   GA4_PROPERTY_ID=123456789
   GA4_CREDENTIALS_PATH=/path/to/service-account-key.json
   ```

7. **Grant Service Account Access:**
   - In Google Analytics, go to Admin → Property Access Management
   - Click "Add users"
   - Enter service account email (from JSON: `client_email`)
   - Select "Viewer" role
   - Click "Add"

### With Testing (Optional)

For running integration and visual tests locally:

```bash
# In .env file
PLAYWRIGHT_BASE_URL=http://localhost:4000

# Or let scripts auto-configure it:
npm run test:integration  # Automatically starts server and sets URL
```

## GitHub Actions Setup

### Required Secrets

No secrets are required for basic CI/CD. The following are optional:

| Secret Name | Purpose | How to Get | Required? |
|-------------|---------|------------|-----------|
| `CODECOV_TOKEN` | Coverage reporting | [Codecov.io](https://codecov.io) after linking repo | No |

### Adding Secrets to GitHub

1. **Navigate to Repository Settings:**
   - Go to your repository on GitHub
   - Click "Settings" tab
   - Select "Secrets and variables" → "Actions"

2. **Add New Secret:**
   - Click "New repository secret"
   - Enter secret name (e.g., `CODECOV_TOKEN`)
   - Paste secret value
   - Click "Add secret"

3. **Verify in Workflow:**
   - Secrets are automatically available in workflows
   - Access via `${{ secrets.SECRET_NAME }}`

### Codecov Setup

```bash
# 1. Go to https://codecov.io
# 2. Sign in with GitHub
# 3. Add repository: DiogoRibeiro7/analytics-blog-jekyll
# 4. Copy repository upload token

# 5. Add to GitHub Secrets:
#    Name: CODECOV_TOKEN
#    Value: <your_codecov_token>

# 6. Coverage reports upload automatically
```

## Analytics Configuration

### Google Analytics 4 Dashboard

The analytics dashboard plugin fetches real-time data from GA4 and displays it on your site.

#### Prerequisites

- Google Cloud Project with billing enabled (free tier available)
- Google Analytics 4 property
- Service account with Analytics API access

#### Step-by-Step Setup

**1. Enable GA4 Tracking Code:**

```yaml
# _config.yml
google_analytics: "G-XXXXXXXXXX"  # Your GA4 measurement ID
```

**2. Configure Analytics Dashboard:**

```yaml
# _config.yml
analytics:
  enabled: true
  ga4_property_id: "123456789"  # Or use GA4_PROPERTY_ID env var
  # ga4_credentials_path: "path/to/key.json"  # Or use env vars
  cache_duration: 3600  # Cache results for 1 hour
  dashboard:
    enabled: true
    metrics:
      - pageviews
      - sessions
      - bounce_rate
      - average_session_duration
```

**3. Set Environment Variables:**

See [Local Development Setup → With Analytics](#with-analytics-optional) above.

**4. Test Locally:**

```bash
# Build site with analytics enabled
JEKYLL_ENV=production bundle exec jekyll serve

# Check for errors in output
# Visit /analytics or any page with dashboard widget
```

#### Troubleshooting Analytics

**Error: "Missing GA4 credentials"**
- Verify `GA4_PROPERTY_ID` is set
- Verify `GA4_CREDENTIALS_JSON` or `GA4_CREDENTIALS_PATH` is set
- Check credentials JSON is valid

**Error: "Permission denied"**
- Ensure service account has "Viewer" role in GA4
- Check service account email is added to GA4 property

**Error: "API not enabled"**
- Enable Google Analytics Data API in Google Cloud Console

**No data showing:**
- Verify GA4 property has received traffic
- Check property ID matches GA4 property
- Ensure data is not filtered in GA4

## Testing Configuration

### Unit Tests

No environment variables required:

```bash
npm run test
npm run test:coverage
```

### Integration Tests

Playwright tests require a running server:

```bash
# Option 1: Auto-managed (recommended)
npm run test:integration

# Option 2: Manual server
bundle exec jekyll serve &
PLAYWRIGHT_BASE_URL=http://localhost:4000 npx playwright test

# Option 3: Use pre-built site
npx http-server _site -p 4173 &
PLAYWRIGHT_BASE_URL=http://127.0.0.1:4173 npx playwright test
```

### Continuous Integration

Tests run automatically in GitHub Actions:

- **Unit tests**: Always run
- **Integration tests**: Run on develop branch

## Security Best Practices

### DO

✅ **Use `.env` for local secrets**
```bash
# .env (gitignored)
GA4_CREDENTIALS_JSON='{"type":"service_account",...}'
```

✅ **Use GitHub Secrets for CI/CD**
- Store in repository settings → Secrets
- Never commit to code

✅ **Use minimal permissions**
- Service accounts: Viewer role only
- API keys: Restrict to necessary scopes

✅ **Rotate credentials regularly**
- Create new service account keys
- Update GitHub Secrets
- Delete old credentials

✅ **Use read-only access**
- Analytics: Viewer role (read-only)
- Never grant write access

### DON'T

❌ **Never commit secrets to git**
```bash
# BAD - Don't do this!
git add .env
git commit -m "Add config"  # .env will be exposed!
```

❌ **Never hardcode in _config.yml**
```yaml
# BAD - Don't do this!
analytics:
  ga4_credentials_path: "/Users/you/secret-key.json"  # Will be committed!
```

❌ **Never log secrets**
```ruby
# BAD - Don't do this!
puts "Credentials: #{ENV['GA4_CREDENTIALS_JSON']}"  # Will appear in logs!
```

❌ **Never use overly permissive roles**
```bash
# BAD - Don't do this!
# Granting "Editor" or "Owner" when "Viewer" is sufficient
```

### Verify Security

```bash
# Check .env is gitignored
grep -q "^\.env$" .gitignore && echo "✓ Safe" || echo "✗ NOT SAFE!"

# Scan for committed secrets (requires git-secrets)
git secrets --scan

# Check for hardcoded credentials
grep -r "service_account" --include="*.yml" --include="*.rb" .
```

## Troubleshooting

### Environment Variables Not Loading

**Problem**: Environment variables set in `.env` are not being read.

**Solutions**:
- Jekyll doesn't load `.env` by default. Access via `ENV['VAR_NAME']` in plugins.
- For local development, use:
  ```bash
  export $(cat .env | xargs) && bundle exec jekyll serve
  ```
- Or use a `.envrc` with [direnv](https://direnv.net/)
- For GitHub Actions, use repository secrets (not `.env`)

### Analytics Dashboard Not Working

**Problem**: Dashboard shows "Configuration error" or "No data"

**Checklist**:
1. Verify `JEKYLL_ENV=production` (dashboard disabled in development by default)
2. Check `GA4_PROPERTY_ID` is set
3. Verify credentials are valid JSON
4. Confirm service account has access to GA4 property
5. Enable Google Analytics Data API in Cloud Console
6. Check Jekyll build output for errors

### Playwright Tests Failing

**Problem**: `PLAYWRIGHT_BASE_URL is not set` error

**Solutions**:
- Use helper script: `npm run test:integration` (auto-configures)
- Or manually set:
  ```bash
  export PLAYWRIGHT_BASE_URL=http://localhost:4000
  npx playwright test
  ```
- In CI, it's set automatically in workflow files

### GitHub Actions Failing

**Problem**: Workflows fail with "Secret not found" or permission errors

**Solutions**:
1. **Check secret names match**:
   - Workflow uses: `${{ secrets.CODECOV_TOKEN }}`
   - Secret name must be exactly: `CODECOV_TOKEN`

2. **Verify secret is set**:
   - Go to Settings → Secrets and variables → Actions
   - Confirm secret exists

3. **Check permissions**:
   - Workflow needs: `contents: read`, `pages: write`, `id-token: write`
   - Verify in workflow file

4. **Optional secrets**:
   - `CODECOV_TOKEN` is optional
   - Workflows handle missing secrets gracefully

## Advanced Configuration

### Multiple Environments

Use different `.env` files for different environments:

```bash
# .env.development
JEKYLL_ENV=development
PLAYWRIGHT_BASE_URL=http://localhost:4000

# .env.production
JEKYLL_ENV=production
GA4_PROPERTY_ID=123456789

# .env.test
JEKYLL_ENV=test
NODE_ENV=test
PLAYWRIGHT_BASE_URL=http://127.0.0.1:4173
```

Load with:
```bash
# Development
export $(cat .env.development | xargs) && bundle exec jekyll serve

# Production build
export $(cat .env.production | xargs) && bundle exec jekyll build

# Testing
export $(cat .env.test | xargs) && npm run test:integration
```

### Using direnv

[direnv](https://direnv.net/) automatically loads `.envrc` when entering directory:

1. **Install direnv:**
   ```bash
   # macOS
   brew install direnv

   # Linux (Ubuntu)
   sudo apt install direnv
   ```

2. **Add to shell rc file:**
   ```bash
   # ~/.bashrc or ~/.zshrc
   eval "$(direnv hook bash)"  # or zsh
   ```

3. **Create `.envrc`:**
   ```bash
   # .envrc (same as .env, but auto-loads)
   export GA4_PROPERTY_ID=123456789
   export CODECOV_TOKEN=your_token
   ```

4. **Allow directory:**
   ```bash
   direnv allow .
   ```

Now environment variables load automatically when you `cd` into the directory!

### GitHub CLI Integration

Use GitHub CLI to manage secrets:

```bash
# Install gh CLI: https://cli.github.com/

# Set secret
gh secret set CODECOV_TOKEN

# List secrets
gh secret list

# Remove secret
gh secret remove CODECOV_TOKEN
```

## Summary

- **No environment variables required** for basic usage
- **Use `.env` locally**, **GitHub Secrets for CI/CD**
- **Never commit secrets** to version control
- **Analytics and testing are optional** features
- **Follow security best practices** (minimal permissions, rotation)

For more information:
- [Configuration Reference](configuration-reference.md)
- [Security Policy](../SECURITY.md)
- [Contributing Guidelines](../CONTRIBUTING.md)

**Questions?** Open a [GitHub Discussion](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/discussions)!
