# Workflow Guide

**Step-by-step workflows for every engagement kind in this logbook.**

**Identity:** [Track A (file)](#track-a-file-analysis) is the **primary** malware triage path (MalwareBazaar-style samples, VM static/dynamic, IOCs). Tracks B–D (CTF, lab, hunt) reuse the same folders and scripts with different phase meaning — see [`ENGAGEMENTS.md`](./ENGAGEMENTS.md).

Pick the track that matches your work, follow it top to bottom, and commit at the end. All tracks share the same slot system, tracker, validation, and export pipeline.

| Track | When to use |
|-------|------------|
| [Track A: File analysis](#track-a-file-analysis) | A malware sample, suspicious artifact, or binary from MalwareBazaar |
| [Track B: CTF](#track-b-ctf-challenge) | A HackTheBox/TryHackMe/CTF challenge |
| [Track C: Lab](#track-c-training-lab) | A guided course lab, module, or exercise |
| [Track D: Threat hunt](#track-d-threat-hunt) | A hypothesis-driven detection or log analysis exercise |

**Not sure which track?**
```
Has a single hash-identified artifact?   -> Track A (file)
Solving a CTF/HtB/THM challenge?         -> Track B (ctf)
Working through a course module?         -> Track C (lab)
Hunting in logs/SIEM with a hypothesis?  -> Track D (hunt)
```

All tracks use `new_engagement.ps1` to scaffold, `close_sample.ps1` to advance, and
`validate.ps1` + `export-summary.ps1` to finalize.

---

# Track A: File Analysis

**A complete, step-by-step walkthrough for taking a malware sample from zero to a committed analysis.**

---

## Table of Contents (Track A)

1. [Prerequisites — set up your environment once](#1-prerequisites--set-up-your-environment-once)
2. [Find and select a sample](#2-find-and-select-a-sample)
3. [Scaffold the slot](#3-scaffold-the-slot)
4. [Fill the acquisition receipt (host machine)](#4-fill-the-acquisition-receipt-host-machine)
5. [Acquire the sample (VM only)](#5-acquire-the-sample-vm-only)
6. [Static analysis — DIE](#6-static-analysis--die)
7. [Static analysis — PEStudio](#7-static-analysis--pestudio)
8. [Static analysis — CFF Explorer](#8-static-analysis--cff-explorer)
9. [Static analysis — HxD](#9-static-analysis--hxd)
10. [Screenshot discipline](#10-screenshot-discipline)
11. [Write the static summary](#11-write-the-static-summary)
12. [Advance to static status](#12-advance-to-static-status)
13. [Dynamic analysis — pre-flight](#13-dynamic-analysis--pre-flight)
14. [Dynamic analysis — execution and observation](#14-dynamic-analysis--execution-and-observation)
15. [Dynamic analysis — post-run documentation](#15-dynamic-analysis--post-run-documentation)
16. [Advance to dynamic status](#16-advance-to-dynamic-status)
17. [Write the findings file](#17-write-the-findings-file)
18. [Update the IOC CSV](#18-update-the-ioc-csv)
19. [Update MITRE coverage](#19-update-mitre-coverage)
20. [Evidence hygiene — EXIF and redaction](#20-evidence-hygiene--exif-and-redaction)
21. [Final close, validate, and commit](#21-final-close-validate-and-commit)
22. [Quick-reference decision tree](#22-quick-reference-decision-tree)

---

## 1. Prerequisites — set up your environment once

Do this once. Everything after this assumes this setup is in place.

### Host machine (your regular computer — where this repo lives)

- [ ] Git installed and repo cloned or pulled
- [ ] PowerShell 5.1 or later (`$PSVersionTable.PSVersion`)
- [ ] exiftool installed (strips EXIF metadata from screenshots before commit):
      ```powershell
      winget install OliverBetz.ExifTool
      ```
      Verify: `exiftool -ver` should print a version number.
- [ ] No analysis tools, no sample files, no VM images — the host is documentation-only

### Virtual machine (isolated analysis environment)

- [ ] Windows 10 or 11 VM (VMware Workstation, VirtualBox, or Hyper-V)
- [ ] **Clean snapshot taken** before any analysis — you will revert to this after every dynamic run
- [ ] VM **network isolated** or set to host-only during execution (prevents live C2 if the sample phones home)
- [ ] Static tools installed on VM:
      - [DIE (Detect It Easy)](https://github.com/horsicq/Detect-It-Easy) — packer/compiler/installer identification
      - [PEStudio](https://www.winitor.com/) — comprehensive PE static analysis
      - [CFF Explorer VIII](https://ntcore.com/?page_id=388) — detailed PE structure viewer
      - [HxD](https://mh-nexus.de/en/hxd/) — hex editor for raw byte inspection
- [ ] Dynamic tools installed on VM (Sysinternals Suite covers Procmon and Process Explorer):
      - [Sysinternals Suite](https://learn.microsoft.com/en-us/sysinternals/downloads/sysinternals-suite)
      - [Wireshark](https://www.wireshark.org/) — optional, for network capture
- [ ] VM is **not** where this repo lives — keep the repo on your host only

### Why the separation matters

The host machine is a clean logbook. No binaries ever touch it. The VM is a sacrificial
workspace that gets reverted after every dynamic run. If a sample escapes the VM (rare
but theoretically possible), it cannot reach your repo, your credentials, or your host
system.

---

## 2. Find and select a sample

### Where to find samples

**MalwareBazaar** (`bazaar.abuse.ch`) is the primary source for this logbook.
It provides verified hashes, community tags, YARA matches, and download via API or UI.

Other sources (use the same workflow): VirusTotal Intelligence, ANY.RUN public submissions,
URLhaus, PolySwarm, Malware Traffic Analysis (for PCAP-adjacent samples).

### What to look for as a beginner

Pick a sample that:
- Has a reasonable number of vendor detections (5–30 is a good range — not zero, not 66/66)
- Has informative tags on MalwareBazaar (e.g., `nsis`, `loader`, `stealer`, `rat`)
- Is a standard PE binary (`.exe`) for your first few — Office macros and scripts come later
- Is recent (last 30-90 days) — older samples may have less public intel available

### What to note before downloading anything

On the MalwareBazaar sample page, before you leave the host machine:

1. Copy the **SHA256** — this is your sample's permanent identity
2. Note the **file name** (claimed), **MIME type**, **size**, **first seen** date
3. Copy the **YARA rule names** flagged on the page
4. Copy any **URLs** listed (delivery links, hosting pages, VT links)
5. Copy **imphash**, **ssdeep**, **TLSH**, **dhash** if shown
6. Note the **MalwareBazaar page URL** itself — you will paste this into the frontmatter later

---

## 3. Scaffold the slot

On the **host machine**, in the repo root, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber <N>
```

Replace `<N>` with the next available number. Check `samples_tracker.csv` to see which
slots are empty if you are unsure. Example for slot 7:

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 7
```

### What this creates

```
00_original/sample_07.md        <- acquisition receipt (fill this next)
01_static/sample_07.md          <- static triage (fill during VM static pass)
02_dynamic/sample_07.md         <- dynamic triage (fill after execution)
03_findings/sample_07.md        <- verdict + IOCs + portfolio blurb (fill last)
50_screenshots/sample_07/
  SHOT_INDEX.txt                <- screenshot map + evidence hygiene checklist
samples_tracker.csv             <- new row: sample_07, status = queued
```

### Verify it worked

```powershell
# Should show all four .md files and the screenshot folder
Get-ChildItem .\00_original\sample_07.md, .\01_static\sample_07.md,
              .\02_dynamic\sample_07.md, .\03_findings\sample_07.md
Get-Item .\50_screenshots\sample_07\
```

---

## 4. Fill the acquisition receipt (host machine)

Open `00_original/sample_07.md`. This is everything you know about the sample
from public sources **before** you touch the VM.

Fill the top table from the MalwareBazaar page:

```markdown
| **MalwareBazaar URL** | https://bazaar.abuse.ch/sample/abc123.../ |
| **SHA256** | abc123...def456 |
| **SHA1** | ... |
| **MD5** | ... |
| **File name (claimed)** | Setup_v3.exe |
| **MIME / type** | application/x-dosexec · Executable exe |
| **Size** | 4,218,880 bytes (~4.0 MiB) |
| **First seen (Bazaar)** | 2026-05-10 14:00:00 UTC |
```

Then fill the delivery context, hash clustering, URLs, and YARA sections from the same page.

### What to write in the YARA section

List each rule name exactly as Bazaar shows it. Add a brief note about what it implies:

```markdown
| Detect_NSIS_Nullsoft_Installer | Obscurity Labs | NSIS installer structure -- may wrap legit or malicious payload |
| Sus_CMD_Powershell_Usage | XiAnzheng | CMD/PS fragments -- high FP rate in NSIS; corroborate with behavior |
```

### What NOT to write here

- Do not write anything from your VM analysis here — this section is pre-acquisition only
- Do not put your host machine's file paths in any field
- Do not put the VM download path here yet — that goes in the acquisition checklist after download

### Also: pre-fill the frontmatter in 03_findings

Open `03_findings/sample_07.md`. Even though you have not analyzed anything yet,
fill what you know right now:

```yaml
---
sample_id: sample_07
sha256: abc123...def456          # paste from Bazaar
mb_url: "https://bazaar.abuse.ch/sample/abc123...def456/"
date_acquired: "2026-05-10"      # today's date
analyst: YourName
---
```

Leave everything else as placeholder. You will fill it as analysis progresses.

---

## 5. Acquire the sample (VM only)

**Switch to your VM.**

### Before downloading

1. Verify your clean snapshot is in place (take one now if not)
2. Note: is real-time protection on or off? Document this in `02_dynamic/sample_07.md`
   under "AV / real-time protection status" — both are valid choices, just be consistent

### Download inside VM

Option A — MalwareBazaar web UI (easiest):
1. Log in to your MalwareBazaar account in the VM browser
2. Search for the SHA256
3. Download the sample (it comes as a password-protected zip; password is `infected`)
4. Extract to a known path — use the SHA256 as the folder name for clarity:
   `C:\Users\win11\Downloads\abc123...def456\`

Option B — MalwareBazaar API:
```powershell
$hash = "abc123...def456"
$url  = "https://mb-api.abuse.ch/api/v1/"
$body = "query=get_file&sha256_hash=$hash"
Invoke-RestMethod -Uri $url -Method Post -Body $body -OutFile "$hash.zip"
```

### Verify the hash on VM

```powershell
Get-FileHash "C:\Users\win11\Downloads\abc123...def456\abc123...def456.exe" -Algorithm SHA256
```

The output `Hash` value must match the MalwareBazaar SHA256 exactly.
If it does not match, do not proceed — re-download or check the extraction.

### Document the VM path (back on host)

Return to the host machine. In `00_original/sample_07.md`, tick the acquisition checklist:

```markdown
- [x] Download **inside VM only** (Bazaar login / API)
- [x] **SHA256 verified on VM** -- matches Bazaar value
- [x] VM path documented: `C:\Users\win11\Downloads\abc123...def456\`
- [x] **Never** copy `.exe` / binary to this host logbook PC
```

> The VM path is acceptable to document here — `win11` is the known VM username, not your host machine identity.

---

## 6. Static analysis — DIE

**Back in the VM. No execution yet.**

Open DIE. Drag the sample file onto DIE or use File > Open.

### What to read and record

**Top line — PE type:**
- `PE32` = 32-bit executable; `PE32+` = 64-bit
- `GUI` = graphical app (no console window); `Console` = CLI app

**Compiler tree node:**
- Records the toolchain: `Microsoft Visual C/C++`, `Borland Delphi`, `Go`, `Rust`, etc.
- Version number helps cluster similar builds across samples

**Installer tree node (if present):**
- `Nullsoft Scriptable Install System (NSIS)` = NSIS wrapper — very common in malware delivery
- `Inno Setup`, `WiX Toolset`, `InstallShield` — other common installers
- Record the version if shown (e.g., `NSIS 3.04`)

**Heuristic tree node:**
- `(Heur) Packer: Generic` = DIE suspects packing but cannot identify the specific packer
- This is a lead, not a verdict — always corroborate

**Overlay tree node:**
- Shows if there is appended data after the PE image
- Record: offset, size, and what DIE identifies it as (e.g., `NSIS data`, `unknown binary`)
- A large overlay is a strong indicator of an installer archive or appended payload

**Entropy value (if shown in Indicators/Heuristics):**
- < 6.5: likely uncompressed/unencrypted
- 6.5 – 7.5: partially compressed or mixed
- > 7.5: heavily compressed or encrypted (compressed overlays, UPX-packed sections, etc.)
- 8.0: theoretical maximum — consistently indicates compression or encryption

### Write to: `01_static/sample_07.md` under `## DIE`

```markdown
## DIE

- **PE type / arch:** PE32 · I386 · GUI · LE · ~4.0 MiB on disk
- **Linker / compiler:** Microsoft Linker 6.0 · Microsoft Visual C/C++ 13.10 [C]
- **Installer:** Nullsoft Scriptable Install System (NSIS) 3.04 -- zlib, solid compression
- **Heuristic:** (Heur) Packer: Generic -- notes .ndata section offset anomaly
- **Overlay:** Binary at offset 0xB600, size 0x40000000 -- identified as NSIS data
```

### Take a screenshot

Capture the main DIE window showing the tree with all nodes expanded.
Save as `IMG_0001.png` (or your naming convention) in `50_screenshots/sample_07/`.

---

## 7. Static analysis — PEStudio

Open PEStudio. File > Open, select the sample.

Allow PEStudio to complete its analysis (it may query VirusTotal in the background
— this is fine and expected).

### What to read and record

**Indicators pane (left sidebar, top):**
- SHA256 — confirm it matches your MalwareBazaar value
- File type, size in bytes
- Entropy (global) — record this number; > 7.5 is notable
- VirusTotal detection ratio (e.g., `5/66`) — note this is a cached/live lookup; take at face value

**Version resource (expand in left tree):**
- `FileDescription` and `ProductName` — often fake or misleading on malware
- `LegalCopyright` — fake copyright strings can help cluster similar samples
- `FileVersion` — note the version string; gibberish or mismatch is a signal

**Manifest (expand in left tree):**
- `Nullsoft.NSIS.exehead` — definitive NSIS stub signal
- `Microsoft.Windows.Common-Controls` — legitimate Windows manifest
- Custom or unusual manifest names are worth noting

**Libraries pane (expand in left tree):**
- Lists imported DLLs and API calls
- Low import count (5–10 libraries, <40 imports) on a large binary = minimal PE stub, payload elsewhere
- High import count on a small binary = feature-rich native code
- Flagged imports (red/orange in PEStudio): `VirtualAlloc`, `WriteProcessMemory`,
  `CreateRemoteThread`, `ShellExecute`, `URLDownloadToFile` — note each one

**Overlay (expand in left tree):**
- Signature: `unknown` = raw binary data PEStudio cannot identify
- Size: should match what DIE reported

### Common gotcha: VT score in PEStudio

The VT detection count in PEStudio may be stale (cached from a previous lookup).
Always visit the actual VT link (`https://www.virustotal.com/gui/file/<sha256>/detection`)
for current data. Record what PEStudio shows but note it as "at time of analysis."

### Write to: `01_static/sample_07.md` under `## PEStudio`

```markdown
## PEStudio

- **SHA256:** ABC123... (matches Bazaar)
- **Type:** 32-bit GUI executable
- **Size:** 4,218,880 bytes · **Entropy: 7.92**
- **FileDescription / ProductName:** `FakeUpdater` (version resource branding)
- **Manifest name:** `Nullsoft.NSIS.exehead` -- NSIS stub confirmed
- **Libraries / imports:** 6 libraries · 28 imports
- **Flagged imports:** `ShellExecuteA`, `URLDownloadToFile`
- **Overlay:** signature unknown · ~4.0 MB
- **VirusTotal (in UI):** 5/66 at time of analysis
- **Entry point:** 0x00003400 in .text
```

### Take a screenshot

Capture the main PEStudio view with the indicators pane expanded and any notable items visible.

---

## 8. Static analysis — CFF Explorer

Open CFF Explorer. File > Open, select the sample.

### What to read and record

**General Info (first tab):**
- `File type`: should say `Portable Executable 32` or `Portable Executable 64`
- `File Size`: the full on-disk size in bytes
- `PE Size` (or Image Size): the size of just the PE image/headers
- **Compare these two:** a large gap means most of the file is overlay/appended data
  - Example: File 72 MB, PE 46 KB → enormous gap → NSIS archive makes up the rest
- MD5 and SHA-1 fields: may show hashes of the PE image only, not the full file — see note below
- NTFS timestamps: Created, Modified, Accessed — these are **VM local time**, not UTC

**Version Info (expand in left tree):**
- All version resource fields in one view
- Cross-check `FileDescription` and `ProductName` with what PEStudio showed

**Important note on CFF hash fields:**

CFF Explorer may display MD5/SHA-1 computed over the PE mapped image only, not the full on-disk file. This is expected behavior on overlay-heavy samples (installers, UPX-packed files). If CFF shows `MD5: AAAAAA` but MalwareBazaar shows `MD5: BBBBBB`, this is not a sign the sample has been tampered with — it is a tool artifact. Always use `Get-FileHash` on the full binary for authoritative hashes. Document this in the `## Hash reconcile` section of `01_static/sample_07.md`.

### Write to: `01_static/sample_07.md` under `## CFF Explorer`

```markdown
## CFF Explorer

- **File type:** Portable Executable 32
- **File size:** 4,218,880 bytes (4.0 MB) · **PE image size:** 47,104 bytes (46 KB)
  -- ~4.0 MB gap = NSIS archive/overlay (matches DIE overlay report)
- **FileDescription / ProductName:** `FakeUpdater` (matches PEStudio)
- **FileVersion:** 2.0.1 · **LegalCopyright:** Copyright 2026 FakeUpdater
- **NTFS timestamps (VM local):** Created 2026-05-10 · Modified 2026-05-10
- **MD5/SHA-1 in UI:** differ from Bazaar -- expected (CFF shows PE-image-only hash
  on overlay-heavy samples; full-file hashes confirmed by Get-FileHash on VM)
```

### Take a screenshot

Capture the General Info tab with file size and PE size both visible.

---

## 9. Static analysis — HxD

Open HxD. File > Open, select the sample.

HxD opens the raw binary. You are looking at actual bytes. The left pane is hex,
the right pane is the ASCII representation.

### What to read and record

**Offset 0x00000000 — file signature (magic bytes):**
- `4D 5A` in hex = `MZ` in ASCII = Windows PE/MZ executable signature
- If you see `50 4B 03 04` = `PK..` = ZIP archive
- If you see `D0 CF 11 E0` = OLE2 compound document (Office files)
- If you see `25 50 44 46` = `%PDF` = PDF file

**Find the PE header:**
- Use Ctrl+G (go to offset) and enter the PE offset value from CFF Explorer's General Info
- Alternatively, Ctrl+F > Hex Values > search for `50 45 00 00` (`PE\0\0`)
- At the PE header, the section table starts — look at the ASCII column

**Section names in the ASCII column:**
- `.text` = code section
- `.rdata` = read-only data (imports, strings, constants)
- `.data` = initialized data (globals)
- `.ndata` = **NSIS-specific section** — definitive NSIS installer signal
- `.rsrc` = resources (icons, manifests, version info)
- `.UPX0`, `.UPX1` = UPX packing
- Random character sections = often custom packers

**Optional: look for readable strings:**
- Scroll through the data sections looking at the ASCII column
- URLs, paths, error messages, registry keys may be visible without any extraction tools
- If you see obvious strings, note them — they become IOC candidates

**Optional: look at the overlay start:**
- Navigate to the offset where the PE image ends (from CFF Explorer)
- Look at the first few bytes — NSIS overlays often start with `EF BE AD DE`

### Write to: `01_static/sample_07.md` under `## HxD`

```markdown
## HxD

- **Signature:** `MZ` (4D 5A) at 0x0 -- Windows PE confirmed
- **PE header:** `PE\0\0` at 0xD0
- **Section names (ASCII column):** .text · .rdata · .data · .ndata · .rsrc
  -- `.ndata` confirms NSIS installer structure
- **Overlay:** NSIS magic `EF BE AD DE` visible at offset 0xB800 (immediately after PE image)
```

### Take a screenshot

Capture HxD with the section names visible in the ASCII column.

---

## 10. Screenshot discipline

Screenshots are your only evidence trail from the VM. Treat them carefully.

### Capture

- Capture the tool's main window with the key finding visible
- One screenshot per tool per key observation is sufficient — avoid redundant captures
- If the tool has multiple relevant views, capture each one separately

### Check before saving

Look at every screenshot before saving:
- [ ] Is your VM username visible in a window title bar or path bar? (e.g., `C:\Users\win11\...`) — `win11` is acceptable, your host username is not
- [ ] Is any internal hostname, email, or personal info visible?
- [ ] Is any unrelated information visible that you would not want public?

### Name and index

Save as a simple numbered filename: `IMG_0001.png`, `IMG_0002.png`, etc.
(If you photographed from a phone, convert HEIC to PNG before committing.)

Open `50_screenshots/sample_07/SHOT_INDEX.txt` and add a row:

```
IMG_0001.png -- DIE 3.21 -- compiler tree: NSIS 3.04 zlib solid, overlay NSIS data
IMG_0002.png -- PEStudio 9.61 -- entropy 7.92, Nullsoft.NSIS.exehead manifest, flagged imports
IMG_0003.png -- CFF Explorer VIII -- file 4MB vs PE 46KB, FakeUpdater version string
IMG_0004.png -- HxD -- MZ/PE sections: .text .rdata .data .ndata .rsrc
```

### HEIC → PNG conversion (if you photographed with a phone)

```python
pip install pillow pillow-heif
python -c "
from PIL import Image
import pillow_heif
pillow_heif.register_heif_opener()
img = Image.open('IMG_0001.HEIC')
img.save('IMG_0001.png')
"
```

---

## 11. Write the static summary

Back in `01_static/sample_07.md`, fill the `## Static summary (portfolio-ready)` section.

This is one paragraph that synthesizes all four tools' findings into a coherent narrative.
Write it as if it might be read by someone who has not seen the individual tool sections.

**What a good static summary covers:**
1. What type of file it is (PE32, installer, etc.)
2. What packaging or obfuscation was detected (NSIS, UPX, custom packer)
3. What entropy/size anomalies were found and what they imply
4. Any branding or version resource signals
5. The confidence level at this stage
6. What the logical next step is

**Example:**

> The object is a 32-bit PE whose on-disk bulk is an NSIS 3.04 (zlib, solid)
> overlay. File size (4.0 MB) vs. PE image size (46 KB) indicates the installer
> archive accounts for nearly all bytes on disk. Global entropy of 7.92 is
> consistent with NSIS compressed data. The embedded version resource reads
> "FakeUpdater" and the PEStudio manifest confirms `Nullsoft.NSIS.exehead`.
> Two flagged imports (`ShellExecuteA`, `URLDownloadToFile`) suggest the inner
> payload may reach out to external resources or launch a secondary binary.
> Static-only analysis is medium confidence; dynamic analysis would confirm
> whether the inner payload executes malicious behavior.

---

## 12. Advance to static status

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_07 -Status static
```

This updates `samples_tracker.csv` and prints the static-phase close checklist.
Work through the checklist and confirm every item is done before continuing.

If you are doing **static analysis only** (no dynamic pass), skip to [Step 17](#17-write-the-findings-file).

---

## 13. Dynamic analysis — pre-flight

**In the VM.** Do not execute anything yet.

### Snapshot check

Confirm your clean snapshot exists. If you have been doing static analysis in this
session, any accidental double-click could have already run something. When in doubt,
revert to the clean snapshot and start the dynamic session fresh.

### Start monitoring tools first, sample second

Order matters: tools must be capturing before the sample runs, not after.

**Step 1 — Start Procmon:**
- Filter > Filter... > Add: `Process Name` `is` `sample_filename.exe` → `Include`
- Enable all event categories: File System, Registry, Network, Process/Thread
- Start capture: Ctrl+E (or click the capture toggle)

**Step 2 — Open Process Explorer:**
- No special setup needed; just have it open and visible
- Note the current process list — this is your baseline

**Step 3 — Open TCPView:**
- Note current established connections — this is your baseline
- You will look for new connections after execution

**Step 4 — Optional: Start Wireshark:**
- Select the correct network adapter
- Start capture
- Apply display filter: `dns or http or tcp` (you can refine later)

**Step 5 — Note the time:**
- Write the exact time you started monitoring in `02_dynamic/sample_07.md`
- This helps correlate Procmon timestamps to real events

---

## 14. Dynamic analysis — execution and observation

### Execute the sample

- Double-click the binary (or right-click > Run as administrator if you want elevated context)
- Note in `02_dynamic/sample_07.md`: how you launched it and whether it ran elevated
- Watch what happens immediately:
  - Does it open a UI?
  - Does it show dialogs, errors, installer windows?
  - Does it appear to do nothing visible?
  - Does it crash immediately?

### Observe for 60–120 seconds

**Process Explorer:** watch for:
- New child processes (anything spawned by your sample)
- The sample itself disappearing and being replaced by another process
- Legitimate-looking process names in unexpected locations (masquerading)

**Procmon:** watch the stream for:
- New files created in `%TEMP%`, `%APPDATA%`, `%PROGRAMDATA%`
- Registry writes to Run keys (`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`)
- Network TCP connects appearing in the event stream

**TCPView:** watch for:
- New connections appearing
- Note the remote IP, port, and which process owns the connection

**On screen:** watch for:
- Any UI that appears (dialogs, browser opens, antivirus alerts, fake error messages)
- Screenshot anything notable immediately

### Take notes in real time

Open `02_dynamic/sample_07.md` on the host machine and take brief notes as you observe.
You do not need perfect formatting yet — just capture what you see. You will clean it up after revert.

---

## 15. Dynamic analysis — post-run documentation

### Export Procmon log

1. Stop capture: Ctrl+E
2. File > Save... > Format: CSV > save to VM desktop as `procmon_sample_07.csv`
3. Filter the CSV: look for events where Process Name matches your sample
4. Key things to extract:
   - File writes: copy paths of any `.exe`, `.dll`, `.bat`, `.ps1` files written
   - Registry writes: copy key + value + data for any Run/RunOnce or persistence-adjacent keys
   - TCP Connect events: copy remote address and port

### Revert the VM snapshot

**Do this before doing anything else on the VM.** Before you analyze, before you export more files, before you check anything. Revert now.

```
VMware: VM > Snapshot > Revert to Snapshot...
VirtualBox: Machine > Restore Snapshot...
Hyper-V: Right-click VM > Apply Checkpoint
```

After revert, the VM is clean again. Your Procmon CSV and any screenshots you took
are still on the host — you copied/noted them, or you took phone photos.

### Fill in `02_dynamic/sample_07.md`

With your notes and Procmon CSV in front of you:

**Process tree** — list what you observed in Process Explorer:

```markdown
| Parent | Child | Command line / notes |
|--------|--------|---------------------|
| sample_07.exe (PID 1234) | cmd.exe | /c "C:\Temp\payload.exe" /silent |
| cmd.exe | payload.exe | /silent |
```

**File system** — drops from Procmon file write events:

```markdown
| Path | Operation | Notes |
|------|-----------|-------|
| C:\Users\win11\AppData\Local\Temp\abc123.exe | WriteFile | dropped by installer |
| C:\Users\win11\AppData\Roaming\FakeApp\ | CreateFile | folder creation |
```

**Registry** — from Procmon registry events:

```markdown
| Key | Value name | Data / notes |
|-----|------------|--------------|
| HKCU\Software\Microsoft\Windows\CurrentVersion\Run | FakeUpdater | C:\Users\win11\AppData\Local\Temp\abc123.exe |
```

**Network** — from TCPView / Wireshark / Procmon TCP events:

```markdown
| Proto | Remote host | Port | Notes |
|-------|-------------|------|-------|
| TCP | 185.220.101.x | 443 | TLS connection immediately after execution |
| DNS | 8.8.8.8 → fakeupdate.pages.dev | 53 | DNS resolution before TCP connect |
```

### Write the dynamic summary

One paragraph synthesizing everything observed:

> After execution, the installer extracted a secondary binary to `%TEMP%\abc123.exe`
> and spawned it via cmd.exe. The secondary binary immediately wrote a Run key for
> persistence and established a TLS connection to `fakeupdate.pages.dev` (resolved
> to 185.220.101.x) on port 443. This behavior is consistent with a dropper delivering
> a persistence-enabled secondary payload with network C2 capability.

---

## 16. Advance to dynamic status

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_07 -Status dynamic
```

Work through the dynamic-phase close checklist before continuing.

---

## 17. Write the findings file

`03_findings/sample_07.md` is the most important file. It is the output artifact —
what a reviewer, colleague, or future-you will read.

### Step A — Complete the YAML frontmatter

Open the file and fill every field:

```yaml
---
sample_id: sample_07
sha256: abc123...def456
phase: findings
analyst: YourName
date_acquired: "2026-05-10"
date_analyzed: "2026-05-10"
status: done
verdict: suspicious                    # benign / suspicious / malicious / unknown
family_guess: "NSIS dropper with persistence"
family_confidence: medium-high         # low / medium / medium-high / high
tags:
  - nsis
  - dropper
  - persistence
  - network-c2
mitre_techniques:
  - T1036    # Masquerading
  - T1027    # Obfuscated Files or Information
  - T1547.001  # Boot or Logon Autostart: Registry Run Keys
  - T1071.001  # Application Layer Protocol: Web Protocols
mb_url: "https://bazaar.abuse.ch/sample/abc123...def456/"
procmon_run: true
dynamic_complete: true
---
```

**Verdict choices:**
- `benign` — confident this is legitimate software
- `suspicious` — indicators of malicious intent but not definitively confirmed
- `malicious` — confirmed malicious behavior (strong evidence, multiple corroborating signals)
- `unknown` — insufficient analysis to conclude

**Confidence choices:**
- `high` — multiple independent signals agree; dynamic behavior confirmed in controlled run
- `medium-high` — strong static + limited behavioral evidence
- `medium` — static only, or behavioral evidence is indirect/circumstantial
- `low` — very little evidence; needs more analysis

**Tags:** use lowercase, hyphenated, descriptive terms. Examples:
`nsis` `dropper` `stealer` `rat` `loader` `fake-alert` `persistence`
`network-c2` `powershell` `office-macro` `anti-vm` `packer-upx`

**MITRE techniques:** use the exact technique ID (e.g., `T1547.001`). You can add
a comment after the ID for your own reference. The export script strips inline comments
when reading frontmatter. See `20_notes/MITRE-coverage.md` for the techniques already
documented.

### Step B — Write the analyst one-liner

One sentence. No hedging, no padding. The most useful sentence you can write.

Bad: "This sample appears to possibly be potentially malicious in nature."
Good: "NSIS dropper extracts a persistence-enabled binary and establishes C2 via TLS to `fakeupdate.pages.dev`."

### Step C — Write the verdict section

```markdown
## Verdict

- **Classification (working):** Malicious dropper with persistence and C2 capability
- **Why:** NSIS wrapper (static) drops secondary PE to %TEMP%, writes Run key for
  persistence (Procmon), and immediately initiates TLS C2 connection (TCPView).
  All three phases of behavior confirmed in controlled VM run.
```

### Step D — Complete the IOC table

List every unique indicator with type and source:

```markdown
## IOCs (keep `40_iocs/indicators.csv` in sync)

| Type | Value | Notes |
|------|-------|-------|
| sha256 | abc123...def456 | Primary sample -- canonical identity |
| md5 | aabbccdd... | Full-file hash |
| filename | Setup_v3.exe | Claimed name on Bazaar |
| domain | fakeupdate.pages.dev | C2 domain -- DNS + TCPView |
| ip | 185.220.101.x | C2 IP at time of run |
| file_path | C:\Users\win11\AppData\Local\Temp\abc123.exe | Dropped secondary PE |
| registry_key | HKCU\...\Run\FakeUpdater | Persistence Run key |
| software_name | FakeUpdater | Version resource branding |
```

### Step E — Write "What you proved"

Separate static evidence from dynamic evidence:

```markdown
## What you proved

- **Static:** NSIS installer structure (DIE + PEStudio manifest + .ndata in HxD);
  entropy 7.92 consistent with compressed archive; branding "FakeUpdater".
- **Dynamic:** Dropped secondary PE to %TEMP%; wrote Run key (persistence confirmed);
  TLS C2 to fakeupdate.pages.dev on 443 (TCPView).
```

### Step F — Write the public-safe blurb

This section must be safe to share with anyone — no internal paths, no VM usernames,
no unreleased details, no information that could identify you.

```markdown
## Public-safe blurb

This sample is a 32-bit Windows executable packaged as an NSIS installer. Static
analysis reveals very high entropy consistent with a compressed archive payload,
and version resource branding of "FakeUpdater." When executed in a controlled
virtual machine environment, the installer extracted a secondary executable to a
temporary directory, wrote a Windows Run key for persistence, and established an
encrypted outbound connection to a third-party web hosting domain. This behavior
is consistent with a dropper delivering a persistence-capable secondary payload
with command-and-control capability. Further analysis of the secondary payload
(separate hash/acquisition) would be needed to characterize its full functionality.
```

---

## 18. Update the IOC CSV

Open `40_iocs/indicators.csv` and append one row per indicator.
Keep the format consistent with existing rows.

```csv
sample_07,sha256,abc123...def456,malwarebazaar,2026-05-10T14:00:00Z,primary sample
sample_07,md5,aabbccdd...,malwarebazaar,,full-file hash
sample_07,filename,Setup_v3.exe,malwarebazaar,,claimed name
sample_07,domain,fakeupdate.pages.dev,dynamic_tcpview_20260510,,C2 domain -- TLS port 443
sample_07,ip,185.220.101.x,dynamic_tcpview_20260510,,C2 IP at time of run
sample_07,file_path,C:\Users\win11\AppData\Local\Temp\abc123.exe,dynamic_procmon_20260510,,dropped secondary PE
sample_07,registry_key,"HKCU\Software\Microsoft\Windows\CurrentVersion\Run\FakeUpdater",dynamic_procmon_20260510,,persistence run key
sample_07,software_name,FakeUpdater,static_pe_version_20260510,,version resource branding
```

**Column: `source`** — use a consistent format so you can trace where each IOC came from:
- `malwarebazaar` — from the Bazaar page before download
- `static_pe_version_YYYYMMDD` — from static PE analysis on that date
- `dynamic_procmon_YYYYMMDD` — from Procmon log during dynamic run
- `dynamic_tcpview_YYYYMMDD` — from TCPView during dynamic run
- `dynamic_network_YYYYMMDD` — from Wireshark capture

---

## 19. Update MITRE coverage

Open `20_notes/MITRE-coverage.md`.

For each technique in the frontmatter `mitre_techniques:` list:
1. Add a new row to the coverage table if the technique is not already there
2. If the technique is already there (from a previous sample), add `sample_07` to the Samples column
3. Increment the tactic heatmap count if this is a new technique for that tactic

Example — adding `T1547.001` which is new to the logbook:

```markdown
| T1547.001 | Boot or Logon Autostart: Registry Run Keys | Persistence | [sample_07](../03_findings/sample_07.md) | High | Run key `HKCU\...\Run\FakeUpdater` confirmed in Procmon log |
```

And update the heatmap:
```markdown
| Persistence | 1 | T1547.001 |
```

If this sample's pattern fits an existing case series (e.g., NSIS delivery), add a row
to that case series file in `20_notes/case-series/`. If it introduces a new pattern
(e.g., first stealer, first Office macro), create a new case series note.

---

## 20. Evidence hygiene — EXIF and redaction

**Back on the host machine.** Do both of these before committing any screenshots.

### Strip EXIF metadata from screenshots

Phone photos carry GPS coordinates, device model, and sometimes the photographer's
name in EXIF metadata. Even desktop screenshots can carry software metadata.

```powershell
# Strip all EXIF from this sample's screenshots (requires exiftool)
powershell -ExecutionPolicy Bypass -File .\30_scripts\strip-exif.ps1 -SampleId sample_07 -SkipBackup
```

If exiftool is not installed, the script falls back to .NET for JPEG only. Install
exiftool for full coverage including PNG:
```powershell
winget install OliverBetz.ExifTool
```

### Run the redaction check

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1 -SampleId sample_07
```

This scans all `.md`, `.csv`, and `.txt` files for:
- Windows paths with non-VM usernames (FAIL — must fix before committing)
- Email addresses (WARN — review; may be legitimate IOC)
- Internal hostnames ending in `.local`, `.corp`, etc. (WARN)
- UNC paths (WARN)

**If you get a FAIL:** open the flagged file, find the match, and either remove it
or rewrite it to use only the VM username or sanitized text.

### Tick off the SHOT_INDEX checklist

Open `50_screenshots/sample_07/SHOT_INDEX.txt` and tick every hygiene checkbox:

```
[x] VM username / hostname NOT visible in captured UI
[x] Analyst host machine paths NOT in any screenshot
[x] No personal information visible
[x] EXIF metadata stripped: run 30_scripts\strip-exif.ps1
[x] HEIC originals converted to PNG before committing
[x] Redact check passed: run 30_scripts\redact-check.ps1
```

---

## 21. Final close, validate, and commit

### Close and validate

```powershell
# Close as done, run all checks, regenerate INDEX.md
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_07 -Status done -RunValidate -RunExport
```

This command:
1. Updates `samples_tracker.csv` status to `done`
2. Prints the full `done`-phase close checklist
3. Runs `validate.ps1` — 10 structural checks
4. Runs `export-summary.ps1` — regenerates `INDEX.md` with updated tag/MITRE cross-references

**Only proceed to commit if `validate.ps1` exits with Result: OK.**

If validate reports any FAIL, fix the issue and re-run before committing.

### Review what will be committed

```powershell
git status
git diff --stat
```

Check that only expected files are staged — no binaries, no VM disk images,
no `.ps1` files from samples (only `30_scripts/*.ps1` which are whitelisted).

### Commit

```powershell
git add -A
git commit -m "add sample_07: NSIS dropper with persistence and C2 (fakeupdate.pages.dev)"
```

Good commit message format:
```
add sample_07: <brief description of the finding>
```

---

## 22. Quick-reference decision tree

Use this after your first few samples when you know the workflow but want a fast reminder.

```
START
  |
  v
[ new_sample.ps1 -NextNumber N ]
  |
  v
[ Fill 00_original/sample_N.md from Bazaar ] -- host machine, before VM
  |
  v
[ VM: Download + verify SHA256 ]
  |
  v
[ VM: DIE --> PEStudio --> CFF Explorer --> HxD ]
  | Document in 01_static/sample_N.md
  | Screenshot each tool
  |
  v
[ close_sample.ps1 -Status static ]
  |
  v
  +-- Skip dynamic? (static-only analysis) -----> [ Jump to Step 17 ]
  |
  v
[ VM: Procmon + ProcExp + TCPView FIRST ]
[ VM: Then execute sample ]
[ VM: Observe 60-120 seconds ]
[ VM: Export Procmon CSV ]
[ VM: REVERT SNAPSHOT ]
  | Document in 02_dynamic/sample_N.md
  | Append network/file/registry IOCs to 40_iocs/indicators.csv
  |
  v
[ close_sample.ps1 -Status dynamic ]
  |
  v
[ Fill 03_findings/sample_N.md ]
  | YAML frontmatter (all fields)
  | Analyst one-liner
  | Verdict + IOC table + public-safe blurb
  |
  v
[ Update 40_iocs/indicators.csv ] -- all IOC rows for this sample
[ Update 20_notes/MITRE-coverage.md ] -- add new technique rows
[ Update 20_notes/case-series/ ] -- add to existing series or create new
  |
  v
[ strip-exif.ps1 -SampleId sample_N -SkipBackup ]
[ redact-check.ps1 -SampleId sample_N ]
[ Tick SHOT_INDEX.txt hygiene checklist ]
  |
  v
[ close_sample.ps1 -Status done -RunValidate -RunExport ]
  |
  validate exits 0?
  YES --> git add -A && git commit -m "add sample_N: <description>"
  NO  --> fix reported issues, re-run validate
```

---

## Additional notes for specific sample types

### Office documents with macros (`.docm`, `.xlsm`)

- Replace DIE/PEStudio/CFF/HxD with: `olevba` (oletools) for macro extraction
- In `01_static/`, add sections for macro code summary, suspicious API calls found
- Dynamic: enable macros in VM; watch for child process spawns (PowerShell, wscript, cmd)
- Add MITRE candidates: T1566.001, T1059.001 / T1059.003

### Script files (`.ps1`, `.vbs`, `.hta`, `.bat`, `.js`)

- Static: open in text editor; document obfuscation method, any hardcoded URLs/IPs
- Use CyberChef or `[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(...))` to decode Base64 in PS
- Dynamic: short dwell time; watch for file drops and network calls immediately
- Add MITRE candidates: T1059 subtechnique based on script type, T1027, T1140

### Archives (`.zip`, `.rar`, `.iso`)

- Static: list contents with 7-Zip without extracting; document the manifest
- Hash each inner file separately; run each through MalwareBazaar/VT
- Extract inner files in VM only; treat each extracted PE as its own analysis
- Do not commit the archive — document it in `00_original/` and treat inner files as new samples

### Unknown or unusual file types

- Start with HxD and identify by magic bytes
- Run DIE — it handles many non-PE formats
- Check file format specification or [Gary Kessler's file signatures table](https://www.garykessler.net/library/file_sigs.html)
- Document what it is and what tools you used to identify it

---

*See also: [`README.md`](./README.md) — repo overview | [`20_notes/tooling-reference.md`](./20_notes/tooling-reference.md) — tool signal reference | [`30_scripts/README.md`](./30_scripts/README.md) — script documentation*

---

# Track B: CTF Challenge

**Steps for documenting a HackTheBox, TryHackMe, PicoCTF, or any other CTF/challenge.**

## Phase map (CTF)

| Phase folder | What you fill |
|---|---|
| `00_original/` | Challenge brief: platform, category, difficulty, description, target info |
| `01_static/` | Recon and enumeration: nmap, gobuster, service versions, interesting finds |
| `02_dynamic/` | Solve attempt: approach log, commands, exploits tried, pivots, flag capture |
| `03_findings/` | Writeup: methodology, key steps, skills, public-safe blurb |

## Step 1: Scaffold

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 `
    -NextNumber 7 -Kind ctf -Platform "HackTheBox" -Title "Lame"
```

Opens four files in `00_original/`, `01_static/`, `02_dynamic/`, `03_findings/` and a screenshots folder.

## Step 2: Fill the challenge brief (00_original)

Open `00_original/sample_07.md` and fill:
- Platform, category, difficulty, points
- Challenge description (paraphrase — no raw flags)
- Target IP/URL or given files
- Initial attack surface notes

Do NOT include raw flag values anywhere in the repo. Use a placeholder
(`[FLAG REDACTED -- challenge active]`) until the challenge is retired.

## Step 3: Recon and enumeration (01_static)

Open `01_static/sample_07.md` and log:
- Port scan results (nmap command + output summary)
- Service versions
- Web directories (gobuster/feroxbuster)
- Credentials, version strings, or misconfigurations found

Take screenshots of interesting tool output and save to `50_screenshots/sample_07/`.

## Step 4: Attempt the solve (02_dynamic)

Open `02_dynamic/sample_07.md` and log:
- Every technique attempted (including rabbit holes — they are useful documentation)
- Exact commands or payloads used
- What worked and why
- Flag capture note (redacted if challenge still active)

Advance status:
```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 `
    -SampleId sample_07 -Status solved
```

## Step 5: Write the writeup (03_findings)

Open `03_findings/sample_07.md` and fill the YAML frontmatter:
- `solved: true`
- `public_writeup_safe: true` (only once the challenge is retired / permitted)
- `category`, `difficulty`, `platform`
- `skills` list (what you actually practised)
- `tags` list

Write the methodology narrative. Then add the public-safe portfolio blurb.

## Step 6: Evidence hygiene and close

```powershell
# Strip EXIF from screenshots
powershell -ExecutionPolicy Bypass -File .\30_scripts\strip-exif.ps1 -SampleId sample_07

# Redaction check -- catches raw flags if any slipped in
powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1

# Close, validate, and regenerate index
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 `
    -SampleId sample_07 -Status writeup_done -RunValidate -RunExport
```

Commit.

---

# Track C: Training Lab

**Steps for documenting a TryHackMe, SANS, TCM, or any other guided course lab.**

## Phase map (lab)

| Phase folder | What you fill |
|---|---|
| `00_original/` | Lab brief: course, module, learning objectives, environment, prerequisites |
| `01_static/` | Step log: numbered steps, commands, expected vs actual output |
| `02_dynamic/` | Results: objectives completion table, errors encountered, proof/output |
| `03_findings/` | Reflection: key takeaways, skills demonstrated, public-safe blurb |

## Step 1: Scaffold

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 `
    -NextNumber 8 -Kind lab -Platform "TryHackMe" -Title "Introductory Researching"
```

## Step 2: Fill the lab brief (00_original)

Open `00_original/sample_08.md` and fill:
- Course and module name
- Learning objectives (copy from the lab page)
- Environment: VM name only — **no IPs, no passwords, no VPN keys**
- Prerequisites and resources

## Step 3: Log your steps (01_static)

Open `01_static/sample_08.md` and document each step:
- Step number, action, command used, expected output, actual output
- Notes on what was confusing, what you looked up, questions raised

This is your personal procedure log. Be detailed — it is the most useful part when reviewing later.

## Step 4: Record results (02_dynamic)

Open `02_dynamic/sample_08.md` and mark:
- Which objectives were met (checkboxes)
- Errors and how you resolved them
- Proof of completion (output snippets, screenshot references — no credentials)

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 `
    -SampleId sample_08 -Status objectives_met
```

## Step 5: Reflect (03_findings)

Open `03_findings/sample_08.md` and fill:
- YAML: `objectives_met: true`, `skills` list, `outcome: success`
- Key takeaways: what was new or reinforced
- Skills demonstrated: specific and concrete (useful for resume)
- Public-safe portfolio blurb

## Step 6: Close

```powershell
# Redaction check -- no lab credentials or IPs in committed files
powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1

powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 `
    -SampleId sample_08 -Status reviewed -RunValidate -RunExport
```

Commit.

---

# Track D: Threat Hunt

**Steps for documenting a hypothesis-driven detection or log analysis exercise.**

## Phase map (hunt)

| Phase folder | What you fill |
|---|---|
| `00_original/` | Scope: hypothesis, data sources, tools, time box, out of scope |
| `01_static/` | Data collection: queries run, raw findings, event IDs referenced |
| `02_dynamic/` | Analysis: timeline, patterns, correlation, false positives, IOC candidates |
| `03_findings/` | Outcome: detections found, confidence, recommendations |

## Step 1: Scaffold

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 `
    -NextNumber 9 -Kind hunt -Title "Lateral movement via scheduled tasks"
```

## Step 2: Define the scope (00_original)

Open `00_original/sample_09.md` and fill:
- Hypothesis: one clear, testable statement
- Data sources: which logs, which tool (SIEM, Splunk, Elastic, raw logs)
- Time box: how long you plan to spend
- Out of scope: what this hunt deliberately excludes

**A good hypothesis:** "An attacker used scheduled tasks (`schtasks.exe`) to establish
persistence after initial access on Windows endpoints between 2026-04-01 and 2026-05-11."

## Step 3: Collect data (01_static)

Open `01_static/sample_09.md` and log:
- Each query you ran and its result count
- Relevant event IDs (4698, 4702, Sysmon 1, etc.)
- Raw findings — sanitised of real user accounts and internal hostnames before commit

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 `
    -SampleId sample_09 -Status collecting
```

## Step 4: Analyse (02_dynamic)

Open `02_dynamic/sample_09.md` and build:
- Timeline from collected events
- Pattern analysis: recurring process chains, rare parent-child relationships
- False positives with reasoning
- IOC candidates: specific hashes, paths, command lines, IPs

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 `
    -SampleId sample_09 -Status analyzing
```

## Step 5: Write the outcome (03_findings)

Open `03_findings/sample_09.md` and fill:
- YAML: `detections_found`, `outcome`, `confidence`, `hypothesis`
- Confirmed detections table
- Confidence reasoning (data quality, coverage gaps)
- Recommendations: alert rule, follow-on hunt, SIEM query to productionise

## Step 6: Close

```powershell
# Redaction check -- no internal hostnames or user accounts
powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1

powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 `
    -SampleId sample_09 -Status closed -RunValidate -RunExport
```

Commit.

---

*See also: [`ENGAGEMENTS.md`](./ENGAGEMENTS.md) — engagement kinds reference | [`README.md`](./README.md) — repo overview | [`30_scripts/README.md`](./30_scripts/README.md) — script documentation*
