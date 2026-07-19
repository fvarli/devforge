#!/usr/bin/env bash

set -Eeuo pipefail

DEVFORGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEVFORGE_ROOT

source "$DEVFORGE_ROOT/lib/logging.sh"
source "$DEVFORGE_ROOT/lib/helpers.sh"
source "$DEVFORGE_ROOT/lib/distro.sh"
source "$DEVFORGE_ROOT/lib/modules.sh"

on_error() {
    local exit_code=$?
    local line_number="${1:-unknown}"

    log_error "Installation failed near line $line_number."
    log_error "Exit code: $exit_code"

    exit "$exit_code"
}

trap 'on_error "$LINENO"' ERR

print_banner() {
    cat <<'BANNER'

========================================
 DevForge
 Developer Workstation Bootstrap
========================================

BANNER
}

load_configuration() {
    local config_file="$DEVFORGE_ROOT/config.env"

    if [[ ! -f "$config_file" ]]; then
        log_warning "config.env not found."
        log_info "Creating config.env from config.env.example."
        cp "$DEVFORGE_ROOT/config.env.example" "$config_file"
    fi

    # shellcheck disable=SC1090
    source "$config_file"
}

main() {
    print_banner

    require_root
    require_command apt-get
    require_command dpkg-query

    load_configuration

    detect_distro
    validate_distro
    print_distro

    if [[ "${INSTALL_SYSTEM:-false}" == "true" ]]; then
        run_module system
    else
        log_info "System module disabled."
    fi

    printf "\n"
    log_success "DevForge foundation completed."
}

main "$@"
