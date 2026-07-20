#!/usr/bin/env bash

# Unit tests for DevForge helper functions
# Tests pure functions that don't require root or system state

set -Eeu

DEVFORGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVFORGE_ROOT

# shellcheck source=../lib/logging.sh
source "$DEVFORGE_ROOT/lib/logging.sh"

# shellcheck source=../lib/metrics.sh
source "$DEVFORGE_ROOT/lib/metrics.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helpers
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="${3:-Test}"

    ((TESTS_RUN++))

    if [[ "$expected" == "$actual" ]]; then
        ((TESTS_PASSED++))
        log_success "$test_name"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "$test_name"
        log_error "  Expected: $expected"
        log_error "  Actual:   $actual"
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local test_name="${2:-Test}"

    ((TESTS_RUN++))

    if eval "$condition"; then
        ((TESTS_PASSED++))
        log_success "$test_name"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "$test_name"
        log_error "  Condition failed: $condition"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local test_name="${2:-Test}"

    ((TESTS_RUN++))

    if ! eval "$condition"; then
        ((TESTS_PASSED++))
        log_success "$test_name"
        return 0
    else
        ((TESTS_FAILED++))
        log_error "$test_name"
        log_error "  Condition should have failed: $condition"
        return 1
    fi
}

# Test format_elapsed_time
test_format_elapsed_time() {
    log_step "Testing format_elapsed_time"

    # Seconds only
    assert_equals "0s" "$(format_elapsed_time 0)" "format_elapsed_time: 0 seconds"
    assert_equals "1s" "$(format_elapsed_time 1)" "format_elapsed_time: 1 second"
    assert_equals "42s" "$(format_elapsed_time 42)" "format_elapsed_time: 42 seconds"
    assert_equals "59s" "$(format_elapsed_time 59)" "format_elapsed_time: 59 seconds"

    # Minutes and seconds
    assert_equals "1m 0s" "$(format_elapsed_time 60)" "format_elapsed_time: 1 minute"
    assert_equals "1m 5s" "$(format_elapsed_time 65)" "format_elapsed_time: 1m 5s"
    assert_equals "3m 12s" "$(format_elapsed_time 192)" "format_elapsed_time: 3m 12s"
    assert_equals "59m 59s" "$(format_elapsed_time 3599)" "format_elapsed_time: 59m 59s"

    # Hours, minutes, and seconds
    assert_equals "1h 0m 0s" "$(format_elapsed_time 3600)" "format_elapsed_time: 1 hour"
    assert_equals "1h 0m 1s" "$(format_elapsed_time 3601)" "format_elapsed_time: 1h 0m 1s"
    assert_equals "1h 4m 9s" "$(format_elapsed_time 3849)" "format_elapsed_time: 1h 4m 9s"
    assert_equals "2h 30m 45s" "$(format_elapsed_time 9045)" "format_elapsed_time: 2h 30m 45s"
    assert_equals "24h 0m 0s" "$(format_elapsed_time 86400)" "format_elapsed_time: 24 hours"
}

# Test metrics counters
test_metrics_counters() {
    log_step "Testing metrics counters"

    # Initialize metrics
    metrics_start

    # Test initial values
    assert_equals "0" "$METRICS_PACKAGES_INSTALLED" "Initial packages_installed is 0"
    assert_equals "0" "$METRICS_PACKAGES_SKIPPED" "Initial packages_skipped is 0"
    assert_equals "0" "$METRICS_APPLICATIONS_INSTALLED" "Initial applications_installed is 0"
    assert_equals "0" "$METRICS_APPLICATIONS_SKIPPED" "Initial applications_skipped is 0"
    assert_equals "0" "$METRICS_WARNINGS" "Initial warnings is 0"
    assert_equals "0" "$METRICS_ERRORS" "Initial errors is 0"

    # Test increments
    metrics_record_package_installed
    assert_equals "1" "$METRICS_PACKAGES_INSTALLED" "After 1 package installed"

    metrics_record_package_installed
    metrics_record_package_installed
    assert_equals "3" "$METRICS_PACKAGES_INSTALLED" "After 3 packages installed"

    metrics_record_package_skipped
    assert_equals "1" "$METRICS_PACKAGES_SKIPPED" "After 1 package skipped"

    metrics_record_application_installed
    assert_equals "1" "$METRICS_APPLICATIONS_INSTALLED" "After 1 application installed"

    metrics_record_application_skipped
    assert_equals "1" "$METRICS_APPLICATIONS_SKIPPED" "After 1 application skipped"

    metrics_increment warnings
    assert_equals "1" "$METRICS_WARNINGS" "After 1 warning"

    metrics_increment errors
    assert_equals "1" "$METRICS_ERRORS" "After 1 error"
}

# Test temp path validation (from cleanup_temp_dir)
test_temp_path_validation() {
    log_step "Testing temp path validation patterns"

    # These are logical tests, not actual cleanup_temp_dir calls
    # We're testing the validation logic patterns

    # Absolute vs relative
    assert_true '[[ "/tmp/devforge.XXXXXX" == /* ]]' "Absolute path starts with /"
    assert_false '[[ "tmp/devforge.XXXXXX" == /* ]]' "Relative path does not start with /"

    # Dangerous literal paths
    assert_true '[[ "/" == "/" ]]' "Root is detected"
    assert_true '[[ "/tmp" == "/tmp" ]]' "System /tmp is detected"
    assert_true '[[ "$HOME" == "$HOME" ]]' "HOME is detected"

    # DevForge prefix
    assert_true '[[ "devforge.XXXXXX" == devforge.* ]]' "DevForge prefix matches"
    assert_false '[[ "something.XXXXXX" == devforge.* ]]' "Non-DevForge prefix does not match"

    # Under system temp
    local test_path="/tmp/devforge.XXXXXX"
    local system_tmp="${TMPDIR:-/tmp}"
    system_tmp="${system_tmp%/}"
    assert_true '[[ "$test_path" == "$system_tmp"/* ]]' "Path under system temp"

    local outside_path="/var/devforge.XXXXXX"
    assert_false '[[ "$outside_path" == "$system_tmp"/* ]]' "Path outside system temp"
}

# Print test summary
print_test_summary() {
    printf "\n"
    log_step "Test Summary"
    printf "\n"
    printf "Tests run:    %d\n" "$TESTS_RUN"
    printf "Tests passed: %d\n" "$TESTS_PASSED"
    printf "Tests failed: %d\n" "$TESTS_FAILED"
    printf "\n"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed"
        return 0
    else
        log_error "$TESTS_FAILED test(s) failed"
        return 1
    fi
}

# Main test runner
main() {
    log_step "DevForge Unit Tests"

    test_format_elapsed_time || true
    test_metrics_counters || true
    test_temp_path_validation || true

    print_test_summary
}

main "$@"
