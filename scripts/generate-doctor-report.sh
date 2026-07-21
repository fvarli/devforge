#!/usr/bin/env bash

# DevForge Doctor Report Generator
# Creates timestamped diagnostic reports in reports/ directory
#
# Usage:
#   ./scripts/generate-doctor-report.sh [options]
#
# Options:
#   --output-dir DIR   Save report to DIR instead of reports/
#   --quiet            Suppress console output (only write to file)
#   --help             Show this help message
#
# Exit codes:
#   0 - All doctor checks passed
#   1 - One or more doctor checks failed
#   2 - Script error (invalid arguments, etc.)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVFORGE_ROOT="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="$DEVFORGE_ROOT/reports"
QUIET_MODE=false

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --output-dir)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --output-dir requires a directory path" >&2
                    exit 2
                fi
                REPORTS_DIR="$2"
                shift 2
                ;;
            --quiet)
                QUIET_MODE=true
                shift
                ;;
            --help)
                grep '^#' "$0" | grep -v '!/usr/bin' | sed 's/^# \?//'
                exit 0
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                exit 2
                ;;
        esac
    done
}

# Generate report metadata header
generate_metadata() {
    local devforge_version
    devforge_version="$(grep 'DEVFORGE_VERSION=' "$DEVFORGE_ROOT/lib/cli.sh" | cut -d'"' -f2)"

    echo "========================================"
    echo "DevForge Doctor Report"
    echo "========================================"
    echo ""
    echo "Generated: $(date -Iseconds)"
    echo "Hostname:  $(hostname)"
    echo "User:      $(whoami)"
    echo "DevForge:  v${devforge_version}"
    echo ""
    echo "----------------------------------------"
    echo ""
}

# Run doctor and capture output with exit code preservation
run_doctor_with_capture() {
    local report_file="$1"

    # Create report with metadata and doctor output
    # Use a subshell to capture PIPESTATUS correctly
    {
        generate_metadata
        # Run doctor with NO_COLOR to ensure plain text output
        NO_COLOR=1 "$DEVFORGE_ROOT/install.sh" --doctor 2>&1
    } > "$report_file"
    local doctor_exit=${PIPESTATUS[0]}

    # Output to console unless quiet mode
    if [[ "$QUIET_MODE" != "true" ]]; then
        cat "$report_file"
    fi

    return "$doctor_exit"
}

main() {
    parse_args "$@"

    # Create reports directory if needed
    if ! mkdir -p "$REPORTS_DIR"; then
        echo "Error: Could not create reports directory: $REPORTS_DIR" >&2
        exit 2
    fi

    # Generate timestamped filename
    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"
    local report_file="$REPORTS_DIR/doctor-report-$timestamp.txt"

    # Run doctor and save report
    local doctor_exit=0
    if ! run_doctor_with_capture "$report_file"; then
        doctor_exit=1
    fi

    # Print report location
    echo ""
    echo "Report saved: $report_file"

    exit "$doctor_exit"
}

main "$@"
