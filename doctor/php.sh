#!/usr/bin/env bash

# Doctor: PHP checks
# Checks PHP, extensions, Composer, Laravel Installer, Symfony CLI

doctor_check_php() {
    doctor_section "PHP"

    local php_version="${PHP_VERSION:-8.4}"

    # Check PHP
    if command_exists "php${php_version}"; then
        local php_output
        php_output="$("php${php_version}" --version 2>/dev/null | head -n1)"
        doctor_pass "PHP: $php_output"
    elif command_exists php; then
        local php_output
        php_output="$(php --version 2>/dev/null | head -n1)"
        doctor_warn "PHP: $php_output (expected php${php_version})"
    else
        doctor_fail "PHP: not found"
        return
    fi

    # Check key extensions
    local php_modules
    php_modules="$("php${php_version}" -m 2>/dev/null || php -m 2>/dev/null || true)"

    local critical_extensions=(mbstring curl pdo_mysql pdo_pgsql)
    local ext
    for ext in "${critical_extensions[@]}"; do
        if echo "$php_modules" | grep -qi "^${ext}$"; then
            doctor_pass "PHP extension: $ext"
        else
            doctor_fail "PHP extension: $ext not loaded"
        fi
    done

    # Check Composer
    if command_exists composer; then
        local composer_version
        composer_version="$(composer --version 2>/dev/null | head -n1)"
        doctor_pass "Composer: $composer_version"
    else
        doctor_fail "Composer: not found"
    fi

    # Check Laravel installer
    local composer_bin
    composer_bin="$(get_composer_global_bin 2>/dev/null || true)"
    if [[ -x "$composer_bin/laravel" ]]; then
        doctor_pass "Laravel Installer: installed"
    elif [[ "${INSTALL_LARAVEL_INSTALLER:-true}" == "true" ]]; then
        doctor_fail "Laravel Installer: not found"
    else
        doctor_skip "Laravel Installer: disabled"
    fi

    # Check Symfony CLI
    if command_exists symfony; then
        local symfony_version
        symfony_version="$(symfony version 2>/dev/null | head -n1 || true)"
        doctor_pass "Symfony CLI: $symfony_version"
    elif [[ "${INSTALL_SYMFONY_CLI:-true}" == "true" ]]; then
        doctor_fail "Symfony CLI: not found"
    else
        doctor_skip "Symfony CLI: disabled"
    fi
}
