#!/usr/bin/env bash

# Databases module for DevForge
# Installs MySQL, PostgreSQL, Redis, and SQLite

# Config defaults
INSTALL_MYSQL="${INSTALL_MYSQL:-true}"
INSTALL_POSTGRESQL="${INSTALL_POSTGRESQL:-true}"
INSTALL_REDIS="${INSTALL_REDIS:-true}"
INSTALL_SQLITE="${INSTALL_SQLITE:-true}"
ENABLE_MYSQL_SERVICE="${ENABLE_MYSQL_SERVICE:-true}"
ENABLE_POSTGRESQL_SERVICE="${ENABLE_POSTGRESQL_SERVICE:-true}"
ENABLE_REDIS_SERVICE="${ENABLE_REDIS_SERVICE:-true}"
INSTALL_DATABASE_CLIENTS="${INSTALL_DATABASE_CLIENTS:-true}"

# Track which databases were installed for security guidance
INSTALLED_DATABASES=()

install_mysql() {
    if [[ "${INSTALL_MYSQL}" != "true" ]]; then
        log_info "Skipping MySQL (INSTALL_MYSQL=false)"
        return 0
    fi

    log_info "Installing MySQL..."

    # Install MySQL server
    if ! install_apt_package mysql-server; then
        log_error "Failed to install mysql-server"
        return 1
    fi

    # Install MySQL client (if clients enabled)
    if [[ "${INSTALL_DATABASE_CLIENTS}" == "true" ]]; then
        if ! install_apt_package mysql-client; then
            log_error "Failed to install mysql-client"
            return 1
        fi
    fi

    # Enable service if configured
    if [[ "${ENABLE_MYSQL_SERVICE}" == "true" ]]; then
        if ! enable_database_service "mysql"; then
            return 1
        fi
    fi

    INSTALLED_DATABASES+=("mysql")
    log_success "MySQL installed"
    return 0
}

install_postgresql() {
    if [[ "${INSTALL_POSTGRESQL}" != "true" ]]; then
        log_info "Skipping PostgreSQL (INSTALL_POSTGRESQL=false)"
        return 0
    fi

    log_info "Installing PostgreSQL..."

    # Install PostgreSQL packages
    local packages=(postgresql postgresql-contrib)

    if [[ "${INSTALL_DATABASE_CLIENTS}" == "true" ]]; then
        packages+=(postgresql-client)
    fi

    local package_name
    for package_name in "${packages[@]}"; do
        if ! install_apt_package "$package_name"; then
            log_error "Failed to install $package_name"
            return 1
        fi
    done

    # Enable service if configured
    if [[ "${ENABLE_POSTGRESQL_SERVICE}" == "true" ]]; then
        if ! enable_database_service "postgresql"; then
            return 1
        fi
    fi

    INSTALLED_DATABASES+=("postgresql")
    log_success "PostgreSQL installed"
    return 0
}

install_redis() {
    if [[ "${INSTALL_REDIS}" != "true" ]]; then
        log_info "Skipping Redis (INSTALL_REDIS=false)"
        return 0
    fi

    log_info "Installing Redis..."

    # Install Redis server
    if ! install_apt_package redis-server; then
        log_error "Failed to install redis-server"
        return 1
    fi

    # Install Redis tools (client)
    if [[ "${INSTALL_DATABASE_CLIENTS}" == "true" ]]; then
        if ! install_apt_package redis-tools; then
            log_error "Failed to install redis-tools"
            return 1
        fi
    fi

    # Enable service if configured
    if [[ "${ENABLE_REDIS_SERVICE}" == "true" ]]; then
        if ! enable_database_service "redis-server"; then
            return 1
        fi
    fi

    INSTALLED_DATABASES+=("redis")
    log_success "Redis installed"
    return 0
}

install_sqlite() {
    if [[ "${INSTALL_SQLITE}" != "true" ]]; then
        log_info "Skipping SQLite (INSTALL_SQLITE=false)"
        return 0
    fi

    log_info "Installing SQLite..."

    # Install SQLite packages
    if ! install_apt_package sqlite3; then
        log_error "Failed to install sqlite3"
        return 1
    fi

    if ! install_apt_package libsqlite3-dev; then
        log_error "Failed to install libsqlite3-dev"
        return 1
    fi

    INSTALLED_DATABASES+=("sqlite")
    log_success "SQLite installed"
    return 0
}

enable_database_service() {
    local service_name="$1"

    log_info "Enabling $service_name service..."

    # Strict systemctl requirement
    if ! command_exists systemctl; then
        log_error "systemctl required for service management"
        return 1
    fi

    # Atomic enable and start
    if ! systemctl enable --now "$service_name"; then
        log_error "Failed to enable and start $service_name service"
        return 1
    fi

    # Verify service is running
    if ! systemctl is-active --quiet "$service_name"; then
        log_error "$service_name service failed to start"
        log_error "Check: journalctl -u $service_name.service"
        return 1
    fi

    log_success "$service_name service enabled and running"
    return 0
}

verify_mysql() {
    if [[ "${INSTALL_MYSQL}" != "true" ]]; then
        return 0
    fi

    log_info "Verifying MySQL installation..."

    # Verify mysql client
    if command_exists mysql; then
        local mysql_version
        mysql_version="$(mysql --version 2>/dev/null)"
        if [[ -n "$mysql_version" ]]; then
            log_success "MySQL client verified: $mysql_version"
        else
            log_error "MySQL client version check failed"
            return 1
        fi
    else
        log_error "MySQL client not found"
        return 1
    fi

    # Verify mysqld (server)
    if command_exists mysqld; then
        local mysqld_version
        mysqld_version="$(mysqld --version 2>/dev/null | head -n1)"
        if [[ -n "$mysqld_version" ]]; then
            log_success "MySQL server verified: $mysqld_version"
        fi
    fi

    # Verify service if enabled
    if [[ "${ENABLE_MYSQL_SERVICE}" == "true" ]] && command_exists systemctl; then
        if systemctl is-active --quiet mysql; then
            log_success "MySQL service verified: running"
        else
            log_warning "MySQL service is not running"
        fi
    fi

    return 0
}

verify_postgresql() {
    if [[ "${INSTALL_POSTGRESQL}" != "true" ]]; then
        return 0
    fi

    log_info "Verifying PostgreSQL installation..."

    # Verify psql client
    if command_exists psql; then
        local psql_version
        psql_version="$(psql --version 2>/dev/null)"
        if [[ -n "$psql_version" ]]; then
            log_success "PostgreSQL client verified: $psql_version"
        else
            log_error "PostgreSQL client version check failed"
            return 1
        fi
    else
        log_error "PostgreSQL client not found"
        return 1
    fi

    # Check pg_isready if service is enabled
    if [[ "${ENABLE_POSTGRESQL_SERVICE}" == "true" ]]; then
        if command_exists pg_isready; then
            if pg_isready >/dev/null 2>&1; then
                log_success "PostgreSQL server verified: accepting connections"
            else
                log_warning "PostgreSQL server not accepting connections"
            fi
        fi
    fi

    # Verify service if enabled
    if [[ "${ENABLE_POSTGRESQL_SERVICE}" == "true" ]] && command_exists systemctl; then
        if systemctl is-active --quiet postgresql; then
            log_success "PostgreSQL service verified: running"
        else
            log_warning "PostgreSQL service is not running"
        fi
    fi

    return 0
}

verify_redis() {
    if [[ "${INSTALL_REDIS}" != "true" ]]; then
        return 0
    fi

    log_info "Verifying Redis installation..."

    # Verify redis-server
    if command_exists redis-server; then
        local redis_version
        redis_version="$(redis-server --version 2>/dev/null)"
        if [[ -n "$redis_version" ]]; then
            log_success "Redis server verified: $redis_version"
        else
            log_error "Redis server version check failed"
            return 1
        fi
    else
        log_error "Redis server not found"
        return 1
    fi

    # Verify redis-cli ping if service is enabled
    if [[ "${ENABLE_REDIS_SERVICE}" == "true" ]]; then
        if command_exists redis-cli; then
            local ping_response
            ping_response="$(redis-cli ping 2>/dev/null)"
            if [[ "$ping_response" == "PONG" ]]; then
                log_success "Redis server verified: responding to ping"
            else
                log_warning "Redis server not responding to ping"
            fi
        fi
    fi

    # Verify service if enabled
    if [[ "${ENABLE_REDIS_SERVICE}" == "true" ]] && command_exists systemctl; then
        if systemctl is-active --quiet redis-server; then
            log_success "Redis service verified: running"
        else
            log_warning "Redis service is not running"
        fi
    fi

    return 0
}

verify_sqlite() {
    if [[ "${INSTALL_SQLITE}" != "true" ]]; then
        return 0
    fi

    log_info "Verifying SQLite installation..."

    # Verify sqlite3
    if command_exists sqlite3; then
        local sqlite_version
        sqlite_version="$(sqlite3 --version 2>/dev/null)"
        if [[ -n "$sqlite_version" ]]; then
            log_success "SQLite verified: $sqlite_version"
        else
            log_error "SQLite version check failed"
            return 1
        fi
    else
        log_error "SQLite not found"
        return 1
    fi

    return 0
}

verify_database_installations() {
    log_info "Verifying database installations..."

    local failed=false

    if ! verify_mysql; then
        failed=true
    fi

    if ! verify_postgresql; then
        failed=true
    fi

    if ! verify_redis; then
        failed=true
    fi

    if ! verify_sqlite; then
        failed=true
    fi

    if [[ "$failed" == "true" ]]; then
        return 1
    fi

    return 0
}

print_security_guidance() {
    # Only print if at least one database was installed
    if [[ ${#INSTALLED_DATABASES[@]} -eq 0 ]]; then
        return 0
    fi

    printf "\n"
    log_step "Database Security Guidance"
    log_info "The following databases were installed with default configurations."
    log_info "For production use, secure them manually:"
    printf "\n"

    local db
    for db in "${INSTALLED_DATABASES[@]}"; do
        case "$db" in
            mysql)
                log_info "MySQL:"
                log_info "  Run: sudo mysql_secure_installation"
                log_info "  This sets root password, removes test databases, etc."
                printf "\n"
                ;;
            postgresql)
                log_info "PostgreSQL:"
                log_info "  Configure: /etc/postgresql/*/main/pg_hba.conf"
                log_info "  Set passwords for database roles"
                log_info "  Consider: sudo -u postgres createuser --interactive"
                printf "\n"
                ;;
            redis)
                log_info "Redis:"
                log_info "  Edit: /etc/redis/redis.conf"
                log_info "  Set 'requirepass <password>' for authentication"
                log_info "  Set 'bind 127.0.0.1' to restrict access"
                printf "\n"
                ;;
            sqlite)
                log_info "SQLite:"
                log_info "  File-based database, no service configuration needed"
                log_info "  Secure database files with appropriate permissions"
                printf "\n"
                ;;
        esac
    done
}

install_databases() {
    log_step "Installing Database Servers"

    # Check if any databases are enabled
    if [[ "${INSTALL_MYSQL}" != "true" ]] && \
       [[ "${INSTALL_POSTGRESQL}" != "true" ]] && \
       [[ "${INSTALL_REDIS}" != "true" ]] && \
       [[ "${INSTALL_SQLITE}" != "true" ]]; then
        log_info "No databases enabled for installation"
        return 0
    fi

    # Reset installed databases tracker
    INSTALLED_DATABASES=()

    # Install each database (failures are critical)
    if ! install_mysql; then
        log_error "MySQL installation failed"
        return 1
    fi

    if ! install_postgresql; then
        log_error "PostgreSQL installation failed"
        return 1
    fi

    if ! install_redis; then
        log_error "Redis installation failed"
        return 1
    fi

    if ! install_sqlite; then
        log_error "SQLite installation failed"
        return 1
    fi

    # Verify installations
    if ! verify_database_installations; then
        log_error "Database installation verification failed"
        return 1
    fi

    # Print security guidance
    print_security_guidance

    log_success "Database installation completed"
    return 0
}
