# Basic Usage Patterns

Common patterns for disk analysis and cleanup operations.

## Overview

This guide demonstrates practical usage patterns for OSXCleanerKit in real-world applications.

## Analysis Patterns

### Analyze Multiple Paths

```swift
import OSXCleanerKit

let analyzer = AnalyzerService()
let paths = [
    "~/Library/Caches",
    "~/Library/Logs",
    "~/Library/Developer/Xcode/DerivedData"
]

for path in paths {
    let config = AnalyzerConfiguration(targetPath: path)
    if let result = try? await analyzer.analyze(with: config) {
        print("\(path): \(result.formattedTotalSize)")
    }
}
```

### Find Largest Items

```swift
let config = AnalyzerConfiguration(
    targetPath: "~/Library",
    minSize: 100 * 1024 * 1024  // 100 MB minimum
)

let result = try await analyzer.analyze(with: config)

// Display top 10 largest items
for item in result.largestItems.prefix(10) {
    print("\(item.formattedSize): \(item.path)")
}
```

### Categorize by Type

```swift
let result = try await analyzer.analyze(with: config)

// Group by category
for category in result.categories.sorted(by: { $0.size > $1.size }) {
    print("\\(category.name): \\(category.formattedSize)")
    print("  Items: \\(category.itemCount)")

    // Show top items in category
    for item in category.topItems.prefix(5) {
        print("  - \\(item.formattedSize): \\(item.path)")
    }
}
```

## Cleanup Patterns

### Dry Run Preview

Always preview changes before cleaning:

```swift
let cleaner = CleanerService()

// Preview what would be deleted
let dryConfig = CleanerConfiguration(
    cleanupLevel: .normal,
    dryRun: true,
    includeSystemCaches: true
)

let preview = try await cleaner.clean(with: dryConfig)
print("Would delete \(preview.deletedFiles) files")
print("Would recover \(preview.formattedSpaceRecovered)")

// Ask user for confirmation
if userConfirmed {
    // Perform actual cleanup
    let realConfig = CleanerConfiguration(
        cleanupLevel: .normal,
        dryRun: false,
        includeSystemCaches: true
    )
    let result = try await cleaner.clean(with: realConfig)
}
```

### Selective Cleanup

Clean only specific categories:

```swift
let config = CleanerConfiguration(
    cleanupLevel: .light,
    dryRun: false,
    includeSystemCaches: true,      // Clean browser/system caches
    includeDeveloperCaches: true,   // Clean Xcode DerivedData
    includeBrowserCaches: true,     // Clean browser caches
    includeLogsCaches: false        // Keep logs
)

let result = try await cleaner.clean(with: config)
```

### Custom Paths

Clean specific paths only:

```swift
let config = CleanerConfiguration(
    cleanupLevel: .normal,
    dryRun: false,
    specificPaths: [
        "~/Library/Developer/Xcode/DerivedData",
        "~/Library/Caches/com.apple.Safari"
    ]
)

let result = try await cleaner.clean(with: config)
```

## Safety Checks

### Check Safety Before Cleaning

```swift
let bridge = RustBridge.shared
try bridge.initialize()

let path = "/Users/example/Documents"
let safetyLevel = try bridge.calculateSafety(for: path)

switch safetyLevel {
case .safe:
    print("Safe to delete")
case .caution:
    print("Proceed with caution")
case .warning:
    print("Warning: Important data may be lost")
case .danger:
    print("Danger: Critical system files")
}
```

### Validate Paths

Use ``PathValidator`` to validate paths before operations:

```swift
import OSXCleanerKit

do {
    try PathValidator.validatePath("/Users/example/Library/Caches")
    // ✅ Valid path
} catch ValidationError.invalidPath(let reason) {
    print("Invalid path: \(reason)")
} catch ValidationError.pathNotFound {
    print("Path does not exist")
} catch ValidationError.permissionDenied {
    print("Permission denied")
}
```

## Configuration Management

### Save and Load Configuration

```swift
let configService = ConfigurationService()

// Load existing configuration
var config = try configService.load()

// Modify settings
config.defaultSafetyLevel = 2
config.excludedPaths.append("~/Projects")

// Save configuration
try configService.save(config)
```

### Exclude Paths

Protect important directories from cleanup:

```swift
var config = try configService.load()
config.excludedPaths = [
    "~/Documents",
    "~/Desktop",
    "~/Pictures",
    "~/Music",
    "~/Movies",
    "~/Projects"  // Custom exclusion
]
try configService.save(config)
```

## Error Handling

### Robust Error Handling

```swift
do {
    let result = try await analyzer.analyze(with: config)
    // Process result
} catch let error as RustBridgeError {
    // Handle Rust FFI errors
    print("FFI error: \(error)")
} catch let error as ValidationError {
    // Handle validation errors
    print("Validation error: \(error)")
} catch {
    // Handle other errors
    print("Unexpected error: \(error)")
}
```

## See Also

- ``AnalyzerService``
- ``CleanerService``
- ``RustBridge``
- ``PathValidator``
- ``ConfigurationService``
