# DevForge Quick Start Guide

Get your development environment running in 5 minutes.

## Prerequisites

- Ubuntu 22.04 LTS or Ubuntu 24.04 LTS (or Ubuntu-based distro)
- sudo access
- Internet connection

## Installation

### Clone the Repository

```bash
git clone https://github.com/fvarli/devforge.git
cd devforge
```

### Create Configuration

```bash
cp config.env.example config.env
```

Edit `config.env` to customize your installation (optional).

### Install

Choose one of these options:

#### Full Stack (Recommended for new machines)

```bash
sudo ./install.sh --all
```

Installs everything: system utilities, terminal tools, Git, PHP, Node.js, Docker, databases, browsers, and desktop apps.

#### Web Development Stack

```bash
sudo ./install.sh --system --terminal --git --php --node --docker
```

Core tools for Laravel/Symfony/React development.

#### Minimal Setup

```bash
sudo ./install.sh --system --terminal --git
```

Just the essentials: system utilities, modern shell tools, and Git.

#### Interactive Mode

```bash
sudo ./install.sh --interactive
```

Choose modules one by one.

## Post-Installation

### Verify Installation

```bash
./install.sh --doctor
```

This runs diagnostic checks on all installed components.

### Configure Git Identity

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Start Docker (if installed)

```bash
sudo systemctl enable --now docker
```

Log out and back in for Docker group membership to take effect.

### Start Database Services (if installed)

```bash
# MySQL
sudo systemctl start mysql

# PostgreSQL
sudo systemctl start postgresql

# Redis
sudo systemctl start redis
```

## Common Tasks

### Node.js Version Management

```bash
# List available versions
nvm ls-remote --lts

# Install a version
nvm install 20

# Switch versions
nvm use 20

# Set default
nvm alias default 20
```

### PHP Version Switching

```bash
# See available versions
sudo update-alternatives --list php

# Switch default PHP version
sudo update-alternatives --config php
```

### Create a Laravel Project

```bash
laravel new myapp
cd myapp
php artisan serve
```

### Create a Symfony Project

```bash
symfony new myapp --webapp
cd myapp
symfony serve
```

## Troubleshooting

### NVM Not Found

Source NVM in your current shell:

```bash
source ~/.nvm/nvm.sh
```

Or restart your terminal.

### Docker Permission Denied

Log out and back in, or run:

```bash
newgrp docker
```

### Module Failed

1. Run doctor to diagnose: `./install.sh --doctor`
2. Re-run the specific module: `sudo ./install.sh --<module>`
3. Check system logs: `journalctl -xe`

## Next Steps

- [Software Matrix](SOFTWARE_MATRIX.md) - Complete list of installed packages
- [Doctor Reporting](DOCTOR_REPORTING.md) - Understanding diagnostic output
- [VM Testing Guide](VM_TESTING.md) - Release validation procedures
