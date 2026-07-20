# DevForge v1.0.0 — Draft Release Notes

> **Note:** This document is a draft for the upcoming v1.0.0 release.
> The runtime version remains 0.9.0 until the actual release.

First stable release of DevForge - a modular developer workstation bootstrap for Ubuntu-based Linux distributions.

## Highlights

- **Modular architecture**: Install only what you need with `--system`, `--php`, `--docker`, etc.
- **Doctor command**: Verify installations without root privileges using `./install.sh --doctor`
- **Idempotent**: Safe to run multiple times - skips already installed components
- **Comprehensive**: PHP, Node.js, Docker, databases, browsers, and desktop apps

## Modules

| Module | Description |
|--------|-------------|
| `system` | Core utilities (curl, wget, htop, ripgrep, jq, etc.) |
| `terminal` | Modern shell (zsh, fzf, bat, eza, zoxide, starship, tmux) |
| `git` | Version control (git, git-lfs, gh CLI, SSH setup) |
| `php` | PHP 8.2-8.4, Composer, Laravel Installer, Symfony CLI |
| `node` | NVM, Node.js (lts/latest), npm, pnpm, Yarn, Bun |
| `docker` | Docker CE, Compose plugin, Buildx (amd64 only) |
| `databases` | MySQL, PostgreSQL, Redis, SQLite |
| `browsers` | Google Chrome, Brave Browser (amd64 only) |
| `apps` | VS Code, DBeaver, VLC, Spotify, Bitwarden, etc. |

## Quick Start

```bash
git clone https://github.com/fvarli/devforge.git
cd devforge
cp config.env.example config.env
sudo ./install.sh --all
```

## Doctor Command

Verify your installation health:

```bash
./install.sh --doctor
```

Output includes:
- Component status: `[OK]`, `[WARN]`, `[FAIL]`, `[SKIP]`
- Health Score percentage
- Summary of total checks, passed, warnings, and failures

## Requirements

- Ubuntu LTS (22.04, 24.04) or Ubuntu-based distribution
- Root privileges (sudo) for installation
- Internet connection

## Configuration

Copy `config.env.example` to `config.env` and customize:
- Enable/disable specific modules and components
- Configure PHP version (8.2, 8.3, 8.4)
- Configure Node.js version (lts, latest, or specific)
- Toggle individual applications

## What's New

### Features
- Full modular architecture with 9 installation modules
- Doctor command for installation verification
- Health Score metric in doctor summary
- Comprehensive CI pipeline with syntax, ShellCheck, and unit tests
- Interactive and CLI installation modes
- Installation metrics and summary report

### Technical
- Strict bash mode (`set -Eeuo pipefail`)
- Safe temp file handling with devforge prefix
- Boolean configuration validation
- Support for Ubuntu derivatives (Kubuntu, Pop!_OS, Linux Mint)
- Idempotent package installation with skip detection

## Documentation

See [README.md](README.md) for full documentation including:
- Detailed module descriptions
- Configuration reference
- Troubleshooting guide
- Development instructions

## License

MIT License - see LICENSE file for details.
