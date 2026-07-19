#!/usr/bin/env bash

install_vscode() {
    if command_exists code; then
        log_info "VS Code is already installed. Skipping."
        return 0
    fi

    log_info "Installing VS Code..."

    # Ensure prerequisites
    if ! install_apt_package curl; then
        return 1
    fi
    if ! install_apt_package gpg; then
        return 1
    fi
    if ! install_apt_package apt-transport-https; then
        return 1
    fi

    # Set up repository
    if ! ensure_apt_repository \
        "https://packages.microsoft.com/keys/microsoft.asc" \
        "/etc/apt/keyrings/packages.microsoft.gpg" \
        "/etc/apt/sources.list.d/vscode.list" \
        "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
        "dearmor"; then
        return 1
    fi

    # Install package
    if ! install_apt_package code; then
        log_error "Failed to install VS Code"
        return 1
    fi

    log_success "VS Code installed"
    return 0
}

install_dbeaver() {
    install_deb_from_url \
        "dbeaver-ce" \
        "DBeaver" \
        "https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb" \
        "dbeaver"
}

install_apps() {
    log_step "Installing desktop applications"

    # Check architecture
    if ! require_amd64 "Apps module"; then
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

        if ! ensure_flathub_remote; then
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
        if ! verify_command code "VS Code" code --version; then
            failed=true
        fi
    fi

    # Verify DBeaver
    if [[ "${INSTALL_DBEAVER:-true}" == "true" ]]; then
        if ! verify_command dbeaver "DBeaver"; then
            failed=true
        fi
    fi

    # Verify Flatpak apps
    if [[ "${INSTALL_BITWARDEN:-true}" == "true" ]]; then
        if ! verify_flatpak_app "com.bitwarden.desktop" "Bitwarden"; then
            failed=true
        fi
    fi

    if [[ "${INSTALL_SPOTIFY:-true}" == "true" ]]; then
        if ! verify_flatpak_app "com.spotify.Client" "Spotify"; then
            failed=true
        fi
    fi

    if [[ "$failed" == "true" ]]; then
        return 1
    fi

    log_success "Desktop applications installation completed"
    return 0
}
