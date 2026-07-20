#!/usr/bin/env bash

# Doctor: Git checks
# Checks git, git-lfs, gh, SSH directory, git config

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
