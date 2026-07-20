#!/usr/bin/env bash

# Git module for DevForge
# Installs Git, Git LFS, GitHub CLI, and configures SSH/git

# Install prerequisites for git module
ensure_git_prerequisites() {
    local prerequisites=(
        ca-certificates
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
}

install_gh_cli() {
    if command_exists gh; then
        log_info "GitHub CLI is already installed. Skipping."
        return 0
    fi

    log_info "Installing GitHub CLI..."

    # Check architecture
    if ! require_amd64 "GitHub CLI"; then
        return 1
    fi

    # Set up repository
    if ! ensure_apt_repository \
        "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
        "/etc/apt/keyrings/githubcli-archive-keyring.gpg" \
        "/etc/apt/sources.list.d/github-cli.list" \
        "deb [arch=amd64 signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        "binary"; then
        return 1
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
        if ! mkdir -p "$ssh_dir"; then
            log_error "Failed to create SSH directory"
            return 1
        fi
    else
        log_info "SSH directory already exists at $ssh_dir"
    fi

    # ALWAYS enforce permissions, regardless of whether dir existed
    if ! chmod 700 "$ssh_dir"; then
        log_error "Failed to set permissions on SSH directory"
        return 1
    fi
    if ! ensure_target_ownership "$ssh_dir"; then
        log_error "Failed to set ownership on SSH directory"
        return 1
    fi

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

    if ! cat > "$git_config" <<'EOF'
[init]
	defaultBranch = main

[pull]
	rebase = false

[core]
	editor = nano
EOF
    then
        log_error "Failed to write Git config file"
        return 1
    fi

    if ! ensure_target_ownership "$git_config"; then
        log_error "Failed to set ownership on Git config"
        return 1
    fi
    if ! chmod 644 "$git_config"; then
        log_error "Failed to set permissions on Git config"
        return 1
    fi

    log_info "Configure Git user with:"
    log_info "  git config --global user.name \"Your Name\""
    log_info "  git config --global user.email \"your.email@example.com\""

    log_success "Git config created"
    return 0
}

install_git() {
    log_step "Installing Git tools"

    if ! ensure_git_prerequisites; then
        return 1
    fi

    local packages=(
        git
        git-lfs
    )

    local package_name

    for package_name in "${packages[@]}"; do
        if ! install_apt_package "$package_name"; then
            log_error "Required package installation failed: $package_name"
            return 1
        fi
    done

    # GitHub CLI is required
    if ! install_gh_cli; then
        log_error "GitHub CLI installation failed"
        return 1
    fi

    log_info "Verifying Git installation..."

    local failed=false

    # Verify Git
    if ! verify_command git "Git" git --version; then
        failed=true
    fi

    # Verify Git LFS
    if command_exists git-lfs; then
        if ! verify_command git-lfs "Git LFS" git-lfs --version; then
            failed=true
        fi

        # Git LFS init still needs special handling
        log_info "Initializing Git LFS..."
        if ! run_as_target_user git lfs install; then
            log_error "Git LFS initialization failed"
            failed=true
        else
            log_success "Git LFS initialized for user"
        fi
    else
        log_error "Git LFS verification failed"
        failed=true
    fi

    # Verify GitHub CLI
    if ! verify_command gh "GitHub CLI" gh --version; then
        failed=true
    fi

    if [[ "$failed" == "true" ]]; then
        return 1
    fi

    if ! setup_ssh_directory; then
        log_error "SSH directory setup failed"
        return 1
    fi

    if ! setup_git_config; then
        log_error "Git config setup failed"
        return 1
    fi

    log_success "Git tools installation completed"
    return 0
}
