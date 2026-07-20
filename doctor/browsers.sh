#!/usr/bin/env bash

# Doctor: Browser checks
# Checks Chrome, Brave

doctor_check_browsers() {
    doctor_section "Browsers"

    # Google Chrome
    if [[ "${INSTALL_CHROME:-true}" == "true" ]]; then
        if command_exists google-chrome-stable || command_exists google-chrome; then
            local chrome_version
            chrome_version="$(google-chrome-stable --version 2>/dev/null || google-chrome --version 2>/dev/null)"
            doctor_pass "Chrome: $chrome_version"
        else
            doctor_fail "Chrome: not found"
        fi
    else
        doctor_skip "Chrome: disabled"
    fi

    # Brave
    if [[ "${INSTALL_BRAVE:-true}" == "true" ]]; then
        if command_exists brave-browser; then
            local brave_version
            brave_version="$(brave-browser --version 2>/dev/null)"
            doctor_pass "Brave: $brave_version"
        else
            doctor_fail "Brave: not found"
        fi
    else
        doctor_skip "Brave: disabled"
    fi
}
