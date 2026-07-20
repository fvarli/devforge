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

        # Record package skipped
        if declare -F metrics_record_package_skipped >/dev/null 2>&1; then
            metrics_record_package_skipped
        fi

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

    # Record package installed
    if declare -F metrics_record_package_installed >/dev/null 2>&1; then
        metrics_record_package_installed
    fi

    log_success "$package_name installed."
}

require_architecture() {
    local expected_arch="$1"
    local display_name="${2:-current module}"
    local actual_arch

    actual_arch="$(dpkg --print-architecture)"

    if [[ "$actual_arch" != "$expected_arch" ]]; then
        log_error "$display_name requires $expected_arch architecture (detected: $actual_arch)"
        return 1
    fi

    return 0
}

require_amd64() {
    require_architecture "amd64" "${1:-This module}"
}

download_file() {
    local url="$1"
    local output_path="$2"

    # Prefer curl, fallback to wget
    if command_exists curl; then
        if ! curl -fsSL "$url" -o "$output_path"; then
            log_error "Failed to download: $url"
            rm -f "$output_path"
            return 1
        fi
    elif command_exists wget; then
        if ! wget -O "$output_path" "$url"; then
            log_error "Failed to download: $url"
            rm -f "$output_path"
            return 1
        fi
    else
        log_error "Neither curl nor wget is available"
        return 1
    fi

    # Verify file exists and is non-empty
    if [[ ! -s "$output_path" ]]; then
        log_error "Downloaded file is empty or missing: $output_path"
        rm -f "$output_path"
        return 1
    fi

    return 0
}

create_temp_dir() {
    local tmp_dir
    tmp_dir="$(mktemp -d -t devforge.XXXXXXXX)"

    if [[ ! -d "$tmp_dir" ]]; then
        log_error "Failed to create temporary directory"
        return 1
    fi

    echo "$tmp_dir"
    return 0
}

cleanup_temp_dir() {
    local tmp_dir="$1"

    # Safety check: empty path
    if [[ -z "$tmp_dir" ]]; then
        log_warning "cleanup_temp_dir called with empty path"
        return 1
    fi

    # Safety check: must be absolute path
    if [[ "$tmp_dir" != /* ]]; then
        log_warning "Refusing to delete relative path: $tmp_dir"
        return 1
    fi

    # Safety check: dangerous literal paths
    if [[ "$tmp_dir" == "/" ]] || [[ "$tmp_dir" == "/tmp" ]] || [[ "$tmp_dir" == "$HOME" ]]; then
        log_warning "Refusing to delete dangerous path: $tmp_dir"
        return 1
    fi

    # Safety check: must be under system temp directory
    local system_tmp_dir
    system_tmp_dir="${TMPDIR:-/tmp}"

    # Canonicalize both paths if possible (use readlink -f if available, otherwise basic check)
    local canonical_tmp_dir
    local canonical_system_tmp

    if command_exists readlink; then
        canonical_tmp_dir="$(readlink -f "$tmp_dir" 2>/dev/null || echo "$tmp_dir")"
        canonical_system_tmp="$(readlink -f "$system_tmp_dir" 2>/dev/null || echo "$system_tmp_dir")"
    else
        canonical_tmp_dir="$tmp_dir"
        canonical_system_tmp="$system_tmp_dir"
    fi

    # Check if path is under system temp (handle trailing slashes)
    canonical_system_tmp="${canonical_system_tmp%/}"
    if [[ "$canonical_tmp_dir" != "$canonical_system_tmp"/* ]]; then
        log_warning "Refusing to delete path outside temp directory: $tmp_dir"
        return 1
    fi

    # Safety check: basename must start with devforge.
    local basename
    basename="$(basename "$tmp_dir")"
    if [[ "$basename" != devforge.* ]]; then
        log_warning "Refusing to delete path without devforge. prefix: $tmp_dir"
        return 1
    fi

    # Directory doesn't exist - not an error, may have been cleaned already
    if [[ ! -d "$tmp_dir" ]]; then
        return 0
    fi

    # All safety checks passed, proceed with deletion
    if ! rm -rf "$tmp_dir"; then
        log_warning "Failed to clean up temporary directory: $tmp_dir"
        return 1
    fi

    return 0
}

ensure_apt_repository() {
    local key_url="$1"
    local keyring_file="$2"
    local sources_file="$3"
    local source_line="$4"
    local key_format="${5:-binary}"  # binary or dearmor

    local needs_update=false

    # Validate key_format parameter
    if [[ "$key_format" != "binary" ]] && [[ "$key_format" != "dearmor" ]]; then
        log_error "Invalid key_format: $key_format (must be 'binary' or 'dearmor')"
        return 1
    fi

    # If dearmor format, ensure gpg exists
    if [[ "$key_format" == "dearmor" ]]; then
        if ! command_exists gpg; then
            log_error "gpg command not found (required for dearmor format)"
            return 1
        fi
    fi

    # Ensure /etc/apt/keyrings exists
    if [[ ! -d /etc/apt/keyrings ]]; then
        if ! mkdir -p /etc/apt/keyrings; then
            log_error "Failed to create /etc/apt/keyrings"
            return 1
        fi
        if ! chmod 755 /etc/apt/keyrings; then
            log_error "Failed to set permissions on /etc/apt/keyrings"
            return 1
        fi
    fi

    # Download and install GPG key if missing
    if [[ ! -f "$keyring_file" ]]; then
        log_info "Adding repository GPG key..."

        local tmp_dir
        if ! tmp_dir="$(create_temp_dir)"; then
            return 1
        fi

        local tmp_key="$tmp_dir/repo.key"

        # Always use download_file first (no duplicate curl/wget logic)
        if ! download_file "$key_url" "$tmp_key"; then
            cleanup_temp_dir "$tmp_dir"
            return 1
        fi

        # Verify downloaded key is non-empty
        if [[ ! -s "$tmp_key" ]]; then
            log_error "Downloaded key file is empty"
            cleanup_temp_dir "$tmp_dir"
            return 1
        fi

        # If dearmor format, process the key
        if [[ "$key_format" == "dearmor" ]]; then
            local tmp_dearmored="$tmp_dir/repo.key.dearmored"

            if ! gpg --dearmor < "$tmp_key" > "$tmp_dearmored"; then
                log_error "Failed to dearmor repository key"
                cleanup_temp_dir "$tmp_dir"
                return 1
            fi

            # Verify dearmored output is non-empty
            if [[ ! -s "$tmp_dearmored" ]]; then
                log_error "Dearmored key file is empty"
                cleanup_temp_dir "$tmp_dir"
                return 1
            fi

            # Use dearmored version
            tmp_key="$tmp_dearmored"
        fi

        # Install keyring with correct permissions
        if ! install -D -o root -g root -m 644 "$tmp_key" "$keyring_file"; then
            log_error "Failed to install repository keyring"
            cleanup_temp_dir "$tmp_dir"
            return 1
        fi

        cleanup_temp_dir "$tmp_dir"
        needs_update=true
    fi

    # Write or update sources file
    if [[ ! -f "$sources_file" ]] || ! grep -qxF "$source_line" "$sources_file"; then
        log_info "Adding repository source..."

        # Write atomically using DevForge-specific temp file pattern
        local tmp_sources
        tmp_sources="$(mktemp -t devforge.XXXXXXXX)"

        if ! echo "$source_line" > "$tmp_sources"; then
            log_error "Failed to write repository source"
            rm -f "$tmp_sources"
            return 1
        fi

        if ! install -o root -g root -m 644 "$tmp_sources" "$sources_file"; then
            log_error "Failed to install repository source file"
            rm -f "$tmp_sources"
            return 1
        fi

        rm -f "$tmp_sources"
        needs_update=true
    fi

    # Mark APT indexes stale if changes were made
    if [[ "$needs_update" == "true" ]]; then
        mark_apt_indexes_stale
    fi

    return 0
}

install_deb_from_url() {
    local package_name="$1"
    local display_name="$2"
    local url="$3"
    local verify_command="$4"

    # Validate all parameters are non-empty
    if [[ -z "$package_name" ]]; then
        log_error "install_deb_from_url: package_name is required"
        return 1
    fi
    if [[ -z "$display_name" ]]; then
        log_error "install_deb_from_url: display_name is required"
        return 1
    fi
    if [[ -z "$url" ]]; then
        log_error "install_deb_from_url: url is required"
        return 1
    fi
    if [[ -z "$verify_command" ]]; then
        log_error "install_deb_from_url: verify_command is required"
        return 1
    fi

    # Check if already installed
    if package_installed "$package_name" && command_exists "$verify_command"; then
        log_info "$display_name is already installed. Skipping."

        # Record application skipped (DEB installations count as applications)
        if declare -F metrics_record_application_skipped >/dev/null 2>&1; then
            metrics_record_application_skipped
        fi

        return 0
    fi

    log_info "Installing $display_name..."

    # Require dpkg-deb
    if ! command_exists dpkg-deb; then
        log_error "dpkg-deb command not found (required for .deb installation)"
        return 1
    fi

    # Require apt-get
    if ! command_exists apt-get; then
        log_error "apt-get command not found (required for .deb installation)"
        return 1
    fi

    # Ensure downloader available
    if ! command_exists wget && ! command_exists curl; then
        if ! install_apt_package wget; then
            log_error "Failed to install wget prerequisite"
            return 1
        fi
    fi

    # Create temporary directory
    local tmp_dir
    if ! tmp_dir="$(create_temp_dir)"; then
        return 1
    fi

    local deb_file="$tmp_dir/package.deb"

    # Download .deb package
    if ! download_file "$url" "$deb_file"; then
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    # Validate .deb package
    if ! dpkg-deb --info "$deb_file" >/dev/null 2>&1; then
        log_error "Downloaded file is not a valid .deb package"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    # Install package
    if ! apt-get install -y "$deb_file"; then
        log_error "Failed to install $display_name"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    # Cleanup before verification
    cleanup_temp_dir "$tmp_dir"

    # Verify installation - require BOTH package AND command
    if ! package_installed "$package_name"; then
        log_error "$display_name package verification failed"
        return 1
    fi

    if ! command_exists "$verify_command"; then
        log_error "$display_name command verification failed"
        return 1
    fi

    log_success "$display_name installed"

    # Record application installed (DEB installations count as applications)
    if declare -F metrics_record_application_installed >/dev/null 2>&1; then
        metrics_record_application_installed
    fi

    return 0
}

verify_command() {
    local command_name="$1"
    local display_name="$2"
    shift 2
    # Remaining args are the version command

    # Check if command exists
    if ! command_exists "$command_name"; then
        log_error "$display_name verification failed: command not found"
        return 1
    fi

    # If version args provided, try to get version
    if [[ $# -gt 0 ]]; then
        local version_output
        local version_exit_code

        # Capture output and exit code separately (no eval needed)
        version_output=$("$@" 2>/dev/null | head -n1)
        version_exit_code=$?

        if [[ $version_exit_code -eq 0 ]] && [[ -n "$version_output" ]]; then
            log_success "$display_name verified: $version_output"
        else
            log_warning "$display_name verified (version command failed)"
        fi
    else
        log_success "$display_name verified"
    fi

    return 0
}
