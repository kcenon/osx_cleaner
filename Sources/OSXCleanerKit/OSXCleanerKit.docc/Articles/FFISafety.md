# FFI Safety Guide

Best practices for safe interaction with the Rust core library.

## Overview

OSXCleanerKit uses Foreign Function Interface (FFI) to call high-performance Rust code from Swift. This guide explains how the ``RustBridge`` ensures memory safety and how to use it correctly.

## Memory Management

### Ownership Model

The FFI bridge follows strict ownership rules:

1. **Input Strings**: Swift owns input strings, Rust borrows them
2. **Output Results**: Rust allocates results, Swift must free them
3. **Automatic Cleanup**: All methods use `defer` to prevent leaks

### Example: Safe FFI Call

```swift
public func analyzePath(_ path: String) throws -> RustAnalysisResult {
    // 1. Validate input before FFI call
    try validateFFIString(path)

    // 2. Call Rust function (string is borrowed)
    let result = path.withCString { pathPtr in
        osx_analyze_path(pathPtr)
    }

    // 3. Process result and free Rust-allocated memory
    return try processFFIResult(result)
}

private func processFFIResult<T>(_ result: osx_FFIResult) throws -> T {
    // Check success before accessing data
    guard result.success else {
        if let errorPtr = result.error_message {
            let error = String(cString: errorPtr)
            // Free error message immediately after copy
            osx_free_string(errorPtr)
            throw RustBridgeError.rustError(error)
        }
    }

    // Copy data to Swift string
    guard let dataPtr = result.data else {
        throw RustBridgeError.nullPointer
    }

    // Free data at end of scope (even if exception thrown)
    defer { osx_free_string(dataPtr) }

    let jsonString = String(cString: dataPtr)
    // ... decode and return
}
```

## Input Validation

All strings passed to FFI must be validated:

### Validation Rules

1. **No Null Bytes**: C strings cannot contain `\0`
2. **Valid UTF-8**: Rust expects valid UTF-8 encoding
3. **Length Limits**: Prevents DoS attacks (max 4096 chars)

### Example: Validation

```swift
try validateFFIString("/Users/example/Library/Caches")
// ✅ Valid path

try validateFFIString("/path/with\0null")
// ❌ Throws: String contains null byte

try validateFFIString(String(repeating: "a", count: 5000))
// ❌ Throws: String exceeds maximum length
```

## Thread Safety

### Initialization

Rust core initialization is protected by a serial queue:

```swift
public func initialize() throws {
    try initQueue.sync {
        guard !isInitialized else { return }
        let success = osx_core_init()
        guard success else {
            throw RustBridgeError.initializationFailed
        }
        isInitialized = true
    }
}
```

### Concurrent Operations

- ✅ **Safe**: Analyzing different paths concurrently
- ✅ **Safe**: Multiple analyzer instances (uses shared Rust core)
- ⚠️ **Caution**: Cleaning the same path concurrently (undefined behavior)

## Error Handling

### Rust Errors

Rust errors are converted to Swift exceptions:

```swift
do {
    let result = try bridge.analyzePath("/invalid/path")
} catch let error as RustBridgeError {
    switch error {
    case .rustError(let message):
        print("Rust error: \(message)")
    case .nullPointer:
        print("Unexpected null pointer")
    case .invalidUTF8:
        print("Invalid UTF-8 in result")
    case .invalidString(let reason):
        print("Invalid input: \(reason)")
    default:
        print("Unknown error: \(error)")
    }
}
```

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `invalidString` | Null byte in path | Remove null bytes |
| `rustError` | Rust panicked or returned error | Check path validity |
| `nullPointer` | Rust returned null | Report as bug |
| `invalidUTF8` | Non-UTF8 data from Rust | Report as bug |

## Best Practices

### ✅ Do

- Always validate input strings
- Use `defer` for cleanup
- Check `success` before accessing data
- Initialize before first use
- Handle all error cases

### ❌ Don't

- Pass unvalidated strings to FFI
- Manually free FFI memory (use `defer`)
- Access `data` without checking `success`
- Assume Rust calls never fail
- Share mutable state across FFI boundary

## Performance Tips

### Rust Core Benefits

- **3-5x faster** than Swift fallback
- **Parallel scanning** with rayon
- **Zero-copy** string handling where possible

### When to Use Swift Fallback

- Rust core unavailable (ARM64 compatibility issues)
- Small paths (< 100 files, overhead not worth it)
- Testing without Rust dependencies

## See Also

- ``RustBridge``
- ``RustBridgeError``
- ``validateFFIString(_:)``
