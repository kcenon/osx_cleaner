#!/usr/bin/env python3
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2021-2025
#
# Benchmark comparison script for OSX Cleaner
# Generates comparison reports between benchmark runs.

"""
Benchmark Comparison Tool

Compares benchmark results between runs and generates markdown reports
with performance trend analysis.

Usage:
    python compare-benchmarks.py [OPTIONS]

Options:
    --output-dir DIR    Directory containing benchmark results (default: benchmark-results/)
    --latest ID         Timestamp-commit ID of latest run to compare
    --baseline ID       Timestamp-commit ID of baseline (default: auto-detect)
    --format FORMAT     Output format: markdown, json, html (default: markdown)
    --threshold PCT     Regression threshold percentage (default: 5.0)
    -v, --verbose       Enable verbose output
"""

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Optional


@dataclass
class BenchmarkResult:
    """Single benchmark result"""
    name: str
    value: float
    unit: str
    raw_value: Optional[float] = None


@dataclass
class ComparisonResult:
    """Comparison between two benchmark results"""
    name: str
    baseline_value: float
    latest_value: float
    unit: str
    change_percent: float
    is_regression: bool
    is_improvement: bool


def parse_rust_results(filepath: Path) -> dict[str, BenchmarkResult]:
    """Parse Rust benchmark JSON results"""
    results = {}

    try:
        with open(filepath) as f:
            data = json.load(f)

        benchmarks = data.get("benchmarks", {})
        for name, info in benchmarks.items():
            if isinstance(info, dict):
                value = info.get("mean_ns", info.get("value", 0))
                unit = info.get("unit", "ns")
                results[name] = BenchmarkResult(
                    name=name,
                    value=float(value),
                    unit=unit,
                    raw_value=info.get("value")
                )
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"Warning: Could not parse Rust results from {filepath}: {e}")

    return results


def parse_swift_results(filepath: Path) -> dict[str, BenchmarkResult]:
    """Parse Swift performance test results"""
    results = {}

    # Try JSON format first
    json_path = filepath.with_suffix(".json")
    if json_path.exists():
        try:
            with open(json_path) as f:
                data = json.load(f)

            tests = data.get("tests", {})
            for name, info in tests.items():
                if isinstance(info, dict):
                    value = info.get("average_seconds", 0)
                    results[name] = BenchmarkResult(
                        name=name,
                        value=float(value) * 1000,  # Convert to ms
                        unit="ms"
                    )
            return results
        except (json.JSONDecodeError, FileNotFoundError):
            pass

    # Fall back to parsing text output
    if filepath.exists():
        try:
            with open(filepath) as f:
                content = f.read()

            # Parse XCTest measure output
            pattern = r"measured.*average:\s+([0-9.]+)"
            test_pattern = r"'([^']+)'"

            lines = content.split("\n")
            current_test = None

            for line in lines:
                test_match = re.search(test_pattern, line)
                if test_match:
                    current_test = test_match.group(1)

                measure_match = re.search(pattern, line)
                if measure_match and current_test:
                    value = float(measure_match.group(1))
                    results[current_test] = BenchmarkResult(
                        name=current_test,
                        value=value * 1000,  # Convert to ms
                        unit="ms"
                    )
        except FileNotFoundError as e:
            print(f"Warning: Could not parse Swift results from {filepath}: {e}")

    return results


def find_latest_results(results_dir: Path, prefix: str) -> Optional[Path]:
    """Find the most recent results file with given prefix"""
    pattern = f"{prefix}-*.json"
    files = list(results_dir.glob(pattern))

    if not files:
        # Try txt for Swift
        pattern = f"{prefix}-*.txt"
        files = list(results_dir.glob(pattern))

    if not files:
        return None

    # Sort by modification time, newest first
    files.sort(key=lambda f: f.stat().st_mtime, reverse=True)
    return files[0]


def find_baseline_results(results_dir: Path, prefix: str) -> Optional[Path]:
    """Find baseline results file"""
    baseline = results_dir / f"{prefix}-baseline.json"
    if baseline.exists():
        return baseline

    # Try txt for Swift
    baseline = results_dir / f"{prefix}-baseline.txt"
    if baseline.exists():
        return baseline

    # Fall back to second most recent file
    pattern = f"{prefix}-*.json"
    files = list(results_dir.glob(pattern))

    if not files:
        pattern = f"{prefix}-*.txt"
        files = list(results_dir.glob(pattern))

    if len(files) < 2:
        return None

    files.sort(key=lambda f: f.stat().st_mtime, reverse=True)
    return files[1]


def compare_results(
    baseline: dict[str, BenchmarkResult],
    latest: dict[str, BenchmarkResult],
    threshold: float = 5.0
) -> list[ComparisonResult]:
    """Compare two sets of benchmark results"""
    comparisons = []

    all_names = set(baseline.keys()) | set(latest.keys())

    for name in sorted(all_names):
        if name not in baseline or name not in latest:
            continue

        base = baseline[name]
        curr = latest[name]

        if base.value == 0:
            change_percent = 0.0
        else:
            change_percent = ((curr.value - base.value) / base.value) * 100

        # For timing benchmarks, positive change = regression (slower)
        is_regression = change_percent > threshold
        is_improvement = change_percent < -threshold

        comparisons.append(ComparisonResult(
            name=name,
            baseline_value=base.value,
            latest_value=curr.value,
            unit=base.unit,
            change_percent=change_percent,
            is_regression=is_regression,
            is_improvement=is_improvement
        ))

    return comparisons


def format_value(value: float, unit: str) -> str:
    """Format a benchmark value with appropriate precision"""
    if unit == "ns":
        if value >= 1_000_000_000:
            return f"{value / 1_000_000_000:.2f}s"
        elif value >= 1_000_000:
            return f"{value / 1_000_000:.2f}ms"
        elif value >= 1_000:
            return f"{value / 1_000:.2f}us"
        else:
            return f"{value:.0f}ns"
    elif unit == "ms":
        if value >= 1000:
            return f"{value / 1000:.2f}s"
        else:
            return f"{value:.2f}ms"
    elif unit == "s":
        return f"{value:.3f}s"
    else:
        return f"{value:.2f}{unit}"


def generate_markdown_report(
    rust_comparisons: list[ComparisonResult],
    swift_comparisons: list[ComparisonResult],
    metadata: dict[str, Any],
    baseline_metadata: Optional[dict[str, Any]] = None
) -> str:
    """Generate a markdown comparison report"""
    lines = []

    # Header
    lines.append("# Performance Comparison Report")
    lines.append("")
    lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("")

    # Metadata
    lines.append("## Environment")
    lines.append("")
    lines.append("| Property | Current | Baseline |")
    lines.append("|----------|---------|----------|")
    lines.append(f"| Commit | `{metadata.get('commit_hash', 'unknown')}` | `{baseline_metadata.get('commit_hash', 'unknown') if baseline_metadata else 'N/A'}` |")
    lines.append(f"| Branch | `{metadata.get('branch', 'unknown')}` | `{baseline_metadata.get('branch', 'unknown') if baseline_metadata else 'N/A'}` |")
    lines.append(f"| Date | {metadata.get('commit_date', 'unknown')} | {baseline_metadata.get('commit_date', 'unknown') if baseline_metadata else 'N/A'} |")
    lines.append("")

    # Summary
    total_tests = len(rust_comparisons) + len(swift_comparisons)
    regressions = sum(1 for c in rust_comparisons + swift_comparisons if c.is_regression)
    improvements = sum(1 for c in rust_comparisons + swift_comparisons if c.is_improvement)
    unchanged = total_tests - regressions - improvements

    lines.append("## Summary")
    lines.append("")

    if regressions > 0:
        lines.append(f"**{regressions} regression(s) detected**")
        lines.append("")

    lines.append(f"- Total benchmarks: {total_tests}")
    lines.append(f"- Improvements: {improvements}")
    lines.append(f"- Regressions: {regressions}")
    lines.append(f"- Unchanged: {unchanged}")
    lines.append("")

    # Rust Benchmarks
    if rust_comparisons:
        lines.append("## Rust Benchmarks")
        lines.append("")
        lines.append("| Benchmark | Baseline | Current | Change |")
        lines.append("|-----------|----------|---------|--------|")

        for c in rust_comparisons:
            base_str = format_value(c.baseline_value, c.unit)
            curr_str = format_value(c.latest_value, c.unit)

            if c.is_regression:
                change_str = f"+{c.change_percent:.2f}%"
                status = "regression"
            elif c.is_improvement:
                change_str = f"{c.change_percent:.2f}%"
                status = "improvement"
            else:
                change_str = f"{c.change_percent:+.2f}%"
                status = "unchanged"

            lines.append(f"| {c.name} | {base_str} | {curr_str} | {change_str} ({status}) |")

        lines.append("")

    # Swift Performance Tests
    if swift_comparisons:
        lines.append("## Swift Performance Tests")
        lines.append("")
        lines.append("| Test | Baseline | Current | Change |")
        lines.append("|------|----------|---------|--------|")

        for c in swift_comparisons:
            base_str = format_value(c.baseline_value, c.unit)
            curr_str = format_value(c.latest_value, c.unit)

            if c.is_regression:
                change_str = f"+{c.change_percent:.2f}%"
                status = "regression"
            elif c.is_improvement:
                change_str = f"{c.change_percent:.2f}%"
                status = "improvement"
            else:
                change_str = f"{c.change_percent:+.2f}%"
                status = "unchanged"

            lines.append(f"| {c.name} | {base_str} | {curr_str} | {change_str} ({status}) |")

        lines.append("")

    # Details section for regressions
    regression_list = [c for c in rust_comparisons + swift_comparisons if c.is_regression]
    if regression_list:
        lines.append("## Regressions Requiring Investigation")
        lines.append("")
        for c in regression_list:
            lines.append(f"### {c.name}")
            lines.append("")
            lines.append(f"- Baseline: {format_value(c.baseline_value, c.unit)}")
            lines.append(f"- Current: {format_value(c.latest_value, c.unit)}")
            lines.append(f"- Regression: +{c.change_percent:.2f}%")
            lines.append("")

    # Improvements section
    improvement_list = [c for c in rust_comparisons + swift_comparisons if c.is_improvement]
    if improvement_list:
        lines.append("## Notable Improvements")
        lines.append("")
        for c in improvement_list:
            lines.append(f"- **{c.name}**: {format_value(c.baseline_value, c.unit)} -> {format_value(c.latest_value, c.unit)} ({c.change_percent:.2f}%)")
        lines.append("")

    return "\n".join(lines)


def generate_json_report(
    rust_comparisons: list[ComparisonResult],
    swift_comparisons: list[ComparisonResult],
    metadata: dict[str, Any]
) -> str:
    """Generate a JSON comparison report"""
    report = {
        "generated": datetime.now().isoformat(),
        "metadata": metadata,
        "summary": {
            "total": len(rust_comparisons) + len(swift_comparisons),
            "regressions": sum(1 for c in rust_comparisons + swift_comparisons if c.is_regression),
            "improvements": sum(1 for c in rust_comparisons + swift_comparisons if c.is_improvement),
        },
        "rust": [
            {
                "name": c.name,
                "baseline": c.baseline_value,
                "current": c.latest_value,
                "unit": c.unit,
                "change_percent": c.change_percent,
                "status": "regression" if c.is_regression else ("improvement" if c.is_improvement else "unchanged")
            }
            for c in rust_comparisons
        ],
        "swift": [
            {
                "name": c.name,
                "baseline": c.baseline_value,
                "current": c.latest_value,
                "unit": c.unit,
                "change_percent": c.change_percent,
                "status": "regression" if c.is_regression else ("improvement" if c.is_improvement else "unchanged")
            }
            for c in swift_comparisons
        ]
    }

    return json.dumps(report, indent=2)


def load_metadata(results_dir: Path, identifier: Optional[str] = None) -> dict[str, Any]:
    """Load metadata for a benchmark run"""
    if identifier:
        metadata_path = results_dir / f"metadata-{identifier}.json"
    else:
        # Find latest metadata file
        files = list(results_dir.glob("metadata-*.json"))
        if not files:
            return {}
        files.sort(key=lambda f: f.stat().st_mtime, reverse=True)
        metadata_path = files[0]

    if metadata_path.exists():
        try:
            with open(metadata_path) as f:
                return json.load(f)
        except json.JSONDecodeError:
            pass

    return {}


def main():
    parser = argparse.ArgumentParser(
        description="Compare benchmark results and generate reports"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("benchmark-results"),
        help="Directory containing benchmark results"
    )
    parser.add_argument(
        "--latest",
        type=str,
        help="Timestamp-commit ID of latest run"
    )
    parser.add_argument(
        "--baseline",
        type=str,
        help="Timestamp-commit ID of baseline run"
    )
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="markdown",
        help="Output format"
    )
    parser.add_argument(
        "--threshold",
        type=float,
        default=5.0,
        help="Regression threshold percentage"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose output"
    )
    parser.add_argument(
        "-o", "--output",
        type=Path,
        help="Output file path (default: stdout or auto-generated)"
    )

    args = parser.parse_args()

    results_dir = args.output_dir
    if not results_dir.exists():
        print(f"Error: Results directory not found: {results_dir}")
        sys.exit(1)

    # Find latest results
    if args.latest:
        rust_latest_path = results_dir / f"rust-{args.latest}.json"
        swift_latest_path = results_dir / f"swift-{args.latest}.txt"
    else:
        rust_latest_path = find_latest_results(results_dir, "rust")
        swift_latest_path = find_latest_results(results_dir, "swift")

    # Find baseline results
    if args.baseline:
        rust_baseline_path = results_dir / f"rust-{args.baseline}.json"
        swift_baseline_path = results_dir / f"swift-{args.baseline}.txt"
    else:
        rust_baseline_path = find_baseline_results(results_dir, "rust")
        swift_baseline_path = find_baseline_results(results_dir, "swift")

    if args.verbose:
        print(f"Rust latest: {rust_latest_path}")
        print(f"Rust baseline: {rust_baseline_path}")
        print(f"Swift latest: {swift_latest_path}")
        print(f"Swift baseline: {swift_baseline_path}")

    # Parse results
    rust_latest = parse_rust_results(rust_latest_path) if rust_latest_path and rust_latest_path.exists() else {}
    rust_baseline = parse_rust_results(rust_baseline_path) if rust_baseline_path and rust_baseline_path.exists() else {}
    swift_latest = parse_swift_results(swift_latest_path) if swift_latest_path and swift_latest_path.exists() else {}
    swift_baseline = parse_swift_results(swift_baseline_path) if swift_baseline_path and swift_baseline_path.exists() else {}

    if not rust_latest and not swift_latest:
        print("Error: No benchmark results found to compare")
        sys.exit(1)

    # Compare results
    rust_comparisons = compare_results(rust_baseline, rust_latest, args.threshold)
    swift_comparisons = compare_results(swift_baseline, swift_latest, args.threshold)

    # Load metadata
    metadata = load_metadata(results_dir, args.latest)
    baseline_metadata = load_metadata(results_dir, args.baseline) if args.baseline else None

    # Generate report
    if args.format == "markdown":
        report = generate_markdown_report(
            rust_comparisons,
            swift_comparisons,
            metadata,
            baseline_metadata
        )
    else:
        report = generate_json_report(rust_comparisons, swift_comparisons, metadata)

    # Output report
    if args.output:
        output_path = args.output
    else:
        timestamp = metadata.get("timestamp", datetime.now().strftime("%Y%m%d-%H%M%S"))
        commit = metadata.get("commit_hash", "unknown")
        ext = "md" if args.format == "markdown" else "json"
        output_path = results_dir / f"report-{timestamp}-{commit}.{ext}"

    with open(output_path, "w") as f:
        f.write(report)

    print(f"Report generated: {output_path}")

    # Exit with error code if regressions found
    total_regressions = sum(1 for c in rust_comparisons + swift_comparisons if c.is_regression)
    if total_regressions > 0:
        print(f"Warning: {total_regressions} regression(s) detected")
        sys.exit(1)


if __name__ == "__main__":
    main()
