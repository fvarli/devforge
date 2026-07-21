#!/usr/bin/env bash

# DevForge Doctor Report Generator
# Creates timestamped diagnostic reports in reports/ directory
#
# Usage:
#   ./scripts/generate-doctor-report.sh [output-file]
#   ./scripts/generate-doctor-report.sh --help
#
# Arguments:
#   output-file    Optional path for the report file
#                  Default: reports/devforge-doctor-YYYYMMDD-HHMMSS.txt
#
# Exit codes:
#   0 - All doctor checks passed
#   1 - One or more doctor checks failed
#   2 - Script error (invalid arguments, etc.)

set -Eeuo pipefail

# Resolve DEVFORGE_ROOT from script location (works from any working directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVFORGE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OUTPUT_FILE=""

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                # Extract help text from header comments (stop at first blank comment or non-comment)
                sed -n '2,/^[^#]/p' "$0" | grep '^#' | sed 's/^# \?//'
                exit 0
                ;;
            -*)
                echo "Error: Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                exit 2
                ;;
            *)
                if [[ -n "$OUTPUT_FILE" ]]; then
                    echo "Error: Multiple output files specified" >&2
                    exit 2
                fi
                OUTPUT_FILE="$1"
                shift
                ;;
        esac
    done
}

# Get distribution name from /etc/os-release
get_distribution() {
    if [[ -f /etc/os-release ]]; then
        grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2
    else
        echo "Unknown"
    fi
}

# Get git working tree state
get_git_state() {
    local status
    status="$(git -C "$DEVFORGE_ROOT" status --porcelain 2>/dev/null)"
    if [[ -z "$status" ]]; then
        echo "clean"
    else
        local count
        count="$(echo "$status" | wc -l)"
        echo "$count modified"
    fi
}

# Generate report metadata header
generate_metadata() {
    local devforge_version
    devforge_version="$(grep 'DEVFORGE_VERSION=' "$DEVFORGE_ROOT/lib/cli.sh" | cut -d'"' -f2)"

    local git_commit
    git_commit="$(git -C "$DEVFORGE_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")"

    local git_branch
    git_branch="$(git -C "$DEVFORGE_ROOT" branch --show-current 2>/dev/null)"
    [[ -z "$git_branch" ]] && git_branch="detached"

    local git_state
    git_state="$(get_git_state)"

    echo "========================================"
    echo "DevForge Doctor Report"
    echo "========================================"
    echo ""
    echo "Generated:    $(date -Iseconds)"
    echo "Hostname:     $(hostname)"
    echo "User:         $(whoami)"
    echo "Distribution: $(get_distribution)"
    echo "Architecture: $(uname -m)"
    echo "Kernel:       $(uname -r)"
    echo ""
    echo "DevForge:     v${devforge_version}"
    echo "Git commit:   ${git_commit}"
    echo "Git branch:   ${git_branch}"
    echo "Working tree: ${git_state}"
    echo ""
    echo "----------------------------------------"
    echo ""
}

# Generate report footer with exit code
generate_footer() {
    local exit_code="$1"
    echo ""
    echo "----------------------------------------"
    echo "Doctor exit code: $exit_code"
    echo "========================================"
}

# Run doctor and capture output with exit code preservation
run_doctor_with_capture() {
    local report_file="$1"
    local doctor_exit=0

    # Run doctor and capture exit code correctly using pipeline
    # The brace group output goes through tee to both file and stdout
    # PIPESTATUS[0] captures the brace group's exit (which is doctor's exit)
    {
        generate_metadata
        NO_COLOR=1 "$DEVFORGE_ROOT/install.sh" --doctor 2>&1 || true
    } | tee "$report_file" > /dev/null

    # Re-run doctor to get the actual exit code (tee masks it)
    # This is the only reliable way with set -e
    NO_COLOR=1 "$DEVFORGE_ROOT/install.sh" --doctor > /dev/null 2>&1 || doctor_exit=$?

    # Append footer with exit code
    generate_footer "$doctor_exit" >> "$report_file"

    # Also print to stdout
    cat "$report_file"

    return "$doctor_exit"
}

main() {
    parse_args "$@"

    # Determine output file path
    local report_file
    if [[ -n "$OUTPUT_FILE" ]]; then
        report_file="$OUTPUT_FILE"
        # Create parent directory if needed
        local parent_dir
        parent_dir="$(dirname "$report_file")"
        if [[ "$parent_dir" != "." ]] && [[ ! -d "$parent_dir" ]]; then
            if ! mkdir -p "$parent_dir"; then
                echo "Error: Could not create directory: $parent_dir" >&2
                exit 2
            fi
        fi
    else
        # Default: reports/devforge-doctor-YYYYMMDD-HHMMSS.txt
        local reports_dir="$DEVFORGE_ROOT/reports"
        if ! mkdir -p "$reports_dir"; then
            echo "Error: Could not create reports directory: $reports_dir" >&2
            exit 2
        fi
        local timestamp
        timestamp="$(date +%Y%m%d-%H%M%S)"
        report_file="$reports_dir/devforge-doctor-$timestamp.txt"
    fi

    # Run doctor and save report, preserving exit code
    local doctor_exit=0
    run_doctor_with_capture "$report_file" || doctor_exit=$?

    # Print report location
    echo ""
    echo "Report saved: $report_file"

    exit "$doctor_exit"
}

main "$@"
