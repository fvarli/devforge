#!/usr/bin/env bash

# Doctor: System checks
# Checks OS, architecture, disk space, DNS resolution

doctor_check_system() {
    doctor_section "System"

    # Check OS
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        doctor_pass "OS: ${PRETTY_NAME:-$ID}"
    else
        doctor_warn "Cannot determine OS (/etc/os-release not found)"
    fi

    # Check architecture
    local arch
    arch="$(uname -m)"
    doctor_pass "Architecture: $arch"

    # Check disk space (warn if < 5GB free)
    local free_space
    free_space="$(df -BG / 2>/dev/null | awk 'NR==2 {gsub("G",""); print $4}')"
    if [[ -n "$free_space" ]]; then
        if [[ "$free_space" -lt 5 ]]; then
            doctor_warn "Low disk space: ${free_space}GB free"
        else
            doctor_pass "Disk space: ${free_space}GB free"
        fi
    fi

    # Check DNS resolution
    if command_exists host; then
        if host -t A google.com >/dev/null 2>&1; then
            doctor_pass "DNS resolution: working"
        else
            doctor_fail "DNS resolution: failed"
        fi
    elif command_exists dig; then
        if dig +short google.com >/dev/null 2>&1; then
            doctor_pass "DNS resolution: working"
        else
            doctor_fail "DNS resolution: failed"
        fi
    else
        doctor_skip "DNS resolution (host/dig not available)"
    fi
}
