#!/usr/bin/env bash

# PHP module for DevForge
# Installs PHP, Composer, Laravel Installer, and Symfony CLI

# Default PHP version if not set in config
PHP_VERSION="${PHP_VERSION:-8.4}"

ensure_php_prerequisites() {
    local prerequisites=(
        ca-certificates
        curl
        wget
        gpg
        software-properties-common
        apt-transport-https
    )

    local package_name

    for package_name in "${prerequisites[@]}"; do
        if ! install_apt_package "$package_name"; then
            log_error "Required prerequisite installation failed: $package_name"
            return 1
        fi
    done
}

setup_ondrej_php_repository() {
    log_info "Setting up ondrej/php PPA for PHP ${PHP_VERSION}..."

    # Check if PPA already added
    if [[ -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.list ]] || \
       [[ -f /etc/apt/sources.list.d/ondrej-php-*.list ]]; then
        log_info "ondrej/php PPA already configured."
        return 0
    fi

    # Add the PPA using add-apt-repository
    if ! add-apt-repository -y ppa:ondrej/php; then
        log_error "Failed to add ondrej/php PPA"
        return 1
    fi

    # Mark APT indexes stale so they get refreshed
    mark_apt_indexes_stale

    log_success "ondrej/php PPA configured"
    return 0
}

install_php_packages() {
    log_info "Installing PHP ${PHP_VERSION} and extensions..."

    local php_packages=(
        "php${PHP_VERSION}"
        "php${PHP_VERSION}-cli"
        "php${PHP_VERSION}-common"
        "php${PHP_VERSION}-dev"
        "php${PHP_VERSION}-fpm"
        "php${PHP_VERSION}-mysql"
        "php${PHP_VERSION}-pgsql"
        "php${PHP_VERSION}-sqlite3"
        "php${PHP_VERSION}-curl"
        "php${PHP_VERSION}-gd"
        "php${PHP_VERSION}-intl"
        "php${PHP_VERSION}-mbstring"
        "php${PHP_VERSION}-xml"
        "php${PHP_VERSION}-zip"
        "php${PHP_VERSION}-bcmath"
        "php${PHP_VERSION}-soap"
        "php${PHP_VERSION}-readline"
        "php${PHP_VERSION}-opcache"
    )

    local package_name

    for package_name in "${php_packages[@]}"; do
        if ! install_apt_package "$package_name"; then
            log_error "Failed to install PHP package: $package_name"
            return 1
        fi
    done

    log_success "PHP ${PHP_VERSION} packages installed"
    return 0
}

install_composer() {
    if command_exists composer; then
        log_info "Composer is already installed. Skipping."
        metrics_record_application_skipped
        return 0
    fi

    log_info "Installing Composer..."

    local tmp_dir
    if ! tmp_dir="$(create_temp_dir)"; then
        return 1
    fi

    local installer_path="$tmp_dir/composer-setup.php"
    local expected_sig_path="$tmp_dir/expected-sig"

    # Download installer signature
    if ! download_file "https://composer.github.io/installer.sig" "$expected_sig_path"; then
        log_error "Failed to download Composer installer signature"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    local expected_sig
    expected_sig="$(cat "$expected_sig_path")"

    if [[ -z "$expected_sig" ]]; then
        log_error "Composer installer signature is empty"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    # Download installer
    if ! download_file "https://getcomposer.org/installer" "$installer_path"; then
        log_error "Failed to download Composer installer"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    # Verify installer signature
    local actual_sig
    actual_sig="$(php -r "echo hash_file('sha384', '$installer_path');")"

    if [[ "$expected_sig" != "$actual_sig" ]]; then
        log_error "Composer installer signature verification failed"
        log_error "Expected: $expected_sig"
        log_error "Actual:   $actual_sig"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    log_info "Composer installer signature verified"

    # Run installer
    if ! php "$installer_path" --install-dir=/usr/local/bin --filename=composer; then
        log_error "Failed to install Composer"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    cleanup_temp_dir "$tmp_dir"

    # Verify installation
    if ! command_exists composer; then
        log_error "Composer installation verification failed"
        return 1
    fi

    log_success "Composer installed"
    metrics_record_application_installed

    return 0
}

install_laravel_installer() {
    local target_home
    local composer_bin_path

    target_home="$(get_target_home)"
    composer_bin_path="$target_home/.config/composer/vendor/bin"

    # Check if Laravel installer already exists
    if [[ -x "$composer_bin_path/laravel" ]]; then
        log_info "Laravel installer is already installed. Skipping."
        metrics_record_application_skipped
        return 0
    fi

    # Alternative location check
    if [[ -x "$target_home/.composer/vendor/bin/laravel" ]]; then
        log_info "Laravel installer is already installed. Skipping."
        metrics_record_application_skipped
        return 0
    fi

    log_info "Installing Laravel installer..."

    # Ensure composer is available
    if ! command_exists composer; then
        log_error "Composer is required for Laravel installer"
        return 1
    fi

    # Install Laravel installer globally for target user
    if ! run_as_target_user composer global require laravel/installer; then
        log_error "Failed to install Laravel installer"
        return 1
    fi

    # Configure PATH for composer global binaries
    configure_composer_path

    # Verify installation
    if [[ -x "$composer_bin_path/laravel" ]] || [[ -x "$target_home/.composer/vendor/bin/laravel" ]]; then
        log_success "Laravel installer installed"
        metrics_record_application_installed
        return 0
    fi

    log_error "Laravel installer verification failed"
    return 1
}

configure_composer_path() {
    local target_home
    target_home="$(get_target_home)"

    local zshrc="$target_home/.zshrc"
    local bashrc="$target_home/.bashrc"

    # Modern Composer path
    local composer_path_line='export PATH="$HOME/.config/composer/vendor/bin:$PATH"'
    # Legacy Composer path
    local legacy_path_line='export PATH="$HOME/.composer/vendor/bin:$PATH"'

    # Add to .zshrc if exists
    if [[ -f "$zshrc" ]]; then
        add_composer_path_to_file "$zshrc" "$composer_path_line" "$legacy_path_line"
    fi

    # Add to .bashrc if exists
    if [[ -f "$bashrc" ]]; then
        add_composer_path_to_file "$bashrc" "$composer_path_line" "$legacy_path_line"
    fi
}

add_composer_path_to_file() {
    local file="$1"
    local modern_path="$2"
    local legacy_path="$3"

    # Check if either path is already configured
    if grep -qF '.config/composer/vendor/bin' "$file" 2>/dev/null || \
       grep -qF '.composer/vendor/bin' "$file" 2>/dev/null; then
        return 0
    fi

    # Add modern path
    if ! echo "$modern_path" >> "$file"; then
        log_warning "Failed to add Composer path to $file"
        return 1
    fi

    if ! ensure_target_ownership "$file"; then
        log_warning "Failed to set ownership on $file"
    fi

    log_info "Added Composer global bin to PATH in $(basename "$file")"
    return 0
}

install_symfony_cli() {
    if command_exists symfony; then
        log_info "Symfony CLI is already installed. Skipping."
        metrics_record_application_skipped
        return 0
    fi

    log_info "Installing Symfony CLI..."

    local tmp_dir
    if ! tmp_dir="$(create_temp_dir)"; then
        return 1
    fi

    # Download Symfony CLI installer
    if ! download_file "https://get.symfony.com/cli/installer" "$tmp_dir/symfony-installer"; then
        log_error "Failed to download Symfony CLI installer"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    # Run installer with install directory
    if ! bash "$tmp_dir/symfony-installer" --install-dir=/usr/local/bin; then
        log_error "Failed to install Symfony CLI"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    cleanup_temp_dir "$tmp_dir"

    # Verify installation
    if ! command_exists symfony; then
        log_error "Symfony CLI installation verification failed"
        return 1
    fi

    log_success "Symfony CLI installed"
    metrics_record_application_installed

    return 0
}

install_pecl_imagick() {
    log_info "Attempting to install PECL imagick..."

    # Install ImageMagick development libraries
    if ! install_apt_package "libmagickwand-dev"; then
        log_warning "Failed to install libmagickwand-dev, skipping imagick"
        return 0
    fi

    # Install PECL if not available
    if ! command_exists pecl; then
        log_warning "PECL not available, skipping imagick"
        return 0
    fi

    # Check if imagick is already installed
    if php -m 2>/dev/null | grep -qi imagick; then
        log_info "PHP imagick extension is already installed. Skipping."
        return 0
    fi

    # Try to install imagick via PECL
    # Use printf to handle interactive prompts
    if ! printf "\n" | pecl install imagick 2>/dev/null; then
        log_warning "Failed to install imagick via PECL (non-critical)"
        return 0
    fi

    # Enable the extension
    local php_ini_dir="/etc/php/${PHP_VERSION}/mods-available"
    local imagick_ini="$php_ini_dir/imagick.ini"

    if [[ -d "$php_ini_dir" ]]; then
        if ! echo "extension=imagick.so" > "$imagick_ini"; then
            log_warning "Failed to create imagick.ini"
            return 0
        fi

        # Enable for all SAPIs if phpenmod is available
        if command_exists phpenmod; then
            phpenmod imagick 2>/dev/null || true
        fi
    fi

    # Verify
    if php -m 2>/dev/null | grep -qi imagick; then
        log_success "PHP imagick extension installed"
    else
        log_warning "imagick extension installed but not loaded (may require service restart)"
    fi

    return 0
}

verify_php_installation() {
    log_info "Verifying PHP installation..."

    local failed=false

    # Verify PHP
    if ! verify_command php "PHP" php --version; then
        failed=true
    fi

    # Verify Composer
    if ! verify_command composer "Composer" composer --version; then
        failed=true
    fi

    # Verify Laravel (check in common locations)
    local target_home
    target_home="$(get_target_home)"

    local laravel_path=""
    if [[ -x "$target_home/.config/composer/vendor/bin/laravel" ]]; then
        laravel_path="$target_home/.config/composer/vendor/bin/laravel"
    elif [[ -x "$target_home/.composer/vendor/bin/laravel" ]]; then
        laravel_path="$target_home/.composer/vendor/bin/laravel"
    fi

    if [[ -n "$laravel_path" ]]; then
        local laravel_version
        laravel_version="$(run_as_target_user "$laravel_path" --version 2>/dev/null | head -n1)"
        if [[ -n "$laravel_version" ]]; then
            log_success "Laravel Installer verified: $laravel_version"
        else
            log_success "Laravel Installer verified"
        fi
    else
        log_error "Laravel Installer verification failed"
        failed=true
    fi

    # Verify Symfony CLI
    if ! verify_command symfony "Symfony CLI" symfony version; then
        failed=true
    fi

    if [[ "$failed" == "true" ]]; then
        return 1
    fi

    return 0
}

install_php() {
    log_step "Installing PHP ${PHP_VERSION} development environment"

    # Ensure prerequisites
    if ! ensure_php_prerequisites; then
        log_error "Failed to install PHP prerequisites"
        return 1
    fi

    # Setup ondrej/php repository
    if ! setup_ondrej_php_repository; then
        log_error "Failed to setup PHP repository"
        return 1
    fi

    # Install PHP packages
    if ! install_php_packages; then
        log_error "Failed to install PHP packages"
        return 1
    fi

    # Install Composer
    if ! install_composer; then
        log_error "Failed to install Composer"
        return 1
    fi

    # Install Laravel installer
    if ! install_laravel_installer; then
        log_error "Failed to install Laravel installer"
        return 1
    fi

    # Install Symfony CLI
    if ! install_symfony_cli; then
        log_error "Failed to install Symfony CLI"
        return 1
    fi

    # Install PECL imagick (optional - don't fail on error)
    install_pecl_imagick

    # Verify installation
    if ! verify_php_installation; then
        log_error "PHP installation verification failed"
        return 1
    fi

    log_success "PHP ${PHP_VERSION} development environment installation completed"
    return 0
}
