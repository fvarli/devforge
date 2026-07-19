#!/usr/bin/env bash

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    local command_name="$1"

    if ! command_exists "$command_name"; then
        die "Required command not found: $command_name"
    fi
}

is_root() {
    [[ "${EUID}" -eq 0 ]]
}

require_root() {
    if ! is_root; then
        die "DevForge must be run with sudo: sudo ./install.sh"
    fi
}

package_installed() {
    local package_name="$1"

    dpkg-query -W \
        -f='${Status}' \
        "$package_name" 2>/dev/null |
        grep -q "install ok installed"
}

install_apt_package() {
    local package_name="$1"

    if package_installed "$package_name"; then
        log_info "$package_name is already installed. Skipping."
        return 0
    fi

    log_info "Installing $package_name..."
    apt-get install -y "$package_name"
    log_success "$package_name installed."
}
