#!/usr/bin/env bash

install_google_chrome() {
    install_deb_from_url \
        "google-chrome-stable" \
        "Google Chrome" \
        "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
        "google-chrome"
}

install_brave_browser() {
    if command_exists brave-browser; then
        log_info "Brave Browser is already installed. Skipping."
        return 0
    fi

    log_info "Installing Brave Browser..."

    # Ensure prerequisites
    if ! install_apt_package curl; then
        return 1
    fi
    if ! install_apt_package gpg; then
        return 1
    fi

    # Set up repository
    if ! ensure_apt_repository \
        "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
        "/etc/apt/keyrings/brave-browser-archive-keyring.gpg" \
        "/etc/apt/sources.list.d/brave-browser-apt-release.list" \
        "deb [signed-by=/etc/apt/keyrings/brave-browser-archive-keyring.gpg arch=amd64] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        "binary"; then
        return 1
    fi

    # Install package
    if ! install_apt_package brave-browser; then
        log_error "Failed to install Brave Browser"
        return 1
    fi

    log_success "Brave Browser installed"
    return 0
}

install_browsers() {
    log_step "Installing browsers"

    # Check architecture
    if ! require_amd64 "Browsers module"; then
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
        if ! verify_command google-chrome "Google Chrome" google-chrome --version; then
            failed=true
        fi
    fi

    if [[ "${INSTALL_BRAVE:-true}" == "true" ]]; then
        if ! verify_command brave-browser "Brave Browser" brave-browser --version; then
            failed=true
        fi
    fi

    if [[ "$failed" == "true" ]]; then
        return 1
    fi

    log_success "Browsers installation completed"
    return 0
}
