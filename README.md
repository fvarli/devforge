# DevForge

Modular developer workstation bootstrap for Ubuntu-based Linux distributions.

## Current status

DevForge is under active development.

The initial foundation includes:

- Linux distribution detection
- Configuration loading
- Logging helpers
- Modular installer architecture
- Idempotent APT package installation
- Error handling
- Module execution timing
- Installation metrics and counters
- Comprehensive summary reporting
- Non-zero exit codes on failure

## Installation Metrics

DevForge tracks installation progress and provides detailed reports:

- **Module timing**: Execution time from start to completion
- **Operation counters**: Packages (APT) vs applications (DEB, Flatpak, scripts)
- **Status tracking**: Warnings and errors encountered
- **Total elapsed time**: Overall installation duration

### Summary Report

```
Modules:
✓ system (12s)
✓ terminal (1m 34s)

Operations:
  Packages: 42 installed, 8 skipped (50 total)
  Applications: 5 installed, 2 skipped (7 total)

Total time: 2m 39s
```

Time formats: `42s`, `3m 12s`, `1h 4m 9s`

### Exit Codes

- `0`: All modules completed successfully
- `1`: One or more modules failed

## Available modules

### system

Essential system utilities and tools:
- Core utilities: ca-certificates, curl, wget, unzip, zip, p7zip-full
- APT tools: software-properties-common, apt-transport-https
- File utilities: tree, rsync, ncdu
- Search and analysis: jq, ripgrep, fd-find
- System monitoring: htop, btop, fastfetch
- Network tools: dnsutils, net-tools, traceroute
- Remote access: openssh-client, openssh-server
- Firewall: ufw

### terminal

Modern terminal tools and shell enhancements (all required):
- Shells: zsh
- Terminal multiplexer: tmux
- Fuzzy finder: fzf
- File viewers: bat (batcat)
- Directory navigation: zoxide
- File listing: eza
- Prompt: Starship

### git

Version control and collaboration tools (all required):
- Git and Git LFS
- GitHub CLI (gh)
- Automatic SSH directory setup (with proper permissions)
- Minimal .gitconfig template (if not exists)

### php

Complete PHP development environment for Laravel:
- PHP (configurable version, default 8.4) via ondrej/php PPA
- Extensions: cli, fpm, mysql, pgsql, sqlite3, curl, gd, intl, mbstring, xml, zip, bcmath, soap, readline, opcache
- php-pear for PECL support
- Composer (with SHA384 signature verification)
- Laravel Installer (global, for target user)
- Symfony CLI
- PECL imagick (optional, warns on failure)
- Automatic default PHP version configuration via update-alternatives

Configuration in `config.env`:
```bash
PHP_VERSION=8.4
SET_DEFAULT_PHP=true
INSTALL_PHP_IMAGICK=true
INSTALL_LARAVEL_INSTALLER=true
INSTALL_SYMFONY_CLI=true
```

### node

Complete Node.js development environment:
- NVM (Node Version Manager) for version management
- Node.js (configurable version: lts, latest, or specific version)
- npm (bundled with Node.js)
- pnpm via Corepack (with npm fallback)
- Yarn via Corepack (with npm fallback)
- Bun JavaScript runtime
- npm-check-updates global tool

All tools are installed for the target user (not root).

Configuration in `config.env`:
```bash
NODE_INSTALL_METHOD=nvm
NODE_VERSION=lts
INSTALL_NPM_GLOBAL_TOOLS=true
INSTALL_PNPM=true
INSTALL_YARN=true
INSTALL_BUN=true
```

### docker

Docker Engine with official repository (amd64 only):
- Docker CE (Community Edition)
- Docker CLI
- containerd.io
- Docker Compose plugin
- Docker Buildx plugin
- Automatic service enable/start
- Docker group configuration for non-root usage

Note: Requires logout/login for docker group membership to take effect.

Configuration in `config.env`:
```bash
INSTALL_DOCKER_ENGINE=true
INSTALL_DOCKER_COMPOSE=true
INSTALL_DOCKER_BUILDX=true
ENABLE_DOCKER_SERVICE=true
ADD_USER_TO_DOCKER_GROUP=true
RUN_DOCKER_HELLO_WORLD=false
```

### browsers

Web browsers (amd64 only):
- Google Chrome Stable (official .deb package)
- Brave Browser (official APT repository)

### apps

Desktop applications (amd64 only for VS Code/DBeaver):
- Development: Visual Studio Code (Microsoft APT repository), DBeaver CE (official .deb package)
- Media: VLC Media Player, Spotify (Flatpak from Flathub)
- Utilities: FileZilla, KeePassXC
- Security: Bitwarden (Flatpak from Flathub)

Note: Flatpak applications are installed system-wide from Flathub.

## Usage

Clone and run with interactive module selection:

```bash
git clone https://github.com/fvarli/devforge.git
cd devforge
cp config.env.example config.env
sudo ./install.sh
```

Install specific modules:

```bash
sudo ./install.sh --system
sudo ./install.sh --terminal
sudo ./install.sh --git
sudo ./install.sh --php
sudo ./install.sh --node
sudo ./install.sh --docker
sudo ./install.sh --browsers
sudo ./install.sh --apps
```

Install multiple modules:

```bash
sudo ./install.sh --system --terminal --git
sudo ./install.sh --php --node --docker
sudo ./install.sh --browsers --apps
```

## Supported distributions

Primary targets:
- Ubuntu LTS (current)
- Kubuntu LTS (current)

Best-effort support:
- Xubuntu
- Pop!_OS
- Linux Mint

Note: Some packages (btop, fastfetch, eza) may not be available
in older repositories and would require alternative installation
methods.

## License

MIT License - see LICENSE file for details
