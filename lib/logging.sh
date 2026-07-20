#!/usr/bin/env bash

if [[ -t 1 ]]; then
    COLOR_RESET='\033[0m'
    COLOR_RED='\033[0;31m'
    COLOR_GREEN='\033[0;32m'
    COLOR_YELLOW='\033[0;33m'
    COLOR_BLUE='\033[0;34m'
    COLOR_CYAN='\033[0;36m'
else
    COLOR_RESET=''
    COLOR_RED=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
    COLOR_CYAN=''
fi

log_info() {
    printf "${COLOR_BLUE}ℹ${COLOR_RESET} %s\n" "$*"
}

log_success() {
    printf "${COLOR_GREEN}✓${COLOR_RESET} %s\n" "$*"
}

log_warning() {
    printf "${COLOR_YELLOW}⚠${COLOR_RESET} %s\n" "$*"

    # Increment warning counter if metrics available
    if declare -F metrics_record_warning >/dev/null 2>&1; then
        metrics_record_warning
    fi
}

log_error() {
    printf "${COLOR_RED}✗${COLOR_RESET} %s\n" "$*" >&2

    # Increment error counter if metrics available
    if declare -F metrics_record_error >/dev/null 2>&1; then
        metrics_record_error
    fi
}

log_step() {
    printf "\n${COLOR_CYAN}==>${COLOR_RESET} %s\n" "$*"
}

die() {
    log_error "$*"
    exit 1
}
