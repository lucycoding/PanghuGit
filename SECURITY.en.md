# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 1.1.x   | ✅ |
| 1.0.x   | ❌ |
| < 1.0   | ❌ |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub Issues.**

If you discover a security vulnerability, please report it privately via:

- **GitHub Security Advisory**: Submit via [Security Advisories](https://github.com/lucycoding/PanghuGit/security/advisories/new)
- **GitHub Issue**: Create a [Private Issue](https://github.com/lucycoding/PanghuGit/issues/new?template=bug_report.yml) with `[Security]` in the title

### What to Include

Please provide the following information:

1. Vulnerability type (e.g., code execution, information disclosure, privilege escalation)
2. Affected versions
3. Steps to reproduce
4. Potential impact
5. Suggested fix (if possible)

### Response Time

- **Acknowledgment**: Within 48 hours
- **Initial assessment**: Within 7 days
- **Fix release**: Typically within 30 days, depending on severity

### Disclosure Policy

- Please do not publicly disclose vulnerability details before a fix is released
- We will credit reporters after the fix is released (unless you request anonymity)

## Security Architecture

Key security design points of PanghuGit:

- **Finder Sync Extension runs in a sandbox** and cannot directly execute Git commands or access the file system
- **Main App is non-sandboxed** (required for Git operations), but only receives extension requests via `panghugit://` URL Scheme
- **App Group communication** only shares settings data, no sensitive information is transmitted
- **Git credentials** are managed by git itself (credential.helper); PanghuGit does not store or handle passwords
- **No network services**: PanghuGit does not open any network ports or services
