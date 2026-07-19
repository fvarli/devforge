#!/usr/bin/env bash

check_browser_architecture() {
    local arch
    arch="$(dpkg --print-architecture)"

    if [[ "$arch" != "amd64" ]]; then
        log_error "Browsers module requires amd64 architecture (detected: $arch)"
        return 1
    fi

    return 0
}

install_google_chrome() {
    if command_exists google-chrome; then
        log_info "Google Chrome is already installed. Skipping."
        return 0
    fi

    log_info "Installing Google Chrome..."

    # Ensure wget is available
    if ! install_apt_package wget; then
        log_error "Failed to install wget prerequisite"
        return 1
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    # Download Chrome .deb package
    if ! wget -O "$tmp_dir/google-chrome-stable_current_amd64.deb" \
         "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"; then
        log_error "Failed to download Google Chrome"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Install the package (resolves dependencies automatically)
    if ! apt-get install -y "$tmp_dir/google-chrome-stable_current_amd64.deb"; then
        log_error "Failed to install Google Chrome"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Verify installation
    if ! command_exists google-chrome; then
        log_error "Google Chrome installation verification failed"
        rm -rf "$tmp_dir"
        return 1
    fi

    rm -rf "$tmp_dir"
    log_success "Google Chrome installed"
    return 0
}

install_brave_browser() {
    if command_exists brave-browser; then
        log_info "Brave Browser is already installed. Skipping."
        return 0
    fi

    log_info "Installing Brave Browser..."

    # Ensure prerequisites
    local prerequisites=(
        curl
        gpg
    )

    local package_name
    for package_name in "${prerequisites[@]}"; do
        if ! install_apt_package "$package_name"; then
            log_error "Required prerequisite installation failed: $package_name"
            return 1
        fi
    done

    local keyring_file="/etc/apt/keyrings/brave-browser-archive-keyring.gpg"
    local sources_file="/etc/apt/sources.list.d/brave-browser-apt-release.list"
    local expected_source="deb [signed-by=/etc/apt/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main"
    local needs_update=false

    # Set up GPG keyring
    if [[ ! -f "$keyring_file" ]]; then
        log_info "Adding Brave Browser repository GPG key..."

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

        if ! curl -fsSL "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
             -o "$tmp_dir/brave-browser-archive-keyring.gpg"; then
            log_error "Failed to download Brave Browser GPG key"
            rm -rf "$tmp_dir"
            return 1
        fi

        if ! install -D -o root -g root -m 644 "$tmp_dir/brave-browser-archive-keyring.gpg" "$keyring_file"; then
            log_error "Failed to install Brave Browser GPG key"
            rm -rf "$tmp_dir"
            return 1
        fi

        rm -rf "$tmp_dir"
        needs_update=true
    fi

    # Set up APT sources
    if [[ ! -f "$sources_file" ]] || ! grep -qxF "$expected_source" "$sources_file"; then
        log_info "Adding Brave Browser repository..."

        if ! echo "$expected_source" > "$sources_file"; then
            log_error "Failed to write Brave Browser repository source"
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

    # Install Brave Browser package
    if ! install_apt_package brave-browser; then
        log_error "Failed to install Brave Browser"
        return 1
    fi

    # Verify installation
    if ! command_exists brave-browser; then
        log_error "Brave Browser installation verification failed"
        return 1
    fi

    log_success "Brave Browser installed"
    return 0
}

install_browsers() {
    log_step "Installing browsers"

    # Check architecture
    if ! check_browser_architecture; then
        return 1
    fi

    # Install Google Chrome if enabled
    if [[ "${INSTALL_CHROME:-true}" == "true" ]]; then
        if ! install_google_chrome; then
            log_error "Google Chrome installation failed"
            return 1
        fi
    fi

    # Install Brave Browser if enabled
    if [[ "${INSTALL_BRAVE:-true}" == "true" ]]; then
        if ! install_brave_browser; then
            log_error "Brave Browser installation failed"
            return 1
        fi
    fi

    # Verify browsers
    log_info "Verifying browsers..."
    local failed=false

    if [[ "${INSTALL_CHROME:-true}" == "true" ]]; then
        if command_exists google-chrome; then
            local chrome_version
            chrome_version="$(google-chrome --version)"
            log_success "Google Chrome verified: $chrome_version"
        else
            log_error "Google Chrome verification failed"
            failed=true
        fi
    fi

    if [[ "${INSTALL_BRAVE:-true}" == "true" ]]; then
        if command_exists brave-browser; then
            local brave_version
            brave_version="$(brave-browser --version)"
            log_success "Brave Browser verified: $brave_version"
        else
            log_error "Brave Browser verification failed"
            failed=true
        fi
    fi

    if [[ "$failed" == "true" ]]; then
        return 1
    fi

    log_success "Browsers installation completed"
    return 0
}
