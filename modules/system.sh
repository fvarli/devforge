#!/usr/bin/env bash

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
        install_apt_package "$package_name"
    done

    if [[ "${ENABLE_SYSTEM_UPGRADE:-false}" == "true" ]]; then
        log_warning "System upgrade is enabled."
        apt-get upgrade -y
    else
        log_info "System upgrade disabled by configuration."
    fi

    log_success "System utilities installation completed"
    return 0
}
