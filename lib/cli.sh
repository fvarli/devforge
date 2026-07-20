#!/usr/bin/env bash

DEVFORGE_VERSION="1.0.0"

declare -a AVAILABLE_MODULES=(
    system
    terminal
    git
    php
    node
    docker
    databases
    browsers
    apps
)

declare -a SELECTED_MODULES=()

SHOW_HELP=false
SHOW_VERSION=false
INSTALL_ALL=false
INTERACTIVE_MODE=false
RUN_DOCTOR=false

print_help() {
    cat <<EOF
DevForge ${DEVFORGE_VERSION}

Usage:
  sudo ./install.sh [options]

Options:
  --all              Enable all available modules
  --system           Enable system module
  --terminal         Enable terminal tools module
  --git              Enable Git and SSH module
  --php              Enable PHP module
  --node             Enable Node.js module
  --docker           Enable Docker module
  --databases        Enable database module
  --browsers         Enable browser module
  --apps             Enable desktop applications module
  --interactive      Start interactive module selection
  --doctor           Run diagnostic checks (no installation, no root required)
  --help, -h         Show this help message
  --version, -v      Show DevForge version

Examples:
  sudo ./install.sh --system --git
  sudo ./install.sh --php --node --docker
  sudo ./install.sh --all
  sudo ./install.sh --interactive
EOF
}

print_version() {
    printf "DevForge %s\n" "$DEVFORGE_VERSION"
}

module_exists() {
    local requested_module="$1"
    local module_name

    for module_name in "${AVAILABLE_MODULES[@]}"; do
        if [[ "$module_name" == "$requested_module" ]]; then
            return 0
        fi
    done

    return 1
}

module_selected() {
    local requested_module="$1"
    local module_name

    for module_name in "${SELECTED_MODULES[@]}"; do
        if [[ "$module_name" == "$requested_module" ]]; then
            return 0
        fi
    done

    return 1
}

select_module() {
    local module_name="$1"

    if ! module_exists "$module_name"; then
        die "Unknown module: $module_name"
    fi

    if module_selected "$module_name"; then
        return 0
    fi

    SELECTED_MODULES+=("$module_name")
}

select_all_modules() {
    local module_name

    for module_name in "${AVAILABLE_MODULES[@]}"; do
        select_module "$module_name"
    done
}

parse_arguments() {
    if [[ "$#" -eq 0 ]]; then
        INTERACTIVE_MODE=true
        return 0
    fi

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --all)
                INSTALL_ALL=true
                ;;
            --system)
                select_module system
                ;;
            --terminal)
                select_module terminal
                ;;
            --git)
                select_module git
                ;;
            --php)
                select_module php
                ;;
            --node)
                select_module node
                ;;
            --docker)
                select_module docker
                ;;
            --databases)
                select_module databases
                ;;
            --browsers)
                select_module browsers
                ;;
            --apps)
                select_module apps
                ;;
            --interactive)
                INTERACTIVE_MODE=true
                ;;
            --doctor|doctor)
                RUN_DOCTOR=true
                ;;
            --help|-h)
                SHOW_HELP=true
                ;;
            --version|-v)
                SHOW_VERSION=true
                ;;
            --)
                shift
                break
                ;;
            *)
                die "Unknown option: $1. Use --help for available options."
                ;;
        esac

        shift
    done

    if [[ "$INSTALL_ALL" == "true" ]]; then
        select_all_modules
    fi
}

prompt_yes_no() {
    local prompt_text="$1"
    local default_answer="${2:-n}"
    local answer

    if [[ "$default_answer" == "y" ]]; then
        read -r -p "$prompt_text [Y/n]: " answer
        answer="${answer:-y}"
    else
        read -r -p "$prompt_text [y/N]: " answer
        answer="${answer:-n}"
    fi

    [[ "$answer" =~ ^[Yy]$ ]]
}

run_interactive_selection() {
    local module_name

    printf "\n"
    log_step "Interactive module selection"

    for module_name in "${AVAILABLE_MODULES[@]}"; do
        if prompt_yes_no "Install ${module_name} module?" "n"; then
            select_module "$module_name"
        fi
    done
}

print_selected_modules() {
    local module_name

    printf "\n"
    log_step "Selected modules"

    if [[ "${#SELECTED_MODULES[@]}" -eq 0 ]]; then
        log_warning "No modules selected."
        return 0
    fi

    for module_name in "${SELECTED_MODULES[@]}"; do
        log_success "$module_name"
    done
}

confirm_installation() {
    if [[ "${#SELECTED_MODULES[@]}" -eq 0 ]]; then
        die "No modules selected."
    fi

    printf "\n"

    if ! prompt_yes_no "Continue with installation?" "y"; then
        log_warning "Installation cancelled by user."
        exit 0
    fi
}
