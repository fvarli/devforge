#!/usr/bin/env bash

detect_distro() {
    if [[ ! -r /etc/os-release ]]; then
        die "/etc/os-release could not be read."
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    DISTRO_ID="${ID:-unknown}"
    DISTRO_NAME="${PRETTY_NAME:-Unknown Linux}"
    DISTRO_VERSION="${VERSION_ID:-unknown}"
    DISTRO_CODENAME="${VERSION_CODENAME:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
}

validate_distro() {
    case "$DISTRO_ID" in
        ubuntu|kubuntu|xubuntu|pop|linuxmint)
            return 0
            ;;
    esac

    if [[ "$DISTRO_LIKE" == *"ubuntu"* ]] || [[ "$DISTRO_LIKE" == *"debian"* ]]; then
        return 0
    fi

    die "Unsupported distribution: $DISTRO_NAME"
}

print_distro() {
    log_success "Detected: $DISTRO_NAME"
    log_info "Distribution ID: $DISTRO_ID"
    log_info "Version: $DISTRO_VERSION"
    log_info "Codename: $DISTRO_CODENAME"
}
