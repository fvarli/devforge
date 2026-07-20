#!/usr/bin/env bash

# Doctor: Database checks
# Checks MySQL, PostgreSQL, Redis, SQLite

doctor_check_databases() {
    doctor_section "Databases"

    local any_enabled=false

    # MySQL
    if [[ "${INSTALL_MYSQL:-true}" == "true" ]]; then
        any_enabled=true
        if command_exists mysqld; then
            local mysqld_version
            mysqld_version="$(mysqld --version 2>/dev/null | head -n1)"
            doctor_pass "MySQL Server: $mysqld_version"

            if [[ "${ENABLE_MYSQL_SERVICE:-true}" == "true" ]] && command_exists systemctl; then
                if systemctl is-active --quiet mysql; then
                    doctor_pass "MySQL service: running"
                else
                    doctor_fail "MySQL service: not running"
                fi
            fi
        else
            doctor_fail "MySQL Server: not found"
        fi
    else
        doctor_skip "MySQL: disabled"
    fi

    # PostgreSQL
    if [[ "${INSTALL_POSTGRESQL:-true}" == "true" ]]; then
        any_enabled=true
        if command_exists postgres || command_exists pg_ctl; then
            local pg_version
            pg_version="$(postgres --version 2>/dev/null || pg_ctl --version 2>/dev/null | head -n1)"
            doctor_pass "PostgreSQL: $pg_version"

            if [[ "${ENABLE_POSTGRESQL_SERVICE:-true}" == "true" ]] && command_exists systemctl; then
                if systemctl is-active --quiet postgresql; then
                    doctor_pass "PostgreSQL service: running"
                else
                    doctor_fail "PostgreSQL service: not running"
                fi
            fi
        else
            doctor_fail "PostgreSQL: not found"
        fi
    else
        doctor_skip "PostgreSQL: disabled"
    fi

    # Redis
    if [[ "${INSTALL_REDIS:-true}" == "true" ]]; then
        any_enabled=true
        if command_exists redis-server; then
            local redis_version
            redis_version="$(redis-server --version 2>/dev/null | head -n1)"
            doctor_pass "Redis: $redis_version"

            if [[ "${ENABLE_REDIS_SERVICE:-true}" == "true" ]] && command_exists systemctl; then
                if systemctl is-active --quiet redis-server; then
                    doctor_pass "Redis service: running"
                else
                    doctor_fail "Redis service: not running"
                fi
            fi
        else
            doctor_fail "Redis: not found"
        fi
    else
        doctor_skip "Redis: disabled"
    fi

    # SQLite
    if [[ "${INSTALL_SQLITE:-true}" == "true" ]]; then
        any_enabled=true
        if command_exists sqlite3; then
            local sqlite_version
            sqlite_version="$(sqlite3 --version 2>/dev/null)"
            doctor_pass "SQLite: $sqlite_version"
        else
            doctor_fail "SQLite: not found"
        fi
    else
        doctor_skip "SQLite: disabled"
    fi

    if [[ "$any_enabled" != "true" ]]; then
        doctor_skip "All databases disabled"
    fi
}
