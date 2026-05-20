# RELEASE-TAGGING.md

When and how to publish a `workflow_gui` GitHub Release using semantic version tags (`vX.Y.Z`).

---

## When a tag is warranted

Push a new tag only when consumers should download a **new binary**. Typical triggers:

| Change | Tag? | Bump |
|--------|------|------|
| `workflow_gui.py` behavior, UI, or engagement-kind logic | **Yes** | major / minor / patch (see below) |
| Bug fix in the GUI only | **Yes** | patch |
| `build_exe.ps1`, `build_linux.sh`, `build_requirements.txt`, `release.yml` only | **Optional** | patch (rebuild same GUI; use `-AllowBuildOnly`) |
| Logbook samples, `03_findings`, notes, scripts other than GUI/build | **No** | — |

**Do not tag** for markdown-only logbook work. The release pipeline exists solely for `workflow_gui.exe`.

---

## Version alignment

- **Git tag:** `v3.0.1` (leading `v`, semver)
- **In-app version:** `APP_VERSION` in [`30_scripts/workflow_gui.py`](./30_scripts/workflow_gui.py) (e.g. `3.0.1`)

For a normal GUI release, **tag and `APP_VERSION` should match** (`v` + `APP_VERSION`).  
`tag_release.ps1` warns if they differ.

### Semver (workflow_gui)

| Bump | Example | When |
|------|---------|------|
| **major** | `3.0.1` → `4.0.0` | Breaking UX, removed flags, incompatible config |
| **minor** | `3.0.1` → `3.1.0` | New features (new tab, new kind fields, new tools) |
| **patch** | `3.0.1` → `3.0.2` | Fixes, copy tweaks, non-breaking polish |

Update `APP_VERSION` in `workflow_gui.py` **before** tagging.

---

## Pre-release checklist

1. **Commit** all changes on `main` (clean `git status`).
2. **Bump** `APP_VERSION` if this release includes GUI changes.
3. **Local build** (recommended):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\30_scripts\build_exe.ps1
   ```
   Confirm `dist\workflow_gui.exe` runs and `dist\SHA256SUMS.txt` looks correct.  
   See [`RELEASE-VERIFICATION.md`](./RELEASE-VERIFICATION.md).
4. **Preflight** (automated by `tag_release.ps1`):
   - `validate.ps1` — no FAIL
   - `redact-check.ps1` — review WARNs
   - Confirm `workflow_gui.py` (or build harness with `-AllowBuildOnly`) changed since last tag
5. **Tag and push** (triggers [`.github/workflows/release.yml`](./.github/workflows/release.yml)):
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\30_scripts\tag_release.ps1 -Tag v3.0.1 -Push
   ```
6. **Watch Actions** on GitHub — integrity → build → SBOM → publish.
7. **Verify** the Release assets: `workflow_gui.exe`, `SHA256SUMS.txt`, `sbom.cdx.json` per `RELEASE-VERIFICATION.md`.

---

## `tag_release.ps1` reference

```powershell
# Suggest tag from APP_VERSION + show diff since last v* tag
powershell -ExecutionPolicy Bypass -File .\30_scripts\tag_release.ps1 -Suggest

# Dry-run (no tag created)
powershell -ExecutionPolicy Bypass -File .\30_scripts\tag_release.ps1 -Tag v3.0.1 -DryRun

# Create annotated tag locally
powershell -ExecutionPolicy Bypass -File .\30_scripts\tag_release.ps1 -Tag v3.0.1

# Create tag and push (starts CI release)
powershell -ExecutionPolicy Bypass -File .\30_scripts\tag_release.ps1 -Tag v3.0.1 -Push

# Rebuild-only release (no workflow_gui.py diff since last tag)
powershell -ExecutionPolicy Bypass -File .\30_scripts\tag_release.ps1 -Tag v3.0.2 -AllowBuildOnly -Push
```

| Parameter | Purpose |
|-----------|---------|
| `-Tag` | Tag name (`v3.0.1` or `3.0.1`) |
| `-Suggest` | Print recommended tag and changed release paths; exit |
| `-DryRun` | Run checks only; do not create a tag |
| `-Push` | `git push origin <tag>` after tagging |
| `-SkipValidate` | Skip `validate.ps1` / `redact-check.ps1` (not recommended) |
| `-AllowBuildOnly` | Allow tag without `workflow_gui.py` changes since last tag |
| `-Force` | Tag even with a dirty working tree (not recommended) |

---

## What CI does after push

Tag pattern `v*` triggers:

1. Integrity gate (`validate.ps1`, `redact-check.ps1`)
2. Windows build (`build_exe.ps1 -SkipPipInstall`, pinned PyInstaller)
3. CycloneDX SBOM
4. GitHub Release with `.exe`, checksums, SBOM

If integrity fails, **no Release is published** — fix on `main`, bump patch tag, push again.

---

## Fixing a bad tag

- Tag pushed but CI failed: fix `main`, create a **new** patch tag (do not reuse the failed tag on a different commit without deleting the remote tag — avoid force-pushing tags unless you understand the impact).
- Never move a tag that already has a published Release consumers may have downloaded.

---

*See also: [README.md](./README.md) (Release hardening), [RELEASE-VERIFICATION.md](./RELEASE-VERIFICATION.md) (consumer verification).*
