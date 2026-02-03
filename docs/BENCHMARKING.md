# Performance Benchmarking Guide

This document describes how to run, interpret, and contribute to the OSX Cleaner benchmark suite.

## Overview

The benchmark suite measures performance of critical operations to:

- Establish performance baselines
- Detect performance regressions
- Validate Service Level Objectives (SLOs)
- Guide optimization efforts

## Performance SLOs

| Operation | Target | Category |
|-----------|--------|----------|
| Analyze 100 files | <500ms | File Analysis |
| Analyze 10K files | <2s | File Analysis |
| Clean 1K files | <5s | Cleanup Operations |
| FFI call overhead | <100us | FFI Overhead |
| Peak memory (100K files) | <100MB | Memory Usage |

## Running Benchmarks

### Rust Benchmarks (Criterion)

```bash
cd rust-core

# Run all benchmarks
cargo bench

# Run specific benchmark
cargo bench --bench analysis_bench
cargo bench --bench ffi_bench
cargo bench --bench safety_benchmark

# Run with baseline comparison
cargo bench -- --save-baseline main
cargo bench -- --baseline main

# Generate HTML reports
cargo bench
# Reports are saved to: target/criterion/<benchmark_name>/report/index.html
```

### Swift Performance Tests

```bash
# Run all performance tests
swift test --filter Performance

# Run specific performance test
swift test --filter testPerformanceAnalyzeSmallDirectory

# Run with verbose output
swift test --filter Performance -v
```

## Benchmark Categories

### 1. File Analysis Benchmarks (`analysis_bench.rs`)

Measures directory scanning and file analysis performance.

| Benchmark | Description | Expected |
|-----------|-------------|----------|
| `analyze_100_files` | Small directory baseline | <50ms |
| `analyze_scaling/1000` | Medium directory | <200ms |
| `analyze_scaling/10000` | Large directory | <2s |
| `analyze_varied_sizes` | Mixed file sizes | <200ms |
| `analyze_nested/depth_10` | Deep directory tree | <500ms |

### 2. Cleanup Benchmarks (`analysis_bench.rs`)

Measures file deletion and cleanup performance.

| Benchmark | Description | Expected |
|-----------|-------------|----------|
| `cleanup_1000_files_parallel` | Parallel deletion | <5s |
| `cleanup_scaling/*` | Scaling with file count | Linear |
| `cleanup_dry_run` | Simulation only | <100ms |

### 3. FFI Benchmarks (`ffi_bench.rs`)

Measures Swift-Rust boundary crossing overhead.

| Benchmark | Description | Expected |
|-----------|-------------|----------|
| `ffi_call_overhead` | Full FFI roundtrip | <100us |
| `ffi_version_query` | Simplest FFI call | <10us |
| `ffi_calculate_safety` | Safety calculation | <50us |
| `ffi_classify_path` | Path classification | <100us |
| `ffi_string_conversion` | CString creation | <1us |
| `ffi_result_lifecycle` | Result create+free | <10us |

### 4. Safety Benchmarks (`safety_benchmark.rs`)

Measures path safety validation performance.

| Benchmark | Description | Expected |
|-----------|-------------|----------|
| `classify_single/*` | Single path classification | <10us |
| `classify_batch/1000` | Batch classification | <10ms |
| `is_protected/*` | Protection check | <5us |
| `classify_10000_paths` | Large batch | <100ms |

### 5. Disk Analyzer Benchmarks (`analysis_bench.rs`)

Measures disk usage analysis components.

| Benchmark | Description | Expected |
|-----------|-------------|----------|
| `disk_analyzer_new` | Analyzer creation | <1ms |
| `disk_space_query` | System disk info | <10ms |
| `home_directory_analysis` | Home dir scan | <500ms |
| `cache_analysis` | Cache enumeration | <200ms |
| `developer_analysis` | Developer tools | <500ms |
| `full_disk_analysis` | Complete analysis | <2s |

## Interpreting Results

### Criterion Output

```
analyze_100_files       time:   [45.234 ms 46.012 ms 46.891 ms]
                        change: [-2.1234% +0.1234% +2.4567%] (p = 0.12 > 0.05)
                        No change in performance detected.
```

- **time**: [lower bound, estimate, upper bound] with 95% confidence
- **change**: Comparison with baseline (if available)
- **p-value**: Statistical significance (p < 0.05 indicates significant change)

### Performance Regression Indicators

| Indicator | Meaning | Action |
|-----------|---------|--------|
| Green (improvement) | Performance improved | Review for correctness |
| Yellow (no change) | Within noise margin | No action needed |
| Red (regression) | Performance degraded | Investigate cause |

## CI Integration

Benchmarks run automatically on:

- Every push to `main` (saves baseline)
- Every pull request (compares to baseline)
- Manual workflow dispatch

### Viewing CI Results

1. Go to the Actions tab in GitHub
2. Find the "Performance Benchmarks" workflow
3. Download artifacts for detailed Criterion HTML reports
4. Check PR comments for summary results

## Contributing Benchmarks

### Adding a New Benchmark

1. Identify the operation to benchmark
2. Create test data generation helpers if needed
3. Add the benchmark function:

```rust
fn bench_my_operation(c: &mut Criterion) {
    // Setup (not measured)
    let data = create_test_data();

    c.bench_function("my_operation", |b| {
        b.iter(|| {
            // Code to benchmark
            my_operation(black_box(&data))
        })
    });
}
```

4. Add to the appropriate criterion group
5. Document expected performance in this file

### Best Practices

1. **Isolate setup**: Don't include setup time in measurements
2. **Use `black_box`**: Prevent compiler optimizations that wouldn't happen in production
3. **Realistic data**: Use data sizes similar to real-world usage
4. **Multiple samples**: Let Criterion collect enough samples for statistical significance
5. **Clean state**: Ensure each iteration starts from the same state

### Benchmark Naming Convention

```
<category>_<operation>_<variant>
```

Examples:
- `analyze_small_directory`
- `ffi_call_overhead`
- `cleanup_1000_files_parallel`

## Troubleshooting

### High Variance Results

If benchmarks show high variance:

1. Close other applications
2. Disable CPU throttling if possible
3. Run on a consistent machine
4. Increase sample size: `group.sample_size(100)`

### Benchmarks Taking Too Long

1. Reduce sample size for slow benchmarks
2. Use `iter_batched` for benchmarks with expensive setup
3. Run specific benchmarks: `cargo bench --bench <name>`

### Memory Issues

For benchmarks creating many files:

1. Clean up test directories in teardown
2. Use `TempDir` which auto-cleans
3. Monitor system memory during runs

## Performance Optimization Workflow

1. Run benchmarks to establish baseline
2. Make code changes
3. Run benchmarks again
4. Compare results:
   ```bash
   cargo bench -- --baseline before --save-baseline after
   ```
5. Document improvements in commit message

## Benchmark Tracking System

The benchmark tracking system enables historical performance analysis by storing benchmark results and generating comparison reports.

### Running with Tracking

```bash
# Run all benchmarks and save results
./scripts/track-benchmarks.sh

# Run only Rust benchmarks
./scripts/track-benchmarks.sh --rust-only

# Run only Swift performance tests
./scripts/track-benchmarks.sh --swift-only

# Run and generate comparison report
./scripts/track-benchmarks.sh --compare

# Save results as baseline
./scripts/track-benchmarks.sh --baseline

# Custom output directory
./scripts/track-benchmarks.sh -o ./my-benchmark-results

# Verbose output
./scripts/track-benchmarks.sh --verbose
```

### Comparing Results

```bash
# Compare latest results with baseline
python3 scripts/compare-benchmarks.py

# Compare specific runs
python3 scripts/compare-benchmarks.py --latest 20260203-120000-abc1234 --baseline 20260202-100000-def5678

# Generate JSON report
python3 scripts/compare-benchmarks.py --format json

# Set custom regression threshold (default: 5%)
python3 scripts/compare-benchmarks.py --threshold 10.0

# Save to custom location
python3 scripts/compare-benchmarks.py -o ./my-report.md
```

### Output Structure

```
benchmark-results/
  rust-20260203-120000-abc1234.json       # Rust benchmark results
  swift-20260203-120000-abc1234.txt       # Swift test output
  swift-20260203-120000-abc1234.json      # Swift parsed results
  metadata-20260203-120000-abc1234.json   # Run metadata
  criterion-20260203-120000-abc1234.tar.gz # Detailed Criterion data
  report-20260203-120000-abc1234.md       # Comparison report
  rust-baseline.json                       # Baseline Rust results
  swift-baseline.txt                       # Baseline Swift results
```

### Comparison Report Format

The comparison report includes:

- **Environment**: Commit hash, branch, date, system info
- **Summary**: Total tests, improvements, regressions
- **Rust Benchmarks**: Table with baseline, current, and change percentage
- **Swift Performance Tests**: Table with baseline, current, and change percentage
- **Regressions**: Detailed list of benchmarks exceeding threshold
- **Improvements**: List of benchmarks showing improvement

Example output:

```markdown
# Performance Comparison Report

## Summary
- Total benchmarks: 25
- Improvements: 3
- Regressions: 1
- Unchanged: 21

## Rust Benchmarks
| Benchmark | Baseline | Current | Change |
|-----------|----------|---------|--------|
| classify_10000_paths | 85.23ms | 82.15ms | -3.61% (improvement) |
| ffi_call_overhead | 45.12us | 48.34us | +7.14% (regression) |
```

### CI/CD Integration

Add benchmark tracking to your CI workflow:

```yaml
# .github/workflows/benchmark.yml
name: Performance Benchmarks

on:
  push:
    branches: [main]
  pull_request:

jobs:
  benchmark:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Benchmarks
        run: ./scripts/track-benchmarks.sh --compare

      - name: Upload Results
        uses: actions/upload-artifact@v4
        with:
          name: benchmark-results
          path: benchmark-results/

      - name: Check for Regressions
        run: |
          if python3 scripts/compare-benchmarks.py --threshold 10.0; then
            echo "No significant regressions"
          else
            echo "Performance regressions detected!"
            exit 1
          fi
```

### Best Practices for Tracking

1. **Consistent Environment**: Run benchmarks on the same hardware/OS when possible
2. **Save Baselines**: Save baseline after significant changes with `--baseline`
3. **Monitor Trends**: Review historical data periodically to catch gradual regressions
4. **Document Changes**: Include performance impact in commit messages when relevant
5. **Clean State**: Ensure system is in consistent state before running benchmarks

## Related Documentation

- [TESTING.md](TESTING.md) - General testing guide
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
- [Criterion Book](https://bheisler.github.io/criterion.rs/book/) - Criterion documentation
