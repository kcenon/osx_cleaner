// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2021-2025, 🍀☀🌕🌥 🌊

//! Comprehensive benchmark tests for file analysis and cleanup operations
//!
//! Tests performance of core operations with varying file counts and scenarios.
//!
//! # Performance Targets (SLOs)
//!
//! | Operation | Target | Notes |
//! |-----------|--------|-------|
//! | Analyze 100 files | <50ms | Baseline |
//! | Analyze 10K files | <2s | Cold cache |
//! | Clean 1K files | <5s | Parallel |
//! | Memory usage | <100MB | Peak for 100K files |

use criterion::{criterion_group, criterion_main, BenchmarkId, Criterion};
use std::hint::black_box;
use osxcore::analyzer::DiskAnalyzer;
use osxcore::{cleaner, scanner};
use std::fs::{self, File};
use std::io::Write;
use std::path::Path;
use tempfile::TempDir;

// =============================================================================
// Test Data Generation
// =============================================================================

/// Create test files in a temporary directory with realistic structure
fn create_test_files(temp_dir: &Path, count: usize) {
    let cache_dir = temp_dir.join("Library/Caches");
    fs::create_dir_all(&cache_dir).expect("Failed to create cache directory for benchmark");

    for i in 0..count {
        let file_path = cache_dir.join(format!("cache_file_{}.tmp", i));
        let mut file =
            File::create(&file_path).expect("Failed to create test file for benchmark");
        // Write some data to make files realistic
        write!(file, "Cache data for file {}", i).expect("Failed to write test file content");
    }
}

/// Create test files with varying sizes for more realistic benchmarks
fn create_varied_size_files(temp_dir: &Path, count: usize) {
    let cache_dir = temp_dir.join("Library/Caches");
    fs::create_dir_all(&cache_dir).expect("Failed to create cache directory for benchmark");

    for i in 0..count {
        let file_path = cache_dir.join(format!("cache_file_{}.tmp", i));
        let mut file =
            File::create(&file_path).expect("Failed to create test file for benchmark");

        // Vary file sizes: small (100B), medium (1KB), large (10KB)
        let size = match i % 3 {
            0 => 100,
            1 => 1024,
            _ => 10240,
        };

        let content = vec![b'X'; size];
        file.write_all(&content)
            .expect("Failed to write test file content");
    }
}

/// Create nested directory structure for testing deep traversal
fn create_nested_structure(temp_dir: &Path, depth: usize, files_per_dir: usize) {
    let mut current_path = temp_dir.join("Library/Caches");

    for d in 0..depth {
        current_path = current_path.join(format!("level_{}", d));
        fs::create_dir_all(&current_path).expect("Failed to create nested directory");

        for f in 0..files_per_dir {
            let file_path = current_path.join(format!("file_{}.dat", f));
            let mut file =
                File::create(&file_path).expect("Failed to create test file for benchmark");
            write!(file, "Data at depth {} file {}", d, f)
                .expect("Failed to write test file content");
        }
    }
}

/// Create developer-like directory structure
fn create_developer_structure(temp_dir: &Path, projects: usize) {
    let developer_dir = temp_dir.join("Library/Developer");
    let xcode_dir = developer_dir.join("Xcode/DerivedData");
    fs::create_dir_all(&xcode_dir).expect("Failed to create DerivedData directory");

    for p in 0..projects {
        let project_dir = xcode_dir.join(format!("Project{}-abcdef12345", p));
        let build_dir = project_dir.join("Build/Intermediates.noindex");
        fs::create_dir_all(&build_dir).expect("Failed to create build directory");

        // Create typical build artifacts
        for f in 0..50 {
            let file_path = build_dir.join(format!("module_{}.o", f));
            let content = vec![0u8; 4096]; // 4KB object files
            fs::write(&file_path, &content).expect("Failed to write build artifact");
        }
    }
}

// =============================================================================
// File Analysis Benchmarks
// =============================================================================

/// Benchmark analyzing a small directory (100 files) - Baseline
fn bench_analyze_small_directory(c: &mut Criterion) {
    let temp = TempDir::new().expect("Failed to create temp directory");
    create_test_files(temp.path(), 100);

    c.bench_function("analyze_100_files", |b| {
        b.iter(|| scanner::analyze(black_box(temp.path().to_str().unwrap())))
    });
}

/// Benchmark file analysis scaling with different file counts
fn bench_analyze_scaling(c: &mut Criterion) {
    let mut group = c.benchmark_group("analyze_scaling");

    // Configure for longer benchmarks on larger sizes
    group.sample_size(50);

    for size in [100, 1_000, 10_000].iter() {
        let temp = TempDir::new().expect("Failed to create temp directory");
        create_test_files(temp.path(), *size);

        group.bench_with_input(BenchmarkId::from_parameter(size), size, |b, _size| {
            b.iter(|| scanner::analyze(black_box(temp.path().to_str().unwrap())));
        });
    }

    group.finish();
}

/// Benchmark analyzing directories with varied file sizes
fn bench_analyze_varied_sizes(c: &mut Criterion) {
    let temp = TempDir::new().expect("Failed to create temp directory");
    create_varied_size_files(temp.path(), 1000);

    c.bench_function("analyze_1000_varied_size_files", |b| {
        b.iter(|| scanner::analyze(black_box(temp.path().to_str().unwrap())))
    });
}

/// Benchmark analyzing deeply nested directory structures
fn bench_analyze_nested_structure(c: &mut Criterion) {
    let mut group = c.benchmark_group("analyze_nested");

    for depth in [5, 10, 20].iter() {
        let temp = TempDir::new().expect("Failed to create temp directory");
        create_nested_structure(temp.path(), *depth, 10);

        group.bench_with_input(BenchmarkId::new("depth", depth), depth, |b, _| {
            b.iter(|| scanner::analyze(black_box(temp.path().to_str().unwrap())))
        });
    }

    group.finish();
}

// =============================================================================
// Cleanup Operation Benchmarks
// =============================================================================

/// Benchmark parallel cleanup operations with 1000 files
fn bench_parallel_cleanup(c: &mut Criterion) {
    c.bench_function("cleanup_1000_files_parallel", |b| {
        b.iter_batched(
            || {
                // Setup: create fresh temp dir with files for each iteration
                let temp = TempDir::new().expect("Failed to create temp directory");
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

/// Benchmark cleanup scaling with different file counts
fn bench_cleanup_scaling(c: &mut Criterion) {
    let mut group = c.benchmark_group("cleanup_scaling");
    group.sample_size(20); // Fewer samples due to file recreation

    for size in [100, 500, 1000].iter() {
        group.bench_with_input(BenchmarkId::from_parameter(size), size, |b, &size| {
            b.iter_batched(
                || {
                    let temp = TempDir::new().expect("Failed to create temp directory");
                    create_test_files(temp.path(), size);
                    temp
                },
                |temp| {
                    let config = cleaner::CleanConfig::from_safety_level(4, false); // System level
                    let _ = cleaner::clean(temp.path().to_str().unwrap(), &config);
                },
                criterion::BatchSize::SmallInput,
            );
        });
    }

    group.finish();
}

/// Benchmark dry-run cleanup (no actual deletion)
fn bench_cleanup_dry_run(c: &mut Criterion) {
    let temp = TempDir::new().expect("Failed to create temp directory");
    create_test_files(temp.path(), 1000);

    c.bench_function("cleanup_1000_files_dry_run", |b| {
        b.iter(|| {
            let config = cleaner::CleanConfig::from_safety_level(2, true);
            let _ = cleaner::clean(black_box(temp.path().to_str().unwrap()), &config);
        })
    });
}

// =============================================================================
// Disk Analyzer Benchmarks
// =============================================================================

/// Benchmark DiskAnalyzer creation
fn bench_disk_analyzer_creation(c: &mut Criterion) {
    c.bench_function("disk_analyzer_new", |b| {
        b.iter(|| DiskAnalyzer::new())
    });
}

/// Benchmark disk space query
fn bench_disk_space_query(c: &mut Criterion) {
    let analyzer = DiskAnalyzer::new();

    c.bench_function("disk_space_query", |b| {
        b.iter(|| analyzer.get_disk_space())
    });
}

/// Benchmark home directory analysis
fn bench_home_directory_analysis(c: &mut Criterion) {
    let temp = TempDir::new().expect("Failed to create temp directory");

    // Create realistic home directory structure
    for dir in ["Documents", "Downloads", "Library", "Desktop"] {
        let dir_path = temp.path().join(dir);
        fs::create_dir_all(&dir_path).expect("Failed to create home subdirectory");

        for i in 0..10 {
            let file_path = dir_path.join(format!("file_{}.dat", i));
            let content = vec![b'X'; 1024];
            fs::write(&file_path, &content).expect("Failed to write test file");
        }
    }

    let analyzer = DiskAnalyzer::with_home_path(temp.path().to_path_buf());

    c.bench_function("home_directory_analysis_top10", |b| {
        b.iter(|| analyzer.analyze_home_directory(black_box(10)))
    });
}

/// Benchmark cache analysis
fn bench_cache_analysis(c: &mut Criterion) {
    let temp = TempDir::new().expect("Failed to create temp directory");

    // Create realistic cache structure
    let caches_dir = temp.path().join("Library/Caches");
    for app in ["com.apple.Safari", "com.google.Chrome", "com.spotify.client"] {
        let app_dir = caches_dir.join(app);
        fs::create_dir_all(&app_dir).expect("Failed to create app cache directory");

        for i in 0..20 {
            let file_path = app_dir.join(format!("cache_{}.dat", i));
            let content = vec![b'X'; 4096];
            fs::write(&file_path, &content).expect("Failed to write cache file");
        }
    }

    let analyzer = DiskAnalyzer::with_home_path(temp.path().to_path_buf());

    c.bench_function("cache_analysis", |b| {
        b.iter(|| analyzer.analyze_caches())
    });
}

/// Benchmark developer tools analysis
fn bench_developer_analysis(c: &mut Criterion) {
    let temp = TempDir::new().expect("Failed to create temp directory");
    create_developer_structure(temp.path(), 5);

    let analyzer = DiskAnalyzer::with_home_path(temp.path().to_path_buf());

    c.bench_function("developer_analysis", |b| {
        b.iter(|| analyzer.analyze_developer())
    });
}

/// Benchmark full disk analysis
fn bench_full_analysis(c: &mut Criterion) {
    let temp = TempDir::new().expect("Failed to create temp directory");

    // Create comprehensive test structure
    create_test_files(temp.path(), 100);
    create_developer_structure(temp.path(), 3);

    let analyzer = DiskAnalyzer::with_home_path(temp.path().to_path_buf());

    c.bench_function("full_disk_analysis", |b| {
        b.iter(|| analyzer.analyze())
    });
}

// =============================================================================
// Concurrency Scaling Benchmarks
// =============================================================================

/// Benchmark analysis with different parallelism levels
fn bench_parallelism_scaling(c: &mut Criterion) {
    let mut group = c.benchmark_group("parallelism_scaling");
    group.sample_size(30);

    let temp = TempDir::new().expect("Failed to create temp directory");
    create_test_files(temp.path(), 5000);

    for threads in [1, 2, 4, 8].iter() {
        let analyzer = DiskAnalyzer::with_home_path(temp.path().to_path_buf())
            .with_parallelism(*threads);

        group.bench_with_input(
            BenchmarkId::new("threads", threads),
            threads,
            |b, _| {
                b.iter(|| analyzer.analyze_home_directory(10))
            },
        );
    }

    group.finish();
}

// =============================================================================
// Criterion Groups
// =============================================================================

criterion_group!(
    name = analysis_benches;
    config = Criterion::default().sample_size(50);
    targets = bench_analyze_small_directory,
              bench_analyze_scaling,
              bench_analyze_varied_sizes,
              bench_analyze_nested_structure
);

criterion_group!(
    name = cleanup_benches;
    config = Criterion::default().sample_size(20);
    targets = bench_parallel_cleanup,
              bench_cleanup_scaling,
              bench_cleanup_dry_run
);

criterion_group!(
    name = disk_analyzer_benches;
    config = Criterion::default().sample_size(50);
    targets = bench_disk_analyzer_creation,
              bench_disk_space_query,
              bench_home_directory_analysis,
              bench_cache_analysis,
              bench_developer_analysis,
              bench_full_analysis
);

criterion_group!(
    name = concurrency_benches;
    config = Criterion::default().sample_size(30);
    targets = bench_parallelism_scaling
);

criterion_main!(
    analysis_benches,
    cleanup_benches,
    disk_analyzer_benches,
    concurrency_benches
);
