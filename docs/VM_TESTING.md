# VM Testing Guide

Manual validation procedures for DevForge release candidates.

## Overview

This guide documents exact procedures for testing DevForge on supported platforms before release. Each VM test validates installation, idempotency, and post-reboot functionality.

## Supported Test Platforms

| Platform | Version | Architecture |
|----------|---------|--------------|
| Ubuntu | 22.04 LTS (Jammy) | amd64 |
| Ubuntu | 24.04 LTS (Noble) | amd64 |
| Kubuntu | 24.04 LTS | amd64 |

## Pre-Test Requirements

- Fresh VM installation (no prior DevForge runs)
- Internet connection
- At least 20GB free disk space
- User account with sudo privileges

## Test Procedure

### Phase 1: System Preparation

```bash
# Update base system
sudo apt update && sudo apt upgrade -y

# Install git
sudo apt install -y git

# Clone DevForge
git clone https://github.com/fvarli/devforge.git
cd devforge

# Verify version
./install.sh --version

# Copy configuration
cp config.env.example config.env

# Review enabled options (edit if needed)
cat config.env
```

### Phase 2: First Installation

```bash
# Run full installation
sudo ./install.sh --all

# Record exit code
echo "Exit code: $?"
```

**Capture:**
- Exit code (0 = success, 1 = partial failure)
- Installation summary (modules, packages, time)
- Any failed or warning modules

### Phase 3: Pre-Reboot Doctor

```bash
# Run doctor before reboot
./install.sh --doctor
```

**Record:**
- Health Score percentage
- Failed checks count
- Warning checks count

### Phase 4: Reboot

```bash
sudo reboot
```

### Phase 5: Post-Reboot Verification

After logging back in:

```bash
cd devforge

# Verify Docker group membership
groups
docker run hello-world

# Verify NVM and Node
source ~/.nvm/nvm.sh  # May be needed in some shells
nvm --version
node --version
npm --version

# Verify PHP tools
php --version
composer --version
laravel --version
symfony version

# Verify database services
systemctl is-active mysql || systemctl is-active mariadb
systemctl is-active postgresql
systemctl is-active redis-server || systemctl is-active redis

# Database connectivity
mysql --version
psql --version
redis-cli ping
```

### Phase 6: Doctor After Reboot

```bash
./install.sh --doctor
```

**Record:**
- Health Score percentage (should be same or higher)
- Any new failures

### Phase 7: Second Installation (Idempotency)

```bash
sudo ./install.sh --all
echo "Exit code: $?"
```

**Verify:**
- Exit code is 0
- Most packages reported as "skipped"
- No duplicate repository additions
- No duplicate shell configuration lines

```bash
# Check for duplicate APT sources
ls /etc/apt/sources.list.d/

# Check shell config for duplicates
grep -c "NVM_DIR" ~/.bashrc
grep -c "NVM_DIR" ~/.zshrc 2>/dev/null || true
```

### Phase 8: Final Doctor

```bash
./install.sh --doctor
```

## Evidence Commands

Use these commands to gather evidence for test reports:

```bash
# System info
lsb_release -a
uname -a
df -h /

# DevForge state
git status
./install.sh --version

# Service status
systemctl --failed

# Tool versions
docker version
docker compose version
php --version
composer --version
node --version
npm --version

# Database versions
mysql --version
psql --version
redis-cli --version

# Doctor output
./install.sh --doctor
```

## Platform-Specific Notes

### Ubuntu 22.04 LTS (Jammy)

- Default PHP may be 8.1; DevForge installs 8.4 from ondrej/php
- MySQL may install as MariaDB on some derivatives

### Ubuntu 24.04 LTS (Noble)

- PHP 8.3 available in default repos; DevForge adds 8.4
- Snap packages may conflict with APT versions

### Kubuntu 24.04 LTS

- Same as Ubuntu 24.04 with KDE Plasma desktop
- Additional KDE apps may be available via Flatpak

## Common Issues

### Docker Permission Denied

If `docker run` fails after reboot:
```bash
# Verify group membership
groups | grep docker

# If missing, re-add and logout/login
sudo usermod -aG docker $USER
```

### NVM Not Found

If `nvm` command not found in new shell:
```bash
# Source NVM manually
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
```

### Database Service Not Running

```bash
# Check service status
systemctl status mysql postgresql redis-server

# Start if needed
sudo systemctl start mysql
sudo systemctl start postgresql
sudo systemctl start redis-server
```

## Test Result Documentation

After completing tests, document results using the template:
[VM_TEST_RESULT_TEMPLATE.md](VM_TEST_RESULT_TEMPLATE.md)
