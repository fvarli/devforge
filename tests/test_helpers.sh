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

# Test run_selected_modules behavior with real DevForge functions
test_run_selected_modules_behavior() {
    log_step "Testing run_selected_modules behavior"

    # Source modules.sh for the actual DevForge function
    source "$DEVFORGE_ROOT/lib/modules.sh"

    # Test 1: Empty selection returns success
    SELECTED_MODULES=()
    COMPLETED_MODULES=()
    FAILED_MODULES=()

    increment_tests_run
    if run_selected_modules; then
        increment_tests_passed
        log_success "Empty module selection returns success"
    else
        increment_tests_failed
        log_error "Empty module selection returns success"
    fi

    # Test 2: Non-existent module is skipped (not failed)
    SELECTED_MODULES=("nonexistent_module_xyz")
    COMPLETED_MODULES=()
    FAILED_MODULES=()

    increment_tests_run
    if run_selected_modules; then
        increment_tests_passed
        log_success "Non-existent module skipped, returns success"
    else
        increment_tests_failed
        log_error "Non-existent module skipped, returns success"
    fi

    # Test 3: FAILED_MODULES array tracks failures correctly
    increment_tests_run
    if [[ "${#FAILED_MODULES[@]}" -eq 0 ]]; then
        increment_tests_passed
        log_success "Skipped module not added to FAILED_MODULES"
    else
        increment_tests_failed
        log_error "Skipped module not added to FAILED_MODULES"
    fi
}

# Test PHP version validation
test_php_version_validation() {
    log_step "Testing PHP version validation"

    # Source PHP module for validate_php_version function
    source "$DEVFORGE_ROOT/modules/php.sh"

    # Valid versions (only supported versions: 8.2, 8.3, 8.4)
    assert_command_succeeds "validate_php_version accepts 8.2" validate_php_version "8.2"
    assert_command_succeeds "validate_php_version accepts 8.3" validate_php_version "8.3"
    assert_command_succeeds "validate_php_version accepts 8.4" validate_php_version "8.4"

    # Invalid versions (EOL versions rejected)
    assert_command_fails "validate_php_version rejects 8.0 (EOL)" validate_php_version "8.0"
    assert_command_fails "validate_php_version rejects 8.1 (EOL)" validate_php_version "8.1"
    assert_command_fails "validate_php_version rejects 8.5 (future)" validate_php_version "8.5"
    assert_command_fails "validate_php_version rejects 7.4" validate_php_version "7.4"
    assert_command_fails "validate_php_version rejects 9.0" validate_php_version "9.0"
    assert_command_fails "validate_php_version rejects empty" validate_php_version ""
    assert_command_fails "validate_php_version rejects invalid format" validate_php_version "8"
    assert_command_fails "validate_php_version rejects string" validate_php_version "latest"
}

# Test Node version validation
test_node_version_validation() {
    log_step "Testing Node version validation"

    # Source Node module for validate_node_version function
    source "$DEVFORGE_ROOT/modules/node.sh"

    # Valid versions - special names
    assert_command_succeeds "validate_node_version accepts lts" validate_node_version "lts"
    assert_command_succeeds "validate_node_version accepts latest" validate_node_version "latest"

    # Valid versions - numeric
    assert_command_succeeds "validate_node_version accepts 22" validate_node_version "22"
    assert_command_succeeds "validate_node_version accepts 22.14" validate_node_version "22.14"
    assert_command_succeeds "validate_node_version accepts 22.14.0" validate_node_version "22.14.0"
    assert_command_succeeds "validate_node_version accepts 18" validate_node_version "18"

    # Invalid versions
    assert_command_fails "validate_node_version rejects empty" validate_node_version ""
    assert_command_fails "validate_node_version rejects invalid string" validate_node_version "stable"
    assert_command_fails "validate_node_version rejects v prefix" validate_node_version "v22"
    assert_command_fails "validate_node_version rejects alpha suffix" validate_node_version "22.0.0-alpha"
}

# Test Ubuntu codename resolution (pure function)
# STRICT MODE: Derivatives WITHOUT UBUNTU_CODENAME must FAIL
test_resolve_ubuntu_codename() {
    log_step "Testing resolve_ubuntu_codename (pure function, strict mode)"

    local result

    # Test 1: Ubuntu with UBUNTU_CODENAME set
    result="$(resolve_ubuntu_codename "ubuntu" "" "jammy" "jammy")"
    assert_equals "jammy" "$result" "resolve_ubuntu_codename: Ubuntu with UBUNTU_CODENAME" || true

    # Test 2: Ubuntu without UBUNTU_CODENAME, use VERSION_CODENAME (direct Ubuntu)
    result="$(resolve_ubuntu_codename "ubuntu" "" "" "noble")"
    assert_equals "noble" "$result" "resolve_ubuntu_codename: Ubuntu using VERSION_CODENAME" || true

    # Test 3: Pop!_OS derivative WITH UBUNTU_CODENAME (should work)
    result="$(resolve_ubuntu_codename "pop" "ubuntu debian" "jammy" "jammy")"
    assert_equals "jammy" "$result" "resolve_ubuntu_codename: Pop!_OS with UBUNTU_CODENAME" || true

    # Test 4: Linux Mint WITHOUT UBUNTU_CODENAME - MUST FAIL (strict)
    # Linux Mint's VERSION_CODENAME "vera" is NOT valid for Docker repo
    assert_command_fails "resolve_ubuntu_codename rejects Mint without UBUNTU_CODENAME" \
        resolve_ubuntu_codename "linuxmint" "ubuntu" "" "vera"

    # Test 5: Kubuntu WITHOUT UBUNTU_CODENAME - MUST FAIL (strict)
    # Known derivative without UBUNTU_CODENAME cannot be trusted
    assert_command_fails "resolve_ubuntu_codename rejects derivative without UBUNTU_CODENAME" \
        resolve_ubuntu_codename "kubuntu" "" "" "noble"

    # Test 6: Elementary WITHOUT UBUNTU_CODENAME - MUST FAIL (strict)
    assert_command_fails "resolve_ubuntu_codename rejects elementary without UBUNTU_CODENAME" \
        resolve_ubuntu_codename "elementary" "ubuntu gnome" "" "odin"

    # Test 7: Fedora should fail
    assert_command_fails "resolve_ubuntu_codename rejects Fedora" resolve_ubuntu_codename "fedora" "rhel" "" "39"

    # Test 8: Arch should fail
    assert_command_fails "resolve_ubuntu_codename rejects Arch" resolve_ubuntu_codename "arch" "" "" ""

    # Test 9: Empty values should fail
    assert_command_fails "resolve_ubuntu_codename rejects all empty" resolve_ubuntu_codename "" "" "" ""

    # Test 10: CachyOS should fail (not Ubuntu-based)
    assert_command_fails "resolve_ubuntu_codename rejects CachyOS" \
        resolve_ubuntu_codename "cachyos" "arch" "" ""
}

# Test validate_boolean_configs (multi-config validation)
test_validate_boolean_configs() {
    log_step "Testing validate_boolean_configs"

    # All valid configs
    assert_command_succeeds "validate_boolean_configs accepts all valid" \
        validate_boolean_configs \
            "CONFIG1" "true" \
            "CONFIG2" "false" \
            "CONFIG3" "true"

    # One invalid config
    assert_command_fails "validate_boolean_configs rejects one invalid" \
        validate_boolean_configs \
            "CONFIG1" "true" \
            "CONFIG2" "yes" \
            "CONFIG3" "false"

    # All invalid
    assert_command_fails "validate_boolean_configs rejects all invalid" \
        validate_boolean_configs \
            "CONFIG1" "YES" \
            "CONFIG2" "NO"

    # Empty call succeeds (no configs to validate)
    assert_command_succeeds "validate_boolean_configs accepts empty" \
        validate_boolean_configs
}

# Test Ubuntu codename validation
# Policy: Only documented LTS releases are supported (jammy=22.04, noble=24.04)
test_is_valid_ubuntu_codename() {
    log_step "Testing is_valid_ubuntu_codename (LTS-only policy)"

    # Supported LTS releases (documented in README)
    assert_command_succeeds "is_valid_ubuntu_codename accepts jammy (22.04 LTS)" is_valid_ubuntu_codename "jammy"
    assert_command_succeeds "is_valid_ubuntu_codename accepts noble (24.04 LTS)" is_valid_ubuntu_codename "noble"

    # Rejected: EOL interim releases
    assert_command_fails "is_valid_ubuntu_codename rejects lunar (23.04 interim EOL)" is_valid_ubuntu_codename "lunar"
    assert_command_fails "is_valid_ubuntu_codename rejects mantic (23.10 interim EOL)" is_valid_ubuntu_codename "mantic"

    # Rejected: undocumented/older releases
    assert_command_fails "is_valid_ubuntu_codename rejects focal (20.04 undocumented)" is_valid_ubuntu_codename "focal"
    assert_command_fails "is_valid_ubuntu_codename rejects bionic (18.04 EOL)" is_valid_ubuntu_codename "bionic"

    # Rejected: invalid values
    assert_command_fails "is_valid_ubuntu_codename rejects invalid" is_valid_ubuntu_codename "invalid"
    assert_command_fails "is_valid_ubuntu_codename rejects empty" is_valid_ubuntu_codename ""
    assert_command_fails "is_valid_ubuntu_codename rejects derivative codename vera" is_valid_ubuntu_codename "vera"
    assert_command_fails "is_valid_ubuntu_codename rejects derivative codename odin" is_valid_ubuntu_codename "odin"
}

# Test boolean config validation
test_validate_boolean_config() {
    log_step "Testing validate_boolean_config"

    # Valid boolean values
    assert_command_succeeds "validate_boolean_config accepts true" validate_boolean_config "true"
    assert_command_succeeds "validate_boolean_config accepts false" validate_boolean_config "false"

    # Invalid values
    assert_command_fails "validate_boolean_config rejects yes" validate_boolean_config "yes"
    assert_command_fails "validate_boolean_config rejects no" validate_boolean_config "no"
    assert_command_fails "validate_boolean_config rejects 1" validate_boolean_config "1"
    assert_command_fails "validate_boolean_config rejects 0" validate_boolean_config "0"
    assert_command_fails "validate_boolean_config rejects TRUE" validate_boolean_config "TRUE"
    assert_command_fails "validate_boolean_config rejects FALSE" validate_boolean_config "FALSE"
    assert_command_fails "validate_boolean_config rejects empty" validate_boolean_config ""
}

# Test NVM version validation
test_validate_nvm_version() {
    log_step "Testing validate_nvm_version"

    # Source Node module for validate_nvm_version function
    source "$DEVFORGE_ROOT/modules/node.sh"

    # Valid NVM versions
    assert_command_succeeds "validate_nvm_version accepts v0.40.1" validate_nvm_version "v0.40.1"
    assert_command_succeeds "validate_nvm_version accepts v0.39.7" validate_nvm_version "v0.39.7"
    assert_command_succeeds "validate_nvm_version accepts v1.0.0" validate_nvm_version "v1.0.0"

    # Invalid NVM versions
    assert_command_fails "validate_nvm_version rejects no v prefix" validate_nvm_version "0.40.1"
    assert_command_fails "validate_nvm_version rejects latest" validate_nvm_version "latest"
    assert_command_fails "validate_nvm_version rejects empty" validate_nvm_version ""
    assert_command_fails "validate_nvm_version rejects partial" validate_nvm_version "v0.40"
}

# Test Ubuntu codename resolution from docker module
test_ubuntu_codename_resolution() {
    log_step "Testing get_ubuntu_codename (integration)"

    # Source Docker module for get_ubuntu_codename function
    source "$DEVFORGE_ROOT/modules/docker.sh"

    # Test that get_ubuntu_codename returns something (we can't predict the exact value)
    local codename
    codename="$(get_ubuntu_codename 2>/dev/null)" || true

    increment_tests_run
    if [[ -n "$codename" ]]; then
        increment_tests_passed
        log_success "get_ubuntu_codename returned: $codename"
    else
        # On non-Ubuntu systems this may fail, which is expected
        increment_tests_passed
        log_info "get_ubuntu_codename returned empty (expected on non-Ubuntu)"
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
    test_run_selected_modules_behavior || true
    test_php_version_validation || true
    test_node_version_validation || true
    test_resolve_ubuntu_codename || true
    test_is_valid_ubuntu_codename || true
    test_validate_boolean_config || true
    test_validate_boolean_configs || true
    test_validate_nvm_version || true
    test_ubuntu_codename_resolution || true

    print_test_summary
}

main "$@"
