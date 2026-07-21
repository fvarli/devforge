# DevForge AI Context

This document provides context for AI assistants working on the DevForge codebase.

## Project Overview

**DevForge** is a Bash-based automated development environment installer for Ubuntu/Debian-based Linux distributions. It provides idempotent installation of development tools with comprehensive diagnostics.

- **Current Version**: 0.9.0
- **Target**: v1.0.0 stable release
- **License**: MIT

## Quick Reference

```bash
# Run all tests
bash tests/test_helpers.sh && bash tests/test_doctor.sh && bash tests/test_report_script.sh

# ShellCheck validation
shellcheck -x install.sh lib/*.sh modules/*.sh doctor/*.sh tests/*.sh scripts/*.sh

# Syntax check
bash -n install.sh lib/*.sh modules/*.sh doctor/*.sh tests/*.sh scripts/*.sh

# Run doctor (diagnostics)
./install.sh --doctor

# Generate diagnostic report
./scripts/generate-doctor-report.sh
```

## Directory Structure

```
devforge/
├── install.sh           # Main entry point
├── lib/                  # Core library functions
│   ├── cli.sh            # CLI parsing, version (DEVFORGE_VERSION)
│   ├── logging.sh        # Logging utilities
│   ├── helpers.sh        # Helper functions
│   ├── distro.sh         # Distribution detection
│   ├── modules.sh        # Module loading system
│   ├── flatpak.sh        # Flatpak installation helpers
│   ├── metrics.sh        # Installation metrics
│   └── doctor.sh         # Doctor system core
├── modules/              # Installation modules (9 total)
│   ├── system.sh         # Base packages
│   ├── terminal.sh       # Shell tools (zsh, fzf, tmux)
│   ├── git.sh            # Git, LFS, gh CLI
│   ├── php.sh            # PHP 8.2-8.4, Composer
│   ├── node.sh           # NVM, pnpm, yarn, bun
│   ├── docker.sh         # Docker Engine, Compose
│   ├── databases.sh      # MySQL, PostgreSQL, Redis
│   ├── browsers.sh       # Chrome, Brave
│   └── apps.sh           # VS Code, DBeaver, VLC
├── doctor/               # Diagnostic check modules
│   ├── system.sh
│   ├── terminal.sh
│   ├── git.sh
│   ├── php.sh
│   ├── node.sh
│   ├── docker.sh
│   ├── databases.sh
│   ├── browsers.sh
│   ├── apps.sh
│   └── summary.sh        # Aggregates results
├── tests/                # Test suites
│   ├── test_helpers.sh   # Helper function tests (108 tests)
│   ├── test_doctor.sh    # Doctor system tests (29 tests)
│   ├── test_report_script.sh  # Report generator tests (26 tests)
│   └── run_syntax_checks.sh   # Syntax validation
├── scripts/              # Utility scripts
│   └── generate-doctor-report.sh  # Diagnostic report generator
├── docs/                 # Documentation
└── .github/workflows/    # CI configuration
    └── ci.yml            # 5 CI jobs
```

## Coding Standards

### Bash Strict Mode
All scripts use strict mode:
```bash
set -Eeuo pipefail
```

### ShellCheck Compliance
All code must pass ShellCheck with `-x` flag (follow sources):
```bash
shellcheck -x script.sh
```

### NO_COLOR Support
Color output respects the `NO_COLOR` environment variable per https://no-color.org/:
```bash
if [[ -z "${NO_COLOR:-}" ]]; then
    # Use colors
fi
```

### Function Naming
- Module functions: `install_<module>_<component>()`
- Doctor functions: `doctor_check_<component>()`
- Helper functions: `lowercase_with_underscores()`

## Key Files

| File | Purpose |
|------|---------|
| `lib/cli.sh` | Version constant, CLI parsing, module list |
| `lib/doctor.sh` | Doctor system core, status markers |
| `lib/modules.sh` | Module loading and execution |
| `install.sh` | Entry point, sources all lib/*.sh |

## CI Pipeline

5 GitHub Actions jobs run on every push:
1. **syntax-check** - `bash -n` validation
2. **shellcheck** - Static analysis
3. **unit-tests** - All test suites
4. **doctor-validation** - Doctor command runs
5. **file-structure** - Required files exist

## Common Tasks

### Adding a New Module
1. Create `modules/<name>.sh` with `install_<name>()` function
2. Create `doctor/<name>.sh` with diagnostic checks
3. Add module to `AVAILABLE_MODULES` in `lib/cli.sh`
4. Add tests to appropriate test file

### Adding a Doctor Check
```bash
doctor_check_<name>() {
    if command -v <tool> &>/dev/null; then
        doctor_ok "<tool>: $(<tool> --version)"
    else
        doctor_fail "<tool>: not found"
    fi
}
```

### Running Specific Module
```bash
sudo ./install.sh --<module>
# Example: sudo ./install.sh --terminal
```

## Critical Constraints

1. **No breaking changes** - Existing installations must not break
2. **Idempotent** - Running twice produces same result
3. **Root required** - Installation needs sudo
4. **Doctor is read-only** - Never modifies system
5. **Version frozen** - 0.9.0 until release

## Related Documentation

- [README.md](README.md) - Full user documentation
- [ARCHITECTURE.md](ARCHITECTURE.md) - System design
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contributor guide
- [docs/DOCTOR_REPORTING.md](docs/DOCTOR_REPORTING.md) - Doctor output format
