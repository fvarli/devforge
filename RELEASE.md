# DevForge Release Process

Release workflow documentation for DevForge.

## Version Numbering

DevForge follows [Semantic Versioning](https://semver.org/):

```
MAJOR.MINOR.PATCH
```

- **MAJOR** - Breaking changes
- **MINOR** - New features, backward compatible
- **PATCH** - Bug fixes, backward compatible

Current version is defined in `lib/cli.sh`:

```bash
DEVFORGE_VERSION="0.9.0"
```

## Release Workflow

### 1. Pre-Release Verification

All automated and manual checks must pass before release.

#### Automated Checks (CI)

The CI pipeline runs 5 jobs on every push:

| Job | Command | Purpose |
|-----|---------|---------|
| syntax-check | `bash -n *.sh` | Bash syntax validation |
| shellcheck | `shellcheck -x *.sh` | Static analysis |
| unit-tests | `bash tests/*.sh` | Test suites |
| doctor-validation | `./install.sh --doctor` | Doctor runs without error |
| file-structure | Check required files | Structure validation |

Verify CI status:
```bash
# Run locally before push
bash -n install.sh lib/*.sh modules/*.sh doctor/*.sh tests/*.sh scripts/*.sh
shellcheck -x install.sh lib/*.sh modules/*.sh doctor/*.sh tests/*.sh scripts/*.sh
bash tests/test_helpers.sh
bash tests/test_doctor.sh
bash tests/test_report_script.sh
```

#### Manual VM Testing

Test on fresh VMs before release. See [docs/VM_TESTING.md](docs/VM_TESTING.md) for detailed procedures.

Required test environments:
- Ubuntu 24.04 LTS (primary target)
- Ubuntu 22.04 LTS (compatibility)
- Kubuntu 24.04 LTS (KDE variant)

Test scenarios:
1. Fresh installation (`--all`)
2. Idempotency run (second `--all`)
3. Module reinstall after removal
4. Post-reboot verification

### 2. Update Version

Update version in `lib/cli.sh`:

```bash
DEVFORGE_VERSION="1.0.0"
```

### 3. Update Changelog

Update `CHANGELOG.md` with:
- Version number
- Release date
- All changes since last version

Format:
```markdown
## [1.0.0] - 2024-01-15

### Added
- New feature X

### Changed
- Updated Y

### Fixed
- Bug Z
```

### 4. Final Commit

```bash
git add lib/cli.sh CHANGELOG.md
git commit -m "chore: release v1.0.0"
```

### 5. Create Tag

```bash
git tag -a v1.0.0 -m "Release v1.0.0"
```

### 6. Push Release

```bash
git push origin main
git push origin v1.0.0
```

### 7. Post-Release Verification

- Verify CI passes on tagged commit
- Test installation from fresh clone
- Verify GitHub release (if using releases)

## Pre-Release Checklist

Full checklist in [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md).

Summary:

| Category | Items |
|----------|-------|
| Syntax | `bash -n` on all scripts |
| ShellCheck | No errors on all scripts |
| Tests | All test suites pass |
| Doctor | Runs without crash |
| VM Testing | Fresh Ubuntu, Kubuntu |
| Documentation | README, CHANGELOG updated |
| Version | lib/cli.sh updated |

## CI Pipeline Details

GitHub Actions workflow in `.github/workflows/ci.yml`:

```yaml
jobs:
  syntax-check:
    # bash -n validation

  shellcheck:
    # shellcheck -x validation

  unit-tests:
    # Run all test suites

  doctor-validation:
    # Run doctor command

  file-structure:
    # Verify required files exist
```

## Generating Doctor Reports

For release validation, generate diagnostic reports:

```bash
# Default timestamped report
./scripts/generate-doctor-report.sh

# Custom output path
./scripts/generate-doctor-report.sh reports/release-validation.txt
```

Reports include:
- System metadata (hostname, distro, kernel)
- DevForge version and git info
- All doctor check results
- Exit code

## Rollback Procedure

If issues found after release:

1. **Revert commit** (if not tagged):
   ```bash
   git revert HEAD
   git push origin main
   ```

2. **Delete tag** (if tagged):
   ```bash
   git tag -d v1.0.0
   git push origin :refs/tags/v1.0.0
   ```

3. **Fix issue and re-release**

## Version History

See [CHANGELOG.md](CHANGELOG.md) for complete version history.

## Related Documentation

- [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) - Detailed pre-release checklist
- [docs/VM_TESTING.md](docs/VM_TESTING.md) - VM testing procedures
- [docs/VM_TEST_RESULT_TEMPLATE.md](docs/VM_TEST_RESULT_TEMPLATE.md) - Test result documentation
- [CONTRIBUTING.md](CONTRIBUTING.md) - Development guidelines
