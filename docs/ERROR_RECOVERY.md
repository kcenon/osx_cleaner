# Error Recovery Guide

> **Version**: 1.0.0
> **Last Updated**: 2026-02-02
> **Purpose**: Comprehensive guide to error recovery mechanisms in OSX Cleaner

## Overview

OSX Cleaner implements comprehensive error recovery mechanisms to ensure reliable operation even in the face of transient failures. The system uses automatic retry logic, fallback modes, and graceful degradation to maintain functionality under adverse conditions.

## Architecture

### Recovery Layers

```
┌─────────────────────────────────────────────────┐
│ Application Layer                               │
│  - Graceful degradation in CleanerService      │
│  - Partial failure handling                     │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ FFI Layer                                       │
│  - Rust core initialization retry              │
│  - FFI operation retry for transient errors    │
│  - Swift-only fallback mode                    │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ Network Layer                                   │
│  - Exponential backoff with jitter             │
│  - Configurable retry policies                 │
│  - HTTP Retry-After header support             │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ File System Layer                               │
│  - File operation retry for locks              │
│  - Continue on partial cleanup failures        │
│  - Automatic recovery from EBUSY/EAGAIN        │
└─────────────────────────────────────────────────┘
```

## Components

### 1. Rust Core Initialization Recovery

**Location**: `Sources/OSXCleanerKit/Bridge/RustBridge.swift`

#### Strategy

- **Retry Attempts**: 3 (configurable)
- **Delay**: Linear backoff (1s, 2s, 3s)
- **Fallback**: Swift-only mode

#### Implementation

```swift
public func initialize() throws {
    var lastError: Error?

    for attempt in 1...maxRetryAttempts {
        do {
            let success = osx_core_init()
            guard success else {
                throw RustBridgeError.initializationFailed
            }
            isInitialized = true
            return
        } catch {
            lastError = error
            AppLogger.shared.warning(
                "Rust core init attempt \(attempt)/\(maxRetryAttempts) failed"
            )
            if attempt < maxRetryAttempts {
                let delay = retryBaseDelay * Double(attempt)
                Thread.sleep(forTimeInterval: delay)
            }
        }
    }

    // Enter fallback mode
    try enterFallbackMode(lastError: lastError!)
}
```

#### Fallback Mode

When Rust initialization fails:

1. Sets `isFallbackMode = true`
2. Uses Swift-only implementations
3. Logs fallback activation
4. Continues operation (no app crash)

**Performance Impact**:
- Rust: ~10x faster file scanning
- Swift fallback: Fully functional but slower

### 2. FFI Error Recovery

**Location**: `Sources/OSXCleanerKit/Bridge/FFIErrorRecovery.swift`

#### Strategy

- **Transient Errors**: Automatic retry
- **Permanent Errors**: Immediate failure
- **Max Attempts**: 3 (default)
- **Delay**: Exponential backoff (0.5s, 1s, 1.5s)

#### Error Classification

| Error Type | Retryable | Reason |
|------------|-----------|--------|
| `rustError("temporarily unavailable")` | ✅ Yes | Resource may become available |
| `rustError("resource busy")` | ✅ Yes | Lock may be released |
| `rustError("timeout")` | ✅ Yes | May succeed on retry |
| `rustError("threading error")` | ✅ Yes | Thread contention may resolve |
| `initializationFailed` | ✅ Yes | Dylib loading may succeed |
| `nullPointer` | ❌ No | Programming error |
| `invalidUTF8` | ❌ No | Data corruption |
| `invalidString` | ❌ No | Input validation failure |
| `jsonParsingError` | ❌ No | Incompatible versions |

#### Usage

```swift
let result = try await FFIErrorRecovery.withRetry(maxAttempts: 3) {
    try bridge.analyzePath("/path/to/analyze")
}
```

### 3. Network Operation Recovery

**Location**: `Sources/OSXCleanerKit/Network/NetworkRetryPolicy.swift`

#### Strategy

- **Retry Attempts**: 5 (default)
- **Delay**: Exponential backoff with jitter
- **Max Delay**: 60 seconds (default)

#### Policies

| Policy | Max Attempts | Base Delay | Max Delay | Use Case |
|--------|--------------|------------|-----------|----------|
| `default` | 5 | 1s | 60s | Standard operations |
| `aggressive` | 10 | 0.5s | 120s | Critical operations |
| `conservative` | 3 | 2s | 30s | Non-critical operations |

#### Backoff Calculation

```swift
delay = min(baseDelay * 2^(attempt-1), maxDelay)
if useJitter:
    delay += random(0, 0.3 * delay)
```

**Example**:
- Attempt 1: 1s + jitter (0-0.3s)
- Attempt 2: 2s + jitter (0-0.6s)
- Attempt 3: 4s + jitter (0-1.2s)
- Attempt 4: 8s + jitter (0-2.4s)
- Attempt 5: 16s + jitter (0-4.8s)

#### Retryable Network Errors

```swift
case .timedOut,
     .networkConnectionLost,
     .notConnectedToInternet,
     .cannotFindHost,
     .cannotConnectToHost,
     .dnsLookupFailed,
     .resourceUnavailable:
    return true
```

#### HTTP Status Codes

| Status Code | Retryable | Description |
|-------------|-----------|-------------|
| 408 | ✅ Yes | Request Timeout |
| 429 | ✅ Yes | Too Many Requests (with backoff) |
| 500 | ✅ Yes | Internal Server Error |
| 502 | ✅ Yes | Bad Gateway |
| 503 | ✅ Yes | Service Unavailable |
| 504 | ✅ Yes | Gateway Timeout |
| 4xx (except 408, 429) | ❌ No | Client errors |
| 2xx | ❌ No | Success (no retry needed) |

#### Usage

```swift
let policy = NetworkRetryPolicy.default

let data = try await policy.execute {
    try await URLSession.shared.data(from: url)
}
```

#### Retry-After Header Support

```swift
if let retryAfter = response.retryAfter {
    // Use server-recommended delay
    try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
}
```

### 4. File Operation Recovery

**Location**: `Sources/OSXCleanerKit/Services/FileOperationRetry.swift`

#### Strategy

- **Retry Attempts**: 3 (default)
- **Delay**: Fixed 0.5s between retries
- **Retryable Errors**: EBUSY, EAGAIN, EINTR

#### Retryable File Errors

| Error Code | Domain | Retryable | Reason |
|------------|--------|-----------|--------|
| `NSFileWriteBusyError` | Cocoa | ✅ Yes | File being written |
| `NSFileReadNoPermissionError` | Cocoa | ✅ Yes | Permission delay |
| `NSFileLockingError` | Cocoa | ✅ Yes | File locked |
| `EBUSY` | POSIX | ✅ Yes | Resource busy |
| `EAGAIN` | POSIX | ✅ Yes | Try again |
| `EINTR` | POSIX | ✅ Yes | Interrupted |
| `NSFileNoSuchFileError` | Cocoa | ❌ No | File doesn't exist |
| `NSFileWriteNoPermissionError` | Cocoa | ❌ No | Permanent permission denied |
| `ENOENT` | POSIX | ❌ No | No such file |
| `EPERM` | POSIX | ❌ No | Not permitted |
| `EACCES` | POSIX | ❌ No | Access denied |
| `ENOSPC` | POSIX | ❌ No | No space left |

#### Operations Supported

```swift
// Remove with retry
try await FileOperationRetry.remove("/path/to/file")

// Copy with retry
try await FileOperationRetry.copy(
    from: "/source/path",
    to: "/dest/path"
)

// Move with retry
try await FileOperationRetry.move(
    from: "/source/path",
    to: "/dest/path"
)

// Write with retry
try await FileOperationRetry.write(data, to: "/path/to/file")
```

### 5. Graceful Degradation in CleanerService

**Location**: `Sources/OSXCleanerKit/Services/CleanerService.swift`

#### Strategy

- **Partial Failures**: Continue with remaining items
- **Error Collection**: Track all failures
- **Result Reporting**: Return both successes and failures

#### Implementation

```swift
for target in targets {
    do {
        let result = try await cleanTarget(target)
        totalFreed += result.freedBytes
        filesRemoved += result.filesRemoved
    } catch {
        // Log error but continue
        errors.append(CleanError(
            path: target.path,
            reason: error.localizedDescription
        ))
    }
}

return CleanResult(
    freedBytes: totalFreed,
    filesRemoved: filesRemoved,
    errors: errors
)
```

**Benefits**:
- Partial cleanup succeeds even if some items fail
- User gets detailed error report
- No data loss from aborted operations

## Configuration

### Retry Policy Tuning

```swift
// Custom FFI retry policy
let result = try await FFIErrorRecovery.withRetry(
    maxAttempts: 5,
    baseDelay: 1.0
) {
    try bridge.analyzePath(path)
}

// Custom network retry policy
let policy = NetworkRetryPolicy(
    maxAttempts: 10,
    baseDelay: 2.0,
    maxDelay: 120.0,
    useJitter: true
)

// Custom file operation retry
try await FileOperationRetry.remove(
    path,
    maxAttempts: 5,
    retryDelay: 1.0
)
```

### Rust Core Initialization

```swift
// Force Swift fallback (for testing)
let service = CleanerService(forceSwiftFallback: true)
```

## Monitoring

### Logging

All recovery events are logged:

```swift
AppLogger.shared.info("Recovery event", metadata: [
    "operation": "rust_init",
    "attempt": 2,
    "success": true,
    "duration": 1.5
])
```

### Metrics

Track recovery performance:

```swift
// Prometheus metrics
counter_increment("recovery_attempts_total", labels: ["operation": "ffi"])
histogram_observe("recovery_duration_seconds", value: duration)
```

## Testing

### Unit Tests

- `FFIErrorRecoveryTests`: FFI retry logic
- `NetworkRetryPolicyTests`: Network retry policies
- `FileOperationRetryTests`: File operation retry
- `RustBridgeRecoveryTests`: Rust core initialization

### Integration Tests

- End-to-end recovery scenarios
- Fallback mode verification
- Partial failure handling

### Running Tests

```bash
swift test --filter ErrorRecoveryTests
```

## Troubleshooting

### Common Issues

#### Rust Core Fails to Initialize

**Symptoms**: App uses Swift fallback, slower performance

**Causes**:
- Rust dylib not found
- Incompatible Rust version
- System permissions

**Resolution**:
1. Check dylib exists: `ls -la rust-core/target/release/libosx_core.dylib`
2. Verify Rust version: `rustc --version` (should be ≥1.70)
3. Rebuild Rust core: `cd rust-core && cargo build --release`

#### Network Operations Keep Failing

**Symptoms**: All retry attempts exhausted

**Causes**:
- No internet connection
- Server down
- Firewall blocking

**Resolution**:
1. Check connection: `ping 8.8.8.8`
2. Verify URL accessible: `curl -I <url>`
3. Check firewall settings

#### File Operations Fail

**Symptoms**: Cleanup partially fails

**Causes**:
- File locked by another process
- Insufficient permissions
- Disk full

**Resolution**:
1. Check file locks: `lsof | grep <filename>`
2. Verify permissions: `ls -l <file>`
3. Check disk space: `df -h`

## Best Practices

### 1. Use Appropriate Retry Policies

```swift
// Critical operations: aggressive policy
let policy = NetworkRetryPolicy.aggressive
try await policy.execute { ... }

// Non-critical: conservative policy
let policy = NetworkRetryPolicy.conservative
try await policy.execute { ... }
```

### 2. Handle Partial Failures

```swift
let result = try await cleanerService.clean(with: config)

if result.errors.isEmpty {
    print("Full success")
} else {
    print("Partial success: \(result.errors.count) failures")
    for error in result.errors {
        print("Failed: \(error.path) - \(error.reason)")
    }
}
```

### 3. Monitor Recovery Metrics

```swift
// Track recovery rate
let successRate = successfulRetries / totalRetries
if successRate < 0.8 {
    alert("High retry failure rate")
}
```

### 4. Test Fallback Modes

```swift
// Test Swift fallback
let service = CleanerService(forceSwiftFallback: true)
let result = try await service.clean(with: config)
XCTAssertFalse(result.errors.isEmpty)
```

## Future Enhancements

### Planned Improvements

1. **Circuit Breaker Pattern**
   - Prevent cascading failures
   - Automatic recovery detection

2. **Adaptive Retry**
   - Learn from failure patterns
   - Adjust retry parameters dynamically

3. **Recovery Analytics**
   - Track recovery success rates
   - Identify problematic operations

4. **User Notifications**
   - Alert on fallback mode activation
   - Provide recovery suggestions

## See Also

- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - General troubleshooting guide
- [TESTING.md](./TESTING.md) - Testing strategies
- [SECURITY.md](./SECURITY.md) - Security considerations

---

**Version**: 1.0.0
**Last Updated**: 2026-02-02
**Maintained By**: OSX Cleaner Team
