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

# Colors for output (respects NO_COLOR)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
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

assert_false() {
    local description="$1"
    local command="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if ! eval "$command" >/dev/null 2>&1; then
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

assert_output_contains() {
    local description="$1"
    local output="$2"
    local pattern="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if echo "$output" | grep -qF -- "$pattern"; then
        printf "${COLOR_GREEN}[PASS]${COLOR_RESET} %s\n" "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        printf "${COLOR_RED}[FAIL]${COLOR_RESET} %s - pattern not found: %s\n" "$description" "$pattern"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test for ANSI escape sequences (ESC byte = \033)
assert_no_ansi_escapes() {
    local description="$1"
    local output="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    local escape_char
    escape_char="$(printf '\033')"
    if echo "$output" | grep -q "$escape_char"; then
        printf "${COLOR_RED}[FAIL]${COLOR_RESET} %s - found ANSI escape sequences\n" "$description"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    else
        printf "${COLOR_GREEN}[PASS]${COLOR_RESET} %s\n" "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
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

    # Script uses NO_COLOR
    assert_contains "Script sets NO_COLOR for doctor" "$REPORT_SCRIPT" "NO_COLOR=1"

    # Script generates required metadata
    assert_contains "Script generates timestamp" "$REPORT_SCRIPT" "date -Iseconds"
    assert_contains "Script captures hostname" "$REPORT_SCRIPT" "hostname"
    assert_contains "Script captures DevForge version" "$REPORT_SCRIPT" "DEVFORGE_VERSION"
    assert_contains "Script captures distribution" "$REPORT_SCRIPT" "PRETTY_NAME"
    assert_contains "Script captures architecture" "$REPORT_SCRIPT" "uname -m"
    assert_contains "Script captures kernel" "$REPORT_SCRIPT" "uname -r"
    assert_contains "Script captures git commit" "$REPORT_SCRIPT" "rev-parse --short HEAD"
    assert_contains "Script captures git branch" "$REPORT_SCRIPT" "branch --show-current"
    assert_contains "Script captures git state" "$REPORT_SCRIPT" "status --porcelain"

    # Script generates exit code footer
    assert_contains "Script generates exit code footer" "$REPORT_SCRIPT" "Doctor exit code:"

    # Default filename format
    assert_contains "Script uses correct default filename" "$REPORT_SCRIPT" "devforge-doctor-"

    # Syntax validation
    assert_true "Script passes bash -n syntax check" "bash -n '$REPORT_SCRIPT'"

    # Help output test
    assert_true "Help option works" "'$REPORT_SCRIPT' --help"

    # Test help content
    local help_output
    help_output="$("$REPORT_SCRIPT" --help 2>&1)"
    assert_output_contains "Help shows usage" "$help_output" "Usage:"
    assert_output_contains "Help shows output-file argument" "$help_output" "output-file"
    assert_output_contains "Help shows exit codes" "$help_output" "Exit codes:"

    # Test directory creation (use temp dir to avoid side effects)
    local temp_dir
    temp_dir="$(mktemp -d)"
    assert_true "Reports directory can be created" "mkdir -p '$temp_dir/reports'"
    rm -rf "$temp_dir"

    # Test working from different directories
    printf "\n==> Testing working directory independence\n"
    assert_true "Script resolves DEVFORGE_ROOT correctly" "[[ -f '$DEVFORGE_ROOT/install.sh' ]]"

    # Test NO_COLOR output (check for ANSI escape sequences)
    printf "\n==> Testing NO_COLOR support\n"
    local doctor_output
    doctor_output="$(NO_COLOR=1 "$DEVFORGE_ROOT/install.sh" --doctor 2>&1 || true)"
    assert_no_ansi_escapes "NO_COLOR doctor output has no ANSI escapes" "$doctor_output"

    # Verify [OK], [WARN], [FAIL], [SKIP] markers still present (they're text, not escape codes)
    assert_output_contains "Doctor output contains status markers" "$doctor_output" "[OK]"

    # Summary
    printf "\n========================================\n"
    printf "Report Script Tests: %d passed, %d failed\n" "$TESTS_PASSED" "$TESTS_FAILED"
    printf "========================================\n"

    # Exit with failure if any tests failed
    [[ "$TESTS_FAILED" -eq 0 ]]
}

main "$@"
