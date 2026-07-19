#!/usr/bin/env bash

APT_INDEXES_UPDATED_FLAG="/tmp/devforge-apt-updated-$$"

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

get_target_user() {
    local sudo_user="${SUDO_USER:-}"

    if [[ -n "$sudo_user" && "$sudo_user" != "root" ]]; then
        echo "$sudo_user"
    else
        echo "$USER"
    fi
}

get_target_home() {
    local target_user
    target_user="$(get_target_user)"

    local target_home
    target_home="$(getent passwd "$target_user" | cut -d: -f6)"

    if [[ -z "$target_home" ]]; then
        die "Failed to resolve home directory for user: $target_user"
    fi

    echo "$target_home"
}

run_as_target_user() {
    local target_user
    target_user="$(get_target_user)"

    if [[ "$target_user" == "$USER" ]]; then
        "$@"
    else
        sudo -u "$target_user" "$@"
    fi
}

mark_apt_indexes_stale() {
    rm -f "$APT_INDEXES_UPDATED_FLAG"
}

refresh_apt_indexes() {
    if [[ -f "$APT_INDEXES_UPDATED_FLAG" ]]; then
        return 0
    fi

    log_info "Refreshing APT package indexes..."
    apt-get update
    touch "$APT_INDEXES_UPDATED_FLAG"
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

    refresh_apt_indexes

    log_info "Installing $package_name..."
    apt-get install -y "$package_name"
    log_success "$package_name installed."
}
