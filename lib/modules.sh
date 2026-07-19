#!/usr/bin/env bash

run_module() {
    local module_name="$1"
    local module_file="$DEVFORGE_ROOT/modules/${module_name}.sh"

    if [[ ! -f "$module_file" ]]; then
        die "Module not found: $module_file"
    fi

    log_step "Running module: $module_name"

    # shellcheck source=/dev/null
    source "$module_file"

    local function_name="install_${module_name}"

    if ! declare -F "$function_name" >/dev/null 2>&1; then
        die "Module function missing: $function_name"
    fi

    "$function_name"

    log_success "Module completed: $module_name"
}
