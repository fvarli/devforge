#!/usr/bin/env bash

# Syntax validation for all DevForge shell scripts
# Runs bash -n per file and shellcheck once for all files with -x flag

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
BASH_SYNTAX_PASSED=0
BASH_SYNTAX_FAILED=0
SHELLCHECK_AVAILABLE=false

# Check if shellcheck is available
if command -v shellcheck >/dev/null 2>&1; then
    SHELLCHECK_AVAILABLE=true
    log_info "ShellCheck $(shellcheck --version | grep version: | awk '{print $2}') found"
else
    log_warning "ShellCheck not available - skipping ShellCheck validation"
fi

# Run bash -n syntax check on a single file
check_bash_syntax() {
    local file="$1"
    local relative_path="${file#"$DEVFORGE_ROOT"/}"

    if bash -n "$file" 2>/dev/null; then
        log_success "bash -n: $relative_path"
        BASH_SYNTAX_PASSED=$((BASH_SYNTAX_PASSED + 1))
        return 0
    else
        log_error "bash -n: $relative_path"
        bash -n "$file" 2>&1 | sed 's/^/    /' >&2
        BASH_SYNTAX_FAILED=$((BASH_SYNTAX_FAILED + 1))
        return 1
    fi
}

# Main validation
main() {
    log_step "DevForge Syntax Validation"

    # Build array of shell scripts (deterministic order)
    local -a shell_files=()
    shell_files+=("$DEVFORGE_ROOT/install.sh")

    local file
    for file in "$DEVFORGE_ROOT"/lib/*.sh; do
        [[ -f "$file" ]] && shell_files+=("$file")
    done
    for file in "$DEVFORGE_ROOT"/modules/*.sh; do
        [[ -f "$file" ]] && shell_files+=("$file")
    done
    for file in "$DEVFORGE_ROOT"/doctor/*.sh; do
        [[ -f "$file" ]] && shell_files+=("$file")
    done
    for file in "$DEVFORGE_ROOT"/tests/*.sh; do
        [[ -f "$file" ]] && shell_files+=("$file")
    done
    for file in "$DEVFORGE_ROOT"/scripts/*.sh; do
        [[ -f "$file" ]] && shell_files+=("$file")
    done

    local total_files="${#shell_files[@]}"
    log_info "Found $total_files shell script(s)"

    # Run bash -n checks per file
    log_step "Running bash -n syntax checks"
    local bash_failed=false
    for file in "${shell_files[@]}"; do
        if ! check_bash_syntax "$file"; then
            bash_failed=true
        fi
    done

    # Run shellcheck once for all files with -x flag
    local shellcheck_failed=false
    if $SHELLCHECK_AVAILABLE; then
        log_step "Running ShellCheck (consolidated with -x flag)"
        if shellcheck -x "${shell_files[@]}"; then
            log_success "ShellCheck passed for all $total_files files"
        else
            log_error "ShellCheck failed"
            shellcheck_failed=true
        fi
    fi

    # Print summary
    printf "\n"
    log_step "Syntax Validation Summary"
    printf "\n"
    printf "Total files:         %d\n" "$total_files"
    printf "bash -n passed:      %d\n" "$BASH_SYNTAX_PASSED"
    printf "bash -n failed:      %d\n" "$BASH_SYNTAX_FAILED"

    if $SHELLCHECK_AVAILABLE; then
        if $shellcheck_failed; then
            printf "shellcheck:          FAILED\n"
        else
            printf "shellcheck:          PASSED\n"
        fi
    fi

    printf "\n"

    # Determine exit code
    local exit_code=0

    if [[ "$bash_failed" == "true" ]]; then
        log_error "bash -n validation failed for $BASH_SYNTAX_FAILED file(s)"
        exit_code=1
    fi

    if $SHELLCHECK_AVAILABLE && [[ "$shellcheck_failed" == "true" ]]; then
        log_error "ShellCheck validation failed"
        exit_code=1
    fi

    if [[ $exit_code -eq 0 ]]; then
        log_success "All syntax checks passed"
    fi

    exit $exit_code
}

main "$@"
