# VM Test Result

## Environment

| Field | Value |
|-------|-------|
| Distribution | |
| Version | |
| Desktop Environment | |
| Architecture | |
| VM Provider | |
| Date | |
| DevForge Commit | |

## First Installation

| Metric | Value |
|--------|-------|
| Exit Code | |
| Duration | |
| Failed Modules | |
| Warnings | |

## Doctor Results

| Metric | Before Reboot | After Reboot |
|--------|---------------|--------------|
| Total Checks | | |
| Passed | | |
| Warnings | | |
| Failed | | |
| Health Score | | |

## Second Installation (Idempotency)

| Metric | Value |
|--------|-------|
| Exit Code | |
| Packages Installed | |
| Packages Skipped | |
| Duplicate Repos | |
| Duplicate Shell Lines | |

## Post-Reboot Verification

| Check | Result |
|-------|--------|
| Docker group active | PASS / FAIL |
| Docker without sudo | PASS / FAIL |
| NVM loads | PASS / FAIL |
| Node works | PASS / FAIL |
| npm works | PASS / FAIL |
| Composer works | PASS / FAIL |
| Laravel installer works | PASS / FAIL |
| Symfony CLI works | PASS / FAIL |
| MySQL service active | PASS / FAIL |
| PostgreSQL service active | PASS / FAIL |
| Redis service active | PASS / FAIL |

## Issues Found

<!-- List any issues discovered during testing -->

## Evidence

```
# DevForge version
./install.sh --version

# System info
lsb_release -a

# Doctor output
./install.sh --doctor
```

## Final Result

**PASS** / **FAIL**

## Notes

<!-- Additional observations -->
