#!/usr/bin/env bash

# DevForge Doctor Command
# Read-only diagnostic checks for installed components
# Does NOT require root privileges

# Doctor counters
DOCTOR_CHECKS_TOTAL=0
DOCTOR_CHECKS_PASSED=0
DOCTOR_CHECKS_WARNINGS=0
DOCTOR_CHECKS_FAILED=0

# Doctor output functions
doctor_pass() {
    printf "${COLOR_GREEN}[OK]${COLOR_RESET} %s\n" "$*"
    ((DOCTOR_CHECKS_TOTAL++))
    ((DOCTOR_CHECKS_PASSED++))
}

doctor_warn() {
    printf "${COLOR_YELLOW}[WARN]${COLOR_RESET} %s\n" "$*"
    ((DOCTOR_CHECKS_TOTAL++))
    ((DOCTOR_CHECKS_WARNINGS++))
}

doctor_fail() {
    printf "${COLOR_RED}[FAIL]${COLOR_RESET} %s\n" "$*"
    ((DOCTOR_CHECKS_TOTAL++))
    ((DOCTOR_CHECKS_FAILED++))
}

doctor_skip() {
    printf "${COLOR_BLUE}[SKIP]${COLOR_RESET} %s\n" "$*"
}

doctor_section() {
    printf "\n${COLOR_CYAN}==> %s${COLOR_RESET}\n" "$*"
}

# System checks
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

# Terminal checks
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

# Git checks
doctor_check_git() {
    doctor_section "Git"

    # Check git
    if command_exists git; then
        local git_version
        git_version="$(git --version 2>/dev/null)"
        doctor_pass "git: $git_version"
    else
        doctor_fail "git: not found"
        return
    fi

    # Check git-lfs
    if command_exists git-lfs; then
        local lfs_version
        lfs_version="$(git-lfs --version 2>/dev/null | head -n1)"
        doctor_pass "git-lfs: $lfs_version"
    else
        doctor_fail "git-lfs: not found"
    fi

    # Check gh
    if command_exists gh; then
        local gh_version
        gh_version="$(gh --version 2>/dev/null | head -n1)"
        doctor_pass "gh: $gh_version"
    else
        doctor_fail "gh: not found"
    fi

    # Check .ssh directory permissions
    local target_home
    target_home="$(get_target_home)"
    local ssh_dir="$target_home/.ssh"

    if [[ -d "$ssh_dir" ]]; then
        local ssh_perms
        ssh_perms="$(stat -c %a "$ssh_dir" 2>/dev/null)"
        if [[ "$ssh_perms" == "700" ]]; then
            doctor_pass ".ssh directory: permissions 700"
        else
            doctor_warn ".ssh directory: permissions $ssh_perms (should be 700)"
        fi
    else
        doctor_skip ".ssh directory: not present"
    fi

    # Check git user config
    local git_user_name
    local git_user_email
    git_user_name="$(git config --global user.name 2>/dev/null || true)"
    git_user_email="$(git config --global user.email 2>/dev/null || true)"

    if [[ -n "$git_user_name" && -n "$git_user_email" ]]; then
        doctor_pass "git config: $git_user_name <$git_user_email>"
    else
        doctor_warn "git config: user.name or user.email not set"
    fi
}

# PHP checks
doctor_check_php() {
    doctor_section "PHP"

    local php_version="${PHP_VERSION:-8.4}"

    # Check PHP
    if command_exists "php${php_version}"; then
        local php_output
        php_output="$("php${php_version}" --version 2>/dev/null | head -n1)"
        doctor_pass "PHP: $php_output"
    elif command_exists php; then
        local php_output
        php_output="$(php --version 2>/dev/null | head -n1)"
        doctor_warn "PHP: $php_output (expected php${php_version})"
    else
        doctor_fail "PHP: not found"
        return
    fi

    # Check key extensions
    local php_modules
    php_modules="$("php${php_version}" -m 2>/dev/null || php -m 2>/dev/null || true)"

    local critical_extensions=(mbstring curl pdo_mysql pdo_pgsql)
    for ext in "${critical_extensions[@]}"; do
        if echo "$php_modules" | grep -qi "^${ext}$"; then
            doctor_pass "PHP extension: $ext"
        else
            doctor_fail "PHP extension: $ext not loaded"
        fi
    done

    # Check Composer
    if command_exists composer; then
        local composer_version
        composer_version="$(composer --version 2>/dev/null | head -n1)"
        doctor_pass "Composer: $composer_version"
    else
        doctor_fail "Composer: not found"
    fi

    # Check Laravel installer
    local composer_bin
    composer_bin="$(get_composer_global_bin 2>/dev/null || true)"
    if [[ -x "$composer_bin/laravel" ]]; then
        doctor_pass "Laravel Installer: installed"
    elif [[ "${INSTALL_LARAVEL_INSTALLER:-true}" == "true" ]]; then
        doctor_fail "Laravel Installer: not found"
    else
        doctor_skip "Laravel Installer: disabled"
    fi

    # Check Symfony CLI
    if command_exists symfony; then
        local symfony_version
        symfony_version="$(symfony version 2>/dev/null | head -n1 || true)"
        doctor_pass "Symfony CLI: $symfony_version"
    elif [[ "${INSTALL_SYMFONY_CLI:-true}" == "true" ]]; then
        doctor_fail "Symfony CLI: not found"
    else
        doctor_skip "Symfony CLI: disabled"
    fi
}

# Node checks
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

# Docker checks
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

# Database checks
doctor_check_databases() {
    doctor_section "Databases"

    local any_enabled=false

    # MySQL
    if [[ "${INSTALL_MYSQL:-true}" == "true" ]]; then
        any_enabled=true
        if command_exists mysqld; then
            local mysqld_version
            mysqld_version="$(mysqld --version 2>/dev/null | head -n1)"
            doctor_pass "MySQL Server: $mysqld_version"

            if [[ "${ENABLE_MYSQL_SERVICE:-true}" == "true" ]] && command_exists systemctl; then
                if systemctl is-active --quiet mysql; then
                    doctor_pass "MySQL service: running"
                else
                    doctor_fail "MySQL service: not running"
                fi
            fi
        else
            doctor_fail "MySQL Server: not found"
        fi
    else
        doctor_skip "MySQL: disabled"
    fi

    # PostgreSQL
    if [[ "${INSTALL_POSTGRESQL:-true}" == "true" ]]; then
        any_enabled=true
        if command_exists postgres || command_exists pg_ctl; then
            local pg_version
            pg_version="$(postgres --version 2>/dev/null || pg_ctl --version 2>/dev/null | head -n1)"
            doctor_pass "PostgreSQL: $pg_version"

            if [[ "${ENABLE_POSTGRESQL_SERVICE:-true}" == "true" ]] && command_exists systemctl; then
                if systemctl is-active --quiet postgresql; then
                    doctor_pass "PostgreSQL service: running"
                else
                    doctor_fail "PostgreSQL service: not running"
                fi
            fi
        else
            doctor_fail "PostgreSQL: not found"
        fi
    else
        doctor_skip "PostgreSQL: disabled"
    fi

    # Redis
    if [[ "${INSTALL_REDIS:-true}" == "true" ]]; then
        any_enabled=true
        if command_exists redis-server; then
            local redis_version
            redis_version="$(redis-server --version 2>/dev/null | head -n1)"
            doctor_pass "Redis: $redis_version"

            if [[ "${ENABLE_REDIS_SERVICE:-true}" == "true" ]] && command_exists systemctl; then
                if systemctl is-active --quiet redis-server; then
                    doctor_pass "Redis service: running"
                else
                    doctor_fail "Redis service: not running"
                fi
            fi
        else
            doctor_fail "Redis: not found"
        fi
    else
        doctor_skip "Redis: disabled"
    fi

    # SQLite
    if [[ "${INSTALL_SQLITE:-true}" == "true" ]]; then
        any_enabled=true
        if command_exists sqlite3; then
            local sqlite_version
            sqlite_version="$(sqlite3 --version 2>/dev/null)"
            doctor_pass "SQLite: $sqlite_version"
        else
            doctor_fail "SQLite: not found"
        fi
    else
        doctor_skip "SQLite: disabled"
    fi

    if [[ "$any_enabled" != "true" ]]; then
        doctor_skip "All databases disabled"
    fi
}

# Browser checks
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

# Desktop apps checks
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

    # Flatpak apps
    if command_exists flatpak; then
        # Bitwarden
        if [[ "${INSTALL_BITWARDEN:-true}" == "true" ]]; then
            if flatpak info com.bitwarden.desktop >/dev/null 2>&1; then
                doctor_pass "Bitwarden: installed (Flatpak)"
            else
                doctor_fail "Bitwarden: not found"
            fi
        else
            doctor_skip "Bitwarden: disabled"
        fi

        # Spotify
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

# Print summary
doctor_print_summary() {
    printf "\n"
    doctor_section "Summary"
    printf "  Total checks: %d\n" "$DOCTOR_CHECKS_TOTAL"
    printf "  ${COLOR_GREEN}Passed${COLOR_RESET}: %d\n" "$DOCTOR_CHECKS_PASSED"
    printf "  ${COLOR_YELLOW}Warnings${COLOR_RESET}: %d\n" "$DOCTOR_CHECKS_WARNINGS"
    printf "  ${COLOR_RED}Failed${COLOR_RESET}: %d\n" "$DOCTOR_CHECKS_FAILED"

    if [[ "$DOCTOR_CHECKS_FAILED" -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Main doctor function
run_doctor() {
    local check_all=false
    local modules_to_check=()

    # Parse arguments (use default empty to handle unset $1)
    if [[ "${1:-}" == "--all" ]]; then
        check_all=true
    elif [[ ${#SELECTED_MODULES[@]} -gt 0 ]]; then
        modules_to_check=("${SELECTED_MODULES[@]}")
    else
        check_all=true
    fi

    printf "${COLOR_CYAN}DevForge Doctor${COLOR_RESET}\n"
    printf "Running diagnostic checks...\n"

    # Reset counters
    DOCTOR_CHECKS_TOTAL=0
    DOCTOR_CHECKS_PASSED=0
    DOCTOR_CHECKS_WARNINGS=0
    DOCTOR_CHECKS_FAILED=0

    # Always check system
    doctor_check_system

    # Check requested modules
    if [[ "$check_all" == "true" ]]; then
        doctor_check_terminal
        doctor_check_git
        doctor_check_php
        doctor_check_node
        doctor_check_docker
        doctor_check_databases
        doctor_check_browsers
        doctor_check_apps
    else
        local module
        for module in "${modules_to_check[@]}"; do
            case "$module" in
                system) ;; # Already checked
                terminal) doctor_check_terminal ;;
                git) doctor_check_git ;;
                php) doctor_check_php ;;
                node) doctor_check_node ;;
                docker) doctor_check_docker ;;
                databases) doctor_check_databases ;;
                browsers) doctor_check_browsers ;;
                apps) doctor_check_apps ;;
                *) doctor_warn "Unknown module: $module" ;;
            esac
        done
    fi

    # Print summary and return status
    doctor_print_summary
}
