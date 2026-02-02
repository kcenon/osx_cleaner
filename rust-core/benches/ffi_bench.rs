// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Comprehensive benchmark tests for FFI interface overhead
//!
//! Tests performance of FFI calls, string conversions, and memory management.
//!
//! # Performance Targets (SLOs)
//!
//! | Operation | Target | Notes |
//! |-----------|--------|-------|
//! | FFI call overhead | <100us | Per call |
//! | CString creation | <1us | Simple path |
//! | Result lifecycle | <10us | Create + free |
//! | Batch validation | <1ms | 100 paths |

use criterion::{criterion_group, criterion_main, BenchmarkId, Criterion};
use std::hint::black_box;
use osxcore::{
    osx_analyze_path, osx_calculate_safety, osx_clean_path, osx_classify_path, osx_core_version,
    osx_free_string, osx_get_disk_space, osx_is_protected, osx_validate_batch, FFIResult,
};
use std::ffi::CString;
use std::fs::{self, File};
use std::io::Write;
use std::path::Path;
use tempfile::TempDir;

// =============================================================================
// Test Data Setup
// =============================================================================

/// Create test files in a temporary directory
fn create_test_files(temp_dir: &Path, count: usize) {
    let cache_dir = temp_dir.join("Library/Caches");
    fs::create_dir_all(&cache_dir).expect("Failed to create cache directory for benchmark");

    for i in 0..count {
        let file_path = cache_dir.join(format!("cache_file_{}.tmp", i));
        let mut file =
            File::create(&file_path).expect("Failed to create test file for benchmark");
        write!(file, "Cache data for file {}", i).expect("Failed to write test file content");
    }
}

/// Generate test paths for batch benchmarks
fn generate_test_paths(count: usize) -> Vec<String> {
    let templates = [
        "/Users/test/Library/Caches/Google/Chrome/Default/Cache/data",
        "/Users/test/Library/Caches/Firefox/Profiles/abc123/cache2/entries",
        "/tmp/temp_file",
        "/Users/test/Library/Caches/com.example.app",
        "/Users/test/Library/Logs/app.log",
        "/Users/test/Library/Developer/Xcode/DerivedData/Project/Build",
    ];

    (0..count)
        .map(|i| format!("{}_{}", templates[i % templates.len()], i))
        .collect()
}

// =============================================================================
// FFI Call Overhead Benchmarks
// =============================================================================

/// Benchmark FFI call overhead with minimal work
fn bench_ffi_overhead(c: &mut Criterion) {
    let temp = TempDir::new().expect("Failed to create temp directory");
    create_test_files(temp.path(), 10);
    let path = CString::new(temp.path().to_str().unwrap()).expect("Failed to create CString");

    c.bench_function("ffi_call_overhead", |b| {
        b.iter(|| unsafe {
            let result = osx_analyze_path(black_box(path.as_ptr()));
            // Free the result strings manually
            osx_free_string(result.data);
            osx_free_string(result.error_message);
        });
    });
}

/// Benchmark version query (simplest FFI call)
fn bench_ffi_version_query(c: &mut Criterion) {
    c.bench_function("ffi_version_query", |b| {
        b.iter(|| {
            let version_ptr = osx_core_version();
            unsafe {
                osx_free_string(version_ptr);
            }
        });
    });
}

/// Benchmark safety calculation FFI
fn bench_ffi_calculate_safety(c: &mut Criterion) {
    let mut group = c.benchmark_group("ffi_calculate_safety");

    let test_cases = [
        ("/tmp/test.tmp", "temp_file"),
        ("/Users/test/Library/Caches/app", "cache"),
        ("/System/Library/Frameworks", "protected"),
        (
            "/Users/test/Library/Developer/Xcode/DerivedData",
            "developer",
        ),
    ];

    for (path, name) in test_cases {
        let cpath = CString::new(path).expect("Failed to create CString");

        group.bench_with_input(BenchmarkId::new("path", name), &cpath, |b, cpath| {
            b.iter(|| unsafe { osx_calculate_safety(black_box(cpath.as_ptr())) });
        });
    }

    group.finish();
}

/// Benchmark is_protected check FFI
fn bench_ffi_is_protected(c: &mut Criterion) {
    let mut group = c.benchmark_group("ffi_is_protected");

    let test_cases = [
        ("/System/Library/Frameworks", "protected_system"),
        ("/usr/bin/ls", "protected_bin"),
        ("/tmp/test", "not_protected_tmp"),
        ("/Users/test/Documents", "not_protected_user"),
    ];

    for (path, name) in test_cases {
        let cpath = CString::new(path).expect("Failed to create CString");

        group.bench_with_input(BenchmarkId::new("path", name), &cpath, |b, cpath| {
            b.iter(|| unsafe { osx_is_protected(black_box(cpath.as_ptr())) });
        });
    }

    group.finish();
}

/// Benchmark path classification FFI
fn bench_ffi_classify_path(c: &mut Criterion) {
    let paths = [
        "/Users/test/Library/Caches/Google/Chrome",
        "/System/Library/Frameworks",
        "/tmp/cache",
        "/Users/test/Library/Developer/Xcode/DerivedData",
    ];

    let mut group = c.benchmark_group("ffi_classify_path");

    for path in paths {
        let cpath = CString::new(path).expect("Failed to create CString");
        let short_name = path.split('/').last().unwrap_or("unknown");

        group.bench_with_input(BenchmarkId::new("path", short_name), &cpath, |b, cpath| {
            b.iter(|| unsafe {
                let result = osx_classify_path(black_box(cpath.as_ptr()));
                osx_free_string(result.data);
                osx_free_string(result.error_message);
            });
        });
    }

    group.finish();
}

/// Benchmark disk space query FFI
fn bench_ffi_disk_space(c: &mut Criterion) {
    c.bench_function("ffi_disk_space_query", |b| {
        b.iter(|| {
            let result = osx_get_disk_space();
            unsafe {
                osx_free_string(result.data);
                osx_free_string(result.error_message);
            }
        });
    });
}

// =============================================================================
// String Conversion Benchmarks
// =============================================================================

/// Benchmark CString creation overhead
fn bench_ffi_string_conversion(c: &mut Criterion) {
    c.bench_function("ffi_cstring_creation", |b| {
        b.iter(|| CString::new(black_box("/tmp/test/path/to/analyze")).unwrap());
    });
}

/// Benchmark CString creation with varying path lengths
fn bench_ffi_string_length_scaling(c: &mut Criterion) {
    let mut group = c.benchmark_group("ffi_string_length");

    for len in [10, 50, 100, 500, 1000].iter() {
        let path = format!("/{}", "a".repeat(*len));

        group.bench_with_input(BenchmarkId::from_parameter(len), &path, |b, path| {
            b.iter(|| CString::new(black_box(path.as_str())).unwrap());
        });
    }

    group.finish();
}

// =============================================================================
// FFI Result Lifecycle Benchmarks
// =============================================================================

/// Benchmark FFI result creation and freeing
fn bench_ffi_result_lifecycle(c: &mut Criterion) {
    c.bench_function("ffi_result_lifecycle", |b| {
        b.iter(|| {
            let result = FFIResult::ok(Some(black_box("test data".to_string())));
            unsafe {
                osx_free_string(result.data);
            }
        });
    });
}

/// Benchmark FFI result with varying data sizes
fn bench_ffi_result_size_scaling(c: &mut Criterion) {
    let mut group = c.benchmark_group("ffi_result_size");

    for size in [100, 1000, 10000, 100000].iter() {
        let data = "x".repeat(*size);

        group.bench_with_input(BenchmarkId::from_parameter(size), &data, |b, data| {
            b.iter(|| {
                let result = FFIResult::ok(Some(black_box(data.clone())));
                unsafe {
                    osx_free_string(result.data);
                }
            });
        });
    }

    group.finish();
}

/// Benchmark FFI error result creation
fn bench_ffi_error_result(c: &mut Criterion) {
    c.bench_function("ffi_error_result", |b| {
        b.iter(|| {
            let result = FFIResult::err(black_box("Error message".to_string()));
            unsafe {
                osx_free_string(result.error_message);
            }
        });
    });
}

// =============================================================================
// Batch Operation Benchmarks
// =============================================================================

/// Benchmark batch path validation FFI
fn bench_ffi_validate_batch(c: &mut Criterion) {
    let mut group = c.benchmark_group("ffi_validate_batch");

    for count in [10, 50, 100].iter() {
        let paths = generate_test_paths(*count);
        let paths_json =
            serde_json::to_string(&paths).expect("Failed to serialize paths to JSON");
        let paths_cstring = CString::new(paths_json).expect("Failed to create CString");

        group.bench_with_input(
            BenchmarkId::new("paths", count),
            &paths_cstring,
            |b, paths_cstring| {
                b.iter(|| unsafe {
                    let result = osx_validate_batch(black_box(paths_cstring.as_ptr()), 2);
                    osx_free_string(result.data);
                    osx_free_string(result.error_message);
                });
            },
        );
    }

    group.finish();
}

// =============================================================================
// Cleanup FFI Benchmarks
// =============================================================================

/// Benchmark cleanup FFI call (dry run)
fn bench_ffi_clean_dry_run(c: &mut Criterion) {
    let temp = TempDir::new().expect("Failed to create temp directory");
    create_test_files(temp.path(), 100);
    let path = CString::new(temp.path().to_str().unwrap()).expect("Failed to create CString");

    c.bench_function("ffi_clean_dry_run", |b| {
        b.iter(|| unsafe {
            let result = osx_clean_path(black_box(path.as_ptr()), 2, true);
            osx_free_string(result.data);
            osx_free_string(result.error_message);
        });
    });
}

// =============================================================================
// Memory Allocation Pattern Benchmarks
// =============================================================================

/// Benchmark repeated FFI result allocations (memory pressure test)
fn bench_ffi_memory_pressure(c: &mut Criterion) {
    c.bench_function("ffi_memory_pressure_1000", |b| {
        b.iter(|| {
            for i in 0..1000 {
                let result = FFIResult::ok(Some(format!("data iteration {}", i)));
                unsafe {
                    osx_free_string(result.data);
                }
            }
        });
    });
}

// =============================================================================
// Criterion Groups
// =============================================================================

criterion_group!(
    name = ffi_overhead_benches;
    config = Criterion::default().sample_size(100);
    targets = bench_ffi_overhead,
              bench_ffi_version_query,
              bench_ffi_calculate_safety,
              bench_ffi_is_protected,
              bench_ffi_classify_path,
              bench_ffi_disk_space
);

criterion_group!(
    name = ffi_string_benches;
    config = Criterion::default().sample_size(100);
    targets = bench_ffi_string_conversion,
              bench_ffi_string_length_scaling
);

criterion_group!(
    name = ffi_result_benches;
    config = Criterion::default().sample_size(100);
    targets = bench_ffi_result_lifecycle,
              bench_ffi_result_size_scaling,
              bench_ffi_error_result
);

criterion_group!(
    name = ffi_batch_benches;
    config = Criterion::default().sample_size(50);
    targets = bench_ffi_validate_batch,
              bench_ffi_clean_dry_run,
              bench_ffi_memory_pressure
);

criterion_main!(
    ffi_overhead_benches,
    ffi_string_benches,
    ffi_result_benches,
    ffi_batch_benches
);
