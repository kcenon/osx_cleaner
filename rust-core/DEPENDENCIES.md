# Rust Core Dependencies

## Overview

This document explains the rationale for each dependency in the osxcore Rust library. Dependencies are carefully chosen to balance functionality, binary size, compile time, and maintainability.

## Dependency Optimization History

### 2026-01-30: chrono Removal

**Change**: Replaced `chrono` with standard library `std::time`

**Rationale**:
- chrono was only used for timestamp formatting in the logging module (2 lines of code)
- Standard library provides sufficient functionality via `SystemTime`
- Benefits:
  - Binary size: 2.4M → 1.9M (**20.8% reduction**)
  - Reduced compile time by eliminating chrono and its dependencies
  - Fewer transitive dependencies to maintain
  - No performance regression (all tests pass)

**Trade-offs**:
- Custom timestamp formatting function required
- Slightly less precise date/time handling for edge cases
- Acceptable trade-off given minimal usage

## Current Dependencies (12 total)

### Core Functionality

#### rayon (1.8)
- **Purpose**: Parallel processing for file scanning and analysis
- **Why**: Significantly improves performance on multi-core systems
- **Usage**: Parallel directory traversal, concurrent file processing
- **Alternatives**: std::thread (too low-level), crossbeam (similar overhead)
- **Size impact**: ~300KB, justified by performance gains

#### walkdir (2.4)
- **Purpose**: Efficient directory tree traversal
- **Why**: Handles symlinks, permissions, and cross-platform differences correctly
- **Usage**: Core file scanning functionality
- **Alternatives**: std::fs::read_dir (missing features), glob (less efficient)
- **Size impact**: Minimal (~20KB)

#### sysinfo (0.30)
- **Purpose**: System information retrieval (disk space, etc.)
- **Why**: Cross-platform API for system metrics
- **Usage**: Disk usage analysis, system information queries
- **Alternatives**: Platform-specific APIs (not cross-platform), sysctl (macOS only)
- **Size impact**: ~200KB, essential for core functionality

### Serialization

#### serde (1.0)
- **Purpose**: Serialization framework
- **Why**: De-facto standard for Rust serialization
- **Usage**: FFI data exchange, configuration
- **Features**: `derive` only (minimal bloat)
- **Alternatives**: manual serialization (too verbose), bincode (less flexible)
- **Size impact**: ~100KB with derive macro

#### serde_json (1.0)
- **Purpose**: JSON serialization
- **Why**: Standard JSON format for FFI communication
- **Usage**: API responses, configuration files
- **Alternatives**: manual JSON (error-prone), simd-json (overkill)
- **Size impact**: ~150KB

### Error Handling

#### thiserror (1.0)
- **Purpose**: Derive macro for error types
- **Why**: Better error messages and ergonomics
- **Usage**: Custom error types throughout the codebase
- **Alternatives**: std::error (more boilerplate), anyhow (runtime cost)
- **Size impact**: Compile-time only (no runtime overhead)

#### anyhow (1.0)
- **Purpose**: Error context and chaining
- **Why**: Rich error messages without boilerplate
- **Usage**: Error propagation with context
- **Alternatives**: thiserror alone (less context), std::error (verbose)
- **Size impact**: ~50KB

### Pattern Matching

#### glob (0.3)
- **Purpose**: Glob pattern matching
- **Why**: Simple and efficient pattern matching for file paths
- **Usage**: Safety validation, path pattern matching
- **Alternatives**: regex (overkill), custom implementation (reinventing wheel)
- **Size impact**: Minimal (~15KB)

### System Utilities

#### dirs (5.0)
- **Purpose**: Home directory detection
- **Why**: Cross-platform home directory paths
- **Usage**: Path expansion, user directory detection
- **Alternatives**: env::var("HOME") (Unix-only), platform-specific APIs
- **Size impact**: Minimal (~10KB)

#### num_cpus (1.16)
- **Purpose**: CPU count detection
- **Why**: Determine optimal parallelism level
- **Usage**: Rayon thread pool configuration
- **Alternatives**: std::thread::available_parallelism (Rust 1.59+, not available in 1.75)
- **Size impact**: Minimal (~5KB)

### Logging

#### log (0.4)
- **Purpose**: Logging facade
- **Why**: Standard logging interface
- **Usage**: Debug and info logging
- **Alternatives**: println! (not configurable), custom logging (reinventing wheel)
- **Size impact**: Minimal (~10KB)

#### env_logger (0.10)
- **Purpose**: Environment-based logging configuration
- **Why**: Easy logging setup via environment variables
- **Usage**: Development and debugging
- **Alternatives**: simplelog (fewer features), custom logger (more work)
- **Size impact**: ~100KB (includes regex dependency)
- **Note**: Only used for development, could be feature-gated in future optimization

## Development Dependencies

### cbindgen (0.26)
- **Purpose**: Generate C/C++ header files from Rust code
- **Why**: Essential for FFI interface
- **Usage**: Build-time header generation
- **Alternatives**: Manual header maintenance (error-prone)
- **Size impact**: Build-time only (not in binary)

### tempfile (3.9)
- **Purpose**: Temporary file handling in tests
- **Why**: Safe and cross-platform temporary files
- **Usage**: Test fixtures
- **Size impact**: Test-time only

### criterion (0.5)
- **Purpose**: Benchmarking framework
- **Why**: Statistical analysis of performance
- **Usage**: Performance regression testing
- **Size impact**: Benchmark-time only

### filetime (0.2)
- **Purpose**: File timestamp manipulation
- **Why**: Test file modification times
- **Usage**: Test fixtures for time-based cleanup
- **Size impact**: Test-time only

## Removed Dependencies

### chrono (0.4) → std::time
- **Removed**: 2026-01-30
- **Reason**: Minimal usage (only timestamp formatting)
- **Replacement**: Standard library `SystemTime`
- **Benefits**: 20.8% binary size reduction, faster compile time
- **Trade-off**: Custom timestamp formatting function

## Future Optimization Opportunities

### env_logger → Feature Gate
- **Potential saving**: ~100KB
- **Approach**: Make logging optional via feature flag
- **Trade-off**: Less convenient for debugging
- **Priority**: Low (convenient for development)

### Feature Flags for serde
- **Current**: Full serde + derive
- **Potential**: Selective feature enabling
- **Benefit**: Minimal (already using minimal features)

### Lazy Static Patterns
- **Current**: Some runtime initialization
- **Potential**: const fn initialization
- **Benefit**: Slightly smaller binary, faster startup
- **Priority**: Low (minor impact)

## Metrics

### Binary Size (2026-01-30)
| Configuration | Size | Change |
|---------------|------|--------|
| Before optimization | 2.4 MB | baseline |
| After chrono removal | 1.9 MB | **-20.8%** |

### Compile Time (Clean Build)
| Configuration | Time | Change |
|---------------|------|--------|
| Current (14 deps) | ~14.5s | baseline |

### Dependency Count
| Category | Count |
|----------|-------|
| Runtime dependencies | 12 |
| Build dependencies | 1 |
| Dev dependencies | 3 |
| **Total** | **16** |

## Maintenance Notes

### Adding New Dependencies

Before adding a new dependency, consider:
1. **Is it necessary?** Can standard library or existing deps suffice?
2. **What's the size impact?** Use `cargo bloat` to measure
3. **How many transitive deps?** Check `cargo tree`
4. **Is it actively maintained?** Check last update, open issues
5. **What's the licensing?** Ensure compatibility with BSD-3-Clause

### Dependency Updates

- **Patch updates**: Apply automatically (security fixes)
- **Minor updates**: Review changelog, test thoroughly
- **Major updates**: Audit breaking changes, measure size impact

### Feature Flags

When possible, use feature flags to make dependencies optional:
```toml
[dependencies]
optional_dep = { version = "1.0", optional = true }

[features]
default = []
extra_feature = ["optional_dep"]
```

## References

- [Cargo Book - Dependencies](https://doc.rust-lang.org/cargo/reference/specifying-dependencies.html)
- [cargo-bloat](https://github.com/RazrFalcon/cargo-bloat) - Binary size profiling
- [cargo-tree](https://doc.rust-lang.org/cargo/commands/cargo-tree.html) - Dependency tree visualization
