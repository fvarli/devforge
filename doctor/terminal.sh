#!/usr/bin/env bash

# Doctor: Terminal checks
# Checks zsh, fzf, bat, eza, zoxide, starship, tmux

doctor_check_terminal() {
    doctor_section "Terminal"

    # Check zsh
    if command_exists zsh; then
        local zsh_version
        zsh_version="$(zsh --version 2>/dev/null | head -n1)"
        doctor_pass "zsh: $zsh_version"
    else
        doctor_fail "zsh: not found"
    fi

    # Check fzf
    if command_exists fzf; then
        local fzf_version
        fzf_version="$(fzf --version 2>/dev/null | head -n1)"
        doctor_pass "fzf: $fzf_version"
    else
        doctor_fail "fzf: not found"
    fi

    # Check bat (batcat on Ubuntu)
    if command_exists batcat; then
        local bat_version
        bat_version="$(batcat --version 2>/dev/null | head -n1)"
        doctor_pass "bat: $bat_version"
    elif command_exists bat; then
        local bat_version
        bat_version="$(bat --version 2>/dev/null | head -n1)"
        doctor_pass "bat: $bat_version"
    else
        doctor_fail "bat: not found"
    fi

    # Check eza
    if command_exists eza; then
        local eza_version
        eza_version="$(eza --version 2>/dev/null | head -n1)"
        doctor_pass "eza: $eza_version"
    else
        doctor_fail "eza: not found"
    fi

    # Check zoxide
    if command_exists zoxide; then
        local zoxide_version
        zoxide_version="$(zoxide --version 2>/dev/null)"
        doctor_pass "zoxide: $zoxide_version"
    else
        doctor_fail "zoxide: not found"
    fi

    # Check starship
    if command_exists starship; then
        local starship_version
        starship_version="$(starship --version 2>/dev/null | head -n1)"
        doctor_pass "starship: $starship_version"
    else
        doctor_fail "starship: not found"
    fi

    # Check tmux
    if command_exists tmux; then
        local tmux_version
        tmux_version="$(tmux -V 2>/dev/null)"
        doctor_pass "tmux: $tmux_version"
    else
        doctor_fail "tmux: not found"
    fi
}
