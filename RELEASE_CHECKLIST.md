# Release Checklist

Pre-release verification checklist for DevForge.

## Automated Checks

### Syntax Validation

- [ ] `bash -n install.sh`
- [ ] `bash -n lib/*.sh`
- [ ] `bash -n modules/*.sh`
- [ ] `bash -n doctor/*.sh`
- [ ] `bash -n tests/*.sh`

### Unit Tests

- [ ] `bash tests/test_helpers.sh` - All tests pass
- [ ] `bash tests/test_doctor.sh` - All tests pass

### ShellCheck

- [ ] `shellcheck install.sh` - No errors
- [ ] `shellcheck lib/*.sh` - No errors
- [ ] `shellcheck modules/*.sh` - No errors
- [ ] `shellcheck doctor/*.sh` - No errors

### Doctor Command

- [ ] `./install.sh --doctor` runs without crashing
- [ ] Doctor output contains all sections (System, Terminal, Git, PHP, Node, Docker, Databases, Browsers, Apps, Summary)
- [ ] Doctor exit code is 0 when no failures, 1 when failures exist

## Manual Testing

### Clean Ubuntu VM

- [ ] Fresh Ubuntu 24.04 LTS VM
- [ ] Clone repository
- [ ] Copy config.env.example to config.env
- [ ] Run `sudo ./install.sh --all`
- [ ] Verify all modules complete successfully
- [ ] Run `./install.sh --doctor` - all checks pass
- [ ] Verify key tools work:
  - [ ] `zsh --version`
  - [ ] `php --version`
  - [ ] `node --version`
  - [ ] `docker --version`
  - [ ] `mysql --version`
  - [ ] `psql --version`

### Clean Kubuntu VM

- [ ] Fresh Kubuntu 24.04 LTS VM
- [ ] Clone repository
- [ ] Copy config.env.example to config.env
- [ ] Run `sudo ./install.sh --all`
- [ ] Verify all modules complete successfully
- [ ] Run `./install.sh --doctor` - all checks pass

### Idempotency Run

- [ ] Run `sudo ./install.sh --all` a second time on same VM
- [ ] Verify no errors
- [ ] Verify metrics show packages as "skipped" not "installed"
- [ ] Verify total time is significantly less than first run

### Reinstall Run

- [ ] Uninstall a package (e.g., `sudo apt remove zsh`)
- [ ] Run `sudo ./install.sh --terminal`
- [ ] Verify package is reinstalled
- [ ] Run `./install.sh --doctor` - terminal checks pass

### Module Selection

- [ ] `sudo ./install.sh --system` - Only system module runs
- [ ] `sudo ./install.sh --php --node` - Only PHP and Node modules run
- [ ] `sudo ./install.sh` (no args) - Interactive mode works
- [ ] `sudo ./install.sh --all` - All modules run

### Configuration

- [ ] Boolean validation works (`INSTALL_DOCKER_ENGINE=yes` fails)
- [ ] PHP version validation works (8.1 rejected as EOL)
- [ ] Node version validation works (invalid format rejected)

## Documentation

- [ ] README.md is up to date
- [ ] All modules documented
- [ ] config.env.example has all options
- [ ] Troubleshooting section covers common issues
- [ ] Doctor command documented

## Changelog

- [ ] CHANGELOG.md updated with all changes
- [ ] Version number updated in lib/cli.sh
- [ ] Release date set in CHANGELOG.md

## Final Verification

- [ ] CI pipeline passes on main branch
- [ ] No uncommitted changes
- [ ] Git tag created: `git tag -a v1.0.0 -m "Release v1.0.0"`
- [ ] Tag pushed: `git push origin v1.0.0`

## Post-Release

- [ ] Verify GitHub release created
- [ ] Test installation from fresh clone
- [ ] Announce release (if applicable)
