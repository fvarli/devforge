#!/usr/bin/env bash

check_apps_architecture() {
    local arch
    arch="$(dpkg --print-architecture)"

    if [[ "$arch" != "amd64" ]]; then
        log_error "Apps module requires amd64 architecture (detected: $arch)"
        return 1
    fi

    return 0
}

ensure_flatpak() {
    if ! install_apt_package flatpak; then
        log_error "Failed to install flatpak"
        return 1
    fi

    return 0
}

setup_flathub_remote() {
    # Check if Flathub remote already exists
    if flatpak remotes --system 2>/dev/null | grep -q "^flathub"; then
        log_info "Flathub remote already configured. Skipping."
        return 0
    fi

    log_info "Adding Flathub remote..."
    if ! flatpak remote-add --system --if-not-exists flathub \
         "https://flathub.org/repo/flathub.flatpakrepo"; then
        log_error "Failed to add Flathub remote"
        return 1
    fi

    log_success "Flathub remote added"
    return 0
}

install_flatpak_app() {
    local app_id="$1"
    local app_name="$2"

    # Check if already installed
    if flatpak info --system "$app_id" >/dev/null 2>&1; then
        log_info "$app_name is already installed. Skipping."
        return 0
    fi

    log_info "Installing $app_name..."
    if ! flatpak install --system -y flathub "$app_id"; then
        log_error "Failed to install $app_name"
        return 1
    fi

    # Verify installation
    if ! flatpak info --system "$app_id" >/dev/null 2>&1; then
        log_error "$app_name installation verification failed"
        return 1
    fi

    log_success "$app_name installed"
    return 0
}

install_vscode() {
    if command_exists code; then
        log_info "VS Code is already installed. Skipping."
        return 0
    fi

    log_info "Installing VS Code..."

    # Ensure prerequisites
    local prerequisites=(
        curl
        gpg
        apt-transport-https
    )

    local package_name
    for package_name in "${prerequisites[@]}"; do
        if ! install_apt_package "$package_name"; then
            log_error "Required prerequisite installation failed: $package_name"
            return 1
        fi
    done

    local keyring_file="/etc/apt/keyrings/packages.microsoft.gpg"
    local sources_file="/etc/apt/sources.list.d/vscode.list"
    local expected_source="deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main"
    local needs_update=false

    # Set up GPG keyring
    if [[ ! -f "$keyring_file" ]]; then
        log_info "Adding VS Code repository GPG key..."

        if ! mkdir -p /etc/apt/keyrings; then
            log_error "Failed to create /etc/apt/keyrings"
            return 1
        fi
        if ! chmod 755 /etc/apt/keyrings; then
            log_error "Failed to set permissions on /etc/apt/keyrings"
            return 1
        fi

        local tmp_dir
        tmp_dir="$(mktemp -d)"

        # Download and dearmor the Microsoft GPG key
        if ! curl -fsSL "https://packages.microsoft.com/keys/microsoft.asc" | \
             gpg --dearmor -o "$tmp_dir/packages.microsoft.gpg"; then
            log_error "Failed to download VS Code GPG key"
            rm -rf "$tmp_dir"
            return 1
        fi

        if ! install -D -o root -g root -m 644 "$tmp_dir/packages.microsoft.gpg" "$keyring_file"; then
            log_error "Failed to install VS Code GPG key"
            rm -rf "$tmp_dir"
            return 1
        fi

        rm -rf "$tmp_dir"
        needs_update=true
    fi

    # Set up APT sources
    if [[ ! -f "$sources_file" ]] || ! grep -qxF "$expected_source" "$sources_file"; then
        log_info "Adding VS Code repository..."

        if ! echo "$expected_source" > "$sources_file"; then
            log_error "Failed to write VS Code repository source"
            return 1
        fi
        if ! chmod 644 "$sources_file"; then
            log_error "Failed to set permissions on $sources_file"
            return 1
        fi
        needs_update=true
    fi

    # Mark indexes stale if repository was added
    if [[ "$needs_update" == "true" ]]; then
        mark_apt_indexes_stale
    fi

    # Install VS Code package
    if ! install_apt_package code; then
        log_error "Failed to install VS Code"
        return 1
    fi

    # Verify installation
    if ! command_exists code; then
        log_error "VS Code installation verification failed"
        return 1
    fi

    log_success "VS Code installed"
    return 0
}

install_dbeaver() {
    if command_exists dbeaver; then
        log_info "DBeaver is already installed. Skipping."
        return 0
    fi

    log_info "Installing DBeaver..."

    # Ensure wget is available
    if ! install_apt_package wget; then
        log_error "Failed to install wget prerequisite"
        return 1
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    # Download DBeaver .deb package
    if ! wget -O "$tmp_dir/dbeaver-ce_latest_amd64.deb" \
         "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb"; then
        log_error "Failed to download DBeaver"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Install the package (resolves dependencies automatically)
    if ! apt-get install -y "$tmp_dir/dbeaver-ce_latest_amd64.deb"; then
        log_error "Failed to install DBeaver"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Verify installation - try version first, fall back to command existence
    if ! command_exists dbeaver; then
        log_error "DBeaver installation verification failed"
        rm -rf "$tmp_dir"
        return 1
    fi

    rm -rf "$tmp_dir"
    log_success "DBeaver installed"
    return 0
}

install_apps() {
    log_step "Installing desktop applications"

    # Check architecture
    if ! check_apps_architecture; then
        return 1
    fi

    # Install APT packages
    local apt_packages=(
        "vlc:${INSTALL_VLC:-true}"
        "filezilla:${INSTALL_FILEZILLA:-true}"
        "keepassxc:${INSTALL_KEEPASSXC:-false}"
    )

    local package_config
    for package_config in "${apt_packages[@]}"; do
        local package_name="${package_config%%:*}"
        local should_install="${package_config#*:}"

        if [[ "$should_install" == "true" ]]; then
            if ! install_apt_package "$package_name"; then
                log_error "Required package installation failed: $package_name"
                return 1
            fi
        fi
    done

    # Install VS Code if enabled
    if [[ "${INSTALL_VSCODE:-true}" == "true" ]]; then
        if ! install_vscode; then
            log_error "VS Code installation failed"
            return 1
        fi
    fi

    # Install DBeaver if enabled
    if [[ "${INSTALL_DBEAVER:-true}" == "true" ]]; then
        if ! install_dbeaver; then
            log_error "DBeaver installation failed"
            return 1
        fi
    fi

    # Install Flatpak apps if any are enabled
    local need_flatpak=false
    if [[ "${INSTALL_BITWARDEN:-true}" == "true" ]] || \
       [[ "${INSTALL_SPOTIFY:-true}" == "true" ]]; then
        need_flatpak=true
    fi

    if [[ "$need_flatpak" == "true" ]]; then
        if ! ensure_flatpak; then
            log_error "Flatpak installation failed"
            return 1
        fi

        if ! setup_flathub_remote; then
            log_error "Flathub setup failed"
            return 1
        fi

        if [[ "${INSTALL_BITWARDEN:-true}" == "true" ]]; then
            if ! install_flatpak_app "com.bitwarden.desktop" "Bitwarden"; then
                log_error "Bitwarden installation failed"
                return 1
            fi
        fi

        if [[ "${INSTALL_SPOTIFY:-true}" == "true" ]]; then
            if ! install_flatpak_app "com.spotify.Client" "Spotify"; then
                log_error "Spotify installation failed"
                return 1
            fi
        fi
    fi

    # Verify applications
    log_info "Verifying desktop applications..."
    local failed=false

    # Verify APT packages
    local verify_apt=(
        "vlc:${INSTALL_VLC:-true}"
        "filezilla:${INSTALL_FILEZILLA:-true}"
        "keepassxc:${INSTALL_KEEPASSXC:-false}"
    )

    local verify_config
    for verify_config in "${verify_apt[@]}"; do
        local package_name="${verify_config%%:*}"
        local should_verify="${verify_config#*:}"

        if [[ "$should_verify" == "true" ]]; then
            if command_exists "$package_name"; then
                # Try to get version, but don't fail if --version not supported
                if version=$("$package_name" --version 2>/dev/null | head -n1); then
                    log_success "$package_name verified: $version"
                else
                    log_success "$package_name verified"
                fi
            else
                log_error "$package_name verification failed"
                failed=true
            fi
        fi
    done

    # Verify VS Code
    if [[ "${INSTALL_VSCODE:-true}" == "true" ]]; then
        if command_exists code; then
            local code_version
            code_version="$(code --version 2>/dev/null | head -n1)"
            log_success "VS Code verified: $code_version"
        else
            log_error "VS Code verification failed"
            failed=true
        fi
    fi

    # Verify DBeaver
    if [[ "${INSTALL_DBEAVER:-true}" == "true" ]]; then
        if command_exists dbeaver; then
            log_success "DBeaver verified"
        else
            log_error "DBeaver verification failed"
            failed=true
        fi
    fi

    # Verify Flatpak apps
    if [[ "${INSTALL_BITWARDEN:-true}" == "true" ]]; then
        if flatpak info --system com.bitwarden.desktop >/dev/null 2>&1; then
            log_success "Bitwarden verified"
        else
            log_error "Bitwarden verification failed"
            failed=true
        fi
    fi

    if [[ "${INSTALL_SPOTIFY:-true}" == "true" ]]; then
        if flatpak info --system com.spotify.Client >/dev/null 2>&1; then
            log_success "Spotify verified"
        else
            log_error "Spotify verification failed"
            failed=true
        fi
    fi

    if [[ "$failed" == "true" ]]; then
        return 1
    fi

    log_success "Desktop applications installation completed"
    return 0
}
