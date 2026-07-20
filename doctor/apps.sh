#!/usr/bin/env bash

# Doctor: Desktop application checks
# Checks VS Code, DBeaver, Bitwarden, Spotify, VLC, FileZilla, KeePassXC

doctor_check_apps() {
    doctor_section "Desktop Applications"

    # VS Code
    if [[ "${INSTALL_VSCODE:-true}" == "true" ]]; then
        if command_exists code; then
            local code_version
            code_version="$(code --version 2>/dev/null | head -n1)"
            doctor_pass "VS Code: $code_version"
        else
            doctor_fail "VS Code: not found"
        fi
    else
        doctor_skip "VS Code: disabled"
    fi

    # DBeaver
    if [[ "${INSTALL_DBEAVER:-true}" == "true" ]]; then
        if command_exists dbeaver; then
            doctor_pass "DBeaver: installed"
        else
            doctor_fail "DBeaver: not found"
        fi
    else
        doctor_skip "DBeaver: disabled"
    fi

    # Flatpak apps - check if flatpak is needed first
    local need_flatpak=false
    if [[ "${INSTALL_BITWARDEN:-true}" == "true" ]] || \
       [[ "${INSTALL_SPOTIFY:-true}" == "true" ]]; then
        need_flatpak=true
    fi

    if [[ "$need_flatpak" == "true" ]]; then
        if ! command_exists flatpak; then
            # Flatpak missing but apps are enabled - this is a failure
            doctor_fail "Flatpak: not installed (required for Bitwarden/Spotify)"
        else
            # Flatpak available, check individual apps
            if [[ "${INSTALL_BITWARDEN:-true}" == "true" ]]; then
                if flatpak info com.bitwarden.desktop >/dev/null 2>&1; then
                    doctor_pass "Bitwarden: installed (Flatpak)"
                else
                    doctor_fail "Bitwarden: not found"
                fi
            else
                doctor_skip "Bitwarden: disabled"
            fi

            if [[ "${INSTALL_SPOTIFY:-true}" == "true" ]]; then
                if flatpak info com.spotify.Client >/dev/null 2>&1; then
                    doctor_pass "Spotify: installed (Flatpak)"
                else
                    doctor_fail "Spotify: not found"
                fi
            else
                doctor_skip "Spotify: disabled"
            fi
        fi
    else
        # Both apps disabled
        if [[ "${INSTALL_BITWARDEN:-true}" != "true" ]]; then
            doctor_skip "Bitwarden: disabled"
        fi
        if [[ "${INSTALL_SPOTIFY:-true}" != "true" ]]; then
            doctor_skip "Spotify: disabled"
        fi
    fi

    # VLC
    if [[ "${INSTALL_VLC:-true}" == "true" ]]; then
        if command_exists vlc; then
            local vlc_version
            vlc_version="$(vlc --version 2>/dev/null | head -n1)"
            doctor_pass "VLC: $vlc_version"
        else
            doctor_fail "VLC: not found"
        fi
    else
        doctor_skip "VLC: disabled"
    fi

    # FileZilla
    if [[ "${INSTALL_FILEZILLA:-true}" == "true" ]]; then
        if command_exists filezilla; then
            doctor_pass "FileZilla: installed"
        else
            doctor_fail "FileZilla: not found"
        fi
    else
        doctor_skip "FileZilla: disabled"
    fi

    # KeePassXC
    if [[ "${INSTALL_KEEPASSXC:-false}" == "true" ]]; then
        if command_exists keepassxc; then
            doctor_pass "KeePassXC: installed"
        else
            doctor_fail "KeePassXC: not found"
        fi
    else
        doctor_skip "KeePassXC: disabled"
    fi
}
