#!/usr/bin/env bash

# DevForge Doctor Command
# Read-only diagnostic checks for installed components
# Does NOT require root privileges
#
# This is a thin orchestrator that sources modular check files from doctor/

# Doctor counters
DOCTOR_CHECKS_TOTAL=0
DOCTOR_CHECKS_PASSED=0
DOCTOR_CHECKS_WARNINGS=0
DOCTOR_CHECKS_FAILED=0

# Doctor output functions
doctor_pass() {
    printf "${COLOR_GREEN}[OK]${COLOR_RESET} %s\n" "$*"
    ((DOCTOR_CHECKS_TOTAL++))
    ((DOCTOR_CHECKS_PASSED++))
}

doctor_warn() {
    printf "${COLOR_YELLOW}[WARN]${COLOR_RESET} %s\n" "$*"
    ((DOCTOR_CHECKS_TOTAL++))
    ((DOCTOR_CHECKS_WARNINGS++))
}

doctor_fail() {
    printf "${COLOR_RED}[FAIL]${COLOR_RESET} %s\n" "$*"
    ((DOCTOR_CHECKS_TOTAL++))
    ((DOCTOR_CHECKS_FAILED++))
}

doctor_skip() {
    printf "${COLOR_BLUE}[SKIP]${COLOR_RESET} %s\n" "$*"
}

doctor_section() {
    printf "\n${COLOR_CYAN}==> %s${COLOR_RESET}\n" "$*"
}

# Source modular check files
# shellcheck source=../doctor/system.sh
source "$DEVFORGE_ROOT/doctor/system.sh"

# shellcheck source=../doctor/terminal.sh
source "$DEVFORGE_ROOT/doctor/terminal.sh"

# shellcheck source=../doctor/git.sh
source "$DEVFORGE_ROOT/doctor/git.sh"

# shellcheck source=../doctor/php.sh
source "$DEVFORGE_ROOT/doctor/php.sh"

# shellcheck source=../doctor/node.sh
source "$DEVFORGE_ROOT/doctor/node.sh"

# shellcheck source=../doctor/docker.sh
source "$DEVFORGE_ROOT/doctor/docker.sh"

# shellcheck source=../doctor/databases.sh
source "$DEVFORGE_ROOT/doctor/databases.sh"

# shellcheck source=../doctor/browsers.sh
source "$DEVFORGE_ROOT/doctor/browsers.sh"

# shellcheck source=../doctor/apps.sh
source "$DEVFORGE_ROOT/doctor/apps.sh"

# shellcheck source=../doctor/summary.sh
source "$DEVFORGE_ROOT/doctor/summary.sh"

# Main doctor function
run_doctor() {
    local check_all=false
    local modules_to_check=()

    # Parse arguments (use default empty to handle unset $1)
    if [[ "${1:-}" == "--all" ]]; then
        check_all=true
    elif [[ ${#SELECTED_MODULES[@]} -gt 0 ]]; then
        modules_to_check=("${SELECTED_MODULES[@]}")
    else
        check_all=true
    fi

    printf "${COLOR_CYAN}DevForge Doctor${COLOR_RESET}\n"
    printf "Running diagnostic checks...\n"

    # Reset counters
    DOCTOR_CHECKS_TOTAL=0
    DOCTOR_CHECKS_PASSED=0
    DOCTOR_CHECKS_WARNINGS=0
    DOCTOR_CHECKS_FAILED=0

    # Always check system
    doctor_check_system

    # Check requested modules
    if [[ "$check_all" == "true" ]]; then
        doctor_check_terminal
        doctor_check_git
        doctor_check_php
        doctor_check_node
        doctor_check_docker
        doctor_check_databases
        doctor_check_browsers
        doctor_check_apps
    else
        local module
        for module in "${modules_to_check[@]}"; do
            case "$module" in
                system) ;; # Already checked
                terminal) doctor_check_terminal ;;
                git) doctor_check_git ;;
                php) doctor_check_php ;;
                node) doctor_check_node ;;
                docker) doctor_check_docker ;;
                databases) doctor_check_databases ;;
                browsers) doctor_check_browsers ;;
                apps) doctor_check_apps ;;
                *) doctor_warn "Unknown module: $module" ;;
            esac
        done
    fi

    # Print summary and return status
    doctor_print_summary
}
