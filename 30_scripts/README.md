# 30_scripts

PowerShell lifecycle and hygiene scripts for the labs malware triage logbook.
All scripts require PowerShell 5.1+ and run from anywhere (they resolve the repo root automatically).

**Workflow GUI (cross-platform):** [`workflow_gui.py`](./workflow_gui.py) -- paste-once autofill for all phase Markdown files. **Usage, Windows/Linux steps, and disclaimers:** [`WORKFLOW-GUI.md`](./WORKFLOW-GUI.md).

---

## Quick reference

| Script | Purpose | When to run |
|--------|---------|-------------|
| `workflow_gui.py` | GUI: autofill phase files from pasted metadata | Optional; alternative or complement to `new_sample.ps1` |
| `new_sample.ps1` | Scaffold a new sample slot | Before starting a new sample |
| `close_sample.ps1` | Advance slot status, print close checklist | After each analysis phase |
| `validate.ps1` | Structural integrity check | Before any commit |
| `export-summary.ps1` | Regenerate `INDEX.md` + `dist/summary.json` | After closing a sample or editing frontmatter |
| `redact-check.ps1` | Scan for PII / non-VM paths in .md files | Before any commit |
| `strip-exif.ps1` | Strip EXIF metadata from screenshot images | Before committing new screenshots |

---

## new_sample.ps1

Creates a full sample slot with richer templates across all four phase folders,
a `50_screenshots/sample_XX/` folder with a hygiene checklist, and a tracker CSV row.

```powershell
# Create slot for sample_07
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 7

# With a custom analyst name
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 7 -Analyst Surrplexie
```

**Files created:**
- `00_original/sample_07.md` -- acquisition receipt, hash fields, Bazaar metadata
- `01_static/sample_07.md` -- DIE / PEStudio / CFF Explorer / HxD sections
- `02_dynamic/sample_07.md` -- Procmon, process tree, file system, registry, network tables
- `03_findings/sample_07.md` -- YAML frontmatter stub + verdict, IOC table, portfolio blurb
- `50_screenshots/sample_07/SHOT_INDEX.txt` -- screenshot map + evidence hygiene checklist
- `samples_tracker.csv` -- new row appended with status `queued`

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

Runs 10 structural checks against the repo and `samples_tracker.csv`. Exits 0 if
all checks pass (WARNs allowed) or 1 if any FAIL.

```powershell
# Standard run
powershell -ExecutionPolicy Bypass -File .\30_scripts\validate.ps1

# Strict mode: WARNs also treated as failures (for CI)
powershell -ExecutionPolicy Bypass -File .\30_scripts\validate.ps1 -FailOnWarn
```

**Checks:**
1. `samples_tracker.csv` schema (required columns)
2. All four phase `.md` files exist for non-empty slots
3. SHA256 populated for non-empty slots
4. Phase files have substantive content (>15 lines)
5. `03_findings/sample_XX.md` has YAML frontmatter
6. SHA256 in tracker matches SHA256 in frontmatter
7. `40_iocs/indicators.csv` schema and sample_id cross-reference
8. Orphan phase `.md` files with no tracker row
9. Forbidden extension scan (`.exe`, `.dll`, `.pcap`, `.iso`, etc.)
10. `50_screenshots/sample_XX/` folder exists for non-empty slots

---

## export-summary.ps1

Parses YAML frontmatter from all `03_findings/sample_XX.md` files, merges with
`samples_tracker.csv` and IOC counts, and writes two outputs:

- `INDEX.md` (repo root) -- committed, human-readable sample index table
- `dist/summary.json` -- gitignored machine-readable dump

```powershell
# Full export
powershell -ExecutionPolicy Bypass -File .\30_scripts\export-summary.ps1

# Skip the JSON (only regenerate INDEX.md)
powershell -ExecutionPolicy Bypass -File .\30_scripts\export-summary.ps1 -SkipJson
```

Run this any time you update frontmatter or finish a sample to keep `INDEX.md` current.

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

## Recommended commit workflow

```powershell
# 1. Create and analyze a sample
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 7

# ... (fill in phase files, take screenshots, run static/dynamic analysis) ...

# 2. Strip EXIF from screenshots
powershell -ExecutionPolicy Bypass -File .\30_scripts\strip-exif.ps1 -SampleId sample_07 -SkipBackup

# 3. Redaction check
powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1 -SampleId sample_07

# 4. Close the sample and regenerate index
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_07 -Status done -RunValidate -RunExport

# 5. Commit
git add -A
git commit -m "add sample_07: <one-line description>"
```
