#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2021-2025
#
# Benchmark tracking script for OSX Cleaner
# Runs Rust and Swift benchmarks and exports results for historical tracking.

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="${PROJECT_ROOT}/benchmark-results"
RUST_CORE_DIR="${PROJECT_ROOT}/rust-core"

# Timestamp and commit info
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
COMMIT_HASH=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
COMMIT_DATE=$(git -C "$PROJECT_ROOT" show -s --format=%ci HEAD 2>/dev/null | cut -d' ' -f1 || echo "unknown")
BRANCH_NAME=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# Output files
RUST_RESULTS="${RESULTS_DIR}/rust-${TIMESTAMP}-${COMMIT_HASH}.json"
SWIFT_RESULTS="${RESULTS_DIR}/swift-${TIMESTAMP}-${COMMIT_HASH}.txt"
METADATA_FILE="${RESULTS_DIR}/metadata-${TIMESTAMP}-${COMMIT_HASH}.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Run benchmarks and export results for historical tracking.

Options:
    -h, --help          Show this help message
    -r, --rust-only     Run only Rust benchmarks
    -s, --swift-only    Run only Swift performance tests
    -c, --compare       Generate comparison report after running
    -b, --baseline      Save as baseline for future comparisons
    -o, --output DIR    Override output directory (default: benchmark-results/)
    -v, --verbose       Show detailed output

Examples:
    $(basename "$0")                    # Run all benchmarks
    $(basename "$0") --rust-only        # Run only Rust benchmarks
    $(basename "$0") --compare          # Run all and generate comparison
    $(basename "$0") -o ./my-results    # Custom output directory

EOF
}

# Parse arguments
RUN_RUST=true
RUN_SWIFT=true
GENERATE_COMPARISON=false
SAVE_BASELINE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -r|--rust-only)
            RUN_RUST=true
            RUN_SWIFT=false
            shift
            ;;
        -s|--swift-only)
            RUN_RUST=false
            RUN_SWIFT=true
            shift
            ;;
        -c|--compare)
            GENERATE_COMPARISON=true
            shift
            ;;
        -b|--baseline)
            SAVE_BASELINE=true
            shift
            ;;
        -o|--output)
            RESULTS_DIR="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Create results directory
mkdir -p "$RESULTS_DIR"

# Write metadata
write_metadata() {
    log_info "Writing metadata..."
    cat > "$METADATA_FILE" << EOF
{
    "timestamp": "${TIMESTAMP}",
    "commit_hash": "${COMMIT_HASH}",
    "commit_date": "${COMMIT_DATE}",
    "branch": "${BRANCH_NAME}",
    "rust_version": "$(rustc --version 2>/dev/null || echo 'not installed')",
    "swift_version": "$(swift --version 2>/dev/null | head -1 || echo 'not installed')",
    "os_version": "$(sw_vers -productVersion 2>/dev/null || uname -r)",
    "hostname": "$(hostname)",
    "cpu_info": "$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'unknown')"
}
EOF
    log_success "Metadata written to: $METADATA_FILE"
}

# Run Rust benchmarks
run_rust_benchmarks() {
    log_info "Running Rust benchmarks..."

    if [[ ! -d "$RUST_CORE_DIR" ]]; then
        log_error "Rust core directory not found: $RUST_CORE_DIR"
        return 1
    fi

    cd "$RUST_CORE_DIR"

    # Check if criterion is available
    if ! cargo bench --help &>/dev/null; then
        log_error "Cargo bench not available"
        return 1
    fi

    # Run benchmarks and capture output
    local bench_output
    if [[ "$VERBOSE" == "true" ]]; then
        cargo bench --message-format=json 2>&1 | tee /tmp/rust_bench_output.txt || true
        bench_output=$(cat /tmp/rust_bench_output.txt)
    else
        bench_output=$(cargo bench 2>&1) || true
    fi

    # Parse criterion output and convert to JSON
    # Criterion stores detailed results in target/criterion/
    local criterion_dir="${RUST_CORE_DIR}/target/criterion"

    # Create JSON output with parsed results
    {
        echo "{"
        echo "  \"timestamp\": \"${TIMESTAMP}\","
        echo "  \"commit\": \"${COMMIT_HASH}\","
        echo "  \"benchmarks\": {"

        local first=true

        # Parse benchmark groups from criterion output
        while IFS= read -r line; do
            if [[ "$line" =~ time:.*\[([0-9.]+)\ ([a-zμ]+)\ ([0-9.]+)\ ([a-zμ]+)\ ([0-9.]+)\ ([a-zμ]+)\] ]]; then
                # Extract timing info from criterion output
                local mean="${BASH_REMATCH[3]}"
                local unit="${BASH_REMATCH[4]}"

                # Get the benchmark name from the previous line context
                local bench_name
                bench_name=$(echo "$prev_line" | sed -n 's/.*\(bench[^ ]*\|classify[^ ]*\|validate[^ ]*\).*/\1/p' | head -1)

                if [[ -n "$bench_name" && -n "$mean" ]]; then
                    if [[ "$first" == "false" ]]; then
                        echo ","
                    fi
                    first=false

                    # Convert to nanoseconds for consistency
                    local ns_value
                    case "$unit" in
                        "ns") ns_value="$mean" ;;
                        "µs"|"us") ns_value=$(echo "$mean * 1000" | bc -l 2>/dev/null || echo "$mean") ;;
                        "ms") ns_value=$(echo "$mean * 1000000" | bc -l 2>/dev/null || echo "$mean") ;;
                        "s") ns_value=$(echo "$mean * 1000000000" | bc -l 2>/dev/null || echo "$mean") ;;
                        *) ns_value="$mean" ;;
                    esac

                    printf "    \"%s\": {\"mean_ns\": %s, \"unit\": \"%s\", \"value\": %s}" \
                        "$bench_name" "$ns_value" "$unit" "$mean"
                fi
            fi
            prev_line="$line"
        done <<< "$bench_output"

        echo ""
        echo "  },"
        echo "  \"raw_output\": $(echo "$bench_output" | head -100 | jq -Rs . 2>/dev/null || echo '""')"
        echo "}"
    } > "$RUST_RESULTS"

    # Also save the detailed criterion results if available
    if [[ -d "$criterion_dir" ]]; then
        local criterion_archive="${RESULTS_DIR}/criterion-${TIMESTAMP}-${COMMIT_HASH}.tar.gz"
        tar -czf "$criterion_archive" -C "$criterion_dir" . 2>/dev/null || true
        log_info "Criterion detailed results archived: $criterion_archive"
    fi

    log_success "Rust benchmark results saved to: $RUST_RESULTS"
    cd "$PROJECT_ROOT"
}

# Run Swift performance tests
run_swift_benchmarks() {
    log_info "Running Swift performance tests..."

    cd "$PROJECT_ROOT"

    # Check if Swift is available
    if ! command -v swift &>/dev/null; then
        log_error "Swift not available"
        return 1
    fi

    # Run Swift performance tests
    local swift_output
    if [[ "$VERBOSE" == "true" ]]; then
        swift test --filter Performance 2>&1 | tee "$SWIFT_RESULTS" || true
    else
        swift_output=$(swift test --filter Performance 2>&1) || true
        echo "$swift_output" > "$SWIFT_RESULTS"
    fi

    # Parse Swift test output and create JSON summary
    local swift_json="${RESULTS_DIR}/swift-${TIMESTAMP}-${COMMIT_HASH}.json"
    {
        echo "{"
        echo "  \"timestamp\": \"${TIMESTAMP}\","
        echo "  \"commit\": \"${COMMIT_HASH}\","
        echo "  \"tests\": {"

        local first=true
        while IFS= read -r line; do
            # Parse XCTest measure output format: measured [Time, seconds] average: 0.001
            if [[ "$line" =~ measured.*average:\ ([0-9.]+) ]]; then
                local avg="${BASH_REMATCH[1]}"
                local test_name
                test_name=$(echo "$prev_line" | sed -n "s/.*'\([^']*\)'.*/\1/p" | head -1)

                if [[ -n "$test_name" && -n "$avg" ]]; then
                    if [[ "$first" == "false" ]]; then
                        echo ","
                    fi
                    first=false
                    printf "    \"%s\": {\"average_seconds\": %s}" "$test_name" "$avg"
                fi
            fi
            # Also capture SLO results
            if [[ "$line" =~ exceeded\ SLO:\ ([0-9.]+)s ]]; then
                log_warning "SLO exceeded: $line"
            fi
            prev_line="$line"
        done < "$SWIFT_RESULTS"

        echo ""
        echo "  },"
        echo "  \"passed\": $(grep -c "passed" "$SWIFT_RESULTS" 2>/dev/null || echo 0),"
        echo "  \"failed\": $(grep -c "failed" "$SWIFT_RESULTS" 2>/dev/null || echo 0)"
        echo "}"
    } > "$swift_json"

    log_success "Swift performance results saved to: $SWIFT_RESULTS"
    log_success "Swift JSON summary saved to: $swift_json"
}

# Save as baseline
save_baseline() {
    log_info "Saving current results as baseline..."

    if [[ -f "$RUST_RESULTS" ]]; then
        cp "$RUST_RESULTS" "${RESULTS_DIR}/rust-baseline.json"
        log_success "Rust baseline saved"
    fi

    if [[ -f "$SWIFT_RESULTS" ]]; then
        cp "$SWIFT_RESULTS" "${RESULTS_DIR}/swift-baseline.txt"
        log_success "Swift baseline saved"
    fi

    cp "$METADATA_FILE" "${RESULTS_DIR}/baseline-metadata.json"
}

# Generate comparison report
generate_comparison() {
    log_info "Generating comparison report..."

    local compare_script="${SCRIPT_DIR}/compare-benchmarks.py"
    if [[ -f "$compare_script" ]]; then
        python3 "$compare_script" --output-dir "$RESULTS_DIR" --latest "$TIMESTAMP-$COMMIT_HASH"
    else
        log_warning "Comparison script not found: $compare_script"
        log_info "Run 'compare-benchmarks.py' manually after installation"
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "========================================"
    echo "Benchmark Tracking Complete"
    echo "========================================"
    echo "Timestamp:  ${TIMESTAMP}"
    echo "Commit:     ${COMMIT_HASH}"
    echo "Branch:     ${BRANCH_NAME}"
    echo ""
    echo "Output files:"
    ls -la "${RESULTS_DIR}"/*"${TIMESTAMP}"* 2>/dev/null | awk '{print "  " $NF}'
    echo ""

    if [[ "$SAVE_BASELINE" == "true" ]]; then
        echo "Baseline files saved."
    fi

    if [[ "$GENERATE_COMPARISON" == "true" ]]; then
        echo "Comparison report generated."
    fi
}

# Main execution
main() {
    log_info "Starting benchmark tracking for OSX Cleaner"
    log_info "Project root: $PROJECT_ROOT"
    log_info "Results directory: $RESULTS_DIR"
    echo ""

    write_metadata

    if [[ "$RUN_RUST" == "true" ]]; then
        run_rust_benchmarks || log_warning "Rust benchmarks failed or incomplete"
    fi

    if [[ "$RUN_SWIFT" == "true" ]]; then
        run_swift_benchmarks || log_warning "Swift benchmarks failed or incomplete"
    fi

    if [[ "$SAVE_BASELINE" == "true" ]]; then
        save_baseline
    fi

    if [[ "$GENERATE_COMPARISON" == "true" ]]; then
        generate_comparison
    fi

    print_summary
}

main "$@"
