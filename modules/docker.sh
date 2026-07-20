#!/usr/bin/env bash

# Docker module for DevForge
# Installs Docker Engine, Docker Compose, and Docker Buildx

# Config defaults
INSTALL_DOCKER_ENGINE="${INSTALL_DOCKER_ENGINE:-true}"
INSTALL_DOCKER_COMPOSE="${INSTALL_DOCKER_COMPOSE:-true}"
INSTALL_DOCKER_BUILDX="${INSTALL_DOCKER_BUILDX:-true}"
ENABLE_DOCKER_SERVICE="${ENABLE_DOCKER_SERVICE:-true}"
ADD_USER_TO_DOCKER_GROUP="${ADD_USER_TO_DOCKER_GROUP:-true}"
RUN_DOCKER_HELLO_WORLD="${RUN_DOCKER_HELLO_WORLD:-false}"

# Packages that conflict with Docker CE
DOCKER_CONFLICT_PACKAGES=(
    docker.io
    docker-doc
    docker-compose
    podman-docker
    containerd
    runc
)

get_ubuntu_codename() {
    # Source os-release to get distribution info
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot determine Ubuntu codename: /etc/os-release not found"
        return 1
    fi

    # shellcheck source=/dev/null
    . /etc/os-release

    local codename
    # Use pure helper from lib/helpers.sh
    if ! codename="$(resolve_ubuntu_codename "${ID:-}" "${ID_LIKE:-}" "${UBUNTU_CODENAME:-}" "${VERSION_CODENAME:-}")"; then
        log_error "Could not determine Ubuntu codename"
        log_error "This system may not be Ubuntu-based"
        return 1
    fi

    # STRICT validation - unknown codenames FAIL
    # Docker repository requires known Ubuntu codenames
    if ! is_valid_ubuntu_codename "$codename"; then
        log_error "Unknown/unsupported Ubuntu codename: $codename"
        log_error "Supported codenames: ${VALID_UBUNTU_CODENAMES[*]}"
        log_error "Docker repository may not have packages for this release"
        return 1
    fi

    echo "$codename"
    return 0
}

check_docker_conflicts() {
    log_info "Checking for conflicting packages..."

    local conflicts=()
    local pkg

    for pkg in "${DOCKER_CONFLICT_PACKAGES[@]}"; do
        if package_installed "$pkg"; then
            conflicts+=("$pkg")
        fi
    done

    if [[ ${#conflicts[@]} -gt 0 ]]; then
        log_error "Conflicting packages detected: ${conflicts[*]}"
        log_error "Review packages and remove manually:"
        log_error "  sudo apt-get remove ${conflicts[*]}"
        log_error "WARNING: This may affect other software depending on these packages."
        log_error "Consider backing up before removal."
        return 1
    fi

    log_info "No conflicting packages found"
    return 0
}

ensure_docker_prerequisites() {
    local prerequisites=(
        ca-certificates
        curl
        gnupg
    )

    local package_name

    for package_name in "${prerequisites[@]}"; do
        if ! install_apt_package "$package_name"; then
            log_error "Required prerequisite installation failed: $package_name"
            return 1
        fi
    done

    return 0
}

setup_docker_repository() {
    log_info "Setting up Docker repository..."

    local ubuntu_codename
    if ! ubuntu_codename="$(get_ubuntu_codename)"; then
        return 1
    fi

    log_info "Ubuntu codename: $ubuntu_codename"

    local keyring_file="/etc/apt/keyrings/docker.asc"
    local sources_file="/etc/apt/sources.list.d/docker.list"
    local key_url="https://download.docker.com/linux/ubuntu/gpg"
    local arch
    arch="$(dpkg --print-architecture)"

    local source_line="deb [arch=${arch} signed-by=${keyring_file}] https://download.docker.com/linux/ubuntu ${ubuntu_codename} stable"

    # Use ensure_apt_repository with ascii key format
    if ! ensure_apt_repository "$key_url" "$keyring_file" "$sources_file" "$source_line" "ascii"; then
        log_error "Failed to setup Docker repository"
        return 1
    fi

    log_success "Docker repository configured"
    return 0
}

install_docker_packages() {
    log_info "Installing Docker packages..."

    local packages=(
        docker-ce
        docker-ce-cli
        containerd.io
    )

    # Add optional plugins based on config
    if [[ "${INSTALL_DOCKER_COMPOSE}" == "true" ]]; then
        packages+=("docker-compose-plugin")
    fi

    if [[ "${INSTALL_DOCKER_BUILDX}" == "true" ]]; then
        packages+=("docker-buildx-plugin")
    fi

    local package_name

    for package_name in "${packages[@]}"; do
        if ! install_apt_package "$package_name"; then
            log_error "Failed to install Docker package: $package_name"
            return 1
        fi
    done

    log_success "Docker packages installed"
    return 0
}

enable_docker_service() {
    if [[ "${ENABLE_DOCKER_SERVICE}" != "true" ]]; then
        log_info "Skipping Docker service enable (ENABLE_DOCKER_SERVICE=false)"
        return 0
    fi

    log_info "Enabling Docker service..."
    enable_systemd_service "docker" "Docker"
}

configure_docker_group() {
    if [[ "${ADD_USER_TO_DOCKER_GROUP}" != "true" ]]; then
        log_info "Skipping Docker group configuration (ADD_USER_TO_DOCKER_GROUP=false)"
        return 0
    fi

    log_info "Configuring Docker group..."

    local target_user
    target_user="$(get_target_user)"

    # Create docker group if it doesn't exist
    if ! getent group docker >/dev/null 2>&1; then
        if ! groupadd docker; then
            log_error "Failed to create docker group"
            return 1
        fi
        log_info "Docker group created"
    fi

    # Check if user is already in docker group
    if id -nG "$target_user" 2>/dev/null | grep -qw docker; then
        log_info "User $target_user is already in docker group"
        return 0
    fi

    # Add user to docker group
    if ! usermod -aG docker "$target_user"; then
        log_error "Failed to add $target_user to docker group"
        return 1
    fi

    log_success "Added $target_user to docker group"
    log_info "Log out and back in for docker group membership to take effect"

    return 0
}

run_hello_world_test() {
    if [[ "${RUN_DOCKER_HELLO_WORLD}" != "true" ]]; then
        return 0
    fi

    log_info "Running Docker hello-world test..."

    # Run hello-world as root (group membership may not be active yet)
    if docker run --rm hello-world >/dev/null 2>&1; then
        log_success "Docker hello-world test passed"
    else
        log_warning "Docker hello-world test failed (non-critical)"
    fi

    return 0
}

verify_docker_installation() {
    log_info "Verifying Docker installation..."

    local failed=false

    # Verify Docker Engine (REQUIRED)
    if command_exists docker; then
        local docker_version
        docker_version="$(docker --version 2>/dev/null)"
        if [[ -n "$docker_version" ]]; then
            log_success "Docker verified: $docker_version"
        else
            log_error "Docker version check failed"
            failed=true
        fi
    else
        log_error "Docker command not found"
        failed=true
    fi

    # Verify containerd (REQUIRED)
    if command_exists containerd; then
        local containerd_version
        containerd_version="$(containerd --version 2>/dev/null | head -n1)"
        if [[ -n "$containerd_version" ]]; then
            log_success "containerd verified: $containerd_version"
        else
            log_error "containerd version check failed"
            failed=true
        fi
    else
        log_error "containerd command not found"
        failed=true
    fi

    # Verify Docker Compose (REQUIRED when enabled)
    if [[ "${INSTALL_DOCKER_COMPOSE}" == "true" ]]; then
        if docker compose version >/dev/null 2>&1; then
            local compose_version
            compose_version="$(docker compose version 2>/dev/null)"
            log_success "Docker Compose verified: $compose_version"
        else
            log_error "Docker Compose verification failed"
            failed=true
        fi
    fi

    # Verify Docker Buildx (REQUIRED when enabled)
    if [[ "${INSTALL_DOCKER_BUILDX}" == "true" ]]; then
        if docker buildx version >/dev/null 2>&1; then
            local buildx_version
            buildx_version="$(docker buildx version 2>/dev/null)"
            log_success "Docker Buildx verified: $buildx_version"
        else
            log_error "Docker Buildx verification failed"
            failed=true
        fi
    fi

    # STRICT service verification (REQUIRED when enabled)
    if [[ "${ENABLE_DOCKER_SERVICE}" == "true" ]]; then
        if ! command_exists systemctl; then
            log_error "systemctl not available - cannot verify Docker service"
            failed=true
        elif ! systemctl is-active --quiet docker; then
            log_error "Docker service is not running"
            failed=true
        else
            log_success "Docker service verified: running"
        fi
    fi

    # STRICT group membership verification (REQUIRED when enabled)
    if [[ "${ADD_USER_TO_DOCKER_GROUP}" == "true" ]]; then
        local target_user
        target_user="$(get_target_user)"
        if id -nG "$target_user" 2>/dev/null | grep -qw docker; then
            log_success "Docker group membership verified for $target_user"
        else
            log_error "User $target_user not in docker group"
            failed=true
        fi
    fi

    if [[ "$failed" == "true" ]]; then
        return 1
    fi

    return 0
}

install_docker() {
    log_step "Installing Docker"

    # Validate boolean configurations
    if ! validate_boolean_configs \
        "INSTALL_DOCKER_ENGINE" "${INSTALL_DOCKER_ENGINE:-true}" \
        "INSTALL_DOCKER_COMPOSE" "${INSTALL_DOCKER_COMPOSE:-true}" \
        "INSTALL_DOCKER_BUILDX" "${INSTALL_DOCKER_BUILDX:-true}" \
        "ENABLE_DOCKER_SERVICE" "${ENABLE_DOCKER_SERVICE:-true}" \
        "ADD_USER_TO_DOCKER_GROUP" "${ADD_USER_TO_DOCKER_GROUP:-true}" \
        "RUN_DOCKER_HELLO_WORLD" "${RUN_DOCKER_HELLO_WORLD:-false}"; then
        log_error "Invalid boolean configuration in Docker module"
        return 1
    fi

    # Respect INSTALL_DOCKER_ENGINE=false
    if [[ "${INSTALL_DOCKER_ENGINE}" != "true" ]]; then
        log_info "Docker installation disabled (INSTALL_DOCKER_ENGINE=false)"
        return 0
    fi

    # Check architecture requirement
    if ! require_amd64 "Docker"; then
        return 1
    fi

    # Check for conflicting packages
    if ! check_docker_conflicts; then
        return 1
    fi

    # Install prerequisites
    if ! ensure_docker_prerequisites; then
        log_error "Failed to install Docker prerequisites"
        return 1
    fi

    # Setup Docker repository
    if ! setup_docker_repository; then
        log_error "Failed to setup Docker repository"
        return 1
    fi

    # Install Docker packages
    if ! install_docker_packages; then
        log_error "Failed to install Docker packages"
        return 1
    fi

    # Enable Docker service
    if ! enable_docker_service; then
        log_error "Failed to enable Docker service"
        return 1
    fi

    # Configure Docker group (failure is critical if enabled)
    if ! configure_docker_group; then
        log_error "Failed to configure Docker group"
        return 1
    fi

    # Run hello-world test (if enabled)
    run_hello_world_test

    # Verify installation
    if ! verify_docker_installation; then
        log_error "Docker installation verification failed"
        return 1
    fi

    log_success "Docker installation completed"
    return 0
}
