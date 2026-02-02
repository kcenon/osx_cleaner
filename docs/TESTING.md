# Testing Guide

> Comprehensive testing guidelines for OSX Cleaner

---

## Table of Contents

- [Overview](#overview)
- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [Writing Tests](#writing-tests)
- [Test Coverage](#test-coverage)
- [Continuous Integration](#continuous-integration)
- [Best Practices](#best-practices)

---

## Overview

OSX Cleaner uses a hybrid testing approach combining:
- **Rust**: Unit tests and integration tests in `rust-core/`
- **Swift**: XCTest-based tests in `Tests/`
- **Coverage**: Automated measurement via llvm-cov and Codecov

### Testing Philosophy

1. **Safety First**: Critical safety features must have ≥90% coverage
2. **Fast Feedback**: Unit tests should run in <5 seconds
3. **Isolation**: Tests should not depend on external state
4. **Clarity**: Test names describe what they verify

---

## Test Structure

```
osx_cleaner/
├── rust-core/
│   ├── src/
│   │   └── */mod.rs          # Inline unit tests (#[cfg(test)])
│   └── tests/
│       ├── integration_test.rs
│       └── ffi_test.rs
├── Tests/
│   ├── OSXCleanerKitTests/   # Swift library tests
│   │   ├── Services/
│   │   ├── Core/
│   │   └── Utilities/
│   └── osxcleanerTests/       # CLI tests
└── benchmarks/                # Performance benchmarks
```

---

## Running Tests

### Quick Commands

```bash
# Run all tests (Rust + Swift)
make test

# Run only Rust tests
cd rust-core && cargo test

# Run only Swift tests
swift test

# Run with coverage
make test-coverage
```

### Detailed Commands

#### Rust Tests

```bash
# Run all tests
cargo test

# Run specific test
cargo test test_safety_classification

# Run with output
cargo test -- --nocapture

# Run doc tests
cargo test --doc

# Run benchmarks
cargo bench

# Run with coverage
cargo install cargo-llvm-cov  # first time only
cargo llvm-cov --all-features
```

#### Swift Tests

```bash
# Run all tests
swift test

# Run specific test class
swift test --filter SafetyTests

# Run with coverage
swift test --enable-code-coverage

# Parallel execution (default)
swift test --parallel

# Sequential execution (debugging)
swift test --no-parallel
```

### Integration Tests

```bash
# Build and test full integration
make all
make test

# Test CLI directly
.build/release/osxcleaner --dry-run --level light
```

---

## Writing Tests

### Rust Unit Tests

**Location**: Inline with module code using `#[cfg(test)]`

```rust
// rust-core/src/safety/mod.rs

pub fn classify_path(path: &Path) -> SafetyLevel {
    // Implementation
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    #[test]
    fn test_system_path_is_danger() {
        let path = Path::new("/System/Library");
        let level = classify_path(path);
        assert_eq!(level, SafetyLevel::Danger);
    }

    #[test]
    fn test_user_cache_is_safe() {
        let path = Path::new("/Users/test/Library/Caches/Chrome");
        let level = classify_path(path);
        assert_eq!(level, SafetyLevel::Safe);
    }

    #[test]
    #[should_panic(expected = "invalid path")]
    fn test_empty_path_panics() {
        classify_path(Path::new(""));
    }
}
```

### Rust Integration Tests

**Location**: `rust-core/tests/*.rs`

```rust
// rust-core/tests/ffi_test.rs

use osx_cleaner_core::*;
use std::ffi::{CStr, CString};

#[test]
fn test_ffi_classify_path() {
    let path = CString::new("/System/Library")
        .expect("Failed to create CString");

    let result = unsafe {
        rust_classify_path(path.as_ptr())
    };

    assert_eq!(result, 3); // SafetyLevel::Danger as i32
}

#[test]
fn test_ffi_memory_safety() {
    // Create and free a string
    let str_ptr = unsafe {
        rust_create_string("test")
    };

    assert!(!str_ptr.is_null());

    unsafe {
        rust_free_string(str_ptr);
    }
    // No memory leak or double-free
}
```

### Swift Unit Tests

**Location**: `Tests/OSXCleanerKitTests/`

```swift
import XCTest
@testable import OSXCleanerKit

final class SafetyTests: XCTestCase {
    var bridge: RustBridge!

    override func setUp() {
        super.setUp()
        bridge = RustBridge()
    }

    override func tearDown() {
        bridge = nil
        super.tearDown()
    }

    func testProtectedPathsAreDetected() {
        // Given
        let protectedPaths = [
            "/System/Library",
            "/bin",
            "/sbin",
            "/usr/bin"
        ]

        // When & Then
        for path in protectedPaths {
            let level = bridge.classifyPath(path)
            XCTAssertEqual(
                level,
                .danger,
                "\(path) should be classified as danger"
            )
        }
    }

    func testBrowserCacheIsSafe() {
        // Given
        let cachePath = "/Users/test/Library/Caches/Google/Chrome"

        // When
        let level = bridge.classifyPath(cachePath)

        // Then
        XCTAssertEqual(level, .safe)
    }

    func testAsyncCleanupOperation() async throws {
        // Given
        let service = CleanerService()

        // When
        let result = try await service.performCleanup(level: .light, dryRun: true)

        // Then
        XCTAssertTrue(result.success)
        XCTAssertGreaterThan(result.itemsProcessed, 0)
    }
}
```

### Test Naming Conventions

| Language | Convention | Example |
|----------|------------|---------|
| Rust | `test_<what>_<condition>` | `test_cache_is_safe` |
| Swift | `test<What><Condition>` | `testCacheIsSafe` |

---

## Test Coverage

### Coverage Requirements

| Component | Minimum | Target | Reason |
|-----------|---------|--------|--------|
| Overall Project | 80% | 85%+ | Quality baseline |
| New Code (PR Patch) | 85% | 90%+ | Prevent regression |
| Safety Module | 90% | 95%+ | Critical for system protection |
| FFI Layer | 80% | 90%+ | Interface stability |
| Core Services | 80% | 85%+ | Business logic |

### Measuring Coverage

#### Local Measurement

**Swift:**
```bash
# Run tests with coverage
swift test --enable-code-coverage

# Generate lcov report
xcrun llvm-cov export --format=lcov \
  --instr-profile=.build/debug/codecov/default.profdata \
  .build/debug/osxcleanerPackageTests.xctest/Contents/MacOS/osxcleanerPackageTests \
  > coverage-swift.lcov

# View summary
xcrun llvm-cov report \
  --instr-profile=.build/debug/codecov/default.profdata \
  .build/debug/osxcleanerPackageTests.xctest/Contents/MacOS/osxcleanerPackageTests
```

**Rust:**
```bash
# Install tool (once)
cargo install cargo-llvm-cov

# Generate coverage
cd rust-core
cargo llvm-cov --all-features --lcov --output-path ../coverage-rust.lcov

# View HTML report
cargo llvm-cov --all-features --html
open target/llvm-cov/html/index.html
```

#### CI/CD Coverage

Coverage is automatically measured in CI:
- **Uploaded to**: [Codecov.io](https://codecov.io/gh/kcenon/osx_cleaner)
- **Reported in**: PR comments and status checks
- **Enforced**: Build fails if coverage drops below threshold

**Codecov Badge**: ![codecov](https://codecov.io/gh/kcenon/osx_cleaner/branch/main/graph/badge.svg)

### Interpreting Coverage Reports

**Codecov UI Components:**
- **File View**: Coverage per file with line-by-line highlighting
- **Sunburst Chart**: Visual representation of coverage distribution
- **Diff View**: Coverage changes in PR (red = uncovered additions)
- **Flags**: Separate coverage for Swift vs Rust

**Coverage Metrics:**
- **Line Coverage**: % of executable lines run by tests
- **Branch Coverage**: % of conditional branches tested
- **Function Coverage**: % of functions called by tests

---

## Continuous Integration

### CI Workflow

The `.github/workflows/ci.yml` runs:

1. **Rust Check**
   - Format check (`cargo fmt`)
   - Linting (`cargo clippy`)
   - Build (`cargo build --release`)
   - Unit tests (`cargo test`)

2. **Swift Check**
   - Build (`swift build`)
   - Unit tests (`swift test`)

3. **Coverage**
   - Swift coverage with llvm-cov
   - Rust coverage with cargo-llvm-cov
   - Upload to Codecov
   - **Enforce thresholds** (80% project, 85% patch)

### Coverage Enforcement

**Configuration**: `codecov.yml`

```yaml
coverage:
  status:
    project:
      default:
        target: 80%
        threshold: 2%
    patch:
      default:
        target: 85%
        threshold: 5%
```

**When CI Fails:**

1. Check Codecov report in PR comment
2. Identify uncovered lines (highlighted in red)
3. Add tests for missing coverage
4. Focus on:
   - Error handling paths
   - Edge cases
   - Boundary conditions
5. Re-run CI

---

## Best Practices

### Do's ✅

1. **Test One Thing**: Each test should verify a single behavior
2. **Use Descriptive Names**: Test names should explain what they verify
3. **Arrange-Act-Assert**: Structure tests clearly (Given-When-Then)
4. **Test Edge Cases**: Empty inputs, max values, null pointers
5. **Test Error Paths**: Ensure error handling is covered
6. **Isolate Tests**: No shared state, use setup/teardown
7. **Mock External Dependencies**: FFI, file system, network

### Don'ts ❌

1. **Don't Skip Tests**: Disabled tests indicate technical debt
2. **Don't Test Implementation Details**: Test behavior, not internals
3. **Don't Duplicate Logic**: Test code should be simple
4. **Don't Ignore Warnings**: Warnings in tests indicate issues
5. **Don't Commit Failing Tests**: Fix or remove before merging
6. **Don't Write Slow Tests**: Unit tests should run in milliseconds
7. **Don't Depend on Test Order**: Tests must be independent

### Testing Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Testing privates | Brittle tests | Test public API only |
| Over-mocking | Tests don't reflect reality | Mock only external dependencies |
| Flaky tests | CI unreliable | Fix or remove immediately |
| Large test files | Hard to navigate | Split by feature/module |
| No assertions | Test passes but validates nothing | Always assert expected outcomes |

---

## Test Maintenance

### Updating Tests

When changing code:
1. Update affected tests first
2. Run tests locally before pushing
3. Ensure coverage doesn't decrease
4. Review Codecov diff in PR

### Removing Dead Tests

When removing features:
1. Remove associated tests
2. Update coverage expectations if needed
3. Document in commit message

### Refactoring Tests

Signs tests need refactoring:
- Duplication across test files
- Hard to understand test logic
- Slow test execution
- Frequent failures

**Refactoring Steps:**
1. Extract common setup to fixtures
2. Use helper functions for repetitive patterns
3. Simplify assertions
4. Document complex test scenarios

---

## Performance Testing

### Benchmarks

**Location**: `rust-core/benches/`

```rust
// rust-core/benches/safety_benchmark.rs

use criterion::{black_box, criterion_group, criterion_main, Criterion};
use osx_cleaner_core::safety::classify_path;
use std::path::Path;

fn benchmark_classify_path(c: &mut Criterion) {
    c.bench_function("classify_system_path", |b| {
        b.iter(|| {
            classify_path(black_box(Path::new("/System/Library")))
        });
    });
}

criterion_group!(benches, benchmark_classify_path);
criterion_main!(benches);
```

**Running Benchmarks:**
```bash
cd rust-core
cargo bench
```

---

## Resources

- [Rust Testing](https://doc.rust-lang.org/book/ch11-00-testing.html)
- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Codecov Documentation](https://docs.codecov.com/)
- [cargo-llvm-cov](https://github.com/taiki-e/cargo-llvm-cov)

---

*Last updated: 2026-01-31*
