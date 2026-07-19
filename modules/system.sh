#!/usr/bin/env bash

install_system() {
    log_info "Refreshing APT package indexes..."
    apt-get update

    local packages=(
        ca-certificates
        curl
        wget
        git
        unzip
        zip
        tree
        jq
        rsync
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
}
