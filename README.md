# DevForge

![CI](https://github.com/fvarli/devforge/workflows/CI/badge.svg)

Modular developer workstation bootstrap for Ubuntu-based Linux distributions.

## Quick Start

```bash
git clone https://github.com/fvarli/devforge.git
cd devforge
cp config.env.example config.env
# Edit config.env to customize
sudo ./install.sh
```

## Installation

### Prerequisites

- Ubuntu LTS or Ubuntu-based distribution (Kubuntu, Pop!_OS, Linux Mint)
- Root privileges (sudo)
- Internet connection

### Interactive Mode

Run without arguments for interactive module selection:

```bash
sudo ./install.sh
```

### Command Line Mode

Install specific modules:

```bash
sudo ./install.sh --system --terminal --git
sudo ./install.sh --php --node --docker
sudo ./install.sh --all
```

### Available Options

| Option | Description |
|--------|-------------|
| `--all` | Install all modules |
| `--system` | System utilities (curl, wget, htop, etc.) |
| `--terminal` | Terminal tools (zsh, tmux, fzf, starship) |
| `--git` | Git, Git LFS, GitHub CLI |
| `--php` | PHP, Composer, Laravel, Symfony |
| `--node` | NVM, Node.js, pnpm, Yarn, Bun |
| `--docker` | Docker Engine, Compose, Buildx |
| `--databases` | MySQL, PostgreSQL, Redis, SQLite |
| `--browsers` | Chrome, Brave |
| `--apps` | VS Code, DBeaver, VLC, etc. |
| `--interactive` | Interactive module selection |
| `--doctor` | Run diagnostic checks (no installation) |
| `--help` | Show help message |
| `--version` | Show version |

## Doctor Command

Verify your installation with the doctor command:

```bash
./install.sh --doctor
```

Doctor checks all configured components and reports their status:

```
DevForge Doctor
Running diagnostic checks...

==> System
[OK] OS: Ubuntu 24.04 LTS
[OK] Architecture: x86_64
[OK] Disk space: 50GB free

==> Terminal
[OK] zsh: zsh 5.9
[OK] fzf: 0.48.0
[FAIL] tmux: not found

==> Summary
  Total checks: 45
  Passed: 42
  Warnings: 1
  Failed: 2
```

- `[OK]` - Component installed and working
- `[WARN]` - Component has issues (non-critical)
- `[FAIL]` - Component missing or broken
- `[SKIP]` - Component disabled in config

**Exit codes:**
- `0` - No failures (warnings are OK)
- `1` - One or more failures

Doctor does NOT require root privileges.

## Configuration

Copy the example configuration:

```bash
cp config.env.example config.env
```

### config.env Reference

```bash
# Target user (defaults to SUDO_USER)
DEVFORGE_USER="${SUDO_USER:-$USER}"

# Module toggles
INSTALL_SYSTEM=true
INSTALL_TERMINAL=false
INSTALL_GIT=false
INSTALL_PHP=false
INSTALL_NODE=false
INSTALL_DOCKER=false
INSTALL_DATABASES=false
INSTALL_BROWSERS=false
INSTALL_APPS=false

# PHP configuration
PHP_VERSION=8.4
SET_DEFAULT_PHP=true
INSTALL_PHP_IMAGICK=true
INSTALL_LARAVEL_INSTALLER=true
INSTALL_SYMFONY_CLI=true

# Node.js configuration
NODE_INSTALL_METHOD=nvm
NODE_VERSION=lts
INSTALL_NPM_GLOBAL_TOOLS=true
INSTALL_PNPM=true
INSTALL_YARN=true
INSTALL_BUN=true

# Docker configuration
INSTALL_DOCKER_ENGINE=true
INSTALL_DOCKER_COMPOSE=true
INSTALL_DOCKER_BUILDX=true
ENABLE_DOCKER_SERVICE=true
ADD_USER_TO_DOCKER_GROUP=true

# Database configuration
INSTALL_MYSQL=true
INSTALL_POSTGRESQL=true
INSTALL_REDIS=true
INSTALL_SQLITE=true
ENABLE_MYSQL_SERVICE=true
ENABLE_POSTGRESQL_SERVICE=true
ENABLE_REDIS_SERVICE=true

# Browser configuration
INSTALL_CHROME=true
INSTALL_BRAVE=true

# Desktop applications
INSTALL_VSCODE=true
INSTALL_DBEAVER=true
INSTALL_BITWARDEN=true
INSTALL_SPOTIFY=true
INSTALL_VLC=true
INSTALL_FILEZILLA=true
INSTALL_KEEPASSXC=false
```

Boolean values must be `true` or `false` (case-sensitive).

## Module Details

### system

Essential system utilities:

- Core: ca-certificates, curl, wget, unzip, zip, p7zip-full
- APT tools: software-properties-common, apt-transport-https
- File utilities: tree, rsync, ncdu
- Search: jq, ripgrep, fd-find
- Monitoring: htop, btop, fastfetch
- Network: dnsutils, net-tools, traceroute
- SSH: openssh-client, openssh-server
- Firewall: ufw

### terminal

Modern terminal environment:

- Shell: zsh
- Multiplexer: tmux
- Fuzzy finder: fzf
- File viewer: bat (batcat)
- Navigation: zoxide
- Listing: eza
- Prompt: Starship

### git

Version control:

- Git and Git LFS
- GitHub CLI (gh)
- SSH directory setup (700 permissions)
- Minimal .gitconfig template

### php

PHP development (Laravel/Symfony ready):

- PHP 8.2, 8.3, or 8.4 via ondrej/php PPA
- Extensions: cli, fpm, mysql, pgsql, sqlite3, curl, gd, intl, mbstring, xml, zip, bcmath, soap, readline, opcache
- Composer (SHA384 verified)
- Laravel Installer (global)
- Symfony CLI
- PECL imagick (optional)

Note: PHP 8.0 and 8.1 are EOL and not supported.

### node

Node.js development:

- NVM (Node Version Manager)
- Node.js (lts, latest, or specific version)
- npm (bundled)
- pnpm via Corepack
- Yarn via Corepack
- Bun runtime
- npm-check-updates

All tools installed for target user, not root.

### docker

Container runtime (amd64 only):

- Docker CE
- Docker CLI
- containerd.io
- Docker Compose plugin
- Docker Buildx plugin

Requires systemd. Logout/login needed for group membership.

### databases

Database servers:

- MySQL Server
- PostgreSQL
- Redis
- SQLite

Services enabled by default. Security hardening is manual:

```bash
# MySQL
sudo mysql_secure_installation

# PostgreSQL
sudo -u postgres createuser --interactive

# Redis
# Edit /etc/redis/redis.conf: requirepass <password>
```

### browsers

Web browsers (amd64 only):

- Google Chrome Stable
- Brave Browser

### apps

Desktop applications:

- VS Code (Microsoft APT)
- DBeaver CE
- VLC Media Player
- Spotify (Flatpak)
- Bitwarden (Flatpak)
- FileZilla
- KeePassXC

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | One or more modules failed |

## Idempotency

DevForge is designed to be run multiple times safely:

- Packages are skipped if already installed
- Repositories are only added if not present
- Configuration files are not overwritten
- Metrics track installed vs skipped operations

## Installation Report

After installation, DevForge shows a summary:

```
Modules:
✓ system (12s)
✓ terminal (1m 34s)
✗ docker (failed)

Operations:
  Packages: 42 installed, 8 skipped (50 total)
  Applications: 5 installed, 2 skipped (7 total)

Total time: 2m 39s
```

## Troubleshooting

### Docker group membership

After Docker installation, you need to log out and back in for group membership to take effect. Alternatively:

```bash
newgrp docker
```

### PHP version mismatch

If the wrong PHP version is active:

```bash
sudo update-alternatives --config php
```

### NVM not found in new shell

Source NVM manually or restart your terminal:

```bash
source ~/.nvm/nvm.sh
```

### Permission denied errors

Ensure you're running with sudo:

```bash
sudo ./install.sh --all
```

### Module failed

Check the specific module's requirements:

1. Run doctor to diagnose: `./install.sh --doctor`
2. Check system logs: `journalctl -xe`
3. Verify dependencies are installed

### APT lock errors

Wait for other package managers to finish:

```bash
# Check for running apt/dpkg processes
ps aux | grep -E 'apt|dpkg'

# Wait for lock to be released (Ctrl+C to abort)
while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
    echo "Waiting for apt lock..."
    sleep 5
done
```

If apt is stuck after a system crash, run:

```bash
sudo dpkg --configure -a
```

**Warning:** Do not delete lock files while apt/dpkg is running.

## Supported Distributions

**Primary:**
- Ubuntu LTS (22.04, 24.04)
- Kubuntu LTS

**Best-effort:**
- Xubuntu
- Pop!_OS
- Linux Mint

Note: Some packages may not be available in older repositories.

## Development

### Running Tests

```bash
bash tests/test_helpers.sh
bash tests/test_doctor.sh
```

### Syntax Check

```bash
bash -n install.sh lib/*.sh modules/*.sh
```

### ShellCheck

```bash
shellcheck install.sh lib/*.sh modules/*.sh
```

### VM Testing

For release validation, see [docs/VM_TESTING.md](docs/VM_TESTING.md).

## License

MIT License - see LICENSE file for details.
