#!/usr/bin/env bash

ensure_git_prerequisites() {
    local prerequisites=(
        ca-certificates
        curl
        gpg
    )

    local package_name

    for package_name in "${prerequisites[@]}"; do
        install_apt_package "$package_name"
    done
}

install_gh_cli() {
    if command_exists gh; then
        log_info "GitHub CLI is already installed. Skipping."
        return 0
    fi

    log_info "Installing GitHub CLI..."

    local keyring_file="/etc/apt/keyrings/githubcli-archive-keyring.gpg"
    local sources_file="/etc/apt/sources.list.d/github-cli.list"
    local arch
    arch="$(dpkg --print-architecture)"
    local expected_source="deb [arch=${arch} signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"

    local needs_update=false

    if [[ ! -f "$keyring_file" ]]; then
        log_info "Adding GitHub CLI repository GPG key..."

        mkdir -p /etc/apt/keyrings
        chmod 755 /etc/apt/keyrings

        local tmp_dir
        tmp_dir="$(mktemp -d)"

        cleanup_gh() {
            rm -rf "$tmp_dir"
        }

        trap cleanup_gh RETURN

        if ! curl -fsSL "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
             -o "$tmp_dir/githubcli-archive-keyring.gpg"; then
            log_error "Failed to download GitHub CLI GPG key"
            return 1
        fi

        install -D -o root -g root -m 644 "$tmp_dir/githubcli-archive-keyring.gpg" "$keyring_file"
        needs_update=true
    fi

    if [[ ! -f "$sources_file" ]] || ! grep -qxF "$expected_source" "$sources_file"; then
        log_info "Adding GitHub CLI repository..."

        echo "$expected_source" > "$sources_file"
        chmod 644 "$sources_file"
        needs_update=true
    fi

    if [[ "$needs_update" == "true" ]]; then
        mark_apt_indexes_stale
    fi

    if ! install_apt_package gh; then
        log_error "Failed to install GitHub CLI"
        return 1
    fi

    return 0
}

setup_ssh_directory() {
    local target_user
    local target_home
    target_user="$(get_target_user)"
    target_home="$(get_target_home)"

    local ssh_dir="$target_home/.ssh"

    # Create if doesn't exist
    if [[ ! -d "$ssh_dir" ]]; then
        log_info "Creating SSH directory at $ssh_dir..."
        mkdir -p "$ssh_dir"
    else
        log_info "SSH directory already exists at $ssh_dir"
    fi

    # ALWAYS enforce permissions, regardless of whether dir existed
    chmod 700 "$ssh_dir"
    ensure_target_ownership "$ssh_dir"

    log_success "SSH directory ready"
    return 0
}

setup_git_config() {
    local target_user
    local target_home
    target_user="$(get_target_user)"
    target_home="$(get_target_home)"

    local git_config="$target_home/.gitconfig"

    if [[ -f "$git_config" ]]; then
        log_info "Git config already exists at $git_config. Skipping."
        return 0
    fi

    log_info "Creating minimal Git config at $git_config..."

    cat > "$git_config" <<'EOF'
[init]
	defaultBranch = main

[pull]
	rebase = false

[core]
	editor = nano
EOF

    ensure_target_ownership "$git_config"
    chmod 644 "$git_config"

    log_info "Configure Git user with:"
    log_info "  git config --global user.name \"Your Name\""
    log_info "  git config --global user.email \"your.email@example.com\""

    log_success "Git config created"
    return 0
}

install_git() {
    log_step "Installing Git tools"

    ensure_git_prerequisites

    local packages=(
        git
        git-lfs
    )

    local package_name

    for package_name in "${packages[@]}"; do
        install_apt_package "$package_name"
    done

    # GitHub CLI is required
    if ! install_gh_cli; then
        log_error "GitHub CLI installation failed"
        return 1
    fi

    log_info "Verifying Git installation..."

    local failed=false

    if command_exists git; then
        local git_version
        git_version="$(git --version)"
        log_success "Git verified: $git_version"
    else
        log_error "Git verification failed"
        failed=true
    fi

    if command_exists git-lfs; then
        local lfs_version
        lfs_version="$(git-lfs --version)"
        log_success "Git LFS verified: $lfs_version"

        log_info "Initializing Git LFS..."
        if run_as_target_user git lfs install; then
            log_success "Git LFS initialized for user"
        else
            log_warning "Git LFS initialization failed"
        fi
    else
        log_error "Git LFS verification failed"
        failed=true
    fi

    if command_exists gh; then
        local gh_version
        gh_version="$(gh --version | head -n1)"
        log_success "GitHub CLI verified: $gh_version"
    else
        log_error "GitHub CLI verification failed"
        failed=true
    fi

    if [[ "$failed" == "true" ]]; then
        return 1
    fi

    setup_ssh_directory
    setup_git_config

    log_success "Git tools installation completed"
    return 0
}
