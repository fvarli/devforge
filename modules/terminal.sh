#!/usr/bin/env bash

# Terminal module for DevForge
# Installs modern shell tools: zsh, fzf, bat, eza, zoxide, starship

# Install prerequisites for terminal module
ensure_terminal_prerequisites() {
    local prerequisites=(
        ca-certificates
        curl
        wget
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

add_line_to_file_idempotent() {
    local file="$1"
    local line="$2"

    if [[ ! -f "$file" ]]; then
        local file_dir
        file_dir="$(dirname "$file")"
        if ! mkdir -p "$file_dir"; then
            log_error "Failed to create directory for $file"
            return 1
        fi

        if ! touch "$file"; then
            log_error "Failed to create $file"
            return 1
        fi
        if ! ensure_target_ownership "$file"; then
            log_error "Failed to set ownership on $file"
            return 1
        fi
    fi

    if ! grep -qxF "$line" "$file"; then
        if ! echo "$line" >> "$file"; then
            log_error "Failed to append to $file"
            return 1
        fi
        log_info "Added to $(basename "$file"): $line"
    fi
}

install_starship() {
    if command_exists starship; then
        log_info "Starship is already installed. Skipping."
        metrics_record_application_skipped
        return 0
    fi

    log_info "Installing Starship..."

    local tmp_dir
    if ! tmp_dir="$(create_temp_dir)"; then
        return 1
    fi

    if ! download_file "https://starship.rs/install.sh" "$tmp_dir/starship-install.sh"; then
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    if ! sh "$tmp_dir/starship-install.sh" -y; then
        log_error "Failed to install Starship"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    cleanup_temp_dir "$tmp_dir"
    log_success "Starship installed"
    metrics_record_application_installed

    return 0
}

configure_starship() {
    local target_home
    target_home="$(get_target_home)"

    local zshrc="$target_home/.zshrc"
    # Intentional literal shell config - expanded when user sources it
    # shellcheck disable=SC2016
    local starship_init='eval "$(starship init zsh)"'

    add_line_to_file_idempotent "$zshrc" "$starship_init"
}

ensure_bat_symlink() {
    local batcat_path="/usr/bin/batcat"
    local bat_symlink="/usr/local/bin/bat"

    # Only proceed if batcat exists
    if [[ ! -f "$batcat_path" ]]; then
        log_info "batcat not found, skipping symlink creation"
        return 0
    fi

    # If symlink already exists and points to correct location, we're done
    if [[ -L "$bat_symlink" ]] && [[ "$(readlink "$bat_symlink")" == "$batcat_path" ]]; then
        return 0
    fi

    # If something else exists at the symlink location, don't override
    if [[ -e "$bat_symlink" ]] && [[ ! -L "$bat_symlink" ]]; then
        log_warning "File exists at $bat_symlink but is not a symlink to batcat"
        return 1
    fi

    # Remove old symlink if it exists and points elsewhere
    if [[ -L "$bat_symlink" ]]; then
        rm "$bat_symlink"
    fi

    # Create the symlink
    ln -s "$batcat_path" "$bat_symlink"
    log_success "Created symlink: bat -> batcat"
    return 0
}

install_eza() {
    if command_exists eza; then
        log_info "eza is already installed. Skipping."
        return 0
    fi

    log_info "Installing eza..."

    # Set up repository
    if ! ensure_apt_repository \
        "https://raw.githubusercontent.com/eza-community/eza/main/deb.asc" \
        "/etc/apt/keyrings/gierens.gpg" \
        "/etc/apt/sources.list.d/gierens.list" \
        "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
        "dearmor"; then
        return 1
    fi

    if ! install_apt_package eza; then
        log_error "Failed to install eza"
        return 1
    fi

    return 0
}

install_zoxide() {
    if command_exists_for_user zoxide; then
        log_info "zoxide is already installed. Skipping."
        metrics_record_application_skipped
        return 0
    fi

    log_info "Installing zoxide..."

    # Try APT first with skip_metrics=true (zoxide counts as application, not package)
    if install_apt_package zoxide true; then
        log_success "zoxide installed from APT"
        metrics_record_application_installed
        return 0
    fi

    log_warning "zoxide not available in APT, using official installer..."

    local target_home
    target_home="$(get_target_home)"

    local tmp_dir
    if ! tmp_dir="$(create_temp_dir)"; then
        return 1
    fi

    if ! download_file "https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh" "$tmp_dir/zoxide-install.sh"; then
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    if ! HOME="$target_home" run_as_target_user sh "$tmp_dir/zoxide-install.sh"; then
        log_error "Failed to install zoxide"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    # Verify installation
    if ! command_exists_for_user zoxide; then
        log_error "zoxide installed but verification failed"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    cleanup_temp_dir "$tmp_dir"
    log_success "zoxide installed"
    metrics_record_application_installed

    return 0
}

configure_zoxide() {
    local target_home
    target_home="$(get_target_home)"

    local zshrc="$target_home/.zshrc"
    # Intentional literal shell config - expanded when user sources it
    # shellcheck disable=SC2016
    local zoxide_init='eval "$(zoxide init zsh)"'

    add_line_to_file_idempotent "$zshrc" "$zoxide_init"
}

install_terminal() {
    log_step "Installing terminal tools"

    if ! ensure_terminal_prerequisites; then
        return 1
    fi

    if ! ensure_local_bin; then
        log_error "Failed to ensure ~/.local/bin directory"
        return 1
    fi

    local packages=(
        zsh
        fzf
        bat
        tmux
    )

    local package_name

    for package_name in "${packages[@]}"; do
        if ! install_apt_package "$package_name"; then
            log_error "Required package installation failed: $package_name"
            return 1
        fi
    done

    # Required tools - fail if they don't install
    if ! install_eza; then
        log_error "eza installation failed"
        return 1
    fi

    if ! install_zoxide; then
        log_error "zoxide installation failed"
        return 1
    fi

    if ! install_starship; then
        log_error "Starship installation failed"
        return 1
    fi

    if ! ensure_bat_symlink; then
        log_error "bat symlink creation failed"
        return 1
    fi

    # Configure tools (required for terminal module)
    if command_exists starship; then
        if ! configure_starship; then
            log_error "Starship configuration failed"
            return 1
        fi
    fi

    if command_exists_for_user zoxide; then
        if ! configure_zoxide; then
            log_error "zoxide configuration failed"
            return 1
        fi
    fi

    log_info "Verifying terminal tools..."

    local failed=false
    local cmd

    # Verify base commands (note: 'bat' package installs as 'batcat' command)
    local required_commands=(
        zsh
        fzf
        batcat
        tmux
        eza
        starship
    )

    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            log_error "Required command verification failed: $cmd"
            failed=true
        fi
    done

    # Verify zoxide (may be in ~/.local/bin)
    if ! command_exists_for_user zoxide; then
        log_error "zoxide verification failed"
        failed=true
    fi

    if [[ "$failed" == "true" ]]; then
        return 1
    fi

    log_success "Terminal tools installation completed"
    return 0
}
