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
        id -un
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
    local target_home
    local current_uid
    local target_uid

    target_user="$(get_target_user)"
    target_home="$(get_target_home)"
    current_uid="$(id -u)"
    target_uid="$(id -u "$target_user")"

    # If already running as target user, execute directly
    if [[ "$current_uid" -eq "$target_uid" ]]; then
        HOME="$target_home" "$@"
    else
        # Use -H and explicit HOME for target user
        sudo -H -u "$target_user" env HOME="$target_home" "$@"
    fi
}

ensure_target_ownership() {
    local path="$1"
    local recursive="${2:-false}"
    local target_user
    local target_uid
    local target_gid

    target_user="$(get_target_user)"
    target_uid="$(id -u "$target_user")"
    target_gid="$(id -g "$target_user")"

    # Don't change ownership if already owned by target user
    local current_uid
    current_uid="$(stat -c '%u' "$path")"

    if [[ "$current_uid" -eq "$target_uid" ]]; then
        return 0
    fi

    if [[ "$recursive" == "true" ]] || [[ "$recursive" == "-R" ]]; then
        chown -R "$target_uid:$target_gid" "$path"
    else
        chown "$target_uid:$target_gid" "$path"
    fi
}

ensure_local_bin() {
    local target_home
    local local_bin_dir

    target_home="$(get_target_home)"
    local_bin_dir="$target_home/.local/bin"

    if [[ ! -d "$local_bin_dir" ]]; then
        log_info "Creating ~/.local/bin directory..."
        if ! mkdir -p "$local_bin_dir"; then
            log_error "Failed to create $local_bin_dir"
            return 1
        fi
        if ! ensure_target_ownership "$local_bin_dir"; then
            log_error "Failed to set ownership for $local_bin_dir"
            return 1
        fi
    fi

    # Always ensure correct permissions
    if ! chmod 755 "$local_bin_dir"; then
        log_error "Failed to set permissions for $local_bin_dir"
        return 1
    fi
    if ! ensure_target_ownership "$local_bin_dir"; then
        log_error "Failed to ensure ownership for $local_bin_dir"
        return 1
    fi
}

command_exists_for_user() {
    local command_name="$1"
    local target_home

    # Check if available in system PATH
    if command -v "$command_name" >/dev/null 2>&1; then
        return 0
    fi

    # Check in target user's ~/.local/bin
    target_home="$(get_target_home)"
    if [[ -x "$target_home/.local/bin/$command_name" ]]; then
        return 0
    fi

    return 1
}

mark_apt_indexes_stale() {
    rm -f "$APT_INDEXES_UPDATED_FLAG"
}

refresh_apt_indexes() {
    if [[ -f "$APT_INDEXES_UPDATED_FLAG" ]]; then
        return 0
    fi

    log_info "Refreshing APT package indexes..."
    if ! apt-get update; then
        log_error "Failed to refresh APT package indexes"
        return 1
    fi
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

    if ! refresh_apt_indexes; then
        return 1
    fi

    log_info "Installing $package_name..."
    if ! apt-get install -y "$package_name"; then
        log_error "Failed to install $package_name"
        return 1
    fi

    # Verify installation succeeded
    if ! package_installed "$package_name"; then
        log_error "$package_name installation verification failed"
        return 1
    fi

    log_success "$package_name installed."
}
