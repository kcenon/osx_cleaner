# OSX Cleaner FFI Guide

## Overview

OSX Cleaner provides a C-compatible Foreign Function Interface (FFI) for integration with Swift and other languages. This guide covers memory management, safety contracts, thread safety, and best practices.

## Table of Contents

1. [Available Functions](#available-functions)
2. [Memory Management](#memory-management)
3. [Error Handling](#error-handling)
4. [Thread Safety](#thread-safety)
5. [Safety Contracts](#safety-contracts)
6. [Common Mistakes](#common-mistakes)
7. [Best Practices](#best-practices)

---

## Available Functions

### Core Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `osx_core_init()` | Initialize Rust core library | `bool` |
| `osx_core_version()` | Get library version | `*mut c_char` |
| `osx_analyze_path()` | Analyze path for cleanup | `FFIResult` |
| `osx_clean_path()` | Execute cleanup operation | `FFIResult` |
| `osx_calculate_safety()` | Get safety level for path | `i32` |

### Safety Validation

| Function | Purpose | Returns |
|----------|---------|---------|
| `osx_is_protected()` | Check if path is protected | `bool` |
| `osx_classify_path()` | Get detailed path classification | `FFIResult` |
| `osx_validate_cleanup()` | Validate cleanup operation | `FFIResult` |
| `osx_validate_batch()` | Validate multiple paths | `FFIResult` |

### Memory Management

| Function | Purpose |
|----------|---------|
| `osx_free_string()` | Free Rust-allocated string |
| `osx_free_result()` | Free FFIResult structure |

### Process Detection

| Function | Purpose | Returns |
|----------|---------|---------|
| `osx_is_app_running()` | Check if app is running | `bool` |
| `osx_is_file_in_use()` | Check if file is in use | `bool` |
| `osx_check_related_app_running()` | Check related app for cache | `FFIResult` |
| `osx_get_running_processes()` | List all running processes | `FFIResult` |

### Cloud Sync Detection

| Function | Purpose | Returns |
|----------|---------|---------|
| `osx_detect_cloud_service()` | Detect cloud service for path | `FFIResult` |
| `osx_get_cloud_sync_info()` | Get cloud sync status | `FFIResult` |
| `osx_is_safe_to_delete_cloud()` | Check cloud deletion safety | `FFIResult` |
| `osx_is_icloud_path()` | Check if path is in iCloud | `bool` |
| `osx_is_dropbox_path()` | Check if path is in Dropbox | `bool` |
| `osx_is_onedrive_path()` | Check if path is in OneDrive | `bool` |
| `osx_is_google_drive_path()` | Check if path is in Google Drive | `bool` |

---

## Memory Management

### Rule 1: Always Free Results

**Every FFI function that returns `FFIResult` allocates memory that must be freed.**

#### Swift

```swift
let result = osx_analyze_path(path)
defer { osx_free_result(result) }  // ALWAYS use defer
```

**Why `defer`?**
- Ensures cleanup even if function throws
- Prevents memory leaks
- Executes at scope exit, regardless of return path

#### C

```c
FFIResult result = osx_analyze_path(path);
if (result.success) {
    printf("Data: %s\n", result.data);
}
osx_free_result(result);  // Manual cleanup
```

### Rule 2: Copy Data Before Freeing

**If you need the data after freeing, copy it first.**

#### ✅ Correct

```swift
let result = osx_analyze_path(path)
let jsonCopy = String(cString: result.data)  // Copy BEFORE free
osx_free_result(result)
// Use jsonCopy...
```

#### ❌ Wrong

```swift
let result = osx_analyze_path(path)
osx_free_result(result)
let json = String(cString: result.data)  // Use-after-free!
```

### Rule 3: Never Free Twice

**Each result must be freed exactly once.**

#### ❌ Wrong - Double Free

```swift
let result = osx_analyze_path(path)
osx_free_result(result)  // First free
osx_free_result(result)  // CRASH: double-free!
```

### Memory Ownership Model

#### Input Strings: Borrowed by Rust, Owned by Caller

```swift
let path = "/Users/example/Library/Caches"
let cPath = path.cString(using: .utf8)!
let result = osx_analyze_path(cPath)
// Rust does NOT take ownership of cPath
// Caller still owns cPath
osx_free_result(result)
```

#### Output Strings: Owned by Caller After Return

```swift
let result = osx_analyze_path(cPath)
// Rust allocates memory for result.data
// Caller now owns result.data
// Caller MUST call osx_free_result() to free
defer { osx_free_result(result) }
```

### FFIResult Memory Layout

```text
FFIResult {
    success: bool,              // Stack allocated, no cleanup needed
    error_message: *mut c_char, // Heap allocated if non-null
    data: *mut c_char,          // Heap allocated if non-null
}
```

---

## Error Handling

### Check `success` Before Accessing Data

#### Swift

```swift
let result = osx_analyze_path(path)
defer { osx_free_result(result) }

if result.success {
    // Safe to use result.data
    let json = String(cString: result.data)
    processData(json)
} else {
    // Use result.error_message for error details
    let error = String(cString: result.error_message)
    throw AnalysisError.failed(error)
}
```

#### C

```c
FFIResult result = osx_analyze_path(path);

if (result.success) {
    printf("Success: %s\n", result.data);
} else {
    fprintf(stderr, "Error: %s\n", result.error_message);
}

osx_free_result(result);
```

### Error Codes for Non-FFIResult Functions

Some functions return simple types with error codes:

```swift
// -1 indicates error
let safetyLevel = osx_calculate_safety(path)
if safetyLevel == -1 {
    // Handle error (null path or invalid UTF-8)
}

// false may indicate error or actual result
let isRunning = osx_is_app_running(appName)
```

---

## Thread Safety

### Thread-Safe Functions

**All FFI functions are thread-safe when called on different data.**

```swift
// Safe: Different paths, can run concurrently
DispatchQueue.global().async {
    let result1 = osx_analyze_path(path1)
    defer { osx_free_result(result1) }
}

DispatchQueue.global().async {
    let result2 = osx_analyze_path(path2)
    defer { osx_free_result(result2) }
}
```

### NOT Thread-Safe for Same Data

**Avoid calling cleanup functions on the same path concurrently.**

#### ❌ Wrong - Race Condition

```swift
// DO NOT DO THIS
DispatchQueue.global().async {
    let result1 = osx_clean_path(path, 2, false)
    osx_free_result(result1)
}

DispatchQueue.global().async {
    let result2 = osx_clean_path(path, 2, false)  // RACE CONDITION
    osx_free_result(result2)
}
```

### Memory Deallocation

**Never free the same result from multiple threads.**

#### ❌ Wrong - Concurrent Free

```swift
// DO NOT DO THIS
var result = osx_analyze_path(path)

DispatchQueue.global().async {
    osx_free_result(result)  // Thread 1
}

DispatchQueue.global().async {
    osx_free_result(result)  // Thread 2 - CRASH!
}
```

---

## Safety Contracts

### Preconditions (Caller Responsibilities)

#### For All `*const c_char` Parameters

The caller MUST ensure:

1. **Valid Pointer**: Pointer is non-null OR function documents null handling
2. **Null-Terminated**: String is properly null-terminated
3. **Valid UTF-8**: String is valid UTF-8 encoded
4. **Valid Lifetime**: Pointer remains valid during the entire function call

#### For `FFIResult` Returns

The caller MUST:

1. **Free Result**: Call `osx_free_result()` on the returned result
2. **Copy Data**: Copy strings before freeing if needed later
3. **No Double-Free**: Free result exactly once
4. **Check Success**: Check `success` before accessing `data`

### Postconditions (Rust Guarantees)

After a function returns:

1. **Ownership Transfer**: Caller owns returned `FFIResult`
2. **No Aliasing**: Rust no longer references input pointers
3. **Valid Result**: Returned pointers are valid until `osx_free_result()`
4. **Thread-Safe**: Function can be called again from any thread

### Undefined Behavior

The following cause undefined behavior:

1. **Null Pointer**: Passing null where not documented as allowed
2. **Invalid UTF-8**: Passing non-UTF-8 strings
3. **Non-Null-Terminated**: Passing strings without null terminator
4. **Use After Free**: Using pointers after `osx_free_result()`
5. **Double Free**: Calling `osx_free_result()` twice on same result
6. **Wrong Allocator**: Freeing strings not allocated by Rust

---

## Common Mistakes

### ❌ Memory Leak

```swift
let result = osx_analyze_path(path)
// WRONG: Forgot to call osx_free_result
return parseResult(result)  // Memory leaked
```

#### ✅ Correct

```swift
let result = osx_analyze_path(path)
defer { osx_free_result(result) }  // Always freed
return parseResult(result)
```

---

### ❌ Use After Free

```swift
let result = osx_analyze_path(path)
osx_free_result(result)
// WRONG: Using result.data after free
let json = String(cString: result.data)  // Undefined behavior
```

#### ✅ Correct

```swift
let result = osx_analyze_path(path)
let json = String(cString: result.data)  // Copy BEFORE free
osx_free_result(result)
// Use json...
```

---

### ❌ Not Checking Success

```swift
let result = osx_analyze_path(path)
defer { osx_free_result(result) }

// WRONG: Not checking success before using data
let json = String(cString: result.data)  // May crash if failed
```

#### ✅ Correct

```swift
let result = osx_analyze_path(path)
defer { osx_free_result(result) }

guard result.success else {
    let error = String(cString: result.error_message)
    throw AnalysisError.failed(error)
}

let json = String(cString: result.data)  // Safe
```

---

### ❌ Storing Result Pointer

```swift
class Analyzer {
    var lastResult: FFIResult?  // WRONG: Storing raw FFI result

    func analyze() {
        lastResult = osx_analyze_path(path)  // Memory never freed
    }
}
```

#### ✅ Correct

```swift
class Analyzer {
    var lastData: String?  // Store copied data, not FFIResult

    func analyze() {
        let result = osx_analyze_path(path)
        defer { osx_free_result(result) }

        if result.success {
            lastData = String(cString: result.data)  // Copy
        }
    }
}
```

---

### ❌ Manual String Deallocation

```swift
let result = osx_analyze_path(path)

// WRONG: Freeing individual strings
osx_free_string(result.data)
osx_free_string(result.error_message)

// This will double-free!
osx_free_result(result)
```

#### ✅ Correct

```swift
let result = osx_analyze_path(path)
// Just free the result - it frees strings automatically
osx_free_result(result)
```

---

## Best Practices

### 1. Always Use `defer` in Swift

```swift
func performAnalysis(path: String) throws -> AnalysisResult {
    let cPath = path.cString(using: .utf8)!
    let result = osx_analyze_path(cPath)
    defer { osx_free_result(result) }  // Automatic cleanup

    guard result.success else {
        throw AnalysisError.failed(String(cString: result.error_message))
    }

    return parseResult(String(cString: result.data))
}
```

### 2. Validate Inputs Before FFI Calls

```swift
func analyzeDirectory(_ path: String) throws {
    // Validate BEFORE calling FFI
    guard FileManager.default.fileExists(atPath: path) else {
        throw AnalysisError.pathNotFound
    }

    let cPath = path.cString(using: .utf8)!
    let result = osx_analyze_path(cPath)
    defer { osx_free_result(result) }

    // ... handle result
}
```

### 3. Use Type-Safe Wrappers

```swift
enum CleanupLevel: Int32 {
    case light = 1
    case normal = 2
    case deep = 3
    case system = 4
}

func cleanPath(_ path: String, level: CleanupLevel, dryRun: Bool) throws {
    let cPath = path.cString(using: .utf8)!
    let result = osx_clean_path(cPath, level.rawValue, dryRun)
    defer { osx_free_result(result) }

    // ... handle result
}
```

### 4. Centralize FFI Error Handling

```swift
struct FFIError: Error {
    let message: String
}

func unwrapFFIResult(_ result: FFIResult) throws -> String {
    defer { osx_free_result(result) }

    guard result.success else {
        let error = String(cString: result.error_message)
        throw FFIError(message: error)
    }

    return String(cString: result.data)
}

// Usage
let json = try unwrapFFIResult(osx_analyze_path(path))
```

### 5. Use Dry-Run Before Actual Cleanup

```swift
func performCleanup(path: String, level: CleanupLevel) throws {
    // 1. Preview changes
    let preview = try cleanPath(path, level: level, dryRun: true)

    // 2. Show user what will be deleted
    showPreview(preview)

    // 3. Confirm with user
    guard userConfirmed() else { return }

    // 4. Execute cleanup
    let actual = try cleanPath(path, level: level, dryRun: false)
    showResults(actual)
}
```

### 6. Handle UTF-8 Encoding Errors

```swift
func safeCString(_ string: String) -> [CChar]? {
    return string.cString(using: .utf8)
}

func analyze(_ path: String) throws {
    guard let cPath = safeCString(path) else {
        throw AnalysisError.invalidUTF8
    }

    let result = osx_analyze_path(cPath)
    defer { osx_free_result(result) }
    // ...
}
```

### 7. Log FFI Operations in Debug Mode

```swift
func debugFFICall<T>(_ name: String, _ block: () throws -> T) rethrows -> T {
    #if DEBUG
    print("[FFI] Calling \(name)")
    defer { print("[FFI] \(name) completed") }
    #endif
    return try block()
}

// Usage
let result = debugFFICall("osx_analyze_path") {
    try performAnalysis(path)
}
```

---

## Complete Example: Safe FFI Wrapper

```swift
import Foundation

struct OSXCleanerFFI {
    enum FFIError: Error {
        case failed(String)
        case invalidUTF8
    }

    // MARK: - Safe Wrapper

    static func analyze(path: String) throws -> AnalysisResult {
        guard let cPath = path.cString(using: .utf8) else {
            throw FFIError.invalidUTF8
        }

        let result = osx_analyze_path(cPath)
        defer { osx_free_result(result) }

        guard result.success else {
            let error = String(cString: result.error_message)
            throw FFIError.failed(error)
        }

        let json = String(cString: result.data)
        return try JSONDecoder().decode(AnalysisResult.self, from: json.data(using: .utf8)!)
    }

    static func clean(path: String, level: CleanupLevel, dryRun: Bool) throws -> CleanStats {
        guard let cPath = path.cString(using: .utf8) else {
            throw FFIError.invalidUTF8
        }

        let result = osx_clean_path(cPath, level.rawValue, dryRun)
        defer { osx_free_result(result) }

        guard result.success else {
            let error = String(cString: result.error_message)
            throw FFIError.failed(error)
        }

        let json = String(cString: result.data)
        return try JSONDecoder().decode(CleanStats.self, from: json.data(using: .utf8)!)
    }
}
```

---

## Version

This guide is for OSX Cleaner Rust Core FFI version 1.0+.

For API changes and migration guides, see [CHANGELOG.md](../../CHANGELOG.md).
