# Input Validation Reference

> **Version**: 1.0.0
> **Last Updated**: 2026-01-30
> **Scope**: Comprehensive input validation rules and error handling

## Overview

OSXCleaner implements comprehensive input validation to prevent security vulnerabilities and improve error handling across all entry points: CLI commands, FFI boundaries, and server APIs.

## Validation Layers

```
┌─────────────────────────────────────────────┐
│ Layer 1: CLI Command Validation            │
│ - Path arguments                            │
│ - Command options                           │
│ - Configuration parameters                  │
└─────────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────┐
│ Layer 2: Swift Application Validation      │
│ - PathValidator                             │
│ - ConfigValidator                           │
│ - Business logic validation                 │
└─────────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────┐
│ Layer 3: FFI Boundary Validation           │
│ - Null byte detection                       │
│ - UTF-8 validation                          │
│ - Length limits                             │
└─────────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────┐
│ Layer 4: Rust Core Validation              │
│ - File system operations                    │
│ - Safety checks                             │
└─────────────────────────────────────────────┘
```

## Path Validation Rules

### PathValidator

Validates file paths to prevent security vulnerabilities and ensure path safety.

| Rule | Description | Error Code | Example |
|------|-------------|------------|---------|
| **Non-empty** | Path must not be empty or whitespace | `EMPTY_PATH` | ❌ `""`, `"   "` |
| **No null bytes** | Path must not contain `\0` characters | `NULL_BYTE_IN_PATH` | ❌ `"path\0malicious"` |
| **Length limit** | Path must be ≤ 1024 characters | `PATH_TOO_LONG` | ❌ 2000-char path |
| **Canonical form** | Path is resolved to absolute canonical form | N/A | ✅ `/../tmp` → `/tmp` |
| **System protection** | System paths are blocked | `SYSTEM_PATH_NOT_ALLOWED` | ❌ `/System`, `/dev` |
| **Existence check** | Path must exist on filesystem (optional) | `PATH_NOT_FOUND` | ❌ `/nonexistent` |
| **Readability** | Path must be readable (optional) | `PATH_NOT_READABLE` | ❌ No permissions |

### Protected Paths

These paths are **never** allowed for cleanup operations:

```swift
System Paths (Critical):
/System                    // macOS system files
/Library/System           // System libraries
/private/var/db           // System databases
/dev                      // Device files
/etc                      // System configuration
/bin                      // System binaries
/sbin                     // System admin binaries
/usr/bin                  // User binaries
/usr/sbin                 // Admin binaries
/var/db                   // Variable databases
/var/root                 // Root user home

Sensitive Paths (Warning):
/Users/Shared             // Shared user data
/Library/Keychains        // Security keychains
/Library/Security         // Security components
```

### Validation Options

PathValidator supports configurable validation options:

```swift
// Default: existence check, tilde expansion, no system paths
PathValidator.ValidationOptions.default

// Strict: all checks enabled
PathValidator.ValidationOptions.strict
  - checkExistence: true
  - checkReadability: true
  - allowSystemPaths: false
  - expandTilde: true

// Lenient: minimal checks (for configuration validation)
PathValidator.ValidationOptions.lenient
  - checkExistence: false
  - checkReadability: false
  - allowSystemPaths: false
  - expandTilde: true
```

### Examples

```swift
// ✅ Valid paths
try PathValidator.validate("/tmp")
try PathValidator.validate("~/Library/Caches")
try PathValidator.validate("/Users/john/Documents")

// ❌ Invalid paths
try PathValidator.validate("")
// → ValidationError.emptyPath

try PathValidator.validate("/System/Library")
// → ValidationError.systemPathNotAllowed("/System/Library")

try PathValidator.validate("path\0malicious")
// → ValidationError.nullByteInPath

try PathValidator.validate(String(repeating: "a", count: 2000))
// → ValidationError.pathTooLong(2000, maximum: 1024)
```

## Configuration Validation Rules

### ConfigValidator

Validates `CleanerConfiguration` and `MDMConfiguration` settings.

| Parameter | Valid Range | Error Code | Example |
|-----------|-------------|------------|---------|
| **cleanupLevel** | 1-4 (light, normal, deep, system) | `INVALID_CLEANUP_LEVEL` | ❌ `5` |
| **customPaths** | Valid paths (via PathValidator) | `EMPTY_PATH`, `PATH_TOO_LONG`, etc. | ❌ `[""]` |
| **dryRun + system** | Cannot combine system level with dry-run | `CONFLICTING_OPTIONS` | ❌ `system + dryRun` |
| **MDM serverURL** | Must use HTTPS protocol | `INSECURE_MDM_URL` | ❌ `http://example.com` |
| **syncInterval** | Must be positive (> 0) | `INVALID_CHECK_INTERVAL` | ❌ `-1`, `0` |
| **requestTimeout** | Must be positive (> 0) | `INVALID_CHECK_INTERVAL` | ❌ `-1` |

### Examples

```swift
// ✅ Valid configuration
let config = CleanerConfiguration(
    cleanupLevel: .normal,
    dryRun: false,
    specificPaths: ["~/Library/Caches"]
)
try ConfigValidator.validate(config)

// ❌ Invalid: system level with dry-run
let config = CleanerConfiguration(
    cleanupLevel: .system,
    dryRun: true
)
try ConfigValidator.validate(config)
// → ValidationError.conflictingOptions("System-level cleanup should not be used with dry-run mode")

// ❌ Invalid: insecure MDM URL
let mdm = MDMConfiguration(
    provider: .jamf,
    serverURL: URL(string: "http://example.com")!,  // HTTP not HTTPS
    requestTimeout: 30,
    syncInterval: 300
)
try ConfigValidator.validate(mdm)
// → ValidationError.insecureMDMURL
```

## FFI Validation Rules

### RustBridge Validation

Validates strings before crossing the FFI boundary to Rust.

| Rule | Limit | Error Code | Rationale |
|------|-------|------------|-----------|
| **No null bytes** | N/A | `INVALID_FFI_STRING` | Prevents C string corruption |
| **Valid UTF-8** | N/A | `INVALID_FFI_STRING` | Ensures Rust can handle strings safely |
| **Length limit** | ≤ 4096 characters | `INVALID_FFI_STRING` | Prevents DoS attacks |

### Examples

```swift
// ✅ Valid FFI strings
try RustBridge.shared.analyzePath("/tmp")
try RustBridge.shared.analyzePath("~/Library/한글경로")  // Unicode OK

// ❌ Invalid FFI strings
try RustBridge.shared.analyzePath("/tmp\0malicious")
// → RustBridgeError.invalidString("String contains null byte")

try RustBridge.shared.analyzePath(String(repeating: "a", count: 5000))
// → RustBridgeError.invalidString("String exceeds maximum length (4096 characters)")
```

## CLI Command Validation

### Command-Line Arguments

All CLI commands validate their arguments before execution.

| Command | Validation | Error Handling |
|---------|-----------|----------------|
| `clean` | Path validation, cleanup level range, conflicting options | Early exit with error message |
| `analyze` | Path validation | Early exit with error message |
| `config` | ConfigValidator for all settings | Early exit with error message |
| `server` | Path validation for data directory | Early exit with error message |
| `policy` | Path validation for policy files | Early exit with error message |

### Example Command Validation

```bash
# ✅ Valid command
$ osxcleaner clean ~/Library/Caches --level normal
Analyzing caches...

# ❌ Invalid: empty path
$ osxcleaner clean ""
Error: Path cannot be empty
Recovery: Provide a valid file path

# ❌ Invalid: system path
$ osxcleaner clean /System/Library
Error: Access to system path not allowed: /System/Library
Recovery: Choose a path outside system directories (/System, /Library/System, /dev, /etc, /private/var/db)

# ❌ Invalid: null byte
$ osxcleaner clean "path\0inject"
Error: Path contains invalid null byte character
Recovery: Remove null byte characters from the path

# ❌ Invalid: conflicting options
$ osxcleaner clean ~/Library/Caches --level system --dry-run
Error: Conflicting options: System-level cleanup should not be used with dry-run mode
Recovery: Remove conflicting command-line options
```

## Error Handling

### Error Response Format

All validation errors conform to `LocalizedError` protocol:

```swift
public enum ValidationError: LocalizedError {
    case emptyPath
    case nullByteInPath
    case pathNotFound(String)
    case systemPathNotAllowed(String)
    case pathNotReadable(String)
    case pathTooLong(Int, maximum: Int)
    case invalidCleanupLevel(Int32)
    case conflictingOptions(String)
    case insecureMDMURL
    case invalidCheckInterval(Int)
    case missingRequiredField(String)
    case invalidFFIString(String)
    case ffiStringTooLong(Int, maximum: Int)
}
```

### Error Messages

Each error provides:
- **errorDescription**: Human-readable error message
- **recoverySuggestion**: Actionable guidance for fixing the error

```swift
let error = ValidationError.systemPathNotAllowed("/System/Library")

print(error.errorDescription)
// "Access to system path not allowed: /System/Library"

print(error.recoverySuggestion)
// "Choose a path outside system directories (/System, /Library/System, /dev, /etc, /private/var/db)"
```

## API Reference

### PathValidator

```swift
/// Validates and canonicalizes a file path
public static func validate(
    _ path: String,
    options: ValidationOptions = .default
) throws -> URL

/// Validates a path and returns the string representation
public static func validatePath(
    _ path: String,
    options: ValidationOptions = .default
) throws -> String

/// Validates multiple paths at once
public static func validateAll(
    _ paths: [String],
    options: ValidationOptions = .default
) throws -> [URL]

/// Validates multiple paths, collecting all errors
public static func validateAllWithErrors(
    _ paths: [String],
    options: ValidationOptions = .default
) -> (urls: [URL], errors: [(path: String, error: ValidationError)])

/// Checks if a path is within system-protected areas
public static func isSystemProtectedPath(_ path: String) -> Bool

/// Checks if a path is a sensitive user path
public static func isSensitivePath(_ path: String) -> Bool
```

### ConfigValidator

```swift
/// Validates a CleanerConfiguration instance
public static func validate(_ config: CleanerConfiguration) throws

/// Validates an MDMConfiguration instance
public static func validate(_ config: MDMConfiguration) throws

/// Validates multiple configurations
public static func validateAll(_ configs: [CleanerConfiguration]) throws

/// Validates multiple configurations, collecting all errors
public static func validateAllWithErrors(
    _ configs: [CleanerConfiguration]
) -> [ValidationError]
```

## Performance Considerations

### Validation Performance

- **PathValidator**: O(1) for most checks, O(n) for path string scanning
- **ConfigValidator**: O(n×m) where n = number of paths, m = path length
- **FFI Validation**: O(n) where n = string length
- **Minimal overhead**: Validation adds <1ms per operation in typical cases

### Optimization Tips

1. **Use lenient options** when existence checking is not needed
2. **Batch validation** for multiple paths using `validateAll()`
3. **Cache validated paths** if reused frequently
4. **Fail fast** - validation happens before expensive operations

## Security Considerations

### Attack Prevention

| Attack Vector | Mitigation | Validation Layer |
|---------------|-----------|------------------|
| **Path traversal** (`../../../etc/passwd`) | Canonicalization + system path blocking | PathValidator |
| **Null byte injection** (`path\0malicious`) | Null byte detection | PathValidator, FFI |
| **Directory traversal** (symbolic links) | Path standardization | PathValidator |
| **DoS via long strings** | Length limits | PathValidator, FFI |
| **Invalid UTF-8** | UTF-8 validation | FFI |
| **Insecure protocols** | HTTPS enforcement | ConfigValidator |

### Threat Model

**Protected Against**:
- Malicious user input via CLI
- Configuration file tampering
- FFI memory corruption
- Path traversal attacks
- Denial of service via resource exhaustion

**Not Protected Against** (out of scope):
- Network attacks (server TLS handles this)
- Physical access attacks
- Kernel-level exploits

## Testing

### Test Coverage

| Module | Test File | Tests | Coverage |
|--------|-----------|-------|----------|
| PathValidator | PathValidatorTests.swift | 28 tests | Comprehensive |
| ConfigValidator | ConfigValidatorTests.swift | 20 tests | Comprehensive |
| FFI Validation | RustBridgeValidationTests.swift | 18 tests | Comprehensive |
| CLI Validation | CommandValidationTests.swift | 12 tests | Comprehensive |

### Running Tests

```bash
# Run all validation tests
swift test --filter Validation

# Run specific test suites
swift test --filter PathValidatorTests
swift test --filter ConfigValidatorTests
swift test --filter RustBridgeValidationTests
swift test --filter CommandValidationTests

# With verbose output
swift test --filter Validation --verbose
```

### Example Test Output

```
Test Suite 'PathValidatorTests' passed at 2026-01-30 13:28:33.239
  Executed 28 tests, with 0 failures (0 unexpected) in 0.015 seconds

Test Suite 'ConfigValidatorTests' passed at 2026-01-30 13:28:41.909
  Executed 20 tests, with 0 failures (0 unexpected) in 0.006 seconds

Test Suite 'RustBridgeValidationTests' passed at 2026-01-30 13:34:18.893
  Executed 18 tests, with 0 failures (0 unexpected) in 0.025 seconds

Test Suite 'CommandValidationTests' passed at 2026-01-30 13:35:36.125
  Executed 12 tests, with 0 failures (0 unexpected) in 0.005 seconds
```

## References

- **Implementation**: `Sources/OSXCleanerKit/Validation/`
- **Tests**: `Tests/OSXCleanerKitTests/`
- **Security**: See `docs/SECURITY.md` for security rationale
- **API Documentation**: See DocC documentation for detailed API reference

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-30 | Initial documentation |

---

**License**: BSD-3-Clause
**Copyright**: © 2021-2025
