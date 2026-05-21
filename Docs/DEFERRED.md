# Deferred decisions (intentional)

Items reviewed in REM-1 / plan tier **“5. Still defer”** and either **closed** (implemented elsewhere) or **permanently out of scope** for this logbook repo.

---

## Closed in REM-8 (implemented)

| Item | Resolution |
|------|------------|
| **PyInstaller bump** | Pin stays **`6.20.0`** (PyPI latest as of 2026-05-20). `smoke_gui.ps1` warns when PyPI drifts; use `-StrictPin` to fail CI. |
| **PR smoke / import on CI** | `30_scripts/smoke_gui.ps1` + `integrity.yml` job **GUI smoke test** (`--smoke-test`, no mainloop). |
| **Code-signing** | Optional **`build_exe.ps1 -SignThumbprint`** / env `WORKFLOW_GUI_SIGN_THUMBPRINT` (signtool when cert available). Documented in [`RELEASE-VERIFICATION.md`](../RELEASE-VERIFICATION.md). |

---

## Permanently deferred (by design)

| Item | Why not |
|------|---------|
| **Bundle `30_scripts/*.ps1` inside the `.exe`** | Release binary is a **thin shell** over a full repo clone (`--repo`). Bundling PS1 would duplicate logic, stale scripts inside the exe, and larger attack surface. Users run the same pinned scripts from the checkout. |
| **Mandatory `04_writeups` in `validate.ps1`** | `03_findings` is the contract per slot; `04` is optional portfolio depth. Check **19** only warns when `04` exists and `engagement_kind` mismatches — never blocks empty `04`. |

---

## Still optional / maintainer-only

| Item | Notes |
|------|--------|
| **GitHub Release `v3.1.1`** | Run `tag_release.ps1` when ready to publish binary. |
| **Authenticode cert** | Signing only runs when thumbprint/env is set; no cert is stored in this repo. |
