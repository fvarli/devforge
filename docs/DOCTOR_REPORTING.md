# DevForge Doctor Reporting Guide

Understanding and using diagnostic output from DevForge.

## Overview

The doctor command performs read-only diagnostic checks on installed components. It does NOT require root privileges and does NOT modify your system.

## Running Doctor

### Basic Usage

```bash
./install.sh --doctor
```

### Generate Report File

```bash
./scripts/generate-doctor-report.sh
```

Creates a timestamped report in `reports/devforge-doctor-YYYYMMDD-HHMMSS.txt`.

### Custom Output File

```bash
./scripts/generate-doctor-report.sh reports/my-machine.txt
```

### CI/Automation Usage

```bash
NO_COLOR=1 ./install.sh --doctor
```

The `NO_COLOR` environment variable disables ANSI color codes for clean log output.

---

## Output Markers

| Marker | Color | Meaning |
|--------|-------|---------|
| [OK] | Green | Check passed - component installed and working |
| [WARN] | Yellow | Non-critical issue - component has minor problems |
| [FAIL] | Red | Component missing or broken |
| [SKIP] | Blue | Check skipped - dependency not installed |

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed (no failures, warnings are OK) |
| 1 | One or more checks failed |

---

## Health Score

The summary includes a health score calculated as:

```
Health Score = passed / (passed + warnings + failed) * 100
```

| Score | Status |
|-------|--------|
| 100% | Perfect installation |
| 80-99% | Minor issues - review warnings |
| <80% | Significant issues - review failures |

---

## Report Format

Generated reports include:

1. **Metadata Header**
   - Generation timestamp
   - Hostname
   - User running the check
   - Distribution (OS name)
   - Architecture (x86_64, etc.)
   - Kernel version
   - DevForge version
   - Git commit hash
   - Git branch
   - Working tree state (clean or modified count)

2. **Section Checks**
   - System
   - Terminal
   - Git
   - PHP
   - Node
   - Docker
   - Databases
   - Browsers
   - Apps

3. **Summary**
   - Total checks count
   - Passed count
   - Warnings count
   - Failed count

4. **Footer**
   - Doctor exit code

---

## Example Report

```
========================================
DevForge Doctor Report
========================================

Generated:    2024-01-15T14:30:00+00:00
Hostname:     dev-workstation
User:         developer
Distribution: Ubuntu 24.04.1 LTS
Architecture: x86_64
Kernel:       6.5.0-15-generic

DevForge:     v0.9.0
Git commit:   a1b2c3d
Git branch:   main
Working tree: clean

----------------------------------------

DevForge Doctor
Running diagnostic checks...

==> System
[OK] OS: Ubuntu 24.04.1 LTS
[OK] Architecture: x86_64
[OK] Disk space: 45GB free

==> Terminal
[OK] zsh: zsh 5.9
[OK] fzf: 0.48.0
[FAIL] tmux: not found

==> Git
[OK] git: git version 2.43.0
[OK] git-lfs: git-lfs/3.4.1
[OK] gh: gh version 2.40.1

==> Summary
  Total checks: 45
  Passed: 42
  Warnings: 1
  Failed: 2
  Health Score: 93%

----------------------------------------
Doctor exit code: 1
========================================
```

---

## Sections Checked

### System
- OS version and name
- Architecture (x86_64/amd64)
- Disk space availability
- Essential packages (curl, wget, etc.)

### Terminal
- zsh installation
- fzf availability
- tmux installation
- bat/batcat
- eza
- zoxide
- Starship prompt

### Git
- Git installation and version
- Git LFS
- GitHub CLI (gh)
- SSH directory permissions

### PHP
- PHP versions (8.2, 8.3, 8.4)
- Required extensions
- Composer installation
- Laravel Installer
- Symfony CLI

### Node
- NVM installation
- Node.js version
- npm
- pnpm
- yarn
- bun

### Docker
- Docker Engine
- Docker CLI
- Docker Compose plugin
- Docker Buildx plugin
- Docker service status
- User group membership

### Databases
- MySQL/MariaDB
- PostgreSQL
- Redis
- SQLite

### Browsers
- Google Chrome
- Brave Browser

### Apps
- VS Code
- DBeaver
- VLC
- Other configured applications

---

## Troubleshooting

### Re-run a Failed Module

```bash
sudo ./install.sh --<module>
```

For example:
```bash
sudo ./install.sh --terminal
```

### Check Specific Component

If a component shows [FAIL], verify manually:

```bash
# Check if command exists
which <command>
command -v <command>

# Check version
<command> --version
```

### View Service Status

```bash
systemctl status docker
systemctl status mysql
systemctl status postgresql
systemctl status redis
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Docker: permission denied | Log out and back in, or run `newgrp docker` |
| NVM: command not found | Run `source ~/.nvm/nvm.sh` or restart terminal |
| PHP extensions missing | Re-run `sudo ./install.sh --php` |
| Service not running | Run `sudo systemctl start <service>` |

---

## Comparing Reports

To compare two doctor reports:

```bash
diff reports/devforge-doctor-20240101-120000.txt reports/devforge-doctor-20240115-120000.txt
```

This helps track changes in your development environment over time.
