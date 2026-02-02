# Security Policy

## Supported Versions

We actively support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

If you discover a security vulnerability in OSX Cleaner, please report it by emailing:

**security@kcenon.com**

You should receive a response within 48 hours. If for some reason you do not, please follow up via email to ensure we received your original message.

Please include the following information in your report:

- Type of vulnerability
- Full paths of source file(s) related to the manifestation of the vulnerability
- The location of the affected source code (tag/branch/commit or direct URL)
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

We will acknowledge your email within 48 hours and send a more detailed response within 96 hours indicating the next steps in handling your report.

## Security Scanning

This project uses comprehensive automated security scanning:

### Continuous Scanning

- **cargo-audit**: Daily Rust dependency vulnerability audits
- **cargo-deny**: License compliance and banned dependency checks
- **Semgrep**: Static Application Security Testing (SAST) on every push
- **Gitleaks**: Secret detection in commits and history
- **SwiftLint**: Security-focused linting rules for Swift code
- **Dependabot**: Automated dependency update pull requests

### Scanning Schedule

| Scanner | Frequency | Trigger |
|---------|-----------|---------|
| cargo-audit | Daily at 2 AM UTC | Scheduled + Every push |
| cargo-deny | Every push/PR | Push/PR |
| Semgrep | Every push/PR | Push/PR |
| Gitleaks | Every push/PR | Push/PR |
| SwiftLint | Every push/PR | Push/PR |
| Dependabot | Weekly (Monday 2 AM KST) | Scheduled |

### Build Failure Conditions

The CI pipeline will fail if:

- Any known vulnerability found in dependencies (cargo-audit)
- GPL/AGPL licensed dependencies or yanked crates (cargo-deny)
- High or Critical security findings (Semgrep)
- Any secrets detected in commits (Gitleaks)
- Security rule violations in Swift code (SwiftLint)

## Security Standards

### Organizational Requirements

As per organizational security policy (`/Library/Application Support/ClaudeCode/CLAUDE.md`):

- All commits must be signed with GPG keys
- No secrets, API keys, or credentials in source code
- Security review required for authentication-related changes
- All dependencies must pass security scanning
- No high/critical security vulnerabilities allowed

### Code Security Practices

1. **Memory Safety**
   - Memory-safe FFI implementation between Rust and Swift
   - Proper error handling at language boundaries
   - Validated pointers and data structures

2. **Input Validation**
   - All user inputs validated before processing
   - Protected system paths verified
   - File operations sandboxed appropriately

3. **Cloud Sync Detection**
   - Safe detection of cloud storage providers
   - Proper handling of symlinks and aliases
   - No modification of protected directories

4. **Dependency Management**
   - Regular dependency audits
   - License compliance verification
   - Minimal dependency footprint

## Security Features

### Current Implementation

- **Memory-safe Rust core**: Core logic implemented in Rust for memory safety
- **Safe FFI boundary**: Validated data passing between Rust and Swift
- **Input validation**: Comprehensive path and argument validation
- **Protected paths**: System-critical paths are never modified
- **Cloud storage detection**: Safe identification without modification
- **Error handling**: Proper error propagation across FFI boundary

### Planned Enhancements

- Integration with macOS Gatekeeper
- Code signing for release binaries
- Notarization for distribution
- Sandboxing for sensitive operations

## Disclosure Policy

When we receive a security bug report, we will:

1. Confirm the problem and determine affected versions
2. Audit code to find similar problems
3. Prepare fixes for all supported versions
4. Release patches as soon as possible

## Security Acknowledgments

We appreciate the security research community's efforts. Contributors who responsibly disclose security vulnerabilities will be acknowledged in our release notes (unless they prefer to remain anonymous).

## Contact

For security-related inquiries that are not vulnerability reports, please contact:

- **Email**: security@kcenon.com
- **GitHub**: @kcenon

## Additional Resources

- [Contributing Guidelines](CONTRIBUTING.md)
- [Code of Conduct](CODE_OF_CONDUCT.md)
- [Security Scanning Workflow](.github/workflows/security.yml)
