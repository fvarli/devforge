# Contributing to DevForge

Guidelines for contributing to DevForge.

## Development Setup

### Prerequisites

- Ubuntu/Debian-based Linux system
- Bash 4.0+
- Git
- ShellCheck (`sudo apt install shellcheck`)

### Clone and Verify

```bash
git clone <repository-url>
cd devforge

# Verify all tests pass
bash tests/test_helpers.sh
bash tests/test_doctor.sh
bash tests/test_report_script.sh

# Verify ShellCheck passes
shellcheck -x install.sh lib/*.sh modules/*.sh doctor/*.sh tests/*.sh scripts/*.sh
```

## Code Standards

### Bash Strict Mode

All scripts must use strict mode:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
```

### ShellCheck Compliance

All code must pass ShellCheck with the `-x` flag:

```bash
shellcheck -x your_script.sh
```

Common ShellCheck fixes:
- Quote variables: `"$var"` not `$var`
- Use `[[` not `[` for tests
- Declare locals: `local var` before assignment

### NO_COLOR Support

Color output must respect the NO_COLOR environment variable:

```bash
if [[ -z "${NO_COLOR:-}" ]]; then
    RED='\033[0;31m'
    NC='\033[0m'
else
    RED=''
    NC=''
fi
```

Reference: https://no-color.org/

### Function Naming

| Type | Pattern | Example |
|------|---------|---------|
| Module installer | `install_<module>_<thing>()` | `install_terminal_zsh()` |
| Doctor check | `doctor_check_<thing>()` | `doctor_check_git_installed()` |
| Helper function | `lowercase_underscores()` | `command_exists()` |

### Error Handling

```bash
# Use || for error handling
command || {
    log_error "Command failed"
    return 1
}

# Check command existence
if ! command_exists required_tool; then
    log_error "required_tool not found"
    return 1
fi
```

## Adding a New Module

1. **Create the module file**

   Create `modules/<name>.sh`:

   ```bash
   #!/usr/bin/env bash
   # modules/mymodule.sh - Description

   install_mymodule() {
       log_section "My Module"

       # Check if already installed
       if command_exists mytool; then
           log_info "mytool already installed"
           return 0
       fi

       # Install
       install_packages mytool-package

       log_success "mytool installed"
   }
   ```

2. **Create doctor checks**

   Create `doctor/<name>.sh`:

   ```bash
   #!/usr/bin/env bash
   # doctor/mymodule.sh - Diagnostic checks

   doctor_check_mytool_installed() {
       if command_exists mytool; then
           doctor_ok "mytool: $(mytool --version 2>&1 | head -1)"
       else
           doctor_fail "mytool: not found"
       fi
   }
   ```

3. **Register the module**

   Add to `AVAILABLE_MODULES` array in `lib/cli.sh`:

   ```bash
   AVAILABLE_MODULES=(
       # ... existing modules
       "mymodule"
   )
   ```

4. **Add tests**

   Add tests to appropriate test file.

## Adding a Doctor Check

Doctor checks are read-only diagnostics. They must:

- Never modify the system
- Use `doctor_ok`, `doctor_warn`, `doctor_fail`, or `doctor_skip`
- Handle missing dependencies gracefully

```bash
doctor_check_example() {
    # Check if dependency exists first
    if ! command_exists parent_tool; then
        doctor_skip "example: parent_tool not installed"
        return 0
    fi

    if [[ -f ~/.example_config ]]; then
        doctor_ok "example config: present"
    else
        doctor_warn "example config: missing (optional)"
    fi
}
```

## Testing

### Running Tests

```bash
# All helper tests (108 tests)
bash tests/test_helpers.sh

# Doctor system tests (29 tests)
bash tests/test_doctor.sh

# Report generator tests (26 tests)
bash tests/test_report_script.sh

# Syntax validation
bash tests/run_syntax_checks.sh

# Full validation
bash -n install.sh lib/*.sh modules/*.sh doctor/*.sh tests/*.sh scripts/*.sh
shellcheck -x install.sh lib/*.sh modules/*.sh doctor/*.sh tests/*.sh scripts/*.sh
```

### Writing Tests

Test pattern:

```bash
test_my_function() {
    local result
    result=$(my_function "input")

    if [[ "$result" == "expected" ]]; then
        echo "PASS: test_my_function"
        return 0
    else
        echo "FAIL: test_my_function - got '$result'"
        return 1
    fi
}
```

## Pull Request Process

1. **Fork and branch**

   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make changes**

   - Follow code standards
   - Add tests if applicable
   - Update documentation if needed

3. **Validate locally**

   ```bash
   # Must all pass
   bash -n install.sh lib/*.sh modules/*.sh doctor/*.sh tests/*.sh scripts/*.sh
   shellcheck -x install.sh lib/*.sh modules/*.sh doctor/*.sh tests/*.sh scripts/*.sh
   bash tests/test_helpers.sh
   bash tests/test_doctor.sh
   bash tests/test_report_script.sh
   ```

4. **Commit with clear message**

   ```bash
   git commit -m "feat: add example feature

   - Added example module
   - Added doctor checks
   - Added tests"
   ```

5. **Push and create PR**

   ```bash
   git push origin feature/my-feature
   ```

6. **CI must pass**

   All 5 CI jobs must pass:
   - syntax-check
   - shellcheck
   - unit-tests
   - doctor-validation
   - file-structure

## Commit Message Format

```
<type>: <short description>

<optional body>
```

Types:
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation only
- `refactor` - Code refactoring
- `test` - Adding tests
- `chore` - Maintenance

Examples:
```
feat: add Redis support to databases module
fix: correct PHP extension detection in doctor
docs: update installation instructions
refactor: simplify module loading logic
test: add tests for helper functions
chore: update CI configuration
```

## Directory Reference

| Directory | Purpose |
|-----------|---------|
| `lib/` | Core library functions |
| `modules/` | Installation modules |
| `doctor/` | Diagnostic check modules |
| `tests/` | Test suites |
| `scripts/` | Utility scripts |
| `docs/` | Documentation |
| `.github/workflows/` | CI configuration |

## Getting Help

- Review existing modules for patterns
- Check [ARCHITECTURE.md](ARCHITECTURE.md) for system design
- Check [CLAUDE.md](CLAUDE.md) for quick reference

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
