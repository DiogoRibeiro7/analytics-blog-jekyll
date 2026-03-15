# Security Policy

## Supported Versions

We actively support the following versions of DataLog Jekyll Theme with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 0.2.x   | :white_check_mark: |
| 0.1.x   | :x:                |
| < 0.1   | :x:                |

## Reporting a Vulnerability

We take the security of DataLog Jekyll Theme seriously. If you discover a security vulnerability, please follow these steps:

### 1. DO NOT Open a Public Issue

Please **do not** report security vulnerabilities through public GitHub issues, discussions, or pull requests.

### 2. Submit a Private Report

Instead, please report security vulnerabilities using one of these methods:

**Preferred Method: GitHub Security Advisories**
- Navigate to the [Security tab](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/security/advisories/new)
- Click "Report a vulnerability"
- Fill in the details of the vulnerability

**Alternative Method: Email**
- Send an email to: **dfr@esmad.ipp.pt**
- Use the subject line: `[SECURITY] DataLog Theme Vulnerability Report`
- Include the details outlined in the "What to Include" section below

### 3. What to Include

Please provide as much information as possible to help us understand and reproduce the issue:

- **Type of vulnerability** (e.g., XSS, CSRF, SQL injection, path traversal, etc.)
- **Affected component(s)** (plugin, layout, script, etc.)
- **Affected version(s)**
- **Step-by-step instructions** to reproduce the vulnerability
- **Proof of concept** or exploit code (if possible)
- **Potential impact** of the vulnerability
- **Suggested fix** (if you have one)
- **Your contact information** for follow-up questions

### 4. What to Expect

After you submit a vulnerability report:

- **Within 48 hours**: We'll acknowledge receipt of your report
- **Within 7 days**: We'll provide an initial assessment and expected timeline
- **Regular updates**: We'll keep you informed as we investigate and develop a fix
- **Credit**: With your permission, we'll acknowledge your contribution in the security advisory

### 5. Responsible Disclosure

We kindly ask that you:

- **Give us reasonable time** to address the vulnerability before public disclosure (typically 90 days)
- **Make a good faith effort** to avoid privacy violations, data destruction, and service disruption
- **Do not access or modify** data that doesn't belong to you
- **Only test against your own installation** of the theme

## Security Best Practices for Users

### Content Security Policy (CSP)

DataLog includes automated CSP generation. To enable:

1. Set `security.enable_csp: true` in `_config.yml`
2. Review generated CSP headers in your deployment
3. Test thoroughly, especially if using custom scripts

### Environment Variables and Secrets

**NEVER commit sensitive data to version control:**

- Use `.env` files (already gitignored)
- Store secrets in GitHub Secrets for CI/CD
- Use environment variables for API keys
- Rotate credentials regularly

**Required secrets:**
- `GA4_CREDENTIALS_JSON` - Google Analytics service account
- `PERCY_TOKEN` - Visual regression testing
- `CODECOV_TOKEN` - Code coverage reporting

See `.env.example` for complete configuration guide.

### Dependency Management

Keep dependencies up to date:

```bash
# Update Ruby dependencies
bundle update

# Update Node.js dependencies
npm update

# Check for known vulnerabilities
bundle audit
npm audit
```

### Input Validation

When adding custom plugins or modifications:

- **Sanitize all user input** before rendering
- **Escape HTML output** to prevent XSS
- **Validate file paths** to prevent path traversal
- **Use parameterized queries** if interacting with databases

### Plugin Development

If developing custom plugins:

- Review [PLUGIN_DEVELOPMENT.md](PLUGIN_DEVELOPMENT.md) for security guidelines
- Avoid executing arbitrary code from user input
- Validate and sanitize all external data
- Use Jekyll's built-in filters for escaping (e.g., `escape`, `xml_escape`)

## Known Security Considerations

### Third-Party Dependencies

DataLog integrates with external services:

- **Google Analytics**: Ensure proper data handling policies
- **Binder/Colab**: Notebooks may execute arbitrary code - review before linking
- **CDN Resources**: Use Subresource Integrity (SRI) hashes (automatically generated)
- **Comment Systems**: Configure Giscus with appropriate moderation

### Notebook Execution

Jupyter notebooks can contain executable code:

- **Review notebooks** from untrusted sources before publishing
- **Disable automatic execution** in production
- **Use Binder/Colab links** for interactive execution instead of server-side

### API Credentials

Google Analytics dashboard plugin requires service account credentials:

- Use **dedicated service accounts** with minimal permissions
- Enable **read-only access** to analytics data
- **Rotate credentials** if compromised
- Store in **environment variables**, not config files

## Security Testing

DataLog includes security testing scripts:

```bash
# Run security validation tests
ruby scripts/test_security.rb

# Check Content Security Policy generation
ruby scripts/test_csp.rb

# Validate dependency security
bundle audit
npm audit
```

## Security Features

DataLog includes several built-in security features:

1. **Automated CSP Generation**: Content Security Policy headers to prevent XSS
2. **SRI Integrity Hashes**: Subresource Integrity for CDN resources
3. **Sanitized Output**: HTML escaping in templates
4. **Path Validation**: Safe file path handling in plugins
5. **HTTPS Enforcement**: Canonical URLs use HTTPS
6. **Privacy-Focused Analytics**: IP anonymization enabled by default

## Security Updates

Security updates will be:

- **Released promptly** after verification
- **Announced via GitHub Security Advisories**
- **Tagged with SECURITY label** in releases
- **Documented in CHANGELOG.md**

Subscribe to repository releases to stay informed.

## Questions?

For security-related questions that aren't sensitive:

- Open a [GitHub Discussion](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/discussions)
- Check existing [Security Advisories](https://github.com/DiogoRibeiro7/analytics-blog-jekyll/security/advisories)

For sensitive security concerns, always use private reporting channels.

## Acknowledgments

We appreciate the security research community's efforts to responsibly disclose vulnerabilities. Contributors will be acknowledged (with permission) in:

- Security advisories
- CHANGELOG.md
- GitHub releases

Thank you for helping keep DataLog and our users safe!
