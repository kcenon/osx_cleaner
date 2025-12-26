// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Benchmark tests for safety module
//!
//! Tests performance of path classification with large numbers of paths.

use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion};
use std::path::{Path, PathBuf};

use osxcore::safety::SafetyValidator;

/// Generate test paths for benchmarking
fn generate_test_paths(count: usize) -> Vec<PathBuf> {
    let mut paths = Vec::with_capacity(count);

    // Mix of different path types for realistic benchmarking
    let templates = [
        // Safe paths (browser caches)
        "/Users/test/Library/Caches/Google/Chrome/Default/Cache/data_{}",
        "/Users/test/Library/Caches/Firefox/Profiles/abc123/cache2/entries/{}",
        "/tmp/temp_file_{}",
        // Caution paths (general caches)
        "/Users/test/Library/Caches/com.example.app/{}",
        "/Users/test/Library/Logs/app_{}.log",
        // Warning paths (developer caches)
        "/Users/test/Library/Developer/Xcode/DerivedData/Project-{}/Build",
        "/Users/test/.npm/_cacache/content-v2/sha512/{}",
        // Danger paths (protected)
        "/System/Library/Frameworks/Foundation_{}.framework",
        "/usr/bin/utility_{}",
    ];

    for i in 0..count {
        let template_idx = i % templates.len();
        let path = templates[template_idx].replace("{}", &i.to_string());
        paths.push(PathBuf::from(path));
    }

    paths
}

/// Benchmark single path classification
fn bench_classify_single(c: &mut Criterion) {
    let validator = SafetyValidator::new();

    let test_cases = [
        (
            "/Users/test/Library/Caches/Google/Chrome/Cache",
            "browser_cache",
        ),
        ("/System/Library/Frameworks", "system_protected"),
        (
            "/Users/test/Library/Developer/Xcode/DerivedData",
            "developer_cache",
        ),
        ("/tmp/test.tmp", "temp_file"),
        ("/Users/test/Library/Caches/com.app.test", "app_cache"),
    ];

    let mut group = c.benchmark_group("classify_single");

    for (path, name) in test_cases {
        group.bench_with_input(BenchmarkId::new("path", name), &path, |b, path| {
            b.iter(|| validator.classify(black_box(Path::new(path))))
        });
    }

    group.finish();
}

/// Benchmark batch path classification with increasing sizes
fn bench_classify_batch(c: &mut Criterion) {
    let validator = SafetyValidator::new();

    let mut group = c.benchmark_group("classify_batch");

    for size in [100, 1000, 10000].iter() {
        let paths = generate_test_paths(*size);

        group.bench_with_input(BenchmarkId::new("paths", size), &paths, |b, paths| {
            b.iter(|| validator.validate_batch(black_box(paths)))
        });
    }

    group.finish();
}

/// Benchmark is_protected check
fn bench_is_protected(c: &mut Criterion) {
    let validator = SafetyValidator::new();

    let test_cases = [
        ("/System/Library/Frameworks", true),
        ("/usr/bin/ls", true),
        ("/Users/test/Documents", false),
        ("/tmp/test", false),
    ];

    let mut group = c.benchmark_group("is_protected");

    for (path, expected) in test_cases {
        let name = if expected {
            "protected"
        } else {
            "not_protected"
        };
        group.bench_with_input(
            BenchmarkId::new(
                "path",
                format!("{}_{}", name, path.split('/').last().unwrap_or("root")),
            ),
            &path,
            |b, path| b.iter(|| validator.is_protected(black_box(Path::new(path)))),
        );
    }

    group.finish();
}

/// Benchmark validator creation
fn bench_validator_creation(c: &mut Criterion) {
    c.bench_function("validator_new", |b| b.iter(|| SafetyValidator::new()));
}

/// Performance test: classify 10,000+ paths
fn bench_large_scale_classification(c: &mut Criterion) {
    let validator = SafetyValidator::new();
    let paths = generate_test_paths(10_000);

    c.bench_function("classify_10000_paths", |b| {
        b.iter(|| {
            for path in black_box(&paths) {
                let _ = validator.classify(path);
            }
        })
    });
}

criterion_group!(
    benches,
    bench_classify_single,
    bench_classify_batch,
    bench_is_protected,
    bench_validator_creation,
    bench_large_scale_classification,
);

criterion_main!(benches);
