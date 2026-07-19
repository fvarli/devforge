#!/usr/bin/env bash

ensure_terminal_prerequisites() {
    local prerequisites=(
        ca-certificates
        curl
        wget
        gpg
    )

    local package_name

    for package_name in "${prerequisites[@]}"; do
        install_apt_package "$package_name"
    done
}

add_line_to_file_idempotent() {
    local file="$1"
    local line="$2"

    if [[ ! -f "$file" ]]; then
        local file_dir
        file_dir="$(dirname "$file")"
        mkdir -p "$file_dir"

        touch "$file"
        ensure_target_ownership "$file"
    fi

    if ! grep -qxF "$line" "$file"; then
        echo "$line" >> "$file"
        log_info "Added to $(basename "$file"): $line"
    fi
}

install_starship() {
    if command_exists starship; then
        log_info "Starship is already installed. Skipping."
        return 0
    fi

    log_info "Installing Starship..."

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    cleanup_starship() {
        rm -rf "$tmp_dir"
    }

    trap cleanup_starship RETURN

    if ! curl -fsSL "https://starship.rs/install.sh" -o "$tmp_dir/starship-install.sh"; then
        log_error "Failed to download Starship installer"
        return 1
    fi

    if ! sh "$tmp_dir/starship-install.sh" -y; then
        log_error "Failed to install Starship"
        return 1
    fi

    log_success "Starship installed"
    return 0
}

configure_starship() {
    local target_home
    target_home="$(get_target_home)"

    local zshrc="$target_home/.zshrc"
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

    local keyring_file="/etc/apt/keyrings/gierens.gpg"
    local sources_file="/etc/apt/sources.list.d/gierens.list"
    local expected_source="deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main"

    local needs_update=false

    if [[ ! -f "$keyring_file" ]]; then
        log_info "Adding eza repository GPG key..."

        mkdir -p /etc/apt/keyrings
        chmod 755 /etc/apt/keyrings

        local tmp_dir
        tmp_dir="$(mktemp -d)"

        cleanup_eza() {
            rm -rf "$tmp_dir"
        }

        trap cleanup_eza RETURN

        if ! wget -qO- "https://raw.githubusercontent.com/eza-community/eza/main/deb.asc" | \
             gpg --dearmor -o "$tmp_dir/gierens.gpg"; then
            log_error "Failed to download eza GPG key"
            return 1
        fi

        install -D -o root -g root -m 644 "$tmp_dir/gierens.gpg" "$keyring_file"
        needs_update=true
    fi

    if [[ ! -f "$sources_file" ]] || ! grep -qxF "$expected_source" "$sources_file"; then
        log_info "Adding eza repository..."

        echo "$expected_source" > "$sources_file"
        chmod 644 "$sources_file"
        needs_update=true
    fi

    if [[ "$needs_update" == "true" ]]; then
        mark_apt_indexes_stale
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
        return 0
    fi

    log_info "Installing zoxide..."

    # Try APT first - don't suppress errors
    if install_apt_package zoxide; then
        log_success "zoxide installed from APT"
        return 0
    fi

    log_warning "zoxide not available in APT, using official installer..."

    local target_user
    local target_home
    target_user="$(get_target_user)"
    target_home="$(get_target_home)"

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    cleanup_zoxide() {
        rm -rf "$tmp_dir"
    }

    trap cleanup_zoxide RETURN

    if ! curl -fsSL "https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh" \
         -o "$tmp_dir/zoxide-install.sh"; then
        log_error "Failed to download zoxide installer"
        return 1
    fi

    if ! HOME="$target_home" run_as_target_user sh "$tmp_dir/zoxide-install.sh"; then
        log_error "Failed to install zoxide"
        return 1
    fi

    # Verify installation
    if ! command_exists_for_user zoxide; then
        log_error "zoxide installed but verification failed"
        return 1
    fi

    log_success "zoxide installed"
    return 0
}

configure_zoxide() {
    local target_home
    target_home="$(get_target_home)"

    local zshrc="$target_home/.zshrc"
    local zoxide_init='eval "$(zoxide init zsh)"'

    add_line_to_file_idempotent "$zshrc" "$zoxide_init"
}

install_terminal() {
    log_step "Installing terminal tools"

    ensure_terminal_prerequisites
    ensure_local_bin

    local packages=(
        zsh
        fzf
        bat
        tmux
    )

    local package_name

    for package_name in "${packages[@]}"; do
        install_apt_package "$package_name"
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

    # Configure only if tools are available
    if command_exists starship; then
        configure_starship
    fi

    if command_exists_for_user zoxide; then
        configure_zoxide
    fi

    log_info "Verifying terminal tools..."

    local failed=false

    # Verify base packages
    for package_name in "${packages[@]}"; do
        if ! command_exists "$package_name"; then
            log_error "Required package verification failed: $package_name"
            failed=true
        fi
    done

    # Verify batcat specifically
    if ! command_exists batcat; then
        log_error "batcat verification failed"
        failed=true
    fi

    # Verify required tools
    for tool in eza starship; do
        if ! command_exists "$tool"; then
            log_error "Tool verification failed: $tool"
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
