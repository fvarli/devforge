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

    # Calculate health score: passed / (passed + warnings + failed) * 100
    local denominator=$((DOCTOR_CHECKS_PASSED + DOCTOR_CHECKS_WARNINGS + DOCTOR_CHECKS_FAILED))
    local health_score=0
    if [[ $denominator -gt 0 ]]; then
        health_score=$((DOCTOR_CHECKS_PASSED * 100 / denominator))
    fi
    printf "  Health Score: ${COLOR_CYAN}%d%%${COLOR_RESET}\n" "$health_score"

    if [[ "$DOCTOR_CHECKS_FAILED" -gt 0 ]]; then
        return 1
    fi
    return 0
}
