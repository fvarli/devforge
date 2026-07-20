#!/usr/bin/env bash

# PHP module for DevForge
# Installs PHP, Composer, Laravel Installer, and Symfony CLI

# Default PHP version if not set in config
PHP_VERSION="${PHP_VERSION:-8.4}"

# Config defaults
SET_DEFAULT_PHP="${SET_DEFAULT_PHP:-true}"
INSTALL_PHP_IMAGICK="${INSTALL_PHP_IMAGICK:-true}"
INSTALL_LARAVEL_INSTALLER="${INSTALL_LARAVEL_INSTALLER:-true}"
INSTALL_SYMFONY_CLI="${INSTALL_SYMFONY_CLI:-true}"

# Supported PHP versions (EOL versions excluded: 8.0, 8.1)
SUPPORTED_PHP_VERSIONS=("8.2" "8.3" "8.4")

validate_php_version() {
    local version="$1"
    local supported

    for supported in "${SUPPORTED_PHP_VERSIONS[@]}"; do
        if [[ "$version" == "$supported" ]]; then
            return 0
        fi
    done

    log_error "Unsupported PHP version: $version"
    log_error "Supported versions: ${SUPPORTED_PHP_VERSIONS[*]}"
    log_error "Note: PHP 8.0 and 8.1 are EOL and not supported"
    return 1
}

# Check if the system is Ubuntu-compatible for ondrej/php PPA
is_ubuntu_compatible() {
    if [[ ! -f /etc/os-release ]]; then
        return 1
    fi

    # shellcheck source=/dev/null
    . /etc/os-release

    # Direct Ubuntu
    if [[ "${ID:-}" == "ubuntu" ]]; then
        return 0
    fi

    # Ubuntu-based distributions
    if [[ "${ID_LIKE:-}" == *"ubuntu"* ]]; then
        return 0
    fi

    # Known Ubuntu derivatives
    case "${ID:-}" in
        pop|linuxmint|kubuntu|xubuntu|lubuntu|elementary)
            return 0
            ;;
    esac

    return 1
}

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

    # Verify Ubuntu compatibility before attempting PPA
    if ! is_ubuntu_compatible; then
        log_error "ondrej/php PPA requires Ubuntu or Ubuntu-based distribution"
        log_error "Current system is not compatible with PPA"
        return 1
    fi

    # Robust check using compgen for safe glob expansion
    if compgen -G "/etc/apt/sources.list.d/*ondrej*php*.list" >/dev/null 2>&1 || \
       compgen -G "/etc/apt/sources.list.d/*ondrej*php*.sources" >/dev/null 2>&1; then
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
        "php-pear"
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

set_default_php_version() {
    if [[ "${SET_DEFAULT_PHP}" != "true" ]]; then
        log_info "Skipping default PHP version configuration (SET_DEFAULT_PHP=false)"
        return 0
    fi

    log_info "Setting PHP ${PHP_VERSION} as default..."

    local php_binary="/usr/bin/php${PHP_VERSION}"

    if [[ ! -x "$php_binary" ]]; then
        log_error "PHP binary not found: $php_binary"
        return 1
    fi

    # Set update-alternatives for PHP commands
    local alternatives=(
        "php:php${PHP_VERSION}"
        "phar:phar${PHP_VERSION}"
        "phar.phar:phar.phar${PHP_VERSION}"
        "phpize:phpize${PHP_VERSION}"
        "php-config:php-config${PHP_VERSION}"
    )

    local entry
    local name
    local binary

    for entry in "${alternatives[@]}"; do
        name="${entry%%:*}"
        binary="${entry#*:}"

        if [[ -x "/usr/bin/$binary" ]]; then
            if ! update-alternatives --set "$name" "/usr/bin/$binary" 2>/dev/null; then
                # Alternative may not exist yet, try to install it
                update-alternatives --install "/usr/bin/$name" "$name" "/usr/bin/$binary" 100 2>/dev/null || true
                update-alternatives --set "$name" "/usr/bin/$binary" 2>/dev/null || true
            fi
        fi
    done

    # Verify default PHP version
    local actual_version
    actual_version="$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;' 2>/dev/null)"

    if [[ "$actual_version" != "$PHP_VERSION" ]]; then
        log_warning "PHP default version mismatch: expected $PHP_VERSION, got $actual_version"
        return 1
    fi

    log_success "PHP ${PHP_VERSION} set as default"
    return 0
}

get_composer_global_bin() {
    local target_home
    target_home="$(get_target_home)"

    # Try to get bin-dir from Composer config
    local bin_dir
    bin_dir="$(run_as_target_user composer global config bin-dir --absolute 2>/dev/null || true)"

    if [[ -n "$bin_dir" && -d "$bin_dir" ]]; then
        echo "$bin_dir"
        return 0
    fi

    # Fallback to known paths
    if [[ -d "$target_home/.config/composer/vendor/bin" ]]; then
        echo "$target_home/.config/composer/vendor/bin"
        return 0
    fi

    if [[ -d "$target_home/.composer/vendor/bin" ]]; then
        echo "$target_home/.composer/vendor/bin"
        return 0
    fi

    # Return expected default path even if it doesn't exist yet
    echo "$target_home/.config/composer/vendor/bin"
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

    # Validate signature format (SHA384 = 96 hex chars)
    if [[ ! "$expected_sig" =~ ^[a-fA-F0-9]{96}$ ]]; then
        log_error "Invalid Composer signature format"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    # Download installer
    if ! download_file "https://getcomposer.org/installer" "$installer_path"; then
        log_error "Failed to download Composer installer"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    # Verify installer signature using specified PHP version
    local actual_sig
    actual_sig="$("php${PHP_VERSION}" -r "echo hash_file('sha384', '$installer_path');")"

    if [[ "$expected_sig" != "$actual_sig" ]]; then
        log_error "Composer installer signature verification failed"
        log_error "Expected: $expected_sig"
        log_error "Actual:   $actual_sig"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    log_info "Composer installer signature verified"

    # Run installer with specified PHP version
    if ! "php${PHP_VERSION}" "$installer_path" --install-dir=/usr/local/bin --filename=composer; then
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
    if [[ "${INSTALL_LARAVEL_INSTALLER}" != "true" ]]; then
        log_info "Skipping Laravel installer (INSTALL_LARAVEL_INSTALLER=false)"
        return 0
    fi

    local composer_bin_path
    composer_bin_path="$(get_composer_global_bin)"

    # Check if Laravel installer already exists
    if [[ -x "$composer_bin_path/laravel" ]]; then
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

    # Configure PATH for composer global binaries (REQUIRED)
    if ! configure_composer_path; then
        log_error "Failed to configure Composer PATH"
        return 1
    fi

    # Refresh bin path after installation
    composer_bin_path="$(get_composer_global_bin)"

    # Verify installation
    if [[ -x "$composer_bin_path/laravel" ]]; then
        # Verify laravel command works
        local laravel_version
        laravel_version="$(run_as_target_user "$composer_bin_path/laravel" --version 2>/dev/null | head -n1 || true)"

        if [[ -n "$laravel_version" ]]; then
            log_success "Laravel installer installed: $laravel_version"
        else
            log_success "Laravel installer installed"
        fi

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

    # Get resolved Composer global bin path
    local composer_bin_path
    composer_bin_path="$(get_composer_global_bin)"

    if [[ -z "$composer_bin_path" ]]; then
        log_error "Could not determine Composer global bin path"
        return 1
    fi

    # Use resolved path in configuration
    local composer_config
    composer_config="
# Composer global bin
export PATH=\"$composer_bin_path:\$PATH\""

    # Check if already configured (either modern or legacy path)
    local marker=".config/composer/vendor/bin"
    local legacy_marker=".composer/vendor/bin"

    local failed=false

    # Add to .bashrc (REQUIRED)
    if ! grep -qF "$marker" "$bashrc" 2>/dev/null && \
       ! grep -qF "$legacy_marker" "$bashrc" 2>/dev/null; then
        if ! add_config_to_shell_file "$bashrc" "$composer_config" "$marker"; then
            log_error "Failed to add Composer PATH to .bashrc"
            failed=true
        else
            log_info "Added Composer PATH to .bashrc"
        fi
    fi

    # Add to .zshrc (if zsh is available)
    if [[ -f "$zshrc" ]] || command_exists zsh; then
        if ! grep -qF "$marker" "$zshrc" 2>/dev/null && \
           ! grep -qF "$legacy_marker" "$zshrc" 2>/dev/null; then
            if ! add_config_to_shell_file "$zshrc" "$composer_config" "$marker"; then
                log_error "Failed to add Composer PATH to .zshrc"
                failed=true
            else
                log_info "Added Composer PATH to .zshrc"
            fi
        fi
    fi

    [[ "$failed" == "true" ]] && return 1
    return 0
}

install_symfony_cli() {
    if [[ "${INSTALL_SYMFONY_CLI}" != "true" ]]; then
        log_info "Skipping Symfony CLI (INSTALL_SYMFONY_CLI=false)"
        return 0
    fi

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

    local installer_path="$tmp_dir/symfony-installer"
    local symfony_binary="$tmp_dir/symfony"

    # Download Symfony CLI installer
    if ! download_file "https://get.symfony.com/cli/installer" "$installer_path"; then
        log_error "Failed to download Symfony CLI installer"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    # Run installer - it downloads the binary to current directory
    if ! (cd "$tmp_dir" && bash "$installer_path" --install-dir="$tmp_dir"); then
        log_error "Failed to run Symfony CLI installer"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    # Check deterministic paths only (no broad find)
    local found_binary=""
    local check_paths=(
        "$tmp_dir/symfony"
        "$tmp_dir/bin/symfony"
        "$tmp_dir/.symfony5/bin/symfony"
        "$tmp_dir/.symfony/bin/symfony"
    )

    local path
    for path in "${check_paths[@]}"; do
        if [[ -f "$path" && -x "$path" ]]; then
            found_binary="$path"
            break
        fi
    done

    if [[ -z "$found_binary" ]]; then
        log_error "Symfony binary not found in expected locations"
        log_error "Checked: ${check_paths[*]}"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    # Install to /usr/local/bin with proper permissions
    if ! install -o root -g root -m 755 "$found_binary" /usr/local/bin/symfony; then
        log_error "Failed to install Symfony CLI to /usr/local/bin"
        cleanup_temp_dir "$tmp_dir"
        return 1
    fi

    cleanup_temp_dir "$tmp_dir"

    # Verify installation at expected location
    if [[ ! -x "/usr/local/bin/symfony" ]]; then
        log_error "Symfony CLI not found at /usr/local/bin/symfony"
        return 1
    fi

    # Verify command works
    if ! /usr/local/bin/symfony version >/dev/null 2>&1; then
        log_error "Symfony CLI installation verification failed"
        return 1
    fi

    log_success "Symfony CLI installed"
    metrics_record_application_installed

    return 0
}

install_pecl_imagick() {
    if [[ "${INSTALL_PHP_IMAGICK}" != "true" ]]; then
        log_info "Skipping imagick (INSTALL_PHP_IMAGICK=false)"
        return 0
    fi

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

    # Check if imagick is already installed using specified PHP version
    if "php${PHP_VERSION}" -m 2>/dev/null | grep -qi imagick; then
        log_info "PHP imagick extension is already installed. Skipping."
        return 0
    fi

    # Check if imagick.ini already exists
    local php_ini_dir="/etc/php/${PHP_VERSION}/mods-available"
    local imagick_ini="$php_ini_dir/imagick.ini"

    if [[ -f "$imagick_ini" ]]; then
        log_info "imagick.ini already exists, enabling module..."
        if command_exists phpenmod; then
            phpenmod -v "$PHP_VERSION" imagick 2>/dev/null || true
        fi
        return 0
    fi

    # Try to install imagick via PECL
    # Use printf to handle interactive prompts
    if ! printf "\n" | pecl install imagick 2>/dev/null; then
        log_warning "Failed to install imagick via PECL (non-critical)"
        return 0
    fi

    # Enable the extension
    if [[ -d "$php_ini_dir" ]]; then
        if ! echo "extension=imagick.so" > "$imagick_ini"; then
            log_warning "Failed to create imagick.ini"
            return 0
        fi

        # Enable for the specific PHP version
        if command_exists phpenmod; then
            phpenmod -v "$PHP_VERSION" imagick 2>/dev/null || true
        fi
    fi

    # Verify using specified PHP version
    if "php${PHP_VERSION}" -m 2>/dev/null | grep -qi imagick; then
        log_success "PHP imagick extension installed"
    else
        log_warning "imagick extension installed but not loaded (may require service restart)"
    fi

    return 0
}

verify_php_extensions() {
    log_info "Verifying PHP extensions..."

    # Run php -m once and store output
    local php_modules
    if ! php_modules="$("php${PHP_VERSION}" -m 2>/dev/null)"; then
        log_error "Failed to get PHP modules list"
        return 1
    fi

    local required_extensions=(
        bcmath
        curl
        gd
        intl
        mbstring
        pdo_mysql
        pdo_pgsql
        pdo_sqlite
        soap
        xml
        zip
    )

    local failed=false
    local extension

    for extension in "${required_extensions[@]}"; do
        if echo "$php_modules" | grep -qi "^${extension}$"; then
            log_info "Extension $extension: OK"
        else
            log_error "Extension $extension: NOT LOADED"
            failed=true
        fi
    done

    # Check OPcache separately (listed as "Zend OPcache" in php -m)
    if echo "$php_modules" | grep -qi "Zend OPcache"; then
        log_info "Extension opcache: OK"
    else
        log_error "Extension opcache: NOT LOADED"
        failed=true
    fi

    if [[ "$failed" == "true" ]]; then
        log_error "Required PHP extensions are missing"
        return 1
    fi

    return 0
}

verify_php_installation() {
    log_info "Verifying PHP installation..."

    local failed=false

    # Verify PHP with version check
    if ! command_exists "php${PHP_VERSION}"; then
        log_error "PHP ${PHP_VERSION} binary not found"
        failed=true
    else
        local php_version_output
        php_version_output="$("php${PHP_VERSION}" --version 2>/dev/null | head -n1)"
        if [[ -n "$php_version_output" ]]; then
            log_success "PHP verified: $php_version_output"
        else
            log_error "PHP version check failed"
            failed=true
        fi
    fi

    # Verify Composer
    if ! verify_command composer "Composer" composer --version; then
        failed=true
    fi

    # Verify Laravel (if enabled)
    if [[ "${INSTALL_LARAVEL_INSTALLER}" == "true" ]]; then
        local composer_bin_path
        composer_bin_path="$(get_composer_global_bin)"

        if [[ -x "$composer_bin_path/laravel" ]]; then
            local laravel_version
            laravel_version="$(run_as_target_user "$composer_bin_path/laravel" --version 2>/dev/null | head -n1 || true)"
            if [[ -n "$laravel_version" ]]; then
                log_success "Laravel Installer verified: $laravel_version"
            else
                log_success "Laravel Installer verified"
            fi
        else
            log_error "Laravel Installer verification failed"
            failed=true
        fi
    fi

    # Verify Symfony CLI (if enabled)
    if [[ "${INSTALL_SYMFONY_CLI}" == "true" ]]; then
        if ! verify_command symfony "Symfony CLI" symfony version; then
            failed=true
        fi
    fi

    # Verify extensions (REQUIRED)
    if ! verify_php_extensions; then
        failed=true
    fi

    if [[ "$failed" == "true" ]]; then
        return 1
    fi

    return 0
}

install_php() {
    log_step "Installing PHP ${PHP_VERSION} development environment"

    # Validate boolean configurations
    if ! validate_boolean_configs \
        "SET_DEFAULT_PHP" "${SET_DEFAULT_PHP:-true}" \
        "INSTALL_PHP_IMAGICK" "${INSTALL_PHP_IMAGICK:-true}" \
        "INSTALL_LARAVEL_INSTALLER" "${INSTALL_LARAVEL_INSTALLER:-true}" \
        "INSTALL_SYMFONY_CLI" "${INSTALL_SYMFONY_CLI:-true}"; then
        log_error "Invalid boolean configuration in PHP module"
        return 1
    fi

    # Validate PHP version
    if ! validate_php_version "$PHP_VERSION"; then
        return 1
    fi

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

    # Set default PHP version (if enabled, failure is critical)
    if [[ "${SET_DEFAULT_PHP}" == "true" ]]; then
        if ! set_default_php_version; then
            log_error "Failed to set default PHP version"
            return 1
        fi
    else
        log_info "Skipping default PHP version configuration (SET_DEFAULT_PHP=false)"
    fi

    # Install Composer
    if ! install_composer; then
        log_error "Failed to install Composer"
        return 1
    fi

    # Install Laravel installer (respects config)
    if ! install_laravel_installer; then
        log_error "Failed to install Laravel installer"
        return 1
    fi

    # Install Symfony CLI (respects config)
    if ! install_symfony_cli; then
        log_error "Failed to install Symfony CLI"
        return 1
    fi

    # Install PECL imagick (optional - respects config, don't fail on error)
    install_pecl_imagick

    # Verify installation
    if ! verify_php_installation; then
        log_error "PHP installation verification failed"
        return 1
    fi

    log_success "PHP ${PHP_VERSION} development environment installation completed"
    return 0
}
