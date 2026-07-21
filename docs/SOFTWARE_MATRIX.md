# DevForge Software Matrix

Complete package manifest by module.

## Module Overview

| Module | Package Count | Default Enabled | Description |
|--------|---------------|-----------------|-------------|
| system | 22 | Yes | Core system utilities |
| terminal | 7 | No | Modern shell tools |
| git | 3 | No | Version control |
| php | 19+ extensions | No | PHP development |
| node | 6 | No | Node.js development |
| docker | 3 | No | Container runtime |
| databases | 4 | No | Database servers |
| browsers | 2 | No | Web browsers |
| apps | 7 | No | Desktop applications |

---

## system Module

Core build tools and utilities. **Always recommended.**

| Package | Source | Purpose |
|---------|--------|---------|
| ca-certificates | APT | SSL/TLS certificates |
| curl | APT | HTTP client |
| wget | APT | File download |
| unzip | APT | ZIP extraction |
| zip | APT | ZIP compression |
| p7zip-full | APT | 7z archive support |
| software-properties-common | APT | PPA management |
| apt-transport-https | APT | HTTPS APT transport |
| tree | APT | Directory tree |
| jq | APT | JSON processor |
| ripgrep | APT | Fast search (rg) |
| fd-find | APT | Fast find (fd) |
| rsync | APT | File synchronization |
| htop | APT | Process monitor |
| btop | APT | Resource monitor |
| fastfetch | APT | System info |
| ncdu | APT | Disk usage analyzer |
| dnsutils | APT | DNS tools (dig, nslookup) |
| net-tools | APT | Network tools (ifconfig) |
| traceroute | APT | Network path tracing |
| openssh-client | APT | SSH client |
| openssh-server | APT | SSH server |
| ufw | APT | Firewall |

---

## terminal Module

Modern terminal environment with zsh-focused tooling.

| Tool | Source | Purpose |
|------|--------|---------|
| zsh | APT | Z shell |
| tmux | APT | Terminal multiplexer |
| fzf | APT | Fuzzy finder |
| bat | APT | Syntax-highlighted cat (batcat) |
| eza | eza APT repo | Modern ls replacement |
| zoxide | APT/installer | Smart cd (z) |
| starship | Official installer | Cross-shell prompt |

Auto-configured in `.zshrc`:
- Starship prompt initialization
- Zoxide shell integration

---

## git Module

Version control and GitHub integration.

| Tool | Source | Purpose |
|------|--------|---------|
| git | APT | Version control |
| git-lfs | APT | Large file storage |
| gh | GitHub APT repo | GitHub CLI |

Also sets up:
- SSH directory (`~/.ssh`) with 700 permissions
- Minimal `.gitconfig` template

---

## php Module

PHP development environment (Laravel/Symfony ready).

### Core Packages

| Package | Purpose |
|---------|---------|
| php${VERSION} | PHP runtime |
| php${VERSION}-cli | Command-line interface |
| php${VERSION}-common | Common files |
| php${VERSION}-dev | Development headers |
| php${VERSION}-fpm | FastCGI Process Manager |

### Extensions

| Extension | Purpose |
|-----------|---------|
| mysql | MySQL/MariaDB driver |
| pgsql | PostgreSQL driver |
| sqlite3 | SQLite driver |
| curl | HTTP client |
| gd | Image processing |
| intl | Internationalization |
| mbstring | Multibyte strings |
| xml | XML processing |
| zip | ZIP archives |
| bcmath | Arbitrary precision |
| soap | SOAP client/server |
| readline | CLI line editing |
| opcache | Bytecode cache |
| php-pear | PECL installer |

### Tools

| Tool | Source | Purpose |
|------|--------|---------|
| Composer | Official installer | Dependency manager |
| Laravel Installer | Composer global | Laravel scaffolding |
| Symfony CLI | Official installer | Symfony tooling |
| imagick | PECL (optional) | ImageMagick integration |

**Supported PHP versions:** 8.2, 8.3, 8.4 (via ondrej/php PPA)

**Note:** PHP 8.0 and 8.1 are EOL and not supported.

---

## node Module

Node.js development environment.

| Tool | Source | Purpose |
|------|--------|---------|
| nvm | GitHub installer | Node version manager |
| node | via nvm | JavaScript runtime |
| npm | bundled with node | Package manager |
| pnpm | npm (via Corepack) | Fast package manager |
| yarn | npm (via Corepack) | Package manager |
| bun | Official installer | Fast JS runtime/bundler |

All tools installed for target user (not root).

---

## docker Module

Container runtime. **Requires amd64 architecture.**

| Package | Source | Purpose |
|---------|--------|---------|
| docker-ce | Docker APT repo | Container engine |
| docker-compose-plugin | Docker APT repo | Compose v2 |
| docker-buildx-plugin | Docker APT repo | BuildKit |

Also installs: docker-ce-cli, containerd.io

**Note:** Requires logout/login for group membership.

---

## databases Module

Database servers.

| Server | Source | Default Port |
|--------|--------|--------------|
| MySQL | APT | 3306 |
| PostgreSQL | APT | 5432 |
| Redis | APT | 6379 |
| SQLite | APT | N/A (file-based) |

Services enabled by default. Security hardening is manual:

```bash
# MySQL
sudo mysql_secure_installation

# PostgreSQL
sudo -u postgres createuser --interactive

# Redis
# Edit /etc/redis/redis.conf: requirepass <password>
```

---

## browsers Module

Web browsers. **Requires amd64 architecture for Chrome.**

| Browser | Source |
|---------|--------|
| Google Chrome | Google APT repo |
| Brave Browser | Brave APT repo |

---

## apps Module

Desktop applications.

| Application | Source | Purpose |
|-------------|--------|---------|
| VS Code | Microsoft APT repo | Code editor |
| DBeaver CE | Snap/Flatpak | Database GUI |
| VLC | APT | Media player |
| Spotify | Flatpak | Music streaming |
| Bitwarden | Flatpak | Password manager |
| FileZilla | APT | FTP client |
| KeePassXC | APT | Password manager (offline) |

---

## Version Configuration

Configurable in `config.env`:

```bash
# PHP version (8.2, 8.3, or 8.4)
PHP_VERSION=8.4

# Node.js version (lts, latest, or specific like 20)
NODE_VERSION=lts
```

---

## Architecture Notes

- **amd64 required:** Docker, Chrome, GitHub CLI
- **ARM support:** Most APT packages work on ARM, but external installers may vary
- **Tested on:** Ubuntu 22.04 LTS, Ubuntu 24.04 LTS, Kubuntu
