#!/usr/bin/env bash

# Syntax validation for all DevForge shell scripts
# Runs bash -n and shellcheck (if available) on all .sh files

set -Eeuo pipefail

DEVFORGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVFORGE_ROOT

# Colors for output
if [[ -t 1 ]]; then
    COLOR_RESET='\033[0m'
    COLOR_RED='\033[0;31m'
    COLOR_GREEN='\033[0;32m'
    COLOR_YELLOW='\033[0;33m'
    COLOR_CYAN='\033[0;36m'
else
    COLOR_RESET=''
    COLOR_RED=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_CYAN=''
fi

log_info() {
    printf "${COLOR_CYAN}ℹ${COLOR_RESET} %s\n" "$*"
}

log_success() {
    printf "${COLOR_GREEN}✓${COLOR_RESET} %s\n" "$*"
}

log_warning() {
    printf "${COLOR_YELLOW}⚠${COLOR_RESET} %s\n" "$*"
}

log_error() {
    printf "${COLOR_RED}✗${COLOR_RESET} %s\n" "$*" >&2
}

log_step() {
    printf "\n${COLOR_CYAN}==>${COLOR_RESET} %s\n" "$*"
}

# Counters
TOTAL_FILES=0
BASH_SYNTAX_PASSED=0
BASH_SYNTAX_FAILED=0
SHELLCHECK_PASSED=0
SHELLCHECK_FAILED=0
SHELLCHECK_AVAILABLE=false

# Check if shellcheck is available
if command -v shellcheck >/dev/null 2>&1; then
    SHELLCHECK_AVAILABLE=true
    log_info "ShellCheck $(shellcheck --version | grep version: | awk '{print $2}') found"
else
    log_warning "ShellCheck not available - skipping ShellCheck validation"
fi

# Find all .sh files
get_shell_scripts() {
    find "$DEVFORGE_ROOT" -type f -name "*.sh" | sort
}

# Run bash -n syntax check
check_bash_syntax() {
    local file="$1"
    local relative_path="${file#$DEVFORGE_ROOT/}"

    if bash -n "$file" 2>/dev/null; then
        log_success "bash -n: $relative_path"
        ((BASH_SYNTAX_PASSED++))
        return 0
    else
        log_error "bash -n: $relative_path"
        bash -n "$file" 2>&1 | sed 's/^/    /' >&2
        ((BASH_SYNTAX_FAILED++))
        return 1
    fi
}

# Run shellcheck
check_shellcheck() {
    local file="$1"
    local relative_path="${file#$DEVFORGE_ROOT/}"

    if ! $SHELLCHECK_AVAILABLE; then
        return 0
    fi

    if shellcheck "$file" 2>/dev/null; then
        log_success "shellcheck: $relative_path"
        ((SHELLCHECK_PASSED++))
        return 0
    else
        log_error "shellcheck: $relative_path"
        shellcheck "$file" 2>&1 | sed 's/^/    /' >&2
        ((SHELLCHECK_FAILED++))
        return 1
    fi
}

# Main validation
main() {
    log_step "DevForge Syntax Validation"

    local files
    files=$(get_shell_scripts)

    if [[ -z "$files" ]]; then
        log_error "No shell scripts found"
        exit 1
    fi

    # Count total files
    TOTAL_FILES=$(echo "$files" | wc -l)
    log_info "Found $TOTAL_FILES shell script(s)"

    # Run bash -n checks
    log_step "Running bash -n syntax checks"
    while IFS= read -r file; do
        check_bash_syntax "$file" || true
    done <<< "$files"

    # Run shellcheck if available
    if $SHELLCHECK_AVAILABLE; then
        log_step "Running ShellCheck"
        while IFS= read -r file; do
            check_shellcheck "$file" || true
        done <<< "$files"
    fi

    # Print summary
    printf "\n"
    log_step "Syntax Validation Summary"
    printf "\n"
    printf "Total files:         %d\n" "$TOTAL_FILES"
    printf "\n"
    printf "bash -n passed:      %d\n" "$BASH_SYNTAX_PASSED"
    printf "bash -n failed:      %d\n" "$BASH_SYNTAX_FAILED"

    if $SHELLCHECK_AVAILABLE; then
        printf "\n"
        printf "shellcheck passed:   %d\n" "$SHELLCHECK_PASSED"
        printf "shellcheck failed:   %d\n" "$SHELLCHECK_FAILED"
    fi

    printf "\n"

    # Determine exit code
    local exit_code=0

    if [[ $BASH_SYNTAX_FAILED -gt 0 ]]; then
        log_error "bash -n validation failed for $BASH_SYNTAX_FAILED file(s)"
        exit_code=1
    fi

    if $SHELLCHECK_AVAILABLE && [[ $SHELLCHECK_FAILED -gt 0 ]]; then
        log_error "shellcheck validation failed for $SHELLCHECK_FAILED file(s)"
        exit_code=1
    fi

    if [[ $exit_code -eq 0 ]]; then
        log_success "All syntax checks passed"
    fi

    exit $exit_code
}

main "$@"
