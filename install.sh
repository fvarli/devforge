#!/usr/bin/env bash

set -Eeuo pipefail

DEVFORGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEVFORGE_ROOT

# shellcheck source=lib/logging.sh
source "$DEVFORGE_ROOT/lib/logging.sh"

# shellcheck source=lib/helpers.sh
source "$DEVFORGE_ROOT/lib/helpers.sh"

# shellcheck source=lib/distro.sh
source "$DEVFORGE_ROOT/lib/distro.sh"

# shellcheck source=lib/modules.sh
source "$DEVFORGE_ROOT/lib/modules.sh"

# shellcheck source=lib/cli.sh
source "$DEVFORGE_ROOT/lib/cli.sh"

# shellcheck source=lib/flatpak.sh
source "$DEVFORGE_ROOT/lib/flatpak.sh"

# shellcheck source=lib/metrics.sh
source "$DEVFORGE_ROOT/lib/metrics.sh"

on_error() {
    local exit_code=$?
    local line_number="${1:-unknown}"

    log_error "DevForge failed near line ${line_number}."
    log_error "Exit code: ${exit_code}"

    exit "$exit_code"
}

trap 'on_error "$LINENO"' ERR

print_banner() {
    cat <<EOF

========================================
 DevForge ${DEVFORGE_VERSION}
 Developer Workstation Bootstrap
========================================

EOF
}

load_configuration() {
    local config_file="$DEVFORGE_ROOT/config.env"

    if [[ ! -f "$config_file" ]]; then
        log_warning "config.env not found."
        log_info "Creating config.env from config.env.example."
        cp "$DEVFORGE_ROOT/config.env.example" "$config_file"
    fi

    # shellcheck source=/dev/null
    source "$config_file"
}

validate_environment() {
    require_root
    require_command apt-get
    require_command dpkg-query
}

main() {
    parse_arguments "$@"

    if [[ "$SHOW_HELP" == "true" ]]; then
        print_help
        exit 0
    fi

    if [[ "$SHOW_VERSION" == "true" ]]; then
        print_version
        exit 0
    fi

    print_banner
    validate_environment
    load_configuration

    detect_distro
    validate_distro
    print_distro

    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        run_interactive_selection
    fi

    print_selected_modules
    confirm_installation

    # Start metrics tracking
    if declare -F metrics_start >/dev/null 2>&1; then
        metrics_start
    fi

    run_selected_modules

    # Finish metrics tracking
    if declare -F metrics_finish >/dev/null 2>&1; then
        metrics_finish
    fi

    # Capture summary exit code
    local summary_exit_code=0
    if ! print_installation_summary; then
        summary_exit_code=1
    fi

    # Only print success if summary succeeded
    if [[ $summary_exit_code -eq 0 ]]; then
        printf "\n"
        log_success "DevForge completed successfully."
    fi

    # Exit with proper code
    exit $summary_exit_code
}

main "$@"
