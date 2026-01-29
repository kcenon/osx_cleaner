// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Benchmark tests for FFI interface overhead
//!
//! Tests performance of FFI calls and string conversions.

use criterion::{black_box, criterion_group, criterion_main, Criterion};
use osxcore::{osx_analyze_path, osx_free_string, FFIResult};
use std::ffi::CString;
use std::fs::{self, File};
use std::io::Write;
use std::path::Path;
use tempfile::TempDir;

/// Create test files in a temporary directory
fn create_test_files(temp_dir: &Path, count: usize) {
    let cache_dir = temp_dir.join("Library/Caches");
    fs::create_dir_all(&cache_dir).unwrap();

    for i in 0..count {
        let file_path = cache_dir.join(format!("cache_file_{}.tmp", i));
        let mut file = File::create(&file_path).unwrap();
        write!(file, "Cache data for file {}", i).unwrap();
    }
}

/// Benchmark FFI call overhead with minimal work
fn bench_ffi_overhead(c: &mut Criterion) {
    let temp = TempDir::new().unwrap();
    create_test_files(temp.path(), 10);
    let path = CString::new(temp.path().to_str().unwrap()).unwrap();

    c.bench_function("ffi_call_overhead", |b| {
        b.iter(|| {
            unsafe {
                let result = osx_analyze_path(black_box(path.as_ptr()));
                // Free the result strings manually
                osx_free_string(result.data);
                osx_free_string(result.error_message);
            }
        });
    });
}

/// Benchmark CString creation overhead
fn bench_ffi_string_conversion(c: &mut Criterion) {
    c.bench_function("ffi_cstring_creation", |b| {
        b.iter(|| CString::new(black_box("/tmp/test/path/to/analyze")).unwrap());
    });
}

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

criterion_group!(
    benches,
    bench_ffi_overhead,
    bench_ffi_string_conversion,
    bench_ffi_result_lifecycle
);

criterion_main!(benches);
