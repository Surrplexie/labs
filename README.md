# labs

> **Personal malware triage logbook — public for professional seekers and learners.**
> No releases, versioned packages, or scheduled updates are guaranteed or will ever be provided.
> **One exception:** the [`workflow_gui`](./30_scripts/workflow_gui.py) compiled binary
> (`.exe` / Linux) may be released via GitHub Releases as the sole distributable artifact
> from this repository. It contains no samples, no credentials, and no analysis data.

---

## Disclaimer

**Read this before using, citing, or distributing anything from this repository.**

This repository is maintained solely for **personal use** and is made public as a professional reference for security researchers, learners, and portfolio reviewers. It is not a product, a service, or an actively maintained project.

- **No executable samples are stored here, ever.** All content exists exclusively as Markdown (`.md`), CSV, and image files. No binaries, compiled artifacts, weaponized scripts, shellcode, or live malware of any kind are committed or will be committed to this repository.
- **All content is provided for educational and research purposes only.** Nothing here constitutes professional security advice, legal guidance, or operational instruction of any kind.
- **Scope of coverage is broad by design.** Content may reference or document anything within the security research domain, including but not limited to: existing CVEs and vulnerability disclosures, malware file reconnaissance (static and dynamic), threat intelligence indicators, reverse engineering workflows, OSINT methodology, forensic analysis notes, and tooling references. Content may include analysis of existing malware families, CVE documentation, deceptive UI artifacts, anti-analysis techniques, and more.
- **This repository is governed by the [MIT License](./LICENSE).** "MIT" here is interpreted in the context of personal, non-commercial reference use. Redistribution must retain original attribution. No claim of ownership is made over any third-party tool names, vendor data, CVE identifiers, or public intelligence referenced within.
- **No warranties of any kind** — expressed or implied — are made regarding the accuracy, completeness, currency, or fitness for any purpose of any content in this repository.
- **No releases, updates, patches, or continued maintenance are guaranteed or promised.** This logbook may go months without a commit. Absence of updates does not imply abandonment.
- **The author assumes no liability** for any use or misuse of the information contained within, including but not limited to harm resulting from acting on documented techniques, tool references, or indicator data.
- Any tooling references, script fragments, or command examples are illustrative only. Validate everything in your own controlled, isolated environment before applying it anywhere.

---

## Purpose

This is a **personal skills and professional reference** logbook documenting static and dynamic malware triage workflows, threat intelligence indicators, and security research tooling notes. Structured to support:

- Portfolio review by professional contacts, recruiters, and peers
- Personal knowledge retention and skill development across the malware analysis discipline
- A consistent, version-controlled record of analytical work over time

It is **not** intended for production deployment, operational use, or redistribution as a training dataset.

---

## Who This Is For

| Audience | How to use this repo |
|---|---|
| **Recruiters / hiring managers** | See [`INDEX.md`](./INDEX.md) for the at-a-glance sample table; read `03_findings/sample_XX.md` public-safe blurbs for portfolio entries |
| **Security learners** | Use the workflow structure below as a triage template; reference `20_notes/tooling-reference.md` for tool guidance |
| **Researchers** | Reference `40_iocs/indicators.csv` and cross-reference with public threat intel; see `20_notes/case-series/` for pattern analysis |
| **General public** | Read-only; nothing here is executable or deployable |

---

## Quick Navigation

| I want to... | Go to |
|---|---|
| See all samples at a glance | [`INDEX.md`](./INDEX.md) |
| Find samples by tag or MITRE technique | [`INDEX.md`](./INDEX.md) sections "By Tag" / "By MITRE" |
| Read a specific sample's findings | `03_findings/sample_XX.md` |
| See which ATT&CK techniques are covered | [`20_notes/MITRE-coverage.md`](./20_notes/MITRE-coverage.md) |
| Understand NSIS-packaged malware patterns | [`20_notes/case-series/NSIS-installers.md`](./20_notes/case-series/NSIS-installers.md) |
| Learn what each tool signal means | [`20_notes/tooling-reference.md`](./20_notes/tooling-reference.md) |
| Use or understand the automation scripts | [`30_scripts/README.md`](./30_scripts/README.md) |
| Access raw IOC data | [`40_iocs/indicators.csv`](./40_iocs/indicators.csv) |
| Walk through the full workflow step by step | [`WORKFLOW.md`](./WORKFLOW.md) |
| Use the GUI to fill phase files automatically | [`30_scripts/workflow_gui.py`](./30_scripts/workflow_gui.py) |
| Step-by-step GUI usage (Windows and Linux) and disclaimers | [`30_scripts/WORKFLOW-GUI.md`](./30_scripts/WORKFLOW-GUI.md) |
| Understand the full workflow (summary) | [Complete Workflow Guide](#complete-workflow-guide) below |

---

## Repository Structure

```
labs/
|
|-- README.md                    <- You are here
|-- INDEX.md                     <- Auto-generated sample index (run export-summary.ps1)
|-- LICENSE                      <- MIT License
|-- .gitignore                   <- Blocks executables, archives, secrets, OS noise
|-- samples_tracker.csv          <- One row per slot: sha256, url, name, status
|
|-- 00_original/                 <- Acquisition receipts (MalwareBazaar metadata, hashes)
|   |-- README.md                <- Folder guide
|   |-- sample_01.md             <- Sample-specific acquisition log
|   `-- sample_02.md ... 06.md   <- Reserve slots (empty)
|
|-- 01_static/                   <- Static triage notes (DIE, PEStudio, CFF, HxD)
|   |-- sample_01.md             <- Completed static analysis
|   `-- sample_02.md ... 06.md   <- Reserve slots (empty templates)
|
|-- 02_dynamic/                  <- Dynamic triage notes (Procmon, ProcExp, network)
|   |-- sample_01.md             <- Partial dynamic (screenshot evidence)
|   `-- sample_02.md ... 06.md   <- Reserve slots (empty templates)
|
|-- 03_findings/                 <- Verdicts, IOC tables, portfolio blurbs
|   |-- sample_01.md             <- Completed findings with YAML frontmatter
|   `-- sample_02.md ... 06.md   <- Reserve slots (YAML stub + empty sections)
|
|-- 10_extracted/                <- Non-executable artifacts (string dumps, NSIS scripts)
|   `-- README.md
|
|-- 20_notes/                    <- Research synthesis, tooling reference, case series
|   |-- README.md
|   |-- MITRE-coverage.md        <- ATT&CK technique coverage tracker
|   |-- tooling-reference.md     <- Tool quick-reference and signal interpretation
|   `-- case-series/
|       |-- README.md
|       `-- NSIS-installers.md   <- Cross-sample pattern note: NSIS delivery
|
|-- 30_scripts/                  <- PowerShell lifecycle and hygiene automation
|   |-- README.md                <- Script documentation and usage examples
|   |-- new_sample.ps1           <- Scaffold a new sample slot
|   |-- close_sample.ps1         <- Advance status, print close checklist
|   |-- validate.ps1             <- 10-point structural integrity check
|   |-- export-summary.ps1       <- Regenerate INDEX.md + dist/summary.json
|   |-- redact-check.ps1         <- Scan for PII / non-VM paths before committing
|   `-- strip-exif.ps1           <- Strip EXIF metadata from screenshots
|
|-- 40_iocs/                     <- Consolidated IOC CSV
|   |-- README.md                <- Schema documentation
|   `-- indicators.csv           <- All IOCs from all samples, flat table
|
`-- 50_screenshots/              <- Screenshot evidence, keyed by sample ID
    |-- sample_01/               <- Completed: IMG_6038-6042.png + SHOT_INDEX.txt
    |-- sample_02/ ... 06/       <- Reserve: .gitkeep + SHOT_INDEX.txt (empty)
    `-- (each folder has SHOT_INDEX.txt with hygiene checklist)
```

**Naming convention:** `sample_01` through `sample_99` (zero-padded) — the same ID runs across every phase folder for consistent cross-referencing.

---

## What Is (and Is Not) Here

| What IS here | What is NOT here |
|---|---|
| `.md` analysis notes per sample | Executable binaries (`.exe`, `.dll`, `.scr`, etc.) |
| Hash references, acquisition checklists | Live or weaponized scripts |
| IOC tables (CSV) | VM disk images or snapshots |
| Screenshots (`.png` / `.jpeg`) | Any file that can execute on a host machine |
| Workflow and tooling documentation | Compiled code or packages |
| CVE reference notes and vulnerability documentation | Proof-of-concept exploit code |
| MITRE ATT&CK technique mapping notes | PII, credentials, or session data of any kind |
| OSINT and threat intelligence methodology notes | Internal infrastructure details |
| Case series cross-sample pattern notes | Host machine usernames or internal paths |

---

## Automation and Tooling

This repo uses a set of PowerShell scripts to maintain consistency and catch errors before commit.
All scripts require **PowerShell 5.1+** and resolve the repo root automatically.

See [`30_scripts/README.md`](./30_scripts/README.md) for full documentation and examples.

### Script overview

| Script | One-line purpose |
|--------|-----------------|
| `workflow_gui.py` | Cross-platform GUI — paste all sample values once, every template section is auto-filled |
| `new_sample.ps1` | Create a new sample slot with all phase files, screenshot folder, and tracker row |
| `close_sample.ps1` | Advance a slot's lifecycle status and print a phase-specific close checklist |
| `validate.ps1` | Run 10 structural integrity checks; exits 1 if any FAIL |
| `export-summary.ps1` | Parse YAML frontmatter, regenerate `INDEX.md` and `dist/summary.json` |
| `redact-check.ps1` | Scan all `.md`/`.csv`/`.txt` files for non-VM paths, emails, internal hostnames |
| `strip-exif.ps1` | Strip EXIF metadata from all images in `50_screenshots/` |
| `build_exe.ps1` | Compile `workflow_gui.py` to a standalone `.exe` using PyInstaller |
| `build_linux.sh` | Compile `workflow_gui.py` to a standalone Linux binary using PyInstaller |

### What validate.ps1 checks

Running `validate.ps1` before every commit gives you confidence that:

1. `samples_tracker.csv` has all required columns
2. All four phase `.md` files exist for every non-empty slot
3. Every non-empty slot has a SHA256 on record
4. Phase files have substantive content (not just headings)
5. `03_findings/` files have YAML frontmatter
6. SHA256 in tracker matches SHA256 in frontmatter
7. `40_iocs/indicators.csv` schema is valid and all sample IDs are known
8. No orphan `.md` files exist without a tracker row
9. No forbidden file extensions exist anywhere in the working tree
10. A `50_screenshots/sample_XX/` folder exists for every non-empty slot

---

## Workflow GUI

### What it is

`30_scripts/workflow_gui.py` is a cross-platform graphical assistant that replaces
manual copy-paste across the four phase files. Instead of opening each `.md` and filling
placeholders by hand, you paste all values into one form and click **Create Sample** —
all four phase files and the screenshot folder are written in one shot with every field
pre-filled from what you provided.

> **Release policy exception:**
> This repository has no releases and will never have versioned packages — with
> **one single exception**: the compiled `workflow_gui` binary (`.exe` on Windows,
> native binary on Linux) may be published via GitHub Releases as the sole distributable
> artifact ever produced by this repo. It contains zero analysis data, zero credentials,
> and zero sample content. If a release exists under Releases, it is `workflow_gui` and
> nothing else.

### Running directly (requires Python 3.10+)

```powershell
python 30_scripts\workflow_gui.py
python 30_scripts\workflow_gui.py --repo "C:\path\to\labs"
```

```bash
python3 30_scripts/workflow_gui.py
python3 30_scripts/workflow_gui.py --repo /path/to/labs
```

### Compiling to a standalone executable

**Windows** — produces `dist\workflow_gui.exe` (~30–50 MB, no Python required):

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\build_exe.ps1
```

**Linux** — produces `dist/workflow_gui` (~25–45 MB, no Python required):

```bash
bash ./30_scripts/build_linux.sh
```

Both build scripts install/upgrade PyInstaller automatically via pip, then call
PyInstaller with `--onefile --windowed`. Build artifacts land in `dist/` which is
excluded from the repo by `.gitignore`.

### What the GUI does

| Tab | What you can do |
|-----|----------------|
| **New Sample** | Fill one form — SHA256, hashes, filename, MIME, dates, verdict, confidence, tags, MITRE IDs, YARA rows — and click Create to write all 4 phase `.md` files + `SHOT_INDEX.txt` in one action |
| **Update Sample** | Select an existing sample, change its lifecycle status and frontmatter values (verdict, confidence, tags, MITRE), write back to tracker and findings file |
| **Tools** | One-click buttons to run `validate.ps1`, `export-summary.ps1`, `redact-check.ps1`, and `strip-exif.ps1` with live output |
| **Settings** | Set the repo root path and default analyst name; saved to a local config file |

The GUI requires no external Python packages — only the standard library `tkinter`
(included with Python on Windows; install `python3-tk` on Debian/Ubuntu or
`python3-tkinter` on Fedora for the native script).

**Full usage walkthrough (Windows and Linux), field-by-field examples, and extended
legal-style disclaimers** (no malware shipped; use at your own risk; hash verification
for any pre-built binary): see [`30_scripts/WORKFLOW-GUI.md`](./30_scripts/WORKFLOW-GUI.md).

---

## Complete Workflow Guide

This section walks through the entire lifecycle of a sample from zero to committed.
Follow it for **any sample type** — PE binary, Office document, script, archive, or other.

### Before you start — environment checklist

- [ ] **Isolated VM** with a clean snapshot (Windows 10/11 recommended)
- [ ] **VM-only internet access** during sample download and execution
- [ ] **Static tools on VM:** DIE (Detect It Easy), PEStudio, CFF Explorer VIII, HxD
- [ ] **Dynamic tools on VM:** Procmon, Process Explorer, TCPView (Sysinternals Suite)
- [ ] **Optional on VM:** Wireshark, x64dbg, Ghidra, FLOSS
- [ ] **Host machine:** this repo checked out, PowerShell 5.1+, no analysis tools
- [ ] **exiftool installed** on host for EXIF stripping (optional but recommended):
      `winget install OliverBetz.ExifTool`

---

### Step 1 — Scaffold the slot

Pick the next available number and create all files in one command:

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 7
```

This creates:
- `00_original/sample_07.md` — acquisition receipt template
- `01_static/sample_07.md` — static triage template (DIE/PEStudio/CFF/HxD)
- `02_dynamic/sample_07.md` — dynamic triage template (Procmon/ProcExp/network)
- `03_findings/sample_07.md` — findings template with YAML frontmatter stub
- `50_screenshots/sample_07/SHOT_INDEX.txt` — screenshot map + hygiene checklist
- Row in `samples_tracker.csv` with status `queued`

---

### Step 2 — Research and pre-acquire (host machine)

Before touching the VM, fill `00_original/sample_07.md` from MalwareBazaar:

1. Open the MalwareBazaar sample page
2. Copy SHA256, SHA1, MD5, imphash, ssdeep, TLSH, dhash
3. Record file name, MIME type, size, first seen, delivery tags
4. Copy any referenced URLs (hosting pages, zip links, VT links)
5. Record YARA rule names flagged on the page
6. Paste the MalwareBazaar URL into the frontmatter `mb_url:` field of `03_findings/sample_07.md`

**Do not download anything yet.** The receipt is filled from public web data only.

---

### Step 3 — Acquire inside VM

Switch to your isolated VM:

1. Verify the VM snapshot is clean
2. Download the sample from MalwareBazaar using the SHA256 hash (API or web UI)
3. Verify the hash on disk: `Get-FileHash <path> -Algorithm SHA256`
4. Confirm the hash matches the MalwareBazaar value exactly
5. Record the VM download path in `00_original/sample_07.md` acquisition checklist
6. Tick off the checklist items

**Never copy any binary to the host machine.**

---

### Step 4 — Static analysis (VM, no execution)

Run all static tools in this order. Document each in `01_static/sample_07.md`.

**DIE (Detect It Easy)**
- Compiler, linker, installer type (NSIS, Inno, etc.), packer heuristic
- Overlay offset and size; compression algorithm
- Record entropy value and any heuristic flags

**PEStudio**
- Confirm SHA256 matches
- Record global entropy, version resource (FileDescription, ProductName), manifest name
- Note import count, any flagged imports (suspicious API calls)
- Record overlay signature, VT detection count

**CFF Explorer**
- File size vs. PE image size (large gap = overlay/installer archive)
- Version info fields (FileVersion, LegalCopyright, ProductName)
- NTFS timestamps (note: VM local time, easily forged)
- Note any discrepancy between CFF hash fields and full-file Bazaar hashes (expected for overlay-heavy files — document the reason)

**HxD**
- Confirm `MZ` signature at offset 0x0
- Locate `PE\0\0` header
- Read section names from ASCII column (`.text`, `.ndata`, `.UPX0`, etc.)
- Note any readable strings in data sections (URLs, paths, error messages)

**Take screenshots** of each tool's key view. Save as PNG under `50_screenshots/sample_07/` and update `SHOT_INDEX.txt`.

**Advance status:**
```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_07 -Status static
```

---

### Step 5 — Optional: Dynamic analysis (VM, controlled execution)

Only do this in an isolated, snapshot-backed VM. If the VM is a one-time-use sandbox, skip the snapshot step.

**Pre-flight:**
1. Take a clean snapshot (if not already done)
2. Start Procmon — filter by the sample's process name
3. Open Process Explorer and TCPView
4. (Optional) Start Wireshark capture

**Execution:**
1. Run the sample once
2. Observe: dialogs, child processes, file system changes, network connections
3. Let it run for 30-120 seconds depending on behavior
4. Stop Procmon capture; export filtered log as CSV

**Post-run documentation:**
1. Fill `02_dynamic/sample_07.md`: process tree, file drops, registry changes, network
2. Append confirmed indicators to `40_iocs/indicators.csv`
3. Take screenshots of key observations
4. **Revert VM snapshot immediately**

**Advance status:**
```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_07 -Status dynamic
```

---

### Step 6 — Write findings

Fill `03_findings/sample_07.md` completely:

1. **Update YAML frontmatter** — fill all fields:
   - `sha256`, `date_acquired`, `date_analyzed`
   - `verdict` — one of: `benign`, `suspicious`, `malicious`, `unknown`
   - `family_guess` and `family_confidence`
   - `tags` — list of analytical tags (e.g., `nsis`, `fake-alert`, `dropper`)
   - `mitre_techniques` — list of observed/inferred ATT&CK technique IDs
   - `procmon_run` and `dynamic_complete` — `true` or `false`

2. **Write the analyst one-liner** — one sentence verdict summary

3. **Fill the verdict section** — classification and reasoning

4. **Complete the IOC table** — all unique indicators for this sample

5. **Write the public-safe blurb** — self-contained paragraph suitable for sharing publicly. No internal paths, usernames, VM details, or unreleased data.

---

### Step 7 — Update supporting files

1. **`40_iocs/indicators.csv`** — append all IOC rows for this sample
2. **`20_notes/MITRE-coverage.md`** — add any new technique mappings to the coverage table
3. **`20_notes/case-series/`** — if this sample matches an existing case series pattern, add a row; if it introduces a new pattern, create a new case series note

---

### Step 8 — Evidence hygiene (before committing screenshots)

```powershell
# Strip EXIF from all screenshots for this sample
powershell -ExecutionPolicy Bypass -File .\30_scripts\strip-exif.ps1 -SampleId sample_07 -SkipBackup

# Check for PII / non-VM paths in all committed files
powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1 -SampleId sample_07
```

Manually verify `50_screenshots/sample_07/SHOT_INDEX.txt` hygiene checklist and tick all boxes.

---

### Step 9 — Close, validate, export, commit

```powershell
# Close the sample as done, print final checklist, run validate, regenerate INDEX.md
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_07 -Status done -RunValidate -RunExport

# Review the output. If validate exits 0, commit.
git add -A
git commit -m "add sample_07: <one-line description>"
```

---

### Workflow at a glance

```
scaffold --> research (host) --> acquire (VM) --> static (VM) --> [dynamic (VM)] --> findings --> hygiene --> close+commit
new_sample.ps1   00_original/    SHA256 verify    01_static/      02_dynamic/      03_findings/  strip-exif  close_sample.ps1
                                                                                   MITRE-coverage redact-check validate.ps1
                                                                                   case-series/   SHOT_INDEX   export-summary
```

---

## Analysis Type Notes

Different sample types require slightly different emphasis. Here is what to adjust per type.

### PE binary (`.exe`, `.dll`, `.scr`)
Standard workflow above applies. Pay extra attention to:
- DIE compiler/linker/packer result
- PEStudio import table (suspicious API calls: `VirtualAlloc`, `WriteProcessMemory`, `CreateRemoteThread`)
- CFF file size vs. PE image size ratio
- Overlay content (NSIS, Inno, UPX, raw data)

### Office document (`.docm`, `.xlsm`, `.doc` with macros)
- Static: use `olevba` (oletools) to extract and read macro code
- Record macro function names, any `Shell`, `CreateObject`, `WScript`, `PowerShell` calls
- Dynamic: enable macros in a clean VM; watch for child process spawns (PowerShell, cmd.exe, wscript.exe) in Procmon
- MITRE candidates: T1566.001 (Phishing Attachment), T1059.001 (PowerShell), T1059.003 (Windows Command Shell)

### Script (`.ps1`, `.vbs`, `.hta`, `.js`, `.bat`)
- Static: open in a text editor and read the code; note obfuscation techniques
- Use `FLOSS` on any embedded PE, or decode Base64 strings manually or with CyberChef
- Dynamic: execute with full Procmon + network capture; scripts often have shorter dwell time than PE
- MITRE candidates: T1059 (Command and Scripting Interpreter), T1027 (Obfuscated Files), T1140 (Deobfuscate)

### Archive (`.zip`, `.rar`, `.7z`, `.iso`, `.img`)
- Static: list contents without extracting (`7-Zip > Open`); document the manifest
- Compute hashes for each inner file; check each on MalwareBazaar / VT
- Extract inner files in VM only; treat each extracted PE as a new sample
- Do not commit the archive or any extracted binary

### Any sample type — quick-start order
1. Hash it → MalwareBazaar search → fill `00_original/`
2. DIE → what is this? → PEStudio entropy → CFF size ratio → HxD sections
3. First verdict hypothesis → static summary → screenshot map
4. (If needed) Dynamic pass → process tree → drops → network
5. Fill `03_findings/` → IOCs to CSV → MITRE → case series

---

## Safety Rules

- **Host machine:** no `.exe`, `.dll`, `.scr`, or any sample-derived executables — documentation and images only.
- **VM only:** all download, extraction, and execution happens inside an isolated, snapshot-backed VM.
- **Always revert snapshot** immediately after any dynamic analysis run.
- **Redact before committing:** run `redact-check.ps1`; no VM usernames, internal paths, or analyst machine info in committed files.
- **Strip EXIF:** run `strip-exif.ps1` before committing screenshots (phone photos carry GPS and device metadata).
- **No HEIC:** convert phone screenshots to PNG before committing — GitHub does not render HEIC.
- **Validate before committing:** run `validate.ps1`; exit code 0 = safe to commit.

---

## Showing This Work

- Point reviewers to `INDEX.md` for the at-a-glance overview
- For a specific sample: four phase files (`00_original/`, `01_static/`, `02_dynamic/`, `03_findings/`) plus `50_screenshots/sample_XX/`
- The **public-safe blurb** in each `03_findings/sample_XX.md` is a self-contained, shareable portfolio entry
- `20_notes/MITRE-coverage.md` shows analytical breadth across techniques and tactics

---

## License

MIT © 2026 Surrplexie — see [LICENSE](./LICENSE).

Personal use. Redistribution must retain attribution. Provided as-is, with no warranty of any kind. This license does not grant rights to any third-party content, tools, or data referenced within this repository.
