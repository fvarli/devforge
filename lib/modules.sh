#!/usr/bin/env bash

declare -a COMPLETED_MODULES=()
declare -a FAILED_MODULES=()

run_module() {
    local module_name="$1"
    local module_file="$DEVFORGE_ROOT/modules/${module_name}.sh"
    local function_name="install_${module_name}"

    if [[ ! -f "$module_file" ]]; then
        log_warning "Module file does not exist yet: $module_name"
        log_info "Skipping unfinished module."

        # Record module skipped
        if declare -F metrics_record_module_skipped >/dev/null 2>&1; then
            metrics_record_module_skipped "$module_name"
        fi

        return 0
    fi

    log_step "Running module: $module_name"

    # Record module start time
    if declare -F metrics_record_module_start >/dev/null 2>&1; then
        metrics_record_module_start "$module_name"
    fi

    # shellcheck source=/dev/null
    source "$module_file"

    if ! declare -F "$function_name" >/dev/null 2>&1; then
        log_error "Module function missing: $function_name"
        FAILED_MODULES+=("$module_name")

        # Record module failed
        if declare -F metrics_record_module_failed >/dev/null 2>&1; then
            metrics_record_module_failed "$module_name"
        fi

        return 1
    fi

    if "$function_name"; then
        COMPLETED_MODULES+=("$module_name")
        log_success "Module completed: $module_name"

        # Record module completed
        if declare -F metrics_record_module_completed >/dev/null 2>&1; then
            metrics_record_module_completed "$module_name"
        fi

        return 0
    fi

    FAILED_MODULES+=("$module_name")
    log_error "Module failed: $module_name"

    # Record module failed
    if declare -F metrics_record_module_failed >/dev/null 2>&1; then
        metrics_record_module_failed "$module_name"
    fi

    return 1
}

run_selected_modules() {
    local module_name

    for module_name in "${SELECTED_MODULES[@]}"; do
        run_module "$module_name"
    done
}

print_installation_summary() {
    # Check if metrics available and enabled
    if declare -F metrics_print_summary >/dev/null 2>&1; then
        if [[ "$METRICS_ENABLED" == "true" ]]; then
            metrics_print_summary

            # Return 1 if any failures
            if [[ "${#FAILED_MODULES[@]}" -gt 0 ]]; then
                return 1
            fi

            return 0
        fi
    fi

    # Fallback to original summary if metrics not available
    local module_name

    printf "\n"
    log_step "Installation summary"

    if [[ "${#COMPLETED_MODULES[@]}" -gt 0 ]]; then
        printf "\nCompleted:\n"

        for module_name in "${COMPLETED_MODULES[@]}"; do
            log_success "$module_name"
        done
    fi

    if [[ "${#FAILED_MODULES[@]}" -gt 0 ]]; then
        printf "\nFailed:\n"

        for module_name in "${FAILED_MODULES[@]}"; do
            log_error "$module_name"
        done

        return 1
    fi

    return 0
}
