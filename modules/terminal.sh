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
    local target_user
    local target_home

    target_user="$(get_target_user)"
    target_home="$(get_target_home)"

    if [[ ! -f "$file" ]]; then
        local file_dir
        file_dir="$(dirname "$file")"
        mkdir -p "$file_dir"

        touch "$file"

        if [[ "$target_user" != "$USER" ]]; then
            local user_uid
            local user_gid
            user_uid="$(id -u "$target_user")"
            user_gid="$(id -g "$target_user")"
            chown "$user_uid:$user_gid" "$file"
        fi
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

    local cleanup_starship() {
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

        local cleanup_eza() {
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
    if command_exists zoxide; then
        log_info "zoxide is already installed. Skipping."
        return 0
    fi

    log_info "Installing zoxide..."

    if install_apt_package zoxide 2>/dev/null; then
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

    local cleanup_zoxide() {
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

    local failed=false

    if ! install_eza; then
        log_warning "eza installation failed, continuing with other tools"
    fi

    if ! install_zoxide; then
        log_warning "zoxide installation failed, continuing with other tools"
    fi

    if ! install_starship; then
        log_warning "Starship installation failed, continuing with other tools"
    fi

    if command_exists starship; then
        configure_starship
    fi

    if command_exists zoxide; then
        configure_zoxide
    fi

    log_info "Verifying terminal tools..."

    for package_name in "${packages[@]}"; do
        if ! command_exists "$package_name"; then
            log_error "Required package verification failed: $package_name"
            failed=true
        fi
    done

    if [[ "$failed" == "true" ]]; then
        return 1
    fi

    log_success "Terminal tools installation completed"
    return 0
}
