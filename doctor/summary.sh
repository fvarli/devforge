#!/usr/bin/env bash

# Doctor: Summary output
# Prints check totals and returns exit status

doctor_print_summary() {
    printf "\n"
    doctor_section "Summary"
    printf "  Total checks: %d\n" "$DOCTOR_CHECKS_TOTAL"
    printf "  ${COLOR_GREEN}Passed${COLOR_RESET}: %d\n" "$DOCTOR_CHECKS_PASSED"
    printf "  ${COLOR_YELLOW}Warnings${COLOR_RESET}: %d\n" "$DOCTOR_CHECKS_WARNINGS"
    printf "  ${COLOR_RED}Failed${COLOR_RESET}: %d\n" "$DOCTOR_CHECKS_FAILED"

    if [[ "$DOCTOR_CHECKS_FAILED" -gt 0 ]]; then
        return 1
    fi
    return 0
}
