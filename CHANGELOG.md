# Changelog

All notable changes to DevForge will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - YYYY-MM-DD

### Added

- **Doctor Command**: Comprehensive diagnostic tool (`--doctor`) to verify installation status
  - Modular architecture with checks for all 9 modules
  - Color-coded output: [OK], [WARN], [FAIL], [SKIP]
  - Exit code 0 when no failures, 1 when failures exist
  - No root privileges required
- **GitHub Actions CI Pipeline**: Automated testing on push and pull requests
  - Syntax validation for all shell scripts
  - ShellCheck linting with caching
  - Unit test execution
  - Doctor command validation
  - File structure verification
- **Browsers Module**: Google Chrome and Brave browser installation
- **Desktop Applications Module**: VS Code, DBeaver, VLC, Spotify, Bitwarden, FileZilla, KeePassXC
- **Installation Metrics**: Track installed vs skipped packages with timing
- **Summary Report**: Post-installation overview of modules, operations, and timing
- **Release Checklist**: Comprehensive pre-release verification guide
- **Interactive Mode**: Module selection when running without arguments
- **Boolean Configuration Validation**: Strict true/false enforcement

### Changed

- **Architecture**: Refactored doctor command into modular `doctor/` directory
  - `doctor/system.sh` - OS, architecture, disk, DNS checks
  - `doctor/terminal.sh` - Shell and terminal tool checks
  - `doctor/git.sh` - Git and GitHub CLI checks
  - `doctor/php.sh` - PHP, Composer, framework checks
  - `doctor/node.sh` - NVM, Node.js, package manager checks
  - `doctor/docker.sh` - Docker engine and plugin checks
  - `doctor/databases.sh` - Database server and client checks
  - `doctor/browsers.sh` - Browser installation checks
  - `doctor/apps.sh` - Desktop application checks
  - `doctor/summary.sh` - Summary output and exit status
- **README**: Comprehensive documentation with all modules, configuration, troubleshooting
- **CI Pipeline**: Enhanced with multiple validation jobs and caching
- **Docker Verification**: Strict checks for all components and services
- **Database Verification**: Client-aware checks respecting configuration
- **Node.js Version Detection**: Improved idempotency using NVM resolution
- **Composer Path**: Uses resolved global bin path instead of hardcoded value
- **PHP Extensions**: Single invocation with stored output for efficiency
- **Symfony CLI**: Deterministic binary location checks

### Fixed

- Ubuntu codename resolution for derivative distributions
- Shell configuration failures now properly propagate errors
- PHP extension verification return value handling
- Metrics safety under strict mode
- Module failure handling under strict mode
- User configuration preservation

### Security

- Composer installation with SHA384 verification
- SSH directory created with 700 permissions
- No eval usage in user-facing code paths
- Quoted variables throughout shell scripts

## [0.2.0] - 2024-12-XX

### Added

- PHP module with Laravel and Symfony toolchain support
- Node.js module with NVM, pnpm, Yarn, Bun support
- Docker module with Compose and Buildx plugins
- Databases module with MySQL, PostgreSQL, Redis, SQLite
- Centralized infrastructure helpers
- Test utilities for unit testing

### Changed

- Refactored metrics integration
- Simplified module error handling

### Fixed

- Strict mode compatibility across all modules
- Expected exit flow preservation

## [0.1.0] - 2024-12-XX

### Added

- Initial DevForge foundation
- System utilities module (curl, wget, htop, etc.)
- Terminal module (zsh, tmux, fzf, starship)
- Git module (git, git-lfs, gh)
- CLI with argument parsing
- Configuration via config.env
- Modular architecture with lib/ and modules/ directories
- MIT License

[Unreleased]: https://github.com/fvarli/devforge/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/fvarli/devforge/compare/v0.2.0...v1.0.0
[0.2.0]: https://github.com/fvarli/devforge/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/fvarli/devforge/releases/tag/v0.1.0
