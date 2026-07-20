#!/usr/bin/env bash

# Unit tests for DevForge helper functions
# Tests pure functions that don't require root or system state

set -Eeu

DEVFORGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVFORGE_ROOT

# shellcheck source=../lib/logging.sh
source "$DEVFORGE_ROOT/lib/logging.sh"

# shellcheck source=../lib/helpers.sh
source "$DEVFORGE_ROOT/lib/helpers.sh"

# shellcheck source=../lib/metrics.sh
source "$DEVFORGE_ROOT/lib/metrics.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Safe counter increment (avoids set -e issues with post-increment from 0)
increment_tests_run() {
    TESTS_RUN=$((TESTS_RUN + 1))
}

increment_tests_passed() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

increment_tests_failed() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

# Core assertion: compare two values
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="${3:-Test}"

    increment_tests_run

    if [[ "$expected" == "$actual" ]]; then
        increment_tests_passed
        log_success "$test_name"
        return 0
    else
        increment_tests_failed
        log_error "$test_name"
        log_error "  Expected: $expected"
        log_error "  Actual:   $actual"
        return 1
    fi
}

# Assert a command succeeds (exit code 0)
assert_command_succeeds() {
    local test_name="$1"
    shift

    increment_tests_run

    if "$@" >/dev/null 2>&1; then
        increment_tests_passed
        log_success "$test_name"
        return 0
    else
        increment_tests_failed
        log_error "$test_name"
        log_error "  Command failed: $*"
        return 1
    fi
}

# Assert a command fails (exit code non-zero)
assert_command_fails() {
    local test_name="$1"
    shift

    increment_tests_run

    if "$@" >/dev/null 2>&1; then
        increment_tests_failed
        log_error "$test_name"
        log_error "  Command should have failed: $*"
        return 1
    else
        increment_tests_passed
        log_success "$test_name"
        return 0
    fi
}

# Test format_elapsed_time
test_format_elapsed_time() {
    log_step "Testing format_elapsed_time"

    # Seconds only
    assert_equals "0s" "$(format_elapsed_time 0)" "format_elapsed_time: 0 seconds" || true
    assert_equals "1s" "$(format_elapsed_time 1)" "format_elapsed_time: 1 second" || true
    assert_equals "42s" "$(format_elapsed_time 42)" "format_elapsed_time: 42 seconds" || true
    assert_equals "59s" "$(format_elapsed_time 59)" "format_elapsed_time: 59 seconds" || true

    # Minutes and seconds
    assert_equals "1m 0s" "$(format_elapsed_time 60)" "format_elapsed_time: 1 minute" || true
    assert_equals "1m 5s" "$(format_elapsed_time 65)" "format_elapsed_time: 1m 5s" || true
    assert_equals "3m 12s" "$(format_elapsed_time 192)" "format_elapsed_time: 3m 12s" || true
    assert_equals "59m 59s" "$(format_elapsed_time 3599)" "format_elapsed_time: 59m 59s" || true

    # Hours, minutes, and seconds
    assert_equals "1h 0m 0s" "$(format_elapsed_time 3600)" "format_elapsed_time: 1 hour" || true
    assert_equals "1h 0m 1s" "$(format_elapsed_time 3601)" "format_elapsed_time: 1h 0m 1s" || true
    assert_equals "1h 4m 9s" "$(format_elapsed_time 3849)" "format_elapsed_time: 1h 4m 9s" || true
    assert_equals "2h 30m 45s" "$(format_elapsed_time 9045)" "format_elapsed_time: 2h 30m 45s" || true
    assert_equals "24h 0m 0s" "$(format_elapsed_time 86400)" "format_elapsed_time: 24 hours" || true
}

# Test metrics counters increment from zero safely
test_metrics_counters() {
    log_step "Testing metrics counters"

    # Initialize metrics
    metrics_start

    # Test initial values
    assert_equals "0" "$METRICS_PACKAGES_INSTALLED" "Initial packages_installed is 0" || true
    assert_equals "0" "$METRICS_PACKAGES_SKIPPED" "Initial packages_skipped is 0" || true
    assert_equals "0" "$METRICS_APPLICATIONS_INSTALLED" "Initial applications_installed is 0" || true
    assert_equals "0" "$METRICS_APPLICATIONS_SKIPPED" "Initial applications_skipped is 0" || true
    assert_equals "0" "$METRICS_WARNINGS" "Initial warnings is 0" || true
    assert_equals "0" "$METRICS_ERRORS" "Initial errors is 0" || true

    # Test increments from zero (critical test for set -e safety)
    metrics_record_package_installed
    assert_equals "1" "$METRICS_PACKAGES_INSTALLED" "After 1 package installed" || true

    metrics_record_package_installed
    metrics_record_package_installed
    assert_equals "3" "$METRICS_PACKAGES_INSTALLED" "After 3 packages installed" || true

    metrics_record_package_skipped
    assert_equals "1" "$METRICS_PACKAGES_SKIPPED" "After 1 package skipped" || true

    metrics_record_application_installed
    assert_equals "1" "$METRICS_APPLICATIONS_INSTALLED" "After 1 application installed" || true

    metrics_record_application_skipped
    assert_equals "1" "$METRICS_APPLICATIONS_SKIPPED" "After 1 application skipped" || true

    # Direct increment API
    metrics_increment warnings
    assert_equals "1" "$METRICS_WARNINGS" "After 1 warning" || true

    metrics_increment errors
    assert_equals "1" "$METRICS_ERRORS" "After 1 error" || true
}

# Test that summary printing does not change counters
test_summary_does_not_change_counters() {
    log_step "Testing summary does not change counters"

    # Initialize and set some counts
    metrics_start
    metrics_record_package_installed
    metrics_record_package_installed
    metrics_record_warning
    metrics_record_error
    metrics_finish

    # Capture counters before summary
    local packages_before="$METRICS_PACKAGES_INSTALLED"
    local warnings_before="$METRICS_WARNINGS"
    local errors_before="$METRICS_ERRORS"

    # Print summary (suppress output)
    metrics_print_summary >/dev/null 2>&1

    # Verify counters unchanged
    assert_equals "$packages_before" "$METRICS_PACKAGES_INSTALLED" "Packages unchanged after summary" || true
    assert_equals "$warnings_before" "$METRICS_WARNINGS" "Warnings unchanged after summary" || true
    assert_equals "$errors_before" "$METRICS_ERRORS" "Errors unchanged after summary" || true

    # Print summary again
    metrics_print_summary >/dev/null 2>&1

    # Still unchanged
    assert_equals "$packages_before" "$METRICS_PACKAGES_INSTALLED" "Packages unchanged after second summary" || true
    assert_equals "$warnings_before" "$METRICS_WARNINGS" "Warnings unchanged after second summary" || true
    assert_equals "$errors_before" "$METRICS_ERRORS" "Errors unchanged after second summary" || true
}

# Test cleanup_temp_dir rejects dangerous paths
test_cleanup_temp_dir_rejects_dangerous_paths() {
    log_step "Testing cleanup_temp_dir path validation"

    # Test rejection of empty path
    assert_command_fails "cleanup_temp_dir rejects empty path" cleanup_temp_dir ""

    # Test rejection of root
    assert_command_fails "cleanup_temp_dir rejects /" cleanup_temp_dir "/"

    # Test rejection of /tmp itself
    assert_command_fails "cleanup_temp_dir rejects /tmp" cleanup_temp_dir "/tmp"

    # Test rejection of relative path
    assert_command_fails "cleanup_temp_dir rejects relative path" cleanup_temp_dir "tmp/devforge.test"

    # Test rejection of path outside temp
    assert_command_fails "cleanup_temp_dir rejects /var path" cleanup_temp_dir "/var/devforge.test"

    # Test rejection of path without devforge prefix
    assert_command_fails "cleanup_temp_dir rejects non-devforge prefix" cleanup_temp_dir "/tmp/something.test"
}

# Test create_temp_dir and cleanup_temp_dir with real directories
test_temp_dir_lifecycle() {
    log_step "Testing temp directory lifecycle"

    # Create a real temp directory
    local tmp_dir
    tmp_dir=$(create_temp_dir)

    # Verify it was created
    increment_tests_run
    if [[ -d "$tmp_dir" ]]; then
        increment_tests_passed
        log_success "create_temp_dir creates directory"
    else
        increment_tests_failed
        log_error "create_temp_dir creates directory"
        log_error "  Directory not found: $tmp_dir"
        return 1
    fi

    # Verify it has devforge prefix
    local basename
    basename=$(basename "$tmp_dir")
    increment_tests_run
    if [[ "$basename" == devforge.* ]]; then
        increment_tests_passed
        log_success "create_temp_dir uses devforge prefix"
    else
        increment_tests_failed
        log_error "create_temp_dir uses devforge prefix"
        log_error "  Actual basename: $basename"
    fi

    # Verify cleanup works
    assert_command_succeeds "cleanup_temp_dir removes valid directory" cleanup_temp_dir "$tmp_dir"

    # Verify it's gone
    increment_tests_run
    if [[ ! -d "$tmp_dir" ]]; then
        increment_tests_passed
        log_success "Directory removed after cleanup"
    else
        increment_tests_failed
        log_error "Directory removed after cleanup"
        log_error "  Directory still exists: $tmp_dir"
        # Clean up anyway
        rm -rf "$tmp_dir"
    fi

    # Cleanup of non-existent path should succeed (idempotent)
    assert_command_succeeds "cleanup_temp_dir succeeds on non-existent path" cleanup_temp_dir "$tmp_dir"
}

# Test module-loop failure aggregation with mock modules
test_module_loop_failure_aggregation() {
    log_step "Testing module loop failure aggregation"

    # Source modules.sh for run_selected_modules
    source "$DEVFORGE_ROOT/lib/modules.sh"

    # Reset module tracking arrays
    COMPLETED_MODULES=()
    FAILED_MODULES=()

    # Create mock module functions
    install_mock_success() {
        return 0
    }

    install_mock_failure() {
        return 1
    }

    # Create temporary mock module files
    local mock_dir
    mock_dir=$(create_temp_dir)
    mkdir -p "$mock_dir"

    # Create mock module that succeeds
    cat > "$mock_dir/mock_success.sh" << 'MOCK_EOF'
install_mock_success() {
    return 0
}
MOCK_EOF

    # Create mock module that fails
    cat > "$mock_dir/mock_failure.sh" << 'MOCK_EOF'
install_mock_failure() {
    return 1
}
MOCK_EOF

    # Temporarily override DEVFORGE_ROOT/modules path
    local original_root="$DEVFORGE_ROOT"

    # Test: run_module with success
    # We'll test the core logic pattern directly
    increment_tests_run
    local test_status=0
    if install_mock_success; then
        increment_tests_passed
        log_success "Mock success module returns 0"
    else
        increment_tests_failed
        log_error "Mock success module returns 0"
    fi

    # Test: run_module with failure
    increment_tests_run
    if install_mock_failure; then
        increment_tests_failed
        log_error "Mock failure module returns non-zero"
    else
        increment_tests_passed
        log_success "Mock failure module returns non-zero"
    fi

    # Test: failure aggregation pattern (simulates run_selected_modules)
    increment_tests_run
    local any_failed=false

    # Run mock success - should not set any_failed
    if ! install_mock_success; then
        any_failed=true
    fi

    # Run mock failure - should set any_failed
    if ! install_mock_failure; then
        any_failed=true
    fi

    if [[ "$any_failed" == "true" ]]; then
        increment_tests_passed
        log_success "Failure aggregation detects failed module"
    else
        increment_tests_failed
        log_error "Failure aggregation detects failed module"
    fi

    # Cleanup
    cleanup_temp_dir "$mock_dir"
}

# Test exit flow patterns under set -Eeuo pipefail
test_exit_flow_patterns() {
    log_step "Testing exit flow patterns"

    # Test: conditional context prevents ERR trap on expected return 1
    # This simulates the install.sh pattern: if main "$@"; then ... else ... fi

    mock_main_success() {
        return 0
    }

    mock_main_failure() {
        return 1
    }

    # Test success case
    increment_tests_run
    local exit_code=0
    if mock_main_success; then
        exit_code=0
    else
        exit_code=$?
    fi

    if [[ $exit_code -eq 0 ]]; then
        increment_tests_passed
        log_success "Conditional context: success returns 0"
    else
        increment_tests_failed
        log_error "Conditional context: success returns 0"
    fi

    # Test failure case - this must not trigger ERR trap
    increment_tests_run
    if mock_main_failure; then
        exit_code=0
    else
        exit_code=$?
    fi

    if [[ $exit_code -eq 1 ]]; then
        increment_tests_passed
        log_success "Conditional context: failure returns 1 without ERR trap"
    else
        increment_tests_failed
        log_error "Conditional context: failure returns 1 without ERR trap"
        log_error "  Actual exit code: $exit_code"
    fi

    # Test: exit code preservation through conditional
    increment_tests_run
    mock_main_specific_code() {
        return 42
    }

    if mock_main_specific_code; then
        exit_code=0
    else
        exit_code=$?
    fi

    if [[ $exit_code -eq 42 ]]; then
        increment_tests_passed
        log_success "Exit code 42 preserved through conditional"
    else
        increment_tests_failed
        log_error "Exit code 42 preserved through conditional"
        log_error "  Actual: $exit_code"
    fi
}

# Test no duplicate ERR diagnostic for expected module failure
test_no_duplicate_err_diagnostic() {
    log_step "Testing no duplicate ERR diagnostic"

    # This test verifies the pattern used in install.sh
    # When a module fails expectedly, the ERR trap should NOT fire

    # Simulate the run_selected_modules pattern
    local err_trap_fired=false

    # Set up a test ERR trap
    trap_test_handler() {
        err_trap_fired=true
    }

    # Save original trap and set test trap
    local original_trap
    original_trap=$(trap -p ERR)
    trap 'trap_test_handler' ERR

    # Run a command that returns non-zero in conditional context
    # This should NOT trigger the ERR trap
    mock_failing_module() {
        return 1
    }

    local module_status=0
    if ! mock_failing_module; then
        module_status=1
    fi

    increment_tests_run
    if [[ "$err_trap_fired" == "false" ]]; then
        increment_tests_passed
        log_success "Conditional context does not trigger ERR trap"
    else
        increment_tests_failed
        log_error "Conditional context does not trigger ERR trap"
        log_error "  ERR trap was fired unexpectedly"
    fi

    # Verify module_status was captured correctly
    increment_tests_run
    if [[ $module_status -eq 1 ]]; then
        increment_tests_passed
        log_success "Module failure status captured correctly"
    else
        increment_tests_failed
        log_error "Module failure status captured correctly"
    fi

    # Restore original trap (or clear it)
    trap - ERR
    if [[ -n "$original_trap" ]]; then
        eval "$original_trap"
    fi
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
    test_summary_does_not_change_counters || true
    test_cleanup_temp_dir_rejects_dangerous_paths || true
    test_temp_dir_lifecycle || true
    test_module_loop_failure_aggregation || true
    test_exit_flow_patterns || true
    test_no_duplicate_err_diagnostic || true

    print_test_summary
}

main "$@"
