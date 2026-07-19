#!/usr/bin/env bash

ensure_flatpak() {
    if ! install_apt_package flatpak; then
        log_error "Failed to install flatpak"
        return 1
    fi

    return 0
}

ensure_flathub_remote() {
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

flatpak_app_installed() {
    local app_id="$1"

    flatpak info --system "$app_id" >/dev/null 2>&1
}

install_flatpak_app() {
    local app_id="$1"
    local app_name="$2"

    # Check if already installed
    if flatpak_app_installed "$app_id"; then
        log_info "$app_name is already installed. Skipping."
        return 0
    fi

    log_info "Installing $app_name..."
    if ! flatpak install --system -y flathub "$app_id"; then
        log_error "Failed to install $app_name"
        return 1
    fi

    # Verify installation
    if ! flatpak_app_installed "$app_id"; then
        log_error "$app_name installation verification failed"
        return 1
    fi

    log_success "$app_name installed"
    return 0
}

verify_flatpak_app() {
    local app_id="$1"
    local app_name="$2"

    if flatpak_app_installed "$app_id"; then
        log_success "$app_name verified"
        return 0
    else
        log_error "$app_name verification failed"
        return 1
    fi
}
