# Getting Started

Learn how to integrate OSXCleanerKit into your macOS application.

## Overview

OSXCleanerKit provides a Swift framework for analyzing and cleaning disk space on macOS. This guide will help you get started with basic disk analysis and cleanup operations.

## Installation

### Swift Package Manager

Add OSXCleanerKit to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/kcenon/osx_cleaner.git", from: "1.0.0")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: ["OSXCleanerKit"]
)
```

## Basic Usage

### Analyzing Disk Space

The simplest way to analyze disk space is using ``AnalyzerService``:

```swift
import OSXCleanerKit

// Create analyzer service
let analyzer = AnalyzerService()

// Configure analysis target
let config = AnalyzerConfiguration(
    targetPath: "~/Library/Caches",
    minSize: 1024 * 1024  // Only show items >= 1 MB
)

// Perform analysis
do {
    let result = try await analyzer.analyze(with: config)

    print("Total size: \(result.formattedTotalSize)")
    print("Potential savings: \(result.formattedPotentialSavings)")
    print("Found \(result.fileCount) files in \(result.directoryCount) directories")

    // Display categories
    for category in result.categories {
        print("\(category.name): \(category.formattedSize)")
    }
} catch {
    print("Analysis failed: \(error)")
}
```

### Cleaning Disk Space

Once you've analyzed a path, you can clean it using ``CleanerService``:

```swift
import OSXCleanerKit

let cleaner = CleanerService()

let config = CleanerConfiguration(
    cleanupLevel: .normal,
    dryRun: false,
    includeSystemCaches: true
)

do {
    let result = try await cleaner.clean(with: config)
    print("Cleaned \(result.deletedFiles) files")
    print("Recovered \(result.formattedSpaceRecovered)")
} catch {
    print("Cleanup failed: \(error)")
}
```

### Safety Levels

OSXCleanerKit uses safety levels to prevent accidental deletion:

- **Safe**: Only temporary caches (browser, system caches)
- **Caution**: Includes build artifacts, old logs
- **Warning**: Includes user caches, downloads folder
- **Danger**: System files (requires elevated permissions)

Always start with a dry run:

```swift
let config = CleanerConfiguration(
    cleanupLevel: .normal,
    dryRun: true  // Preview only, no deletion
)
```

## Next Steps

- Learn about <doc:FFISafety> for advanced Rust core usage
- Explore <doc:BasicUsage> for common patterns
- Review ``RustBridge`` for FFI details
