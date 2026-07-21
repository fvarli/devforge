# DevForge Architecture

Technical architecture documentation for DevForge v0.9.0.

## System Overview

DevForge is a modular Bash-based installer that configures development environments on Ubuntu/Debian systems. The architecture emphasizes:

- **Modularity** - Independent modules for each tool category
- **Idempotency** - Safe to run multiple times
- **Diagnostics** - Comprehensive health checks via doctor system
- **Testability** - Unit tests for core functionality

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         install.sh                              │
│                     (Entry Point)                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         lib/*.sh                                │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ cli.sh   │ │logging.sh│ │helpers.sh│ │ distro.sh│           │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │modules.sh│ │flatpak.sh│ │metrics.sh│ │doctor.sh │           │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│      modules/*.sh       │     │      doctor/*.sh        │
│   (Installation)        │     │   (Diagnostics)         │
├─────────────────────────┤     ├─────────────────────────┤
│ system.sh               │     │ system.sh               │
│ terminal.sh             │     │ terminal.sh             │
│ git.sh                  │     │ git.sh                  │
│ php.sh                  │     │ php.sh                  │
│ node.sh                 │     │ node.sh                 │
│ docker.sh               │     │ docker.sh               │
│ databases.sh            │     │ databases.sh            │
│ browsers.sh             │     │ browsers.sh             │
│ apps.sh                 │     │ apps.sh                 │
│                         │     │ summary.sh              │
└─────────────────────────┘     └─────────────────────────┘
```

## Execution Flow

### Installation Mode

```
User runs: sudo ./install.sh --all
                    │
                    ▼
            ┌───────────────┐
            │  install.sh   │
            │  - set -Eeuo  │
            │  - source lib │
            └───────────────┘
                    │
                    ▼
            ┌───────────────┐
            │   cli.sh      │
            │  parse_args() │
            └───────────────┘
                    │
                    ▼
            ┌───────────────┐
            │  distro.sh    │
            │detect_distro()│
            └───────────────┘
                    │
                    ▼
            ┌───────────────┐
            │  modules.sh   │
            │ load_module() │
            └───────────────┘
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐
   │system.sh│ │ git.sh  │ │ ... .sh │
   └─────────┘ └─────────┘ └─────────┘
        │           │           │
        └───────────┼───────────┘
                    ▼
            ┌───────────────┐
            │  metrics.sh   │
            │print_summary()│
            └───────────────┘
```

### Doctor Mode

```
User runs: ./install.sh --doctor
                    │
                    ▼
            ┌───────────────┐
            │  install.sh   │
            │ (no sudo req) │
            └───────────────┘
                    │
                    ▼
            ┌───────────────┐
            │  doctor.sh    │
            │ run_doctor()  │
            └───────────────┘
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐
   │doctor/  │ │doctor/  │ │doctor/  │
   │system.sh│ │ git.sh  │ │ ... .sh │
   └─────────┘ └─────────┘ └─────────┘
        │           │           │
        └───────────┼───────────┘
                    ▼
            ┌───────────────┐
            │doctor/summary │
            │  .sh          │
            │ Health Score  │
            └───────────────┘
```

## Core Library Components

### lib/cli.sh

Central configuration and CLI parsing.

```bash
DEVFORGE_VERSION="0.9.0"

AVAILABLE_MODULES=(
    "system"
    "terminal"
    "git"
    "php"
    "node"
    "docker"
    "databases"
    "browsers"
    "apps"
)
```

Key functions:
- `parse_args()` - Process command-line arguments
- `show_help()` - Display usage information
- `show_version()` - Print version

### lib/logging.sh

Consistent output formatting.

```bash
log_info()    # Blue [INFO] prefix
log_success() # Green [OK] prefix
log_warn()    # Yellow [WARN] prefix
log_error()   # Red [ERROR] prefix
log_section() # ==> Section header
```

Color output respects `NO_COLOR` environment variable.

### lib/helpers.sh

Utility functions used across modules.

```bash
command_exists()      # Check if command available
require_root()        # Enforce sudo
add_apt_repository()  # Add PPA safely
install_packages()    # apt-get with error handling
download_file()       # curl/wget wrapper
```

### lib/distro.sh

Distribution detection and compatibility.

```bash
detect_distro()       # Returns: ubuntu, debian, etc.
get_distro_version()  # Returns: 22.04, 24.04, etc.
is_supported()        # Check if distro supported
```

### lib/modules.sh

Module loading and execution system.

```bash
load_module()         # Source module file
run_module()          # Execute install_<name>()
list_modules()        # Show available modules
```

### lib/doctor.sh

Diagnostic system core.

```bash
doctor_ok()           # [OK] status marker
doctor_warn()         # [WARN] status marker
doctor_fail()         # [FAIL] status marker
doctor_skip()         # [SKIP] status marker
run_doctor()          # Execute all doctor checks
```

## Module System

### Module Contract

Each module in `modules/*.sh` must:

1. Define `install_<name>()` function
2. Use logging functions for output
3. Be idempotent (safe to run multiple times)
4. Handle errors gracefully

Example structure:

```bash
#!/usr/bin/env bash
# modules/example.sh

install_example() {
    log_section "Example Module"

    if command_exists example; then
        log_info "example already installed"
        return 0
    fi

    install_packages example-package
    log_success "example installed"
}
```

### Module Dependencies

```
system ─────┐
            │
terminal ───┼──► git ──► php ──► node
            │
            └──► docker ──► databases
                    │
                    └──► browsers ──► apps
```

The `--all` flag installs in dependency order.

## Doctor System

### Check Contract

Each file in `doctor/*.sh` must:

1. Define check functions with `doctor_check_` prefix
2. Use `doctor_ok`, `doctor_warn`, `doctor_fail`, `doctor_skip`
3. Never modify the system (read-only)
4. Handle missing dependencies gracefully

Example:

```bash
#!/usr/bin/env bash
# doctor/example.sh

doctor_check_example_installed() {
    if command_exists example; then
        doctor_ok "example: $(example --version 2>&1 | head -1)"
    else
        doctor_fail "example: not found"
    fi
}

doctor_check_example_config() {
    if [[ -f ~/.examplerc ]]; then
        doctor_ok "example config: present"
    else
        doctor_warn "example config: missing (optional)"
    fi
}
```

### Health Score Calculation

```
Health Score = (passed / (passed + warnings + failed)) * 100
```

| Score | Status |
|-------|--------|
| 100%  | Perfect |
| 80-99% | Minor issues |
| <80%  | Significant issues |

## Configuration

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `NO_COLOR` | Disable ANSI color output |
| `DEVFORGE_ROOT` | Override installation root |
| `DEBIAN_FRONTEND` | Set to `noninteractive` during install |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Failure (doctor: checks failed) |
| 2 | Script error (invalid arguments) |

## Testing Architecture

```
tests/
├── test_helpers.sh      # 108 tests for lib/helpers.sh
├── test_doctor.sh       # 29 tests for doctor system
├── test_report_script.sh # 26 tests for report generator
└── run_syntax_checks.sh # bash -n validation
```

### Test Pattern

```bash
test_function_name() {
    local result
    result=$(function_under_test "input")
    if [[ "$result" == "expected" ]]; then
        echo "PASS: test_function_name"
        return 0
    else
        echo "FAIL: test_function_name"
        return 1
    fi
}
```

## CI/CD Pipeline

```
┌─────────────┐
│   Push/PR   │
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────┐
│                    GitHub Actions                            │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐               │
│  │syntax-check│ │ shellcheck │ │ unit-tests │               │
│  └────────────┘ └────────────┘ └────────────┘               │
│  ┌──────────────────┐ ┌──────────────────┐                  │
│  │doctor-validation │ │ file-structure   │                  │
│  └──────────────────┘ └──────────────────┘                  │
└──────────────────────────────────────────────────────────────┘
```

## File Dependencies

```
install.sh
    │
    ├── lib/logging.sh
    ├── lib/helpers.sh
    ├── lib/distro.sh
    ├── lib/modules.sh
    ├── lib/cli.sh
    ├── lib/flatpak.sh
    ├── lib/metrics.sh
    └── lib/doctor.sh
            │
            ├── doctor/system.sh
            ├── doctor/terminal.sh
            ├── doctor/git.sh
            ├── doctor/php.sh
            ├── doctor/node.sh
            ├── doctor/docker.sh
            ├── doctor/databases.sh
            ├── doctor/browsers.sh
            ├── doctor/apps.sh
            └── doctor/summary.sh
```

## Related Documentation

- [CLAUDE.md](CLAUDE.md) - AI assistant context
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contributor guidelines
- [README.md](README.md) - User documentation
