// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Benchmark tests for file analysis and cleanup operations
//!
//! Tests performance of core operations with varying file counts.

use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion};
use osxcore::{cleaner, scanner};
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
        // Write some data to make files realistic
        write!(file, "Cache data for file {}", i).unwrap();
    }
}

/// Benchmark analyzing a small directory (100 files)
fn bench_analyze_small_directory(c: &mut Criterion) {
    let temp = TempDir::new().unwrap();
    create_test_files(temp.path(), 100);

    c.bench_function("analyze_100_files", |b| {
        b.iter(|| scanner::analyze(black_box(temp.path().to_str().unwrap())))
    });
}

/// Benchmark file analysis scaling with different file counts
fn bench_analyze_scaling(c: &mut Criterion) {
    let mut group = c.benchmark_group("analyze_scaling");

    for size in [100, 1_000, 10_000].iter() {
        let temp = TempDir::new().unwrap();
        create_test_files(temp.path(), *size);

        group.bench_with_input(BenchmarkId::from_parameter(size), size, |b, _size| {
            b.iter(|| scanner::analyze(black_box(temp.path().to_str().unwrap())));
        });
    }

    group.finish();
}

/// Benchmark parallel cleanup operations
fn bench_parallel_cleanup(c: &mut Criterion) {
    c.bench_function("cleanup_1000_files_parallel", |b| {
        b.iter_batched(
            || {
                // Setup: create fresh temp dir with files for each iteration
                let temp = TempDir::new().unwrap();
                create_test_files(temp.path(), 1000);
                temp
            },
            |temp| {
                // Benchmark: clean the files
                let config = cleaner::CleanConfig::from_safety_level(2, false);
                let _ = cleaner::clean(temp.path().to_str().unwrap(), &config);
            },
            criterion::BatchSize::SmallInput,
        );
    });
}

criterion_group!(
    benches,
    bench_analyze_small_directory,
    bench_analyze_scaling,
    bench_parallel_cleanup
);

criterion_main!(benches);
