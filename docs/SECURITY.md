# Security Documentation

> **Version**: 1.0.0
> **Last Updated**: 2026-01-30
> **Scope**: Security architecture and practices for OSXCleaner

## Overview

OSXCleaner implements defense-in-depth security through multiple layers of validation, sanitization, and protection mechanisms. This document outlines our security architecture, threat model, and mitigation strategies.

## Security Architecture

```
┌──────────────────────────────────────────────────────────┐
│ Layer 1: User Input                                     │
│ - CLI arguments                                          │
│ - Configuration files                                    │
│ - API requests                                           │
└──────────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────────┐
│ Layer 2: Input Validation                               │
│ - PathValidator: Path safety checks                     │
│ - ConfigValidator: Configuration validation             │
│ - FFI Validator: String safety for FFI boundary         │
└──────────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────────┐
│ Layer 3: Business Logic                                 │
│ - Safety level calculation                              │
│ - Permission checks                                      │
│ - Policy enforcement                                     │
└──────────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────────┐
│ Layer 4: FFI Boundary                                   │
│ - Memory safety checks                                   │
│ - Type conversions                                       │
│ - Error handling                                         │
└──────────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────────┐
│ Layer 5: Rust Core                                      │
│ - File system operations (Rust safety guarantees)       │
│ - Atomic operations                                      │
│ - Error handling                                         │
└──────────────────────────────────────────────────────────┘
```

## Input Validation

### Defense-in-Depth Validation

OSXCleaner implements multiple layers of input validation to prevent security vulnerabilities:

#### Path Validation

**Purpose**: Prevent path traversal attacks, unauthorized file access, and directory traversal vulnerabilities.

**Implementation**: PathValidator module

**Security Measures**:

1. **Canonicalization**: Resolves symbolic links and removes `..` components
   ```swift
   // Attack: /tmp/../../../etc/passwd
   // Result: Canonicalized to /etc/passwd
   // Action: Rejected (system path)
   ```

2. **System Path Protection**: Blocks access to critical system directories
   ```swift
   Protected Paths:
   - /System           // macOS system files
   - /Library/System   // System libraries
   - /dev              // Device files
   - /etc              // System configuration
   - /bin, /sbin       // System binaries
   - /private/var/db   // System databases
   ```

3. **Null Byte Detection**: Prevents null byte injection attacks
   ```swift
   // Attack: "path\0malicious"
   // Result: Rejected immediately
   // Threat: Null bytes can truncate strings in C code
   ```

4. **Length Validation**: Prevents buffer overflows and DoS attacks
   ```swift
   // Maximum path length: 1024 characters (PATH_MAX on macOS)
   // Longer paths are rejected
   ```

**Security Benefits**:
- Prevents unauthorized access to system files
- Blocks path traversal attacks (e.g., `../../etc/passwd`)
- Stops null byte injection
- Mitigates DoS via extremely long paths

#### Configuration Validation

**Purpose**: Prevent invalid states, insecure configurations, and conflicting options.

**Implementation**: ConfigValidator module

**Security Measures**:

1. **HTTPS Enforcement**: MDM server URLs must use HTTPS
   ```swift
   // Attack: http://malicious.com (man-in-the-middle)
   // Result: Rejected
   // Required: https://secure.com
   ```

2. **Range Validation**: Cleanup levels constrained to valid range
   ```swift
   // Valid: 1-4 (light, normal, deep, system)
   // Invalid: 0, 5, -1, etc.
   ```

3. **Conflicting Option Detection**: Prevents dangerous combinations
   ```swift
   // Attack: system level + dry-run (could give false sense of security)
   // Result: Rejected
   // Rationale: System cleanup should be explicit, not dry-run
   ```

**Security Benefits**:
- Prevents man-in-the-middle attacks on MDM communication
- Ensures configuration integrity
- Stops invalid or dangerous option combinations

#### FFI Validation

**Purpose**: Ensure safe interaction with Rust core across FFI boundary.

**Implementation**: RustBridge `validateFFIString()` method

**Security Measures**:

1. **Null Byte Detection**: Prevents C string corruption
   ```swift
   // Attack: "path\0injection"
   // Result: Rejected before FFI call
   // Threat: Null bytes corrupt C strings, can bypass security checks
   ```

2. **UTF-8 Validation**: Ensures strings are valid UTF-8
   ```swift
   // Attack: Invalid UTF-8 sequences
   // Result: Rejected
   // Threat: Invalid UTF-8 can cause Rust panics
   ```

3. **Length Limit**: Prevents DoS attacks
   ```swift
   // Maximum FFI string length: 4096 characters
   // Prevents: Memory exhaustion, buffer overflows
   ```

**Security Benefits**:
- Maintains Rust memory safety guarantees
- Prevents FFI-related crashes and panics
- Stops DoS attacks via resource exhaustion

### Validation Checklist

Before any operation, OSXCleaner validates:

- [ ] **Paths**: Non-empty, no null bytes, canonical, within allowed boundaries, exists
- [ ] **Configuration**: Valid ranges, consistent options, required fields present
- [ ] **FFI Strings**: Valid UTF-8, no null bytes, reasonable length
- [ ] **CLI Arguments**: No conflicting options, valid enums, required args present
- [ ] **API Requests**: Schema validation, type checking, range validation

## Threat Model

### In-Scope Threats

| Threat | Likelihood | Impact | Mitigation |
|--------|-----------|--------|------------|
| **Path Traversal** | High | Critical | Canonicalization + system path blocking |
| **Null Byte Injection** | Medium | High | Null byte detection at all entry points |
| **Directory Traversal (symlinks)** | Medium | High | Path standardization |
| **DoS via Long Strings** | Medium | Medium | Length limits (1024 for paths, 4096 for FFI) |
| **Invalid UTF-8** | Low | Medium | UTF-8 validation before FFI |
| **Insecure Protocols** | Medium | High | HTTPS enforcement for MDM |
| **Configuration Tampering** | Medium | High | Configuration validation |
| **Unauthorized File Access** | High | Critical | System path protection |

### Out-of-Scope Threats

| Threat | Reason |
|--------|--------|
| Network attacks | Handled by TLS/HTTPS layers |
| Physical access | Assumes trusted physical environment |
| Kernel exploits | Beyond application scope |
| Time-of-check-time-of-use (TOCTOU) | Mitigated by Rust core's atomic operations |

### Attack Surface

#### Entry Points

1. **CLI Interface**
   - Input: Command-line arguments
   - Validation: PathValidator, ConfigValidator
   - Risk: Path traversal, invalid options

2. **Configuration Files**
   - Input: JSON/YAML configuration
   - Validation: ConfigValidator
   - Risk: Tampered configuration, insecure settings

3. **API Endpoints** (if server mode enabled)
   - Input: HTTP requests
   - Validation: Request schema validation
   - Risk: Injection attacks, invalid payloads

4. **FFI Boundary**
   - Input: Swift strings to Rust
   - Validation: FFI string validation
   - Risk: Memory corruption, panics

#### Privileged Operations

1. **File Deletion**: Requires user confirmation (except in non-interactive mode)
2. **System Cleanup**: Restricted to safe cleanup levels
3. **Configuration Changes**: Validated before applying

## Security Best Practices

### For Users

1. **Verify Paths**: Always check paths before cleanup operations
2. **Use Dry-Run**: Test with `--dry-run` before actual cleanup
3. **Review Logs**: Check logs after cleanup to verify actions
4. **Backup Important Data**: Keep backups before system-level cleanup
5. **HTTPS Only**: Always use HTTPS for MDM server URLs

### For Developers

1. **Validate All Inputs**: Never trust user input
2. **Use PathValidator**: Always validate paths before file operations
3. **Fail Fast**: Reject invalid input immediately
4. **Clear Error Messages**: Provide actionable recovery suggestions
5. **Test Edge Cases**: Include fuzzing and boundary tests
6. **Document Security**: Note security rationale for validation rules

### For Administrators

1. **Policy Enforcement**: Use MDM policies to control cleanup levels
2. **Audit Logs**: Enable audit logging for compliance
3. **Secure Configuration**: Store configuration in secure locations
4. **Regular Updates**: Keep OSXCleaner updated for security patches
5. **Monitor Usage**: Track cleanup operations for anomalies

## Security Testing

### Validation Testing

All validation modules have comprehensive test coverage:

| Module | Tests | Coverage | Status |
|--------|-------|----------|--------|
| PathValidator | 28 tests | Comprehensive | ✅ Passing |
| ConfigValidator | 20 tests | Comprehensive | ✅ Passing |
| FFI Validation | 18 tests | Comprehensive | ✅ Passing |
| CLI Validation | 12 tests | Comprehensive | ✅ Passing |

### Security Test Cases

```swift
// Path Traversal
testValidate_PathTraversalAttempt_Canonicalizes()
testValidate_SystemPath_ThrowsError()

// Null Byte Injection
testValidate_NullByteInMiddle_ThrowsError()
testFFIValidator_NullByte_ThrowsError()

// DoS Prevention
testValidate_ExcessivelyLongPath_ThrowsError()
testFFIValidator_TooLong_ThrowsError()

// Fuzzing Tests
testMultipleNullBytes_AllRejected()
testVeryLongStrings_AllRejected()
```

### Running Security Tests

```bash
# Run all validation tests
swift test --filter Validation

# Run specific security tests
swift test --filter testValidate_PathTraversalAttempt
swift test --filter testNullByte
swift test --filter testTooLong

# Verbose output for debugging
swift test --filter Validation --verbose
```

## Incident Response

### Security Vulnerability Reporting

If you discover a security vulnerability:

1. **Do NOT** open a public GitHub issue
2. Email security details to: [security contact]
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if available)

### Response Timeline

- **24 hours**: Acknowledge receipt
- **72 hours**: Initial assessment
- **30 days**: Fix and patch release
- **Disclosure**: After patch is deployed

## Compliance

### Security Standards

OSXCleaner follows these security standards:

- **OWASP Top 10**: Addresses injection, broken access control, etc.
- **CWE/SANS Top 25**: Mitigates common software errors
- **NIST Cybersecurity Framework**: Identify, Protect, Detect, Respond, Recover

### Audit Trail

All cleanup operations are logged with:
- Timestamp (ISO 8601 format)
- User/agent identity
- Operation type (analyze, clean, etc.)
- Cleanup level
- Paths affected
- Bytes freed
- Success/failure status

## References

- **Input Validation**: See `docs/VALIDATION.md`
- **FFI Security**: See `docs/reference/ffi-guide.md`
- **API Security**: See API documentation
- **Audit Logging**: See `docs/reference/audit-logging.md`

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-30 | Initial security documentation with input validation |

---

**License**: BSD-3-Clause
**Copyright**: © 2021-2025
