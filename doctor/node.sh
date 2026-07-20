#!/usr/bin/env bash

# Doctor: Node.js checks
# Checks NVM, Node.js, npm, pnpm, Yarn, Bun

doctor_check_node() {
    doctor_section "Node.js"

    local target_home
    target_home="$(get_target_home)"
    local nvm_dir="$target_home/.nvm"

    # Check NVM
    if [[ -d "$nvm_dir" && -f "$nvm_dir/nvm.sh" ]]; then
        doctor_pass "NVM: installed at $nvm_dir"
    else
        doctor_fail "NVM: not found"
        return
    fi

    # Check Node via NVM
    local node_version
    node_version="$(run_with_nvm node --version 2>/dev/null || true)"
    if [[ -n "$node_version" ]]; then
        doctor_pass "Node.js: $node_version"
    else
        doctor_fail "Node.js: not found"
    fi

    # Check npm
    local npm_version
    npm_version="$(run_with_nvm npm --version 2>/dev/null || true)"
    if [[ -n "$npm_version" ]]; then
        doctor_pass "npm: v$npm_version"
    else
        doctor_fail "npm: not found"
    fi

    # Check pnpm (if enabled)
    if [[ "${INSTALL_PNPM:-true}" == "true" ]]; then
        local pnpm_version
        pnpm_version="$(run_with_nvm pnpm --version 2>/dev/null || true)"
        if [[ -n "$pnpm_version" ]]; then
            doctor_pass "pnpm: v$pnpm_version"
        else
            doctor_fail "pnpm: not found"
        fi
    else
        doctor_skip "pnpm: disabled"
    fi

    # Check Yarn (if enabled)
    if [[ "${INSTALL_YARN:-true}" == "true" ]]; then
        local yarn_version
        yarn_version="$(run_with_nvm yarn --version 2>/dev/null || true)"
        if [[ -n "$yarn_version" ]]; then
            doctor_pass "Yarn: v$yarn_version"
        else
            doctor_fail "Yarn: not found"
        fi
    else
        doctor_skip "Yarn: disabled"
    fi

    # Check Bun (if enabled)
    if [[ "${INSTALL_BUN:-true}" == "true" ]]; then
        local bun_dir="$target_home/.bun"
        if [[ -x "$bun_dir/bin/bun" ]]; then
            local bun_version
            bun_version="$("$bun_dir/bin/bun" --version 2>/dev/null || true)"
            doctor_pass "Bun: v$bun_version"
        else
            doctor_fail "Bun: not found"
        fi
    else
        doctor_skip "Bun: disabled"
    fi
}
