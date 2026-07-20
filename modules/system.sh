#!/usr/bin/env bash

# System module for DevForge
# Installs core system utilities: curl, wget, htop, ripgrep, etc.

install_system() {
    log_step "Installing system utilities"

    local packages=(
        ca-certificates
        curl
        wget
        unzip
        zip
        p7zip-full
        software-properties-common
        apt-transport-https
        tree
        jq
        ripgrep
        fd-find
        rsync
        htop
        btop
        fastfetch
        ncdu
        dnsutils
        net-tools
        traceroute
        openssh-client
        openssh-server
        ufw
    )

    local package_name

    for package_name in "${packages[@]}"; do
        if ! install_apt_package "$package_name"; then
            log_error "Required package installation failed: $package_name"
            return 1
        fi
    done

    if [[ "${ENABLE_SYSTEM_UPGRADE:-false}" == "true" ]]; then
        log_warning "System upgrade is enabled."
        if ! refresh_apt_indexes; then
            log_error "Failed to refresh indexes before upgrade"
            return 1
        fi
        if ! apt-get upgrade -y; then
            log_error "System upgrade failed"
            return 1
        fi
    else
        log_info "System upgrade disabled by configuration."
    fi

    log_success "System utilities installation completed"
    return 0
}
