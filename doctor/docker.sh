#!/usr/bin/env bash

# Doctor: Docker checks
# Checks Docker, containerd, Compose, Buildx, service, group membership

doctor_check_docker() {
    doctor_section "Docker"

    if [[ "${INSTALL_DOCKER_ENGINE:-true}" != "true" ]]; then
        doctor_skip "Docker: disabled (INSTALL_DOCKER_ENGINE=false)"
        return
    fi

    # Check docker
    if command_exists docker; then
        local docker_version
        docker_version="$(docker --version 2>/dev/null)"
        doctor_pass "Docker: $docker_version"
    else
        doctor_fail "Docker: not found"
        return
    fi

    # Check containerd
    if command_exists containerd; then
        local containerd_version
        containerd_version="$(containerd --version 2>/dev/null | head -n1)"
        doctor_pass "containerd: $containerd_version"
    else
        doctor_fail "containerd: not found"
    fi

    # Check Docker Compose (if enabled)
    if [[ "${INSTALL_DOCKER_COMPOSE:-true}" == "true" ]]; then
        if docker compose version >/dev/null 2>&1; then
            local compose_version
            compose_version="$(docker compose version 2>/dev/null)"
            doctor_pass "Docker Compose: $compose_version"
        else
            doctor_fail "Docker Compose: not found"
        fi
    else
        doctor_skip "Docker Compose: disabled"
    fi

    # Check Docker Buildx (if enabled)
    if [[ "${INSTALL_DOCKER_BUILDX:-true}" == "true" ]]; then
        if docker buildx version >/dev/null 2>&1; then
            local buildx_version
            buildx_version="$(docker buildx version 2>/dev/null)"
            doctor_pass "Docker Buildx: $buildx_version"
        else
            doctor_fail "Docker Buildx: not found"
        fi
    else
        doctor_skip "Docker Buildx: disabled"
    fi

    # Check Docker service (if enabled)
    if [[ "${ENABLE_DOCKER_SERVICE:-true}" == "true" ]]; then
        if command_exists systemctl; then
            if systemctl is-active --quiet docker; then
                doctor_pass "Docker service: running"
            else
                doctor_fail "Docker service: not running"
            fi
        else
            doctor_skip "Docker service: systemctl not available"
        fi
    else
        doctor_skip "Docker service: disabled"
    fi

    # Check docker group membership (if enabled)
    if [[ "${ADD_USER_TO_DOCKER_GROUP:-true}" == "true" ]]; then
        local target_user
        target_user="$(get_target_user)"
        if id -nG "$target_user" 2>/dev/null | grep -qw docker; then
            doctor_pass "Docker group: $target_user is member"
        else
            doctor_warn "Docker group: $target_user not in docker group (logout/login may be needed)"
        fi
    else
        doctor_skip "Docker group: disabled"
    fi
}
