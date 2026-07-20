#!/usr/bin/env bash

# Node.js module for DevForge
# Installs NVM, Node.js, pnpm, Yarn, Bun, and global tools

# NVM version to install
NVM_VERSION="${NVM_VERSION:-v0.40.1}"

# Config defaults
NODE_INSTALL_METHOD="${NODE_INSTALL_METHOD:-nvm}"
NODE_VERSION="${NODE_VERSION:-lts}"
INSTALL_NPM_GLOBAL_TOOLS="${INSTALL_NPM_GLOBAL_TOOLS:-true}"
INSTALL_PNPM="${INSTALL_PNPM:-true}"
INSTALL_YARN="${INSTALL_YARN:-true}"
INSTALL_BUN="${INSTALL_BUN:-true}"

validate_node_version() {
    local version="$1"

    # Accept: lts, latest, or version numbers like 22, 22.14.0
    if [[ "$version" == "lts" || "$version" == "latest" ]]; then
        return 0
    fi

    # Accept numeric versions: 22, 22.14, 22.14.0
    if [[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
        return 0
    fi

    log_error "Invalid NODE_VERSION: $version (supported: lts, latest, or version number like 22 or 22.14.0)"
    return 1
}

get_nvm_dir() {
    local target_home
    target_home="$(get_target_home)"
    echo "$target_home/.nvm"
}

nvm_installed() {
    local nvm_dir
    nvm_dir="$(get_nvm_dir)"

    [[ -d "$nvm_dir" && -f "$nvm_dir/nvm.sh" ]]
}

run_with_nvm() {
    local target_home
    local nvm_dir

    target_home="$(get_target_home)"
    nvm_dir="$(get_nvm_dir)"

    # Run command with NVM loaded
    run_as_target_user bash -c "
        export NVM_DIR=\"$nvm_dir\"
        [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
        $*
    "
}

install_nvm() {
    if nvm_installed; then
        log_info "NVM is already installed. Skipping."
        metrics_record_application_skipped
        return 0
    fi

    log_info "Installing NVM ${NVM_VERSION}..."

    local target_home
    local nvm_dir

    target_home="$(get_target_home)"
    nvm_dir="$(get_nvm_dir)"

    # Ensure curl is available
    if ! command_exists curl; then
        if ! install_apt_package curl; then
            log_error "Failed to install curl prerequisite"
            return 1
        fi
    fi

    # Download and run NVM installer as target user
    local nvm_install_url="https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh"

    if ! run_as_target_user bash -c "curl -fsSL '$nvm_install_url' | bash"; then
        log_error "Failed to install NVM"
        return 1
    fi

    # Verify installation
    if ! nvm_installed; then
        log_error "NVM installation verification failed"
        return 1
    fi

    # Configure shell rc files idempotently
    configure_nvm_shell

    log_success "NVM ${NVM_VERSION} installed"
    metrics_record_application_installed

    return 0
}

configure_nvm_shell() {
    local target_home
    local nvm_dir

    target_home="$(get_target_home)"
    nvm_dir="$(get_nvm_dir)"

    local nvm_config='
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

    local bashrc="$target_home/.bashrc"
    local zshrc="$target_home/.zshrc"

    # Add to .bashrc if exists and not already configured
    if [[ -f "$bashrc" ]]; then
        if ! grep -qF 'NVM_DIR' "$bashrc" 2>/dev/null; then
            echo "$nvm_config" >> "$bashrc"
            ensure_target_ownership "$bashrc"
            log_info "Added NVM configuration to .bashrc"
        fi
    fi

    # Add to .zshrc if exists and not already configured
    if [[ -f "$zshrc" ]]; then
        if ! grep -qF 'NVM_DIR' "$zshrc" 2>/dev/null; then
            echo "$nvm_config" >> "$zshrc"
            ensure_target_ownership "$zshrc"
            log_info "Added NVM configuration to .zshrc"
        fi
    fi
}

install_node_via_nvm() {
    log_info "Installing Node.js ${NODE_VERSION} via NVM..."

    local nvm_version_arg="$NODE_VERSION"

    # Convert friendly names to NVM arguments
    if [[ "$NODE_VERSION" == "lts" ]]; then
        nvm_version_arg="--lts"
    elif [[ "$NODE_VERSION" == "latest" ]]; then
        nvm_version_arg="node"
    fi

    # Install Node.js
    if ! run_with_nvm "nvm install $nvm_version_arg"; then
        log_error "Failed to install Node.js ${NODE_VERSION}"
        return 1
    fi

    # Set as default
    if ! run_with_nvm "nvm alias default $nvm_version_arg"; then
        log_warning "Failed to set Node.js ${NODE_VERSION} as default"
    fi

    # Verify installation
    local node_version
    node_version="$(run_with_nvm "node --version" 2>/dev/null)"

    if [[ -z "$node_version" ]]; then
        log_error "Node.js installation verification failed"
        return 1
    fi

    local npm_version
    npm_version="$(run_with_nvm "npm --version" 2>/dev/null)"

    log_success "Node.js installed: $node_version (npm $npm_version)"
    metrics_record_application_installed

    return 0
}

install_pnpm() {
    if [[ "${INSTALL_PNPM}" != "true" ]]; then
        log_info "Skipping pnpm (INSTALL_PNPM=false)"
        return 0
    fi

    # Check if already installed
    if run_with_nvm "command -v pnpm" >/dev/null 2>&1; then
        log_info "pnpm is already installed. Skipping."
        metrics_record_application_skipped
        return 0
    fi

    log_info "Installing pnpm via Corepack..."

    # Enable corepack
    if ! run_with_nvm "corepack enable"; then
        log_warning "Failed to enable Corepack, trying npm install..."

        # Fallback to npm install
        if ! run_with_nvm "npm install -g pnpm"; then
            log_error "Failed to install pnpm"
            return 1
        fi
    else
        # Prepare pnpm via corepack
        if ! run_with_nvm "corepack prepare pnpm@latest --activate"; then
            log_warning "Corepack prepare failed, trying npm install..."

            if ! run_with_nvm "npm install -g pnpm"; then
                log_error "Failed to install pnpm"
                return 1
            fi
        fi
    fi

    # Verify installation
    local pnpm_version
    pnpm_version="$(run_with_nvm "pnpm --version" 2>/dev/null)"

    if [[ -z "$pnpm_version" ]]; then
        log_error "pnpm installation verification failed"
        return 1
    fi

    log_success "pnpm installed: v$pnpm_version"
    metrics_record_application_installed

    return 0
}

install_yarn() {
    if [[ "${INSTALL_YARN}" != "true" ]]; then
        log_info "Skipping Yarn (INSTALL_YARN=false)"
        return 0
    fi

    # Check if already installed
    if run_with_nvm "command -v yarn" >/dev/null 2>&1; then
        log_info "Yarn is already installed. Skipping."
        metrics_record_application_skipped
        return 0
    fi

    log_info "Installing Yarn via Corepack..."

    # Enable corepack
    if ! run_with_nvm "corepack enable"; then
        log_warning "Failed to enable Corepack, trying npm install..."

        # Fallback to npm install
        if ! run_with_nvm "npm install -g yarn"; then
            log_error "Failed to install Yarn"
            return 1
        fi
    else
        # Prepare yarn via corepack
        if ! run_with_nvm "corepack prepare yarn@stable --activate"; then
            log_warning "Corepack prepare failed, trying npm install..."

            if ! run_with_nvm "npm install -g yarn"; then
                log_error "Failed to install Yarn"
                return 1
            fi
        fi
    fi

    # Verify installation
    local yarn_version
    yarn_version="$(run_with_nvm "yarn --version" 2>/dev/null)"

    if [[ -z "$yarn_version" ]]; then
        log_error "Yarn installation verification failed"
        return 1
    fi

    log_success "Yarn installed: v$yarn_version"
    metrics_record_application_installed

    return 0
}

get_bun_dir() {
    local target_home
    target_home="$(get_target_home)"
    echo "$target_home/.bun"
}

bun_installed() {
    local bun_dir
    bun_dir="$(get_bun_dir)"

    [[ -x "$bun_dir/bin/bun" ]]
}

install_bun() {
    if [[ "${INSTALL_BUN}" != "true" ]]; then
        log_info "Skipping Bun (INSTALL_BUN=false)"
        return 0
    fi

    if bun_installed; then
        log_info "Bun is already installed. Skipping."
        metrics_record_application_skipped
        return 0
    fi

    log_info "Installing Bun..."

    local target_home
    target_home="$(get_target_home)"

    # Ensure unzip is available (required by Bun installer)
    if ! command_exists unzip; then
        if ! install_apt_package unzip; then
            log_error "Failed to install unzip prerequisite"
            return 1
        fi
    fi

    # Download and run Bun installer as target user
    if ! run_as_target_user bash -c "curl -fsSL https://bun.sh/install | bash"; then
        log_error "Failed to install Bun"
        return 1
    fi

    # Verify installation
    if ! bun_installed; then
        log_error "Bun installation verification failed"
        return 1
    fi

    # Configure PATH in shell rc files
    configure_bun_path

    # Get version
    local bun_dir
    local bun_version
    bun_dir="$(get_bun_dir)"
    bun_version="$(run_as_target_user "$bun_dir/bin/bun" --version 2>/dev/null)"

    log_success "Bun installed: v$bun_version"
    metrics_record_application_installed

    return 0
}

configure_bun_path() {
    local target_home
    target_home="$(get_target_home)"

    local bun_path_line='export BUN_INSTALL="$HOME/.bun"'
    local bun_bin_line='export PATH="$BUN_INSTALL/bin:$PATH"'

    local bashrc="$target_home/.bashrc"
    local zshrc="$target_home/.zshrc"

    # Add to .bashrc if exists and not already configured
    if [[ -f "$bashrc" ]]; then
        if ! grep -qF 'BUN_INSTALL' "$bashrc" 2>/dev/null; then
            {
                echo ""
                echo "$bun_path_line"
                echo "$bun_bin_line"
            } >> "$bashrc"
            ensure_target_ownership "$bashrc"
            log_info "Added Bun to PATH in .bashrc"
        fi
    fi

    # Add to .zshrc if exists and not already configured
    if [[ -f "$zshrc" ]]; then
        if ! grep -qF 'BUN_INSTALL' "$zshrc" 2>/dev/null; then
            {
                echo ""
                echo "$bun_path_line"
                echo "$bun_bin_line"
            } >> "$zshrc"
            ensure_target_ownership "$zshrc"
            log_info "Added Bun to PATH in .zshrc"
        fi
    fi
}

install_npm_global_tools() {
    if [[ "${INSTALL_NPM_GLOBAL_TOOLS}" != "true" ]]; then
        log_info "Skipping npm global tools (INSTALL_NPM_GLOBAL_TOOLS=false)"
        return 0
    fi

    log_info "Installing npm global tools..."

    # npm-check-updates
    if run_with_nvm "command -v ncu" >/dev/null 2>&1; then
        log_info "npm-check-updates is already installed. Skipping."
        metrics_record_application_skipped
    else
        if run_with_nvm "npm install -g npm-check-updates"; then
            local ncu_version
            ncu_version="$(run_with_nvm "ncu --version" 2>/dev/null)"
            log_success "npm-check-updates installed: v$ncu_version"
            metrics_record_application_installed
        else
            log_warning "Failed to install npm-check-updates (non-critical)"
        fi
    fi

    return 0
}

verify_node_installation() {
    log_info "Verifying Node.js installation..."

    local failed=false

    # Verify NVM
    if nvm_installed; then
        log_success "NVM verified"
    else
        log_error "NVM verification failed"
        failed=true
    fi

    # Verify Node.js
    local node_version
    node_version="$(run_with_nvm "node --version" 2>/dev/null)"

    if [[ -n "$node_version" ]]; then
        log_success "Node.js verified: $node_version"
    else
        log_error "Node.js verification failed"
        failed=true
    fi

    # Verify npm
    local npm_version
    npm_version="$(run_with_nvm "npm --version" 2>/dev/null)"

    if [[ -n "$npm_version" ]]; then
        log_success "npm verified: v$npm_version"
    else
        log_error "npm verification failed"
        failed=true
    fi

    # Verify pnpm (if enabled)
    if [[ "${INSTALL_PNPM}" == "true" ]]; then
        local pnpm_version
        pnpm_version="$(run_with_nvm "pnpm --version" 2>/dev/null)"

        if [[ -n "$pnpm_version" ]]; then
            log_success "pnpm verified: v$pnpm_version"
        else
            log_error "pnpm verification failed"
            failed=true
        fi
    fi

    # Verify Yarn (if enabled)
    if [[ "${INSTALL_YARN}" == "true" ]]; then
        local yarn_version
        yarn_version="$(run_with_nvm "yarn --version" 2>/dev/null)"

        if [[ -n "$yarn_version" ]]; then
            log_success "Yarn verified: v$yarn_version"
        else
            log_error "Yarn verification failed"
            failed=true
        fi
    fi

    # Verify Bun (if enabled)
    if [[ "${INSTALL_BUN}" == "true" ]]; then
        if bun_installed; then
            local bun_dir
            local bun_version
            bun_dir="$(get_bun_dir)"
            bun_version="$(run_as_target_user "$bun_dir/bin/bun" --version 2>/dev/null)"
            log_success "Bun verified: v$bun_version"
        else
            log_error "Bun verification failed"
            failed=true
        fi
    fi

    if [[ "$failed" == "true" ]]; then
        return 1
    fi

    return 0
}

install_node() {
    log_step "Installing Node.js development environment"

    # Validate configuration
    if [[ "$NODE_INSTALL_METHOD" != "nvm" ]]; then
        log_error "Unsupported NODE_INSTALL_METHOD: $NODE_INSTALL_METHOD (only 'nvm' is supported)"
        return 1
    fi

    if ! validate_node_version "$NODE_VERSION"; then
        return 1
    fi

    # Install NVM
    if ! install_nvm; then
        log_error "Failed to install NVM"
        return 1
    fi

    # Install Node.js via NVM
    if ! install_node_via_nvm; then
        log_error "Failed to install Node.js"
        return 1
    fi

    # Install pnpm (respects config)
    if ! install_pnpm; then
        log_error "Failed to install pnpm"
        return 1
    fi

    # Install Yarn (respects config)
    if ! install_yarn; then
        log_error "Failed to install Yarn"
        return 1
    fi

    # Install Bun (respects config)
    if ! install_bun; then
        log_error "Failed to install Bun"
        return 1
    fi

    # Install global tools (respects config)
    install_npm_global_tools

    # Verify installation
    if ! verify_node_installation; then
        log_error "Node.js installation verification failed"
        return 1
    fi

    log_success "Node.js development environment installation completed"
    return 0
}
