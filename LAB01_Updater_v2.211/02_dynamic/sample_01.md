# sample_01 -- dynamic triage

| Field | Value |
|--------|--------|
| **SHA256** | `ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7` |
| **Date analyzed** | 2026-05-06 |
| **VM type** | Windows 11 lab VM (user `win11`) |
| **AV / real-time protection** | Off (visible in `IMG_6042` -- Windows Security background) |
| **Snapshot name** | Not recorded for this pass |
| **Instrumentation** | Phone screenshots only -- **no Procmon / ProcExp / TCPView capture** |

Cross-references: [findings](../03_findings/sample_01.md) | [static](../01_static/sample_01.md) | [acquisition](../00_original/sample_01.md) | [screenshots](../50_screenshots/)

---

## Execution observed -- `IMG_6042`

**Evidence:** `50_screenshots/IMG_6042.png` (from `IMG_6042.HEIC`).

Background: **Windows Security -> Virus & threat protection** with **real-time protection** messaging indicating it is **off** (common in lab VMs; also what some malware expects).

Overlaid dialogs (user-facing behavior after run):

| Dialog | Title | Message / notes |
|--------|-------|------------------|
| Left | **Error** | **`Critical systeam error 0x00305353321`** -- typo **"systeam"** instead of **"system"** (common fake/scam trope). |
| Right | **`HGWJY`** | Gibberish body, e.g. **`jimnb uq0ukc1m ulo0ov lui0kilpa cqch an`** -- **OK** / **Cancel**. |

**Interpretation:** Not a normal Windows fault string pattern; aligns with **nuisance / fake error malware or installer stage** distractions. Combine with NSIS branding in **`01_static`**: installer -> ran -> **immediate suspicious UI**.

### Branch

- ~~A (tools-only)~~ **`IMG_6042` confirms Branch B:** sample **was executed** enough to surface these windows.

---

## Pre-flight -- for your next disciplined run

_If you repeat for a textbook capture:_

- [ ] Clean **snapshot** baseline.
- [ ] **Procmon** capture from boot or pre-run.
- [ ] **Process Explorer** / **TCPView**.
- [ ] Execute once -> export **filtered** log -> PNGs -> **revert snapshot**.

**(This notebook pass)** used phone evidence only -- **Procmon/registry/filesystem/network tables below are not populated** until filled from a tooling run or VM notes.

---

## Execution (best current knowledge)

- **How launched:** User ran the on-disk `.exe` from the VM download folder (exact double-click vs context menu not recorded on photo).
- **On-disk name in VM:** `ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7.exe` under `C:\Users\win11\Downloads\ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7\` (same SHA256 as Bazaar; claimed Bazaar name `Updater_v2.211.exe`).
- **User context:** Standard user assumed (elevated run not documented).
- **Immediate visible behavior:** Two overlapping error-style dialogs (see table above); no legitimate updater progress UI captured.

## Process tree (Process Explorer)

| Parent | Child | Command line / notes |
|--------|--------|---------------------|
| _Not captured_ | _Not captured_ | No Process Explorer log for this pass -- only post-run UI in `IMG_6042`. |

## File system (Procmon WriteFile / CreateFile events)

| Path | Operation | Notes |
|------|-----------|-------|
| _Not captured_ | _Not captured_ | No Procmon export -- typical NSIS installers often write under `%TEMP%`; not confirmed here. |

## Registry (Procmon RegSetValue events)

| Key | Value name | Data / notes |
|-----|------------|--------------|
| _Not captured_ | _Not captured_ | No Procmon export -- persistence not confirmed. |

## Network (TCPView / Wireshark)

| Proto | Remote host | Port | Notes |
|-------|-------------|------|-------|
| _Not captured_ | _Not captured_ | _Not captured_ | No network capture for this pass. Delivery URLs from Bazaar are in **`00_original`** / **`40_iocs/indicators.csv`** (not observed live in this session). |

## Post-run observations

- Deceptive error UI only -- no documented child tools, services, or scheduled tasks from instrumentation.
- Static triage (**`01_static`**) shows a large **NSIS** installer package; executed behavior matches **non-legitimate UX** rather than a normal updater.
- **Optional redo:** Snapshot clean, run **Procmon** + **Process Explorer** + **TCPView**, then revert after export.

## Dynamic summary (portfolio-ready)

After execution, Windows displayed **two fake-looking error dialogs** (misspelled "critical system" string and randomized title/body). Static triage shows the binary is predominantly an **NSIS installer** package; executed behavior aligns with **deceptive UI** rather than a normal updater. **Process, file, registry, and network tables were not instrumented** in this pass -- only screenshot evidence.

## Screenshots

| File | Role |
|------|------|
| `IMG_6042.heic` / `IMG_6042.png` | Post-execution deceptive dialogs |

