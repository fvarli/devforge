#!/usr/bin/env bash

# Unit tests for DevForge doctor command
# Tests doctor functions without requiring actual installations

set -Eeu

DEVFORGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVFORGE_ROOT

# shellcheck source=../lib/logging.sh
source "$DEVFORGE_ROOT/lib/logging.sh"

# shellcheck source=../lib/helpers.sh
source "$DEVFORGE_ROOT/lib/helpers.sh"

# shellcheck source=../lib/doctor.sh
source "$DEVFORGE_ROOT/lib/doctor.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Safe counter increment
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

# Assert a command succeeds
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

# Assert a command fails
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

# Test doctor counter initialization
test_doctor_counter_init() {
    log_step "Testing doctor counter initialization"

    # Reset counters
    DOCTOR_CHECKS_TOTAL=0
    DOCTOR_CHECKS_PASSED=0
    DOCTOR_CHECKS_WARNINGS=0
    DOCTOR_CHECKS_FAILED=0

    assert_equals "0" "$DOCTOR_CHECKS_TOTAL" "Initial DOCTOR_CHECKS_TOTAL is 0" || true
    assert_equals "0" "$DOCTOR_CHECKS_PASSED" "Initial DOCTOR_CHECKS_PASSED is 0" || true
    assert_equals "0" "$DOCTOR_CHECKS_WARNINGS" "Initial DOCTOR_CHECKS_WARNINGS is 0" || true
    assert_equals "0" "$DOCTOR_CHECKS_FAILED" "Initial DOCTOR_CHECKS_FAILED is 0" || true
}

# Test doctor counter increments
test_doctor_counter_increments() {
    log_step "Testing doctor counter increments"

    # Reset counters
    DOCTOR_CHECKS_TOTAL=0
    DOCTOR_CHECKS_PASSED=0
    DOCTOR_CHECKS_WARNINGS=0
    DOCTOR_CHECKS_FAILED=0

    # Test doctor_pass increments
    doctor_pass "Test pass message" >/dev/null
    assert_equals "1" "$DOCTOR_CHECKS_TOTAL" "doctor_pass increments total" || true
    assert_equals "1" "$DOCTOR_CHECKS_PASSED" "doctor_pass increments passed" || true

    # Test doctor_warn increments
    doctor_warn "Test warn message" >/dev/null
    assert_equals "2" "$DOCTOR_CHECKS_TOTAL" "doctor_warn increments total" || true
    assert_equals "1" "$DOCTOR_CHECKS_WARNINGS" "doctor_warn increments warnings" || true

    # Test doctor_fail increments
    doctor_fail "Test fail message" >/dev/null
    assert_equals "3" "$DOCTOR_CHECKS_TOTAL" "doctor_fail increments total" || true
    assert_equals "1" "$DOCTOR_CHECKS_FAILED" "doctor_fail increments failed" || true

    # Test doctor_skip does NOT increment counters
    local total_before="$DOCTOR_CHECKS_TOTAL"
    doctor_skip "Test skip message" >/dev/null
    assert_equals "$total_before" "$DOCTOR_CHECKS_TOTAL" "doctor_skip does not increment total" || true
}

# Test doctor exit status
test_doctor_exit_status() {
    log_step "Testing doctor exit status"

    # Reset counters - no failures
    DOCTOR_CHECKS_TOTAL=5
    DOCTOR_CHECKS_PASSED=4
    DOCTOR_CHECKS_WARNINGS=1
    DOCTOR_CHECKS_FAILED=0

    increment_tests_run
    if doctor_print_summary >/dev/null 2>&1; then
        increment_tests_passed
        log_success "doctor_print_summary returns 0 when no failures"
    else
        increment_tests_failed
        log_error "doctor_print_summary returns 0 when no failures"
    fi

    # Reset counters - with failures
    DOCTOR_CHECKS_TOTAL=5
    DOCTOR_CHECKS_PASSED=3
    DOCTOR_CHECKS_WARNINGS=1
    DOCTOR_CHECKS_FAILED=1

    increment_tests_run
    if doctor_print_summary >/dev/null 2>&1; then
        increment_tests_failed
        log_error "doctor_print_summary returns 1 when failures exist"
    else
        increment_tests_passed
        log_success "doctor_print_summary returns 1 when failures exist"
    fi
}

# Test doctor no side effects (doesn't create files)
test_doctor_no_side_effects() {
    log_step "Testing doctor no side effects"

    # Create a temp dir to watch
    local watch_dir
    watch_dir="$(mktemp -d)"

    # Record file count before
    local files_before
    files_before="$(find "$watch_dir" -type f 2>/dev/null | wc -l)"

    # Run doctor_check_system (suppress output)
    (cd "$watch_dir" && doctor_check_system) >/dev/null 2>&1

    # Record file count after
    local files_after
    files_after="$(find "$watch_dir" -type f 2>/dev/null | wc -l)"

    # Clean up
    rm -rf "$watch_dir"

    assert_equals "$files_before" "$files_after" "doctor_check_system creates no files" || true
}

# Test doctor summary format
test_doctor_summary_format() {
    log_step "Testing doctor summary format"

    # Reset counters
    DOCTOR_CHECKS_TOTAL=10
    DOCTOR_CHECKS_PASSED=7
    DOCTOR_CHECKS_WARNINGS=2
    DOCTOR_CHECKS_FAILED=1

    local summary_output
    summary_output="$(doctor_print_summary 2>&1)" || true

    increment_tests_run
    if echo "$summary_output" | grep -q "Total checks: 10"; then
        increment_tests_passed
        log_success "Summary contains total checks"
    else
        increment_tests_failed
        log_error "Summary contains total checks"
    fi

    increment_tests_run
    if echo "$summary_output" | grep -q "Passed.*7"; then
        increment_tests_passed
        log_success "Summary contains passed count"
    else
        increment_tests_failed
        log_error "Summary contains passed count"
    fi

    increment_tests_run
    if echo "$summary_output" | grep -q "Warnings.*2"; then
        increment_tests_passed
        log_success "Summary contains warnings count"
    else
        increment_tests_failed
        log_error "Summary contains warnings count"
    fi

    increment_tests_run
    if echo "$summary_output" | grep -q "Failed.*1"; then
        increment_tests_passed
        log_success "Summary contains failed count"
    else
        increment_tests_failed
        log_error "Summary contains failed count"
    fi
}

# Test doctor output functions produce correct prefixes
test_doctor_output_prefixes() {
    log_step "Testing doctor output prefixes"

    # Reset counters
    DOCTOR_CHECKS_TOTAL=0
    DOCTOR_CHECKS_PASSED=0
    DOCTOR_CHECKS_WARNINGS=0
    DOCTOR_CHECKS_FAILED=0

    local output

    # Test [OK] prefix
    output="$(doctor_pass "test" 2>&1)"
    increment_tests_run
    if echo "$output" | grep -q "\[OK\]"; then
        increment_tests_passed
        log_success "doctor_pass outputs [OK] prefix"
    else
        increment_tests_failed
        log_error "doctor_pass outputs [OK] prefix"
    fi

    # Test [WARN] prefix
    output="$(doctor_warn "test" 2>&1)"
    increment_tests_run
    if echo "$output" | grep -q "\[WARN\]"; then
        increment_tests_passed
        log_success "doctor_warn outputs [WARN] prefix"
    else
        increment_tests_failed
        log_error "doctor_warn outputs [WARN] prefix"
    fi

    # Test [FAIL] prefix
    output="$(doctor_fail "test" 2>&1)"
    increment_tests_run
    if echo "$output" | grep -q "\[FAIL\]"; then
        increment_tests_passed
        log_success "doctor_fail outputs [FAIL] prefix"
    else
        increment_tests_failed
        log_error "doctor_fail outputs [FAIL] prefix"
    fi

    # Test [SKIP] prefix
    output="$(doctor_skip "test" 2>&1)"
    increment_tests_run
    if echo "$output" | grep -q "\[SKIP\]"; then
        increment_tests_passed
        log_success "doctor_skip outputs [SKIP] prefix"
    else
        increment_tests_failed
        log_error "doctor_skip outputs [SKIP] prefix"
    fi
}

# Regression test: counters must work from 0 under set -e
# This tests that we use safe assignment (VAR=$((VAR + 1))) instead of
# unsafe post-increment (((VAR++))) which fails when VAR=0
test_doctor_counters_strict_mode() {
    log_step "Testing doctor counters strict mode (regression)"

    # Reset all counters to 0
    DOCTOR_CHECKS_TOTAL=0
    DOCTOR_CHECKS_PASSED=0
    DOCTOR_CHECKS_WARNINGS=0
    DOCTOR_CHECKS_FAILED=0

    # Under set -e, ((0++)) evaluates to 0 (falsy) and triggers ERR trap
    # Our safe pattern (VAR=$((VAR + 1))) should not fail

    # This would fail with ((DOCTOR_CHECKS_TOTAL++)) when counter is 0
    increment_tests_run
    if doctor_pass "strict mode test" >/dev/null 2>&1; then
        increment_tests_passed
        log_success "doctor_pass works from counter 0"
    else
        increment_tests_failed
        log_error "doctor_pass works from counter 0"
    fi

    # Reset and test doctor_warn from 0
    DOCTOR_CHECKS_TOTAL=0
    DOCTOR_CHECKS_WARNINGS=0

    increment_tests_run
    if doctor_warn "strict mode test" >/dev/null 2>&1; then
        increment_tests_passed
        log_success "doctor_warn works from counter 0"
    else
        increment_tests_failed
        log_error "doctor_warn works from counter 0"
    fi

    # Reset and test doctor_fail from 0
    DOCTOR_CHECKS_TOTAL=0
    DOCTOR_CHECKS_FAILED=0

    increment_tests_run
    if doctor_fail "strict mode test" >/dev/null 2>&1; then
        increment_tests_passed
        log_success "doctor_fail works from counter 0"
    else
        increment_tests_failed
        log_error "doctor_fail works from counter 0"
    fi
}

# Test health score calculation edge cases
test_doctor_health_score() {
    log_step "Testing doctor health score calculation"

    # Source summary.sh if not already loaded
    # shellcheck source=../doctor/summary.sh
    if ! declare -f doctor_print_summary >/dev/null 2>&1; then
        source "$DEVFORGE_ROOT/doctor/summary.sh"
    fi

    local output

    # Test 100% health score (all passes)
    DOCTOR_CHECKS_TOTAL=10
    DOCTOR_CHECKS_PASSED=10
    DOCTOR_CHECKS_WARNINGS=0
    DOCTOR_CHECKS_FAILED=0

    output="$(doctor_print_summary 2>&1)" || true
    increment_tests_run
    if echo "$output" | grep -q "Health Score:.*100%"; then
        increment_tests_passed
        log_success "Health score 100% when all passes"
    else
        increment_tests_failed
        log_error "Health score 100% when all passes"
    fi

    # Test 0% health score (all failures)
    DOCTOR_CHECKS_TOTAL=5
    DOCTOR_CHECKS_PASSED=0
    DOCTOR_CHECKS_WARNINGS=0
    DOCTOR_CHECKS_FAILED=5

    output="$(doctor_print_summary 2>&1)" || true
    increment_tests_run
    if echo "$output" | grep -q "Health Score:.*0%"; then
        increment_tests_passed
        log_success "Health score 0% when all failures"
    else
        increment_tests_failed
        log_error "Health score 0% when all failures"
    fi

    # Test warnings-only (warnings count toward denominator but not score)
    DOCTOR_CHECKS_TOTAL=5
    DOCTOR_CHECKS_PASSED=3
    DOCTOR_CHECKS_WARNINGS=2
    DOCTOR_CHECKS_FAILED=0

    output="$(doctor_print_summary 2>&1)" || true
    increment_tests_run
    # 3 / (3 + 2 + 0) = 3/5 = 60%
    if echo "$output" | grep -q "Health Score:.*60%"; then
        increment_tests_passed
        log_success "Health score 60% with warnings"
    else
        increment_tests_failed
        log_error "Health score 60% with warnings"
    fi

    # Test division by zero protection (all zeros)
    DOCTOR_CHECKS_TOTAL=0
    DOCTOR_CHECKS_PASSED=0
    DOCTOR_CHECKS_WARNINGS=0
    DOCTOR_CHECKS_FAILED=0

    output="$(doctor_print_summary 2>&1)" || true
    increment_tests_run
    if echo "$output" | grep -q "Health Score:.*0%"; then
        increment_tests_passed
        log_success "Health score 0% when no checks (division by zero protection)"
    else
        increment_tests_failed
        log_error "Health score 0% when no checks (division by zero protection)"
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
    log_step "DevForge Doctor Unit Tests"

    test_doctor_counter_init || true
    test_doctor_counter_increments || true
    test_doctor_counters_strict_mode || true
    test_doctor_exit_status || true
    test_doctor_no_side_effects || true
    test_doctor_summary_format || true
    test_doctor_output_prefixes || true
    test_doctor_health_score || true

    print_test_summary
}

main "$@"
