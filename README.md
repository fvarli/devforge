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
```

Install multiple modules:

```bash
sudo ./install.sh --system --terminal --git
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
