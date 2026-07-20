#!/usr/bin/env bash

# Metrics tracking for DevForge installation
# This file provides functions to track installation progress and generate summary reports

# METRICS COUNTING RULES:
#
# To avoid double-counting, applications are categorized as follows:
#
# PACKAGE METRICS (installed via install_apt_package):
#   - System utilities (all packages in system module)
#   - Terminal tools: zsh, fzf, bat, tmux
#   - APT packages in apps module: vlc, filezilla, keepassxc
#   - Custom repo applications: brave-browser, code (VS Code), eza, gh (GitHub CLI)
#
# APPLICATION METRICS (distinct user-facing applications):
#   - Direct DEB downloads: google-chrome-stable, dbeaver-ce
#   - Flatpak apps: com.bitwarden.desktop, com.spotify.Client
#   - Script installers: starship, zoxide
#
# Note: zoxide is a special case - it counts as APPLICATION even when installed via APT
#       because it's a distinct user-facing tool that can also be installed via script

# Global metrics state
METRICS_ENABLED=false
METRICS_START_TIME=0
METRICS_END_TIME=0

# Module metrics
declare -a METRICS_MODULES_COMPLETED=()
declare -a METRICS_MODULES_FAILED=()
declare -a METRICS_MODULES_SKIPPED=()
declare -A METRICS_MODULE_START_TIMES=()
declare -A METRICS_MODULE_ELAPSED_TIMES=()

# Operation counters
METRICS_PACKAGES_INSTALLED=0
METRICS_PACKAGES_SKIPPED=0
METRICS_APPLICATIONS_INSTALLED=0
METRICS_APPLICATIONS_SKIPPED=0
METRICS_WARNINGS=0
METRICS_ERRORS=0

# Initialize metrics tracking
metrics_start() {
    METRICS_ENABLED=true
    METRICS_START_TIME=$(date +%s)

    # Reset all counters
    METRICS_MODULES_COMPLETED=()
    METRICS_MODULES_FAILED=()
    METRICS_MODULES_SKIPPED=()
    METRICS_MODULE_START_TIMES=()
    METRICS_MODULE_ELAPSED_TIMES=()

    METRICS_PACKAGES_INSTALLED=0
    METRICS_PACKAGES_SKIPPED=0
    METRICS_APPLICATIONS_INSTALLED=0
    METRICS_APPLICATIONS_SKIPPED=0
    METRICS_WARNINGS=0
    METRICS_ERRORS=0
}

# Finalize metrics tracking
metrics_finish() {
    if [[ "$METRICS_ENABLED" != "true" ]]; then
        return 0
    fi

    METRICS_END_TIME=$(date +%s)
}

# Increment a counter
metrics_increment() {
    local counter_name="$1"

    if [[ "$METRICS_ENABLED" != "true" ]]; then
        return 0
    fi

    case "$counter_name" in
        packages_installed)
            METRICS_PACKAGES_INSTALLED=$((METRICS_PACKAGES_INSTALLED + 1))
            ;;
        packages_skipped)
            METRICS_PACKAGES_SKIPPED=$((METRICS_PACKAGES_SKIPPED + 1))
            ;;
        applications_installed)
            METRICS_APPLICATIONS_INSTALLED=$((METRICS_APPLICATIONS_INSTALLED + 1))
            ;;
        applications_skipped)
            METRICS_APPLICATIONS_SKIPPED=$((METRICS_APPLICATIONS_SKIPPED + 1))
            ;;
        warnings)
            METRICS_WARNINGS=$((METRICS_WARNINGS + 1))
            ;;
        errors)
            METRICS_ERRORS=$((METRICS_ERRORS + 1))
            ;;
        *)
            # Unknown counter - silently ignore
            ;;
    esac
}

# Record module start
metrics_record_module_start() {
    local module_name="$1"

    if [[ "$METRICS_ENABLED" != "true" ]]; then
        return 0
    fi

    METRICS_MODULE_START_TIMES["$module_name"]=$(date +%s)
}

# Record module completed
metrics_record_module_completed() {
    local module_name="$1"

    if [[ "$METRICS_ENABLED" != "true" ]]; then
        return 0
    fi

    METRICS_MODULES_COMPLETED+=("$module_name")

    # Calculate elapsed time if start time recorded
    if [[ -n "${METRICS_MODULE_START_TIMES[$module_name]:-}" ]]; then
        local start_time="${METRICS_MODULE_START_TIMES[$module_name]}"
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        METRICS_MODULE_ELAPSED_TIMES["$module_name"]=$elapsed
    fi
}

# Record module failed
metrics_record_module_failed() {
    local module_name="$1"

    if [[ "$METRICS_ENABLED" != "true" ]]; then
        return 0
    fi

    METRICS_MODULES_FAILED+=("$module_name")

    # Calculate elapsed time if start time recorded
    if [[ -n "${METRICS_MODULE_START_TIMES[$module_name]:-}" ]]; then
        local start_time="${METRICS_MODULE_START_TIMES[$module_name]}"
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        METRICS_MODULE_ELAPSED_TIMES["$module_name"]=$elapsed
    fi
}

# Record module skipped
metrics_record_module_skipped() {
    local module_name="$1"

    if [[ "$METRICS_ENABLED" != "true" ]]; then
        return 0
    fi

    METRICS_MODULES_SKIPPED+=("$module_name")
}

# Record package installed
metrics_record_package_installed() {
    metrics_increment packages_installed
}

# Record package skipped
metrics_record_package_skipped() {
    metrics_increment packages_skipped
}

# Record application installed
metrics_record_application_installed() {
    metrics_increment applications_installed
}

# Record application skipped
metrics_record_application_skipped() {
    metrics_increment applications_skipped
}

# Record warning
metrics_record_warning() {
    metrics_increment warnings
}

# Record error
metrics_record_error() {
    metrics_increment errors
}

# Format elapsed time as human-readable string
format_elapsed_time() {
    local total_seconds="$1"

    local hours=$((total_seconds / 3600))
    local minutes=$(( (total_seconds % 3600) / 60 ))
    local seconds=$((total_seconds % 60))

    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" "$hours" "$minutes" "$seconds"
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" "$minutes" "$seconds"
    else
        printf "%ds" "$seconds"
    fi
}

# Print installation summary report (read-only - does not modify metrics)
metrics_print_summary() {
    if [[ "$METRICS_ENABLED" != "true" ]]; then
        return 0
    fi

    printf "\n"
    printf "\n${COLOR_CYAN}==>${COLOR_RESET} %s\n" "Installation Summary"

    # Modules section
    printf "\nModules:\n"

    local module_name

    # Completed modules
    if [[ "${#METRICS_MODULES_COMPLETED[@]}" -gt 0 ]]; then
        for module_name in "${METRICS_MODULES_COMPLETED[@]}"; do
            local elapsed_str=""
            if [[ -n "${METRICS_MODULE_ELAPSED_TIMES[$module_name]:-}" ]]; then
                local elapsed="${METRICS_MODULE_ELAPSED_TIMES[$module_name]}"
                elapsed_str=" ($(format_elapsed_time "$elapsed"))"
            fi
            printf "${COLOR_GREEN}✓${COLOR_RESET} %s\n" "$module_name$elapsed_str"
        done
    fi

    # Failed modules
    if [[ "${#METRICS_MODULES_FAILED[@]}" -gt 0 ]]; then
        for module_name in "${METRICS_MODULES_FAILED[@]}"; do
            local elapsed_str=""
            if [[ -n "${METRICS_MODULE_ELAPSED_TIMES[$module_name]:-}" ]]; then
                local elapsed="${METRICS_MODULE_ELAPSED_TIMES[$module_name]}"
                elapsed_str=" ($(format_elapsed_time "$elapsed"))"
            fi
            printf "${COLOR_RED}✗${COLOR_RESET} %s\n" "$module_name$elapsed_str"
        done
    fi

    # Skipped modules
    if [[ "${#METRICS_MODULES_SKIPPED[@]}" -gt 0 ]]; then
        for module_name in "${METRICS_MODULES_SKIPPED[@]}"; do
            printf "${COLOR_YELLOW}-${COLOR_RESET} %s\n" "$module_name"
        done
    fi

    # Operations summary
    printf "\nOperations:\n"

    local total_packages=$((METRICS_PACKAGES_INSTALLED + METRICS_PACKAGES_SKIPPED))
    local total_applications=$((METRICS_APPLICATIONS_INSTALLED + METRICS_APPLICATIONS_SKIPPED))

    if [[ $total_packages -gt 0 ]]; then
        printf "  Packages: %d installed, %d skipped (%d total)\n" \
            "$METRICS_PACKAGES_INSTALLED" "$METRICS_PACKAGES_SKIPPED" "$total_packages"
    fi

    if [[ $total_applications -gt 0 ]]; then
        printf "  Applications: %d installed, %d skipped (%d total)\n" \
            "$METRICS_APPLICATIONS_INSTALLED" "$METRICS_APPLICATIONS_SKIPPED" "$total_applications"
    fi

    if [[ $METRICS_WARNINGS -gt 0 ]]; then
        printf "  Warnings: %d\n" "$METRICS_WARNINGS"
    fi

    if [[ $METRICS_ERRORS -gt 0 ]]; then
        printf "  Errors: %d\n" "$METRICS_ERRORS"
    fi

    # Total elapsed time
    if [[ $METRICS_END_TIME -gt 0 ]]; then
        local total_elapsed=$((METRICS_END_TIME - METRICS_START_TIME))
        printf "\nTotal time: %s\n" "$(format_elapsed_time "$total_elapsed")"
    fi
}
