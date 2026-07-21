#!/usr/bin/env bash

set -Eeuo pipefail

OUTPUT="${1:-git-diff.txt}"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: This directory is not a Git repository." >&2
    exit 1
fi

repo_name="$(basename "$(git rev-parse --show-toplevel)")"
branch_name="$(git branch --show-current)"

if [[ -z "$branch_name" ]]; then
    branch_name="DETACHED_HEAD"
fi

echo "Generating Git report..."

{
    echo "=================================================="
    echo "Repository: $repo_name"
    echo "Generated : $(date '+%Y-%m-%d %H:%M:%S %z')"
    echo "Branch    : $branch_name"
    echo "Commit    : $(git rev-parse --short HEAD)"
    echo "=================================================="
    echo

    echo "=================================================="
    echo "GIT STATUS"
    echo "=================================================="
    echo
    git status
    echo

    echo "=================================================="
    echo "FULL GIT DIFF — UNSTAGED"
    echo "=================================================="
    echo
    git diff --no-ext-diff
    echo

    echo "=================================================="
    echo "STAGED DIFF"
    echo "=================================================="
    echo
    git diff --cached --no-ext-diff
    echo

    echo "=================================================="
    echo "DIFF STAT — UNSTAGED"
    echo "=================================================="
    echo
    git diff --stat
    echo

    echo "=================================================="
    echo "DIFF STAT — STAGED"
    echo "=================================================="
    echo
    git diff --cached --stat
    echo
} > "$OUTPUT"

echo
echo "Created: $OUTPUT"
echo "Size   : $(du -h "$OUTPUT" | cut -f1)"
