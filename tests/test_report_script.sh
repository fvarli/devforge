#!/usr/bin/env bash

# Unit tests for scripts/generate-doctor-report.sh
# Tests script structure and basic functionality without running full doctor

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVFORGE_ROOT="$(dirname "$SCRIPT_DIR")"
REPORT_SCRIPT="$DEVFORGE_ROOT/scripts/generate-doctor-report.sh"

# Test counters (use safe increments for set -e compatibility)
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
if [[ -t 1 ]]; then
    COLOR_RESET='\033[0m'
    COLOR_RED='\033[0;31m'
    COLOR_GREEN='\033[0;32m'
else
    COLOR_RESET=''
    COLOR_RED=''
    COLOR_GREEN=''
fi

# Test assertion helpers
assert_true() {
    local description="$1"
    local command="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if eval "$command" >/dev/null 2>&1; then
        printf "${COLOR_GREEN}[PASS]${COLOR_RESET} %s\n" "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        printf "${COLOR_RED}[FAIL]${COLOR_RESET} %s\n" "$description"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_exists() {
    local description="$1"
    local file="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -f "$file" ]]; then
        printf "${COLOR_GREEN}[PASS]${COLOR_RESET} %s\n" "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        printf "${COLOR_RED}[FAIL]${COLOR_RESET} %s - file not found: %s\n" "$description" "$file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_file_executable() {
    local description="$1"
    local file="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ -x "$file" ]]; then
        printf "${COLOR_GREEN}[PASS]${COLOR_RESET} %s\n" "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        printf "${COLOR_RED}[FAIL]${COLOR_RESET} %s - not executable: %s\n" "$description" "$file"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local description="$1"
    local file="$2"
    local pattern="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    # Use -F for fixed string and -- to handle patterns starting with -
    if grep -qF -- "$pattern" "$file"; then
        printf "${COLOR_GREEN}[PASS]${COLOR_RESET} %s\n" "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        printf "${COLOR_RED}[FAIL]${COLOR_RESET} %s - pattern not found: %s\n" "$description" "$pattern"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Main tests
main() {
    printf "DevForge Report Script Tests\n"
    printf "========================================\n\n"

    # Script existence and permissions
    assert_file_exists "Report script exists" "$REPORT_SCRIPT"
    assert_file_executable "Report script is executable" "$REPORT_SCRIPT"

    # Script structure
    assert_contains "Script has bash shebang" "$REPORT_SCRIPT" "#!/usr/bin/env bash"
    assert_contains "Script uses strict mode" "$REPORT_SCRIPT" "set -Eeuo pipefail"
    assert_contains "Script has help option" "$REPORT_SCRIPT" "--help"
    assert_contains "Script has quiet option" "$REPORT_SCRIPT" "--quiet"
    assert_contains "Script has output-dir option" "$REPORT_SCRIPT" "--output-dir"

    # Script uses NO_COLOR
    assert_contains "Script sets NO_COLOR for doctor" "$REPORT_SCRIPT" "NO_COLOR=1"

    # Script generates metadata
    assert_contains "Script generates timestamp" "$REPORT_SCRIPT" "date"
    assert_contains "Script captures hostname" "$REPORT_SCRIPT" "hostname"
    assert_contains "Script captures DevForge version" "$REPORT_SCRIPT" "DEVFORGE_VERSION"

    # Syntax validation
    assert_true "Script passes bash -n syntax check" "bash -n '$REPORT_SCRIPT'"

    # Help output test
    assert_true "Help option works" "'$REPORT_SCRIPT' --help"

    # Test directory creation (use temp dir to avoid side effects)
    local temp_dir
    temp_dir="$(mktemp -d)"
    assert_true "Reports directory can be created" "mkdir -p '$temp_dir/reports'"
    rm -rf "$temp_dir"

    # Summary
    printf "\n========================================\n"
    printf "Report Script Tests: %d passed, %d failed\n" "$TESTS_PASSED" "$TESTS_FAILED"
    printf "========================================\n"

    # Exit with failure if any tests failed
    [[ "$TESTS_FAILED" -eq 0 ]]
}

main "$@"
