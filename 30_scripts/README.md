# 30_scripts

PowerShell lifecycle and hygiene scripts for the labs malware triage logbook.
All scripts require PowerShell 5.1+ and run from anywhere (they resolve the repo root automatically).

**Workflow GUI (cross-platform):** [`workflow_gui.py`](./workflow_gui.py) -- paste-once autofill for all phase Markdown files. **Usage, Windows/Linux steps, and disclaimers:** [`WORKFLOW-GUI.md`](./WORKFLOW-GUI.md).

---

## Quick reference

| Script | Purpose | When to run |
|--------|---------|-------------|
| `workflow_gui.py` | GUI: autofill phase files from pasted metadata (all engagement kinds) | Optional; alternative to `new_engagement.ps1` |
| `new_engagement.ps1` | Scaffold any engagement slot (`file`, `ctf`, `lab`, `hunt`) | Before starting any engagement |
| `new_sample.ps1` | Backward-compatible alias for `new_engagement.ps1 -Kind file` | Legacy; prefer `new_engagement.ps1` |
| `ingest-procmon.ps1` | Parse Procmon CSV -> Markdown tables + IOC candidates in `02_dynamic` | After dynamic VM run (file kind) |
| `ingest-events.ps1` | Parse SIEM/Sysmon event export -> timeline + IOC candidates in `02_dynamic` | After hunt data collection |
| `install-hooks.ps1` | Install pre-push git hook (Windows) | Once, after cloning |
| `install-hooks.sh` | Install pre-push git hook (Linux) | Once, after cloning |
| `close_sample.ps1` | Advance slot status, print kind-specific close checklist | After each analysis phase |
| `validate.ps1` | Structural integrity check (13+ checks, kind-aware) | Before any commit |
| `export-summary.ps1` | Regenerate `INDEX.md` + `dist/summary.json` + `dist/portfolio.json` | After closing an engagement or editing frontmatter |
| `redact-check.ps1` | Scan for PII / non-VM paths in .md files | Before any commit |
| `strip-exif.ps1` | Strip EXIF metadata from screenshot images | Before committing new screenshots |

---

## new_engagement.ps1

Creates a full engagement slot across all four phase folders with **kind-specific templates**,
a `50_screenshots/sample_XX/` folder, and a tracker CSV row.

**`-Kind` parameter** selects the engagement type:

| Kind | 01_static template | 02_dynamic template | Use case |
|------|--------------------|---------------------|---------|
| `file` (default) | Static triage (DIE/PEStudio/CFF/HxD) | Procmon, process tree, network | Malware file analysis |
| `ctf` | Recon/enumeration log | Solve attempt / exploit log | HackTheBox, TryHackMe, CTF events |
| `lab` | Procedure / step log | Results / objectives completion | Courses, training labs |
| `hunt` | Data collection queries | Timeline / false-positive triage | Threat hunting exercises |

```powershell
# File analysis -- PE (default)
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 7

# File analysis -- Office macro
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 8 -Kind file -Type Office

# CTF challenge
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 9 -Kind ctf -Title "HTB -- Blunder"

# Training lab
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 10 -Kind lab -Title "TCM PEH Module 8"

# Threat hunt
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 11 -Kind hunt -Title "Hunt: LSASS Access"
```

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-NextNumber` | required | Slot number (1-99) |
| `-Kind` | `file` | `file`, `ctf`, `lab`, `hunt` |
| `-Type` | `PE` | For `file` kind: `PE`, `Office`, `Script`, `Archive` |
| `-Title` | auto | Short title (especially useful for ctf/lab/hunt) |
| `-Analyst` | `Surrplexie` | Analyst name in frontmatter |

**Files created:**
- `00_original/sample_XX.md` -- acquisition receipt or brief
- `01_static/sample_XX.md` -- kind-specific phase 2 template
- `02_dynamic/sample_XX.md` -- kind-specific phase 3 template
- `03_findings/sample_XX.md` -- YAML frontmatter with `engagement_kind` + seeded fields
- `50_screenshots/sample_XX/SHOT_INDEX.txt` -- screenshot map
- `samples_tracker.csv` -- new row with `engagement_kind`, `date_started`, status

---

## new_sample.ps1

Backward-compatible alias. Calls `new_engagement.ps1 -Kind file` with the same
parameters. Existing commands and docs using `new_sample.ps1` continue to work.
For all engagement types, prefer `new_engagement.ps1` directly.

Creates a full sample slot across all four phase folders with **type-specific templates**,
a `50_screenshots/sample_XX/` folder, and a tracker CSV row.

**`-Type` parameter** selects the template set:

| Type | Static template focuses on | Dynamic template focuses on |
|------|----------------------------|-----------------------------|
| `PE` (default) | DIE / PEStudio / CFF Explorer / HxD | Process tree, file/reg/net Procmon tables |
| `Office` | olevba / oledump / embedded objects | Word/Excel child processes, dropped files |
| `Script` | Deobfuscation steps, API calls, IOC strings | Script host children, console output |
| `Archive` | Archive manifest, inner file hashes, VT | Inner payload extraction and execution |

```powershell
# PE (default)
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 7

# Office macro document
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 8 -Type Office

# Script (PS1/VBS/HTA/JS/etc.)
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 9 -Type Script

# Archive / container (ZIP/ISO/RAR)
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 10 -Type Archive
```

**Files created:**
- `00_original/sample_XX.md` -- acquisition receipt (shared across all types)
- `01_static/sample_XX.md` -- type-specific static triage template
- `02_dynamic/sample_XX.md` -- type-specific dynamic triage template (includes Procmon ingest reminder)
- `03_findings/sample_XX.md` -- YAML frontmatter with `sample_type` field + seeded MITRE/tag hints
- `50_screenshots/sample_XX/SHOT_INDEX.txt` -- screenshot map + hygiene checklist
- `samples_tracker.csv` -- new row appended with status `queued`

---

## ingest-procmon.ps1

Reads a **Procmon CSV export** from your VM and writes structured Markdown tables and
IOC candidates into the sample's `02_dynamic` file and `40_iocs/indicators.csv`.

The raw Procmon CSV is **never committed** -- it stays on your VM or a scratch location.
Only the extracted, human-readable tables land in the repo.

**What it extracts:**
- Process tree (parent -> child Create events)
- File system events (writes/creates on user-space and interesting paths)
- Registry events (RegSetValue + persistence-adjacent keys, auto-flagged)
- Network events (TCP/UDP connections, remote host and port)
- IOC candidates (dropped file paths, persistence keys, remote hosts) as a review table

```powershell
# Basic: all processes in the CSV
powershell -ExecutionPolicy Bypass -File .\30_scripts\ingest-procmon.ps1 `
    -SampleId sample_07 `
    -ProcmonCsv "C:\Users\win11\Desktop\procmon_sample_07.csv"

# Filter to specific processes (recommended -- reduces noise)
powershell -ExecutionPolicy Bypass -File .\30_scripts\ingest-procmon.ps1 `
    -SampleId sample_07 `
    -ProcmonCsv "C:\Users\win11\Desktop\procmon_sample_07.csv" `
    -ProcessFilter "Updater_v2.211.exe,cmd.exe,powershell.exe"

# Dry run: preview output without writing anything
powershell -ExecutionPolicy Bypass -File .\30_scripts\ingest-procmon.ps1 `
    -SampleId sample_07 `
    -ProcmonCsv "C:\Users\win11\Desktop\procmon_sample_07.csv" `
    -DryRun

# Skip appending to indicators.csv (tables only)
powershell -ExecutionPolicy Bypass -File .\30_scripts\ingest-procmon.ps1 `
    -SampleId sample_07 `
    -ProcmonCsv "C:\Users\win11\Desktop\procmon_sample_07.csv" `
    -SkipIocAppend
```

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-SampleId` | required | e.g. `sample_07` or bare `7` |
| `-ProcmonCsv` | required | Full path to Procmon CSV export |
| `-ProcessFilter` | (all) | Comma-separated process names to filter to |
| `-MaxRows` | 40 | Max rows per Markdown table before truncation |
| `-DryRun` | off | Print output only, modify nothing |
| `-SkipIocAppend` | off | Skip appending candidates to indicators.csv |
| `-Root` | auto | Repo root path |

**After running:** Open `02_dynamic/sample_XX.md`, review appended tables, remove noise rows,
fill Notes columns, then run `close_sample.ps1 -Status dynamic`.

---

## ingest-events.ps1

Reads a **SIEM or Sysmon event CSV export** and writes structured Markdown tables and
IOC candidates into a hunt engagement's `02_dynamic` file and `40_iocs/indicators.csv`.

Designed for `hunt` kind engagements. Works with CSV exports from Splunk, Elastic, or
a direct Sysmon evtx-to-CSV conversion.

**What it extracts:**
- Process creation timeline (Sysmon Event 1 or equivalent)
- Network connection events (Sysmon Event 3)
- File create/write events (Sysmon Event 11)
- Registry events (Sysmon Event 12/13)
- Process access events (Sysmon Event 10 -- LSASS access)
- IOC candidates (suspicious hashes, IPs, file paths, process chains)

**Expected CSV columns (flexible -- auto-detected):**
`TimeGenerated`, `EventID`, `Computer`, `Image`, `CommandLine`, `ParentImage`,
`TargetImage`, `GrantedAccess`, `DestinationIp`, `DestinationPort`, `TargetFilename`

```powershell
# Basic: full CSV, hunt engagement sample_11
powershell -ExecutionPolicy Bypass -File .\30_scripts\ingest-events.ps1 `
    -SampleId sample_11 `
    -EventCsv "C:\analysis\sysmon_export.csv"

# Filter to specific hosts
powershell -ExecutionPolicy Bypass -File .\30_scripts\ingest-events.ps1 `
    -SampleId sample_11 `
    -EventCsv "C:\analysis\sysmon_export.csv" `
    -HostFilter "WRK-04,WRK-07"

# Filter by EventID (comma-separated)
powershell -ExecutionPolicy Bypass -File .\30_scripts\ingest-events.ps1 `
    -SampleId sample_11 `
    -EventCsv "C:\analysis\sysmon_export.csv" `
    -EventIdFilter "1,3,10,11"

# Dry run: preview output without writing
powershell -ExecutionPolicy Bypass -File .\30_scripts\ingest-events.ps1 `
    -SampleId sample_11 `
    -EventCsv "C:\analysis\sysmon_export.csv" `
    -DryRun
```

**Parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-SampleId` | required | e.g. `sample_11` or bare `11` |
| `-EventCsv` | required | Full path to SIEM/Sysmon CSV export |
| `-HostFilter` | (all) | Comma-separated hostnames to focus on |
| `-EventIdFilter` | (all) | Comma-separated Sysmon EventIDs to include |
| `-MaxRows` | 50 | Max rows per Markdown table before truncation |
| `-DryRun` | off | Print output only, modify nothing |
| `-SkipIocAppend` | off | Skip appending candidates to indicators.csv |
| `-Root` | auto | Repo root path |

**After running:** Review the appended tables in `02_dynamic/sample_XX.md`, remove noise,
annotate TP/FP in the "False positive triage" section, then run
`close_sample.ps1 -SampleId sample_11 -Status analyzing`.

---

## close_sample.ps1

Advances a sample's lifecycle status in `samples_tracker.csv` and prints a phase-specific
close checklist. Optionally runs `validate.ps1` and `export-summary.ps1` as part of the close.

**Status lifecycle:** `queued` -> `static` -> `dynamic` -> `done`

```powershell
# Mark sample_07 as static analysis complete
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_07 -Status static

# Mark as fully done
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_07 -Status done

# Done + run validate + regenerate INDEX.md
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_07 -Status done -RunValidate -RunExport

# Accepts bare number too
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId 7 -Status done
```

**What it does:**
- Updates `samples_tracker.csv` status field in place
- Prints a checklist of tasks required before the status is considered complete
- Optionally chains `validate.ps1` and `export-summary.ps1`

---

## validate.ps1

Runs 13+ structural checks against the repo and `samples_tracker.csv`. Kind-aware:
some checks (SHA256, IOC cross-reference) apply only to `file` kind engagements.
Exits 0 if all checks pass (WARNs allowed) or 1 if any FAIL.

```powershell
# Standard run
powershell -ExecutionPolicy Bypass -File .\30_scripts\validate.ps1

# Strict mode: WARNs also treated as failures (for CI)
powershell -ExecutionPolicy Bypass -File .\30_scripts\validate.ps1 -FailOnWarn
```

**Checks:**
1. `samples_tracker.csv` schema (required columns including `engagement_kind`)
2. All four phase `.md` files exist for non-empty slots
3. SHA256 populated for `file` kind non-empty slots (WARN for other kinds)
4. Phase files have substantive content (>15 lines)
5. `03_findings/sample_XX.md` has YAML frontmatter
6. SHA256 in tracker matches SHA256 in frontmatter (`file` kind only)
7. `40_iocs/indicators.csv` schema and sample_id cross-reference (`file` kind only)
8. Orphan phase `.md` files with no tracker row
9. Forbidden extension scan (`.exe`, `.dll`, `.pcap`, `.iso`, etc.)
10. `50_screenshots/sample_XX/` folder exists for non-empty slots
11. `schema_version` field present in all active findings files (accepts 1 or 2)
12. Secret / flag pattern scan (warns on raw CTF flags or credential-like patterns in .md files)
13. `engagement_kind` field present and non-blank for all active tracker rows

---

## export-summary.ps1

Parses YAML frontmatter from all `03_findings/sample_XX.md` files, merges with
`samples_tracker.csv` and IOC counts, and writes three outputs:

- `INDEX.md` (repo root) -- committed human-readable index with per-kind sections
- `dist/summary.json` -- gitignored machine-readable dump (schema_version: 2)
- `dist/portfolio.json` -- gitignored portfolio slice (only `public_writeup_safe: true` rows)

```powershell
# Full export
powershell -ExecutionPolicy Bypass -File .\30_scripts\export-summary.ps1

# Skip all JSON (only regenerate INDEX.md)
powershell -ExecutionPolicy Bypass -File .\30_scripts\export-summary.ps1 -SkipJson

# Skip portfolio.json only
powershell -ExecutionPolicy Bypass -File .\30_scripts\export-summary.ps1 -SkipPortfolio
```

**INDEX.md sections generated:**
- Summary table with per-kind counts (file, ctf, lab, hunt)
- All Engagements flat table (Kind, Platform, Outcome)
- File Analyses (with IOC count, MITRE techniques, verdict)
- CTF Write-ups (with Platform, Category, Difficulty, Solved)
- Labs (with Course, Module, Objectives Met)
- Threat Hunts (with Hypothesis summary, Detections Found)
- Cross-reference: By Skill (skills field, all kinds)
- Cross-reference: By Platform (ctf/lab kinds)
- Cross-reference: By MITRE Technique (file kind)
- Reserve Slots

Run this any time you update frontmatter or finish an engagement to keep `INDEX.md` current.

---

## redact-check.ps1

Scans all `.md`, `.csv`, and `.txt` files in the repo for patterns that should not
appear in a public repository before committing.

**Patterns checked:**

| Pattern | Severity | Notes |
|---------|---------|-------|
| `C:\Users\<non-VM-user>\` | FAIL | Any Windows path with a username not in the allowed VM list |
| Email addresses | WARN | May be false positives in IOC context -- review manually |
| Internal hostnames (`.local`, `.corp`, `.lan`, `.internal`) | WARN | May be legitimate IOCs |
| UNC paths (`\\hostname\share`) | WARN | May be legitimate IOCs |

```powershell
# Full repo scan
powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1

# One sample only
powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1 -SampleId sample_01

# Add extra safe VM username(s)
powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1 -AllowedVmUsers analyst,vm_user

# Also scan 40_iocs/ (skipped by default to reduce false positives)
powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1 -IncludeIocFiles
```

Exit codes: 0 = clean or WARN-only, 1 = one or more FAIL matches.

---

## strip-exif.ps1

Strips embedded metadata (EXIF, IPTC, XMP, GPS, author, device info) from PNG, JPEG,
and HEIC screenshot files before committing.

**Primary method:** `exiftool` (recommended -- handles all formats)

```powershell
# Install exiftool (choose one):
winget install OliverBetz.ExifTool
# OR: choco install exiftool
# OR: https://exiftool.org/install.html
```

**Fallback:** .NET `System.Drawing` (JPEG only -- PNG not supported without exiftool)

```powershell
# Strip all screenshots
powershell -ExecutionPolicy Bypass -File .\30_scripts\strip-exif.ps1

# Dry run (report only, no changes)
powershell -ExecutionPolicy Bypass -File .\30_scripts\strip-exif.ps1 -DryRun

# One sample's screenshots only
powershell -ExecutionPolicy Bypass -File .\30_scripts\strip-exif.ps1 -SampleId sample_01

# Skip exiftool backup files (*.jpg_original)
powershell -ExecutionPolicy Bypass -File .\30_scripts\strip-exif.ps1 -SkipBackup
```

**HEIC files:** Detected and flagged. Convert to PNG before committing:

```python
pip install pillow pillow-heif
python -c "from PIL import Image; import pillow_heif; pillow_heif.register_heif_opener(); img=Image.open('file.heic'); img.save('file.png')"
```

---

## install-hooks.ps1 / install-hooks.sh

Installs `.github/hooks/pre-push` into `.git/hooks/pre-push` so that `validate.ps1`
and `redact-check.ps1` run automatically before every `git push`.

**Run once after cloning:**

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File .\30_scripts\install-hooks.ps1

# Uninstall
powershell -ExecutionPolicy Bypass -File .\30_scripts\install-hooks.ps1 -Uninstall
```

```bash
# Linux
bash ./30_scripts/install-hooks.sh

# Uninstall
bash ./30_scripts/install-hooks.sh --uninstall
```

**Emergency bypass:** `git push --no-verify`

The hook source lives in `.github/hooks/pre-push` (POSIX shell) and detects both
`powershell` (Windows built-in) and `pwsh` (PowerShell Core on Linux) automatically.

---

## schema/

Versioned JSON Schema contracts for two machine-readable formats:

| File | Purpose |
|------|---------|
| `schema/frontmatter.schema.json` | Required fields, types, and patterns for `03_findings/sample_XX.md` YAML frontmatter |
| `schema/summary.schema.json` | Versioned envelope and record structure for `dist/summary.json` |
| `schema/CHANGELOG.md` | History of changes and migration guide |

**Current version: schema_version 2.**

- `file` kind findings use `schema_version: 1` or `2`.
- `ctf`, `lab`, `hunt` kind findings use `schema_version: 2`.
- `validate.ps1` check 11 enforces presence (accepts 1 or 2).
- `export-summary.ps1` wraps `dist/summary.json` in a `schema_version: 2` envelope.
- See `schema/CHANGELOG.md` for migration notes.

---

## Recommended commit workflow

```powershell
# 0. One-time hook install (run once after clone)
powershell -ExecutionPolicy Bypass -File .\30_scripts\install-hooks.ps1

# 1a. Create a file analysis slot
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 7 -Kind file

# 1b. Create a CTF slot
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 8 -Kind ctf -Title "HTB -- Blunder"

# 1c. Create a hunt slot
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 9 -Kind hunt -Title "Hunt: LSASS Access"

# ... fill in phase files, take screenshots, run analysis ...

# 2. Strip EXIF from screenshots (all kinds)
powershell -ExecutionPolicy Bypass -File .\30_scripts\strip-exif.ps1 -SampleId sample_07 -SkipBackup

# 3. Redaction check (all kinds)
powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1 -SampleId sample_07

# 4. Close the engagement and regenerate index
#    File:  -Status done
#    CTF:   -Status solved  (or writeup_done)
#    Lab:   -Status reviewed
#    Hunt:  -Status closed
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_07 -Status done -RunValidate -RunExport

# 5. Commit (pre-push hook runs validate + redact-check automatically on push)
git add -A
git commit -m "add sample_07: <one-line description>"
git push
```
