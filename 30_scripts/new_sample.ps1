#Requires -Version 5.1
<#
.SYNOPSIS
    Scaffolds a new sample slot across all phase folders with type-specific templates.

.DESCRIPTION
    Creates four phase .md files, a 50_screenshots/sample_XX/ folder with a
    SHOT_INDEX.txt hygiene checklist, and appends a row to samples_tracker.csv.

    Files created:
      00_original/sample_XX.md   - acquisition receipt and hash record (shared across types)
      01_static/sample_XX.md     - static triage (tool checklist varies by type)
      02_dynamic/sample_XX.md    - dynamic triage (observation tables vary by type)
      03_findings/sample_XX.md   - verdict, IOCs, YAML frontmatter, portfolio blurb
      50_screenshots/sample_XX/  - screenshot folder with SHOT_INDEX.txt

.PARAMETER NextNumber
    The slot number to create (1-99). The ID will be zero-padded (e.g., 7 -> sample_07).

.PARAMETER Analyst
    Analyst name written into the YAML frontmatter. Defaults to 'Surrplexie'.

.PARAMETER Type
    Sample type controlling which static/dynamic template is scaffolded.
    One of: PE (default), Office, Script, Archive.
    PE      - Windows portable executable (DIE/PEStudio/CFF/HxD workflow)
    Office  - Office document with macros (olevba/oledump/strings workflow)
    Script  - Standalone script (PS1/VBS/HTA/BAT/JS/PY/etc.)
    Archive - Container file (ZIP/RAR/ISO/CAB) that wraps a payload

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 7
    powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 7 -Type Office
    powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 7 -Type Script -Analyst Surrplexie
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 99)]
    [int]$NextNumber,

    [string]$Analyst = 'Surrplexie',

    [ValidateSet('PE', 'Office', 'Script', 'Archive')]
    [string]$Type = 'PE'
)

$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root '00_original'))) {
    Write-Error "Cannot find 00_original under repo root: $root"
    exit 1
}

$id   = 'sample_{0:D2}' -f $NextNumber

# ---------------------------------------------------------------------------
# Guard: check this slot isn't already taken in the tracker
# ---------------------------------------------------------------------------
$csvPath = Join-Path $root 'samples_tracker.csv'
if (Test-Path $csvPath) {
    $tracker = Import-Csv $csvPath
    $existing = $tracker | Where-Object { $_.sample_id -eq $id }
    if ($existing -and $existing.status -ne 'empty') {
        Write-Warning "Slot $id already exists in tracker with status '$($existing.status)'. Use a different number or clear the slot first."
        exit 1
    }
}

Write-Host ""
Write-Host "Scaffolding $id (Type: $Type) ..." -ForegroundColor Cyan

# ===========================================================================
# SHARED: 00_original template (identical for all types)
# ===========================================================================

$tmplOriginal = @'
# SAMPLE_ID -- acquisition receipt (host log)

**Type:** SAMPLE_TYPE | **Purpose:** Record identification and sourcing before/at acquisition.
Binaries stay VM-only. Populate from your source (MalwareBazaar, VirusTotal, URLhaus, etc.)
before downloading.

| Field | Value |
|--------|--------|
| **Sample ID** | `SAMPLE_ID` |
| **Source URL** | |
| **SHA256** | |
| **SHA1** | |
| **MD5** | |
| **File name (claimed)** | |
| **MIME / type** | |
| **Size** | |
| **First seen** | |
| **Bazaar verdict** | |
| **Vendor detections** | |

## Delivery & context

| Field | Value |
|--------|--------|
| **Delivery method** | |
| **Reporter / origin** | |
| **Tags (source)** | |

## Hashes for clustering / lookups

| Field | Value | Notes |
|--------|--------|--------|
| **imphash** | | |
| **ssdeep** | | |
| **TLSH** | | |

## URLs referenced on source page (IOC leads)

| Kind | URL / note |
|------|------------|
| | |

## YARA / detection rules flagged

| Rule | Author | Implication (rough) |
|------|--------|---------------------|
| | | |

## Intelligence snippets

| Metric | Value |
|--------|--------|
| `# of uploads` | |
| `# of downloads` | |
| **Origin country** | |

## Acquisition checklist (VM)

- [ ] Download **inside VM only**
- [ ] **Hash verified on VM** -- matches source value
- [ ] VM path documented (no sensitive analyst-machine paths here)
- [ ] Optional: clean **snapshot taken before** first run
- [ ] **Never** copy binary to this host logbook PC

## Cross-links

- Static: `01_static/SAMPLE_ID.md`
- Dynamic: `02_dynamic/SAMPLE_ID.md`
- Findings: `03_findings/SAMPLE_ID.md`
- Screenshots: `50_screenshots/SAMPLE_ID/`
'@

# ===========================================================================
# TYPE-SPECIFIC: 01_static templates
# ===========================================================================

$tmplStaticPE = @'
# SAMPLE_ID -- static triage (PE)

| Field | Value |
|--------|--------|
| **SHA256** | <!-- fill --> |
| **Date analyzed** | <!-- fill --> |
| **VM user** | |

Cross-references: [acquisition](../00_original/SAMPLE_ID.md) | [dynamic](../02_dynamic/SAMPLE_ID.md) | [findings](../03_findings/SAMPLE_ID.md)

---

## Session results

| Step | Done? | Notes |
|------|-------|-------|
| DIE | | |
| PEStudio | | |
| CFF Explorer | | |
| HxD | | |

## Hash reconcile

<!-- Note if any tool hash differs from the full-file source hash and explain why.
     CFF Explorer may show PE-image-only hash on overlay-heavy samples (expected). -->

---

## DIE

- **PE type / arch:** <!-- PE32 / PE32+ / I386 / AMD64 / GUI / Console -->
- **Linker / compiler:** <!-- e.g. Microsoft Linker 6.0 / GCC / Delphi / Go -->
- **Installer:** <!-- NSIS / Inno Setup / WiX / none -->
- **Heuristic:** <!-- (Heur) Packer: Generic / etc. -->
- **Overlay:** <!-- offset, size, type if identified -->

## PEStudio

- **SHA256:** <!-- confirm matches source -->
- **Type:** <!-- 32-bit / 64-bit / GUI / Console -->
- **Size:** <!-- bytes --> | **Entropy:** <!-- X.XX -->
- **FileDescription / ProductName:** <!-- from version resource -->
- **Manifest name:** <!-- e.g. Nullsoft.NSIS.exehead -->
- **Libraries / imports:** <!-- N libraries / N imports -->
- **Flagged imports:** <!-- VirtualAlloc, WriteProcessMemory, URLDownloadToFile, etc. -->
- **Overlay:** <!-- signature and size -->
- **VirusTotal (in UI):** <!-- N/66 at time of analysis -->

## CFF Explorer

- **File type:** <!-- Portable Executable 32 / 64 -->
- **File size:** <!-- bytes --> | **PE image size:** <!-- bytes / note gap -->
- **FileDescription / ProductName:** <!-- version resource -->
- **FileVersion:** <!-- --> | **LegalCopyright:** <!-- -->
- **NTFS timestamps (VM local):** <!-- Created / Modified -->

## HxD

- **Signature:** <!-- MZ (4D 5A) / PK.. (50 4B) / etc. at 0x0 -->
- **PE header:** <!-- PE\0\0 at offset -->
- **Section names (ASCII column):** <!-- .text .rdata .data .rsrc etc. -->
- **Overlay start:** <!-- notable bytes at PE image end -->

---

## Static summary (portfolio-ready)

<!-- One paragraph synthesizing all four tools:
     PE type, packaging, entropy/size anomalies, version resource, confidence level, next steps. -->

## Screenshot map

| File | Tool | What it shows |
|------|------|----------------|
| | | |

## Cross-links

- Original: `00_original/SAMPLE_ID.md`
- Dynamic: `02_dynamic/SAMPLE_ID.md`
- Findings: `03_findings/SAMPLE_ID.md`
'@

$tmplStaticOffice = @'
# SAMPLE_ID -- static triage (Office document)

| Field | Value |
|--------|--------|
| **SHA256** | <!-- fill --> |
| **Date analyzed** | <!-- fill --> |
| **VM user** | |
| **File extension** | <!-- .doc / .docx / .xls / .xlsx / .docm / .xlsm / .pptm --> |

Cross-references: [acquisition](../00_original/SAMPLE_ID.md) | [dynamic](../02_dynamic/SAMPLE_ID.md) | [findings](../03_findings/SAMPLE_ID.md)

---

## Session results

| Step | Done? | Notes |
|------|-------|-------|
| DIE / file type confirm | | |
| olevba (macro extraction) | | |
| oledump.py | | |
| strings / HxD scan | | |
| Embedded objects check | | |

---

## DIE / file type

- **Identified as:** <!-- OLE2 compound doc / OOXML / RTF / other -->
- **Password protected:** <!-- yes / no / unknown -->

## olevba output

<!-- paste or summarize key output:
     - macro streams found
     - suspicious API calls (Shell, CreateObject, WScript.Shell, URLDownloadToFile)
     - obfuscation level (Auto_Open, Auto_Exec, Document_Open)
     - IOC strings in macros (URLs, file paths, encoded payloads)
     Use: olevba --reveal --deobf FILE -->

### Macro API calls flagged

| API / keyword | Stream | Significance |
|---------------|--------|--------------|
| | | |

### Hard-coded strings in macros (IOC candidates)

| String | Type | Notes |
|--------|------|-------|
| | | |

## oledump.py

<!-- streams with macros: M = macro, m = macro with attributes, A = ActiveX -->
<!-- oledump.py -p plugin_biff FILE (for XLS 97-2003 format) -->

| Stream # | Name | Flags | Notes |
|----------|------|-------|-------|
| | | | |

## Embedded objects / external references

<!-- Check for DDEAUTO, template injection, external oleObject URLs -->

| Type | Value | Notes |
|------|-------|-------|
| | | |

## Strings (selected)

<!-- Interesting strings from HxD or strings utility (URLs, paths, encoded blobs) -->

| String | Location | Notes |
|--------|----------|-------|
| | | |

---

## Static summary (portfolio-ready)

<!-- Paragraph: doc type, macro presence/absence, obfuscation method, IOC quality, confidence. -->

## Screenshot map

| File | Tool | What it shows |
|------|------|----------------|
| | | |
'@

$tmplStaticScript = @'
# SAMPLE_ID -- static triage (script file)

| Field | Value |
|--------|--------|
| **SHA256** | <!-- fill --> |
| **Date analyzed** | <!-- fill --> |
| **Script type** | <!-- PS1 / VBS / HTA / BAT / CMD / JS / JSE / WSF / PY / other --> |
| **VM user** | |

Cross-references: [acquisition](../00_original/SAMPLE_ID.md) | [dynamic](../02_dynamic/SAMPLE_ID.md) | [findings](../03_findings/SAMPLE_ID.md)

---

## Session results

| Step | Done? | Notes |
|------|-------|-------|
| Text / hex view | | |
| Encoding / obfuscation identification | | |
| Decode / deobfuscate | | |
| IOC extraction | | |

---

## Raw or decoded content summary

<!-- Do not paste full malicious code. Describe:
     - obfuscation method (Base64, hex, XOR, char-code concat, etc.)
     - decode steps taken and tools used (CyberChef, PS -EncodedCommand decode, etc.) -->

### Obfuscation method

<!-- e.g. Base64-encoded command passed to powershell.exe -EncodedCommand
     or string concatenation / char-code obfuscation / compression -->

### Deobfuscation steps

| Step | Input / note | Output / result |
|------|--------------|-----------------|
| | | |

## API / function calls found

<!-- High-value calls that indicate intent -->

| Call | Language | Significance |
|------|----------|--------------|
| | | |

## Hard-coded IOC candidates

| Type | Value | Notes |
|------|-------|-------|
| url | | |
| path | | |
| domain | | |

## Strings (additional)

<!-- Anything not covered above -- C2 addresses, registry keys, file drops, encoded blobs -->

| String | Notes |
|--------|-------|
| | |

---

## Static summary (portfolio-ready)

<!-- Paragraph: script type, obfuscation method, decoded intent, IOC quality, confidence. -->

## Screenshot map

| File | Tool | What it shows |
|------|------|----------------|
| | | |
'@

$tmplStaticArchive = @'
# SAMPLE_ID -- static triage (archive / container)

| Field | Value |
|--------|--------|
| **SHA256** | <!-- fill --> |
| **Date analyzed** | <!-- fill --> |
| **Archive format** | <!-- ZIP / RAR / 7z / ISO / CAB / TAR / other --> |
| **VM user** | |

Cross-references: [acquisition](../00_original/SAMPLE_ID.md) | [dynamic](../02_dynamic/SAMPLE_ID.md) | [findings](../03_findings/SAMPLE_ID.md)

---

## Session results

| Step | Done? | Notes |
|------|-------|-------|
| File type confirm (DIE / magic bytes) | | |
| Archive manifest (list without extract) | | |
| Inner file hashes | | |
| Inner file type identification | | |
| Nested archive check | | |

---

## DIE / HxD -- file type confirm

- **Magic bytes:** <!-- PK.. / Rar! / 7z / etc. -->
- **DIE / format identified:** <!-- archive type and version -->
- **Password protected:** <!-- yes (known password?) / no -->

## Archive manifest (list without extracting)

<!-- Use: 7z l FILE, python -m zipfile -l FILE, isoinfo -i FILE -l -->
<!-- Do NOT extract to the host machine -- extract inside VM only -->

| Path in archive | Size | Modified | Notes |
|-----------------|------|----------|-------|
| | | | |

## Inner file hashes (computed inside VM only)

| Inner file | SHA256 | Type (DIE/file) | Notes |
|------------|--------|-----------------|-------|
| | | | |

## Inner file threat intelligence

| Inner file SHA256 | VT / Bazaar link | Detection ratio | Notes |
|-------------------|------------------|-----------------|-------|
| | | | |

## Suspicious indicators in archive structure

<!-- Password-protected sub-archives, deeply nested paths, double extensions, oversized decompression ratio -->

| Indicator | Detail | Risk |
|-----------|--------|------|
| | | |

---

## Static summary (portfolio-ready)

<!-- Paragraph: archive format, manifest content, inner file types, IOC quality, confidence. -->

## Screenshot map

| File | Tool | What it shows |
|------|------|----------------|
| | | |
'@

# ===========================================================================
# TYPE-SPECIFIC: 02_dynamic templates
# ===========================================================================

$tmplDynamicPE = @'
# SAMPLE_ID -- dynamic triage (PE)

| Field | Value |
|--------|--------|
| **SHA256** | <!-- fill --> |
| **Date analyzed** | <!-- fill --> |
| **VM type** | <!-- Windows 10/11 VM --> |
| **AV / real-time protection** | <!-- on / off --> |
| **Snapshot name** | <!-- fill --> |

Cross-references: [findings](../03_findings/SAMPLE_ID.md) | [static](../01_static/SAMPLE_ID.md)

---

## Pre-flight checklist

- [ ] Clean snapshot baseline confirmed
- [ ] **Procmon** capture started (boot or pre-run) -- filter: Process Name is SAMPLE_ID.exe
- [ ] **Process Explorer** open
- [ ] **TCPView** open -- baseline connections noted
- [ ] AV / real-time protection status noted
- [ ] Time noted: <!-- HH:MM --> (for log correlation)

## Execution

- **How launched:** <!-- double-click / cmd / elevated -->
- **User context:** <!-- standard user / administrator -->
- **Observed UX:** <!-- dialogs, errors, silent, browser opens, etc. -->

## Process tree (Process Explorer)

| Parent | Child | PID | Command line / notes |
|--------|--------|-----|---------------------|
| | | | |

## File system (Procmon WriteFile / CreateFile events)

| Path | Operation | Notes |
|------|-----------|-------|
| | | |

## Registry (Procmon RegSetValue events)

| Key | Value name | Data / notes |
|-----|------------|--------------|
| | | |

## Network (TCPView / Wireshark / Procmon TCP Connect)

| Proto | Remote host / domain | Port | Notes |
|-------|----------------------|------|-------|
| | | | |

## Post-run observations

<!-- Scheduled tasks, services, autorun entries, browser changes, changed files -->

## Dynamic summary (portfolio-ready)

<!-- Synthesize static + runtime: what executed, what it dropped, where it persisted, network. -->

## Post-run checklist

- [ ] Procmon log exported: `procmon_SAMPLE_ID.csv` (not committed -- VM only)
- [ ] Ingest tables: run `30_scripts\ingest-procmon.ps1 -SampleId SAMPLE_ID -ProcmonCsv <path>`
- [ ] IOCs appended to `40_iocs/indicators.csv`
- [ ] Screenshots captured and indexed in SHOT_INDEX.txt
- [ ] VM snapshot **reverted**

## Screenshots

`50_screenshots/SAMPLE_ID/`

## Cross-links

- Original: `00_original/SAMPLE_ID.md`
- Static: `01_static/SAMPLE_ID.md`
- Findings: `03_findings/SAMPLE_ID.md`
'@

$tmplDynamicOffice = @'
# SAMPLE_ID -- dynamic triage (Office document)

| Field | Value |
|--------|--------|
| **SHA256** | <!-- fill --> |
| **Date analyzed** | <!-- fill --> |
| **VM type** | <!-- Windows 10/11 VM --> |
| **Office version** | <!-- Word / Excel / PowerPoint + version --> |
| **Macros enabled** | <!-- yes / no / prompted --> |
| **AV / real-time protection** | <!-- on / off --> |
| **Snapshot name** | <!-- fill --> |

Cross-references: [findings](../03_findings/SAMPLE_ID.md) | [static](../01_static/SAMPLE_ID.md)

---

## Pre-flight checklist

- [ ] Clean snapshot confirmed
- [ ] **Procmon** capture started -- filter: Process Name is WINWORD.EXE / EXCEL.EXE / etc.
- [ ] **Process Explorer** open
- [ ] **TCPView** open
- [ ] Macro security: **Disable all macros** for preview; **Enable** for execution run
- [ ] Protected View: disabled in Office Trust Center (to allow macro execution)

## Execution

- **Opened with:** <!-- Microsoft Word 2019 / LibreOffice / etc. -->
- **Macro prompt:** <!-- "Enable Content" shown / auto-executed / not prompted -->
- **Observed UX:** <!-- dialogs, decoy document text, browser opens, errors -->

## Process tree (Process Explorer)

| Parent | Child | PID | Command line / notes |
|--------|--------|-----|---------------------|
| WINWORD.EXE | | | |

## Child process details

<!-- Focus on unusual Office children: cmd.exe, powershell.exe, wscript.exe, mshta.exe -->

| Process | Command line | Significance |
|---------|--------------|--------------|
| | | |

## File system (Procmon)

| Path | Operation | Notes |
|------|-----------|-------|
| | | |

## Registry (Procmon)

| Key | Value name | Data / notes |
|-----|------------|--------------|
| | | |

## Network (TCPView / Procmon)

| Proto | Remote host / domain | Port | Notes |
|-------|----------------------|------|-------|
| | | | |

## Downloaded / dropped files

| Path | SHA256 | Type | Notes |
|------|--------|------|-------|
| | | | |

## Dynamic summary (portfolio-ready)

<!-- What the macro did: child processes spawned, payloads downloaded, persistence written. -->

## Post-run checklist

- [ ] Procmon log exported (not committed)
- [ ] Ingest tables: run `30_scripts\ingest-procmon.ps1 -SampleId SAMPLE_ID -ProcmonCsv <path>`
- [ ] IOCs appended to `40_iocs/indicators.csv`
- [ ] VM snapshot **reverted**

## Screenshots

`50_screenshots/SAMPLE_ID/`
'@

$tmplDynamicScript = @'
# SAMPLE_ID -- dynamic triage (script)

| Field | Value |
|--------|--------|
| **SHA256** | <!-- fill --> |
| **Date analyzed** | <!-- fill --> |
| **VM type** | <!-- Windows 10/11 VM --> |
| **Script host** | <!-- powershell.exe / wscript.exe / cscript.exe / node.exe / python.exe --> |
| **Execution policy / context** | <!-- Bypass / Restricted / Unrestricted / Admin --> |
| **AV / real-time protection** | <!-- on / off --> |
| **Snapshot name** | <!-- fill --> |

Cross-references: [findings](../03_findings/SAMPLE_ID.md) | [static](../01_static/SAMPLE_ID.md)

---

## Pre-flight checklist

- [ ] Clean snapshot confirmed
- [ ] **Procmon** capture started -- filter: Process Name is powershell.exe / wscript.exe / etc.
- [ ] **Process Explorer** open
- [ ] **TCPView** open
- [ ] AMSI / Script Block Logging: note if enabled (affects observation depth)

## Execution

- **Command used:** <!-- powershell.exe -ExecutionPolicy Bypass -File script.ps1 / etc. -->
- **User context:** <!-- standard user / administrator -->
- **Observed UX:** <!-- console output, dialogs, silent, errors -->
- **Execution time before exit / timeout:** <!-- seconds -->

## Console / stdout output captured

<!-- paste key lines only -- redact any PII / credentials first -->

```
(paste relevant output here)
```

## Process tree (Process Explorer)

| Parent | Child | PID | Command line / notes |
|--------|--------|-----|---------------------|
| | | | |

## File system (Procmon)

| Path | Operation | Notes |
|------|-----------|-------|
| | | |

## Registry (Procmon)

| Key | Value name | Data / notes |
|-----|------------|--------------|
| | | |

## Network (TCPView / Procmon)

| Proto | Remote host / domain | Port | Notes |
|-------|----------------------|------|-------|
| | | | |

## Dynamic summary (portfolio-ready)

<!-- What the script did at runtime: child processes, downloads, persistence, C2 comms. -->

## Post-run checklist

- [ ] Procmon log exported (not committed)
- [ ] Ingest tables: run `30_scripts\ingest-procmon.ps1 -SampleId SAMPLE_ID -ProcmonCsv <path>`
- [ ] IOCs appended to `40_iocs/indicators.csv`
- [ ] VM snapshot **reverted**

## Screenshots

`50_screenshots/SAMPLE_ID/`
'@

$tmplDynamicArchive = @'
# SAMPLE_ID -- dynamic triage (archive -- inner payload execution)

| Field | Value |
|--------|--------|
| **SHA256 (archive)** | <!-- fill --> |
| **Date analyzed** | <!-- fill --> |
| **VM type** | <!-- Windows 10/11 VM --> |
| **AV / real-time protection** | <!-- on / off --> |
| **Snapshot name** | <!-- fill --> |

**Note:** Dynamic analysis here covers the **extracted inner payload(s)** executed inside the VM.
Document each inner file as a separate observation block if multiple executables are involved.
Consider creating an additional `sample_XX` slot for significant inner payloads.

Cross-references: [findings](../03_findings/SAMPLE_ID.md) | [static](../01_static/SAMPLE_ID.md)

---

## Pre-flight checklist

- [ ] Clean snapshot confirmed
- [ ] **Procmon** capture started
- [ ] **Process Explorer** open
- [ ] **TCPView** open
- [ ] Extraction tool noted: <!-- 7-Zip / WinRAR / built-in Windows -->
- [ ] Extraction path on VM: <!-- e.g. C:\Users\win11\Desktop\extracted\ -->

## Extraction and inner payload execution

| Inner file | SHA256 | Type | How run |
|------------|--------|------|---------|
| | | | |

## Process tree (Process Explorer)

| Parent | Child | PID | Command line / notes |
|--------|--------|-----|---------------------|
| | | | |

## File system (Procmon)

| Path | Operation | Notes |
|------|-----------|-------|
| | | |

## Registry (Procmon)

| Key | Value name | Data / notes |
|-----|------------|--------------|
| | | |

## Network (TCPView / Procmon)

| Proto | Remote host / domain | Port | Notes |
|-------|----------------------|------|-------|
| | | | |

## Dynamic summary (portfolio-ready)

<!-- What happened after extraction and execution: drops, persistence, network callbacks. -->

## Post-run checklist

- [ ] Procmon log exported (not committed)
- [ ] Ingest tables: run `30_scripts\ingest-procmon.ps1 -SampleId SAMPLE_ID -ProcmonCsv <path>`
- [ ] IOCs appended to `40_iocs/indicators.csv`
- [ ] VM snapshot **reverted**

## Screenshots

`50_screenshots/SAMPLE_ID/`
'@

# ===========================================================================
# TYPE-SPECIFIC MITRE starting suggestions (frontmatter hints)
# ===========================================================================

$mitreByType = @{
    'PE'      = "  # T1204.002  # User Execution: Malicious File`n  # T1027    # Obfuscated Files or Information`n  # T1547.001  # Boot or Logon Autostart: Registry Run Keys"
    'Office'  = "  # T1566.001  # Phishing: Spearphishing Attachment`n  # T1059.001  # Command and Scripting Interpreter: PowerShell`n  # T1059.003  # Command and Scripting Interpreter: Windows Command Shell"
    'Script'  = "  # T1059    # Command and Scripting Interpreter`n  # T1027    # Obfuscated Files or Information`n  # T1140    # Deobfuscate/Decode Files or Information"
    'Archive' = "  # T1566.001  # Phishing: Spearphishing Attachment`n  # T1204.002  # User Execution: Malicious File`n  # T1027    # Obfuscated Files or Information"
}

$tagsByType = @{
    'PE'      = "  # - exe`n  # - pe"
    'Office'  = "  # - office-macro`n  # - ole"
    'Script'  = "  # - script"
    'Archive' = "  # - archive`n  # - container"
}

# ===========================================================================
# Select templates by type
# ===========================================================================

$tmplStatic  = switch ($Type) {
    'Office'  { $tmplStaticOffice }
    'Script'  { $tmplStaticScript }
    'Archive' { $tmplStaticArchive }
    default   { $tmplStaticPE }
}

$tmplDynamic = switch ($Type) {
    'Office'  { $tmplDynamicOffice }
    'Script'  { $tmplDynamicScript }
    'Archive' { $tmplDynamicArchive }
    default   { $tmplDynamicPE }
}

$mitreSeed = $mitreByType[$Type]
$tagSeed   = $tagsByType[$Type]

# ===========================================================================
# Write phase files
# ===========================================================================

$map = @{
    '00_original' = $tmplOriginal.Replace('SAMPLE_ID', $id).Replace('SAMPLE_TYPE', $Type)
    '01_static'   = $tmplStatic.Replace('SAMPLE_ID', $id)
    '02_dynamic'  = $tmplDynamic.Replace('SAMPLE_ID', $id)
}

foreach ($d in @('00_original', '01_static', '02_dynamic')) {
    $dirPath = Join-Path $root $d
    if (-not (Test-Path $dirPath)) { New-Item -ItemType Directory -Path $dirPath | Out-Null }
    $f = Join-Path $dirPath "$id.md"
    if (Test-Path $f) {
        Write-Warning "Already exists, skipping: $f"
    } else {
        Set-Content -Path $f -Value $map[$d] -Encoding UTF8
        Write-Host "  [created] $d\$id.md" -ForegroundColor Green
    }
}

# Findings file with YAML frontmatter (includes type field + seeded MITRE/tags)
$findingsPath = Join-Path $root "03_findings\$id.md"
if (Test-Path $findingsPath) {
    Write-Warning "Already exists, skipping: $findingsPath"
} else {
    $findingsContent = @"
---
schema_version: 1
sample_id: $id
name_tag: ""
sha256: ""
phase: findings
analyst: $Analyst
date_acquired: ""
date_analyzed: ""
sample_type: $Type
status: queued
verdict: unknown
family_guess: ""
family_confidence: ""
tags:
$tagSeed
mitre_techniques:
$mitreSeed
mb_url: ""
procmon_run: false
dynamic_complete: false
---

# $id -- findings (portfolio slice) [$Type]

**SHA256:** <!-- fill --> | **Confidence:** <!-- low / medium / medium-high / high -->

**Analyst one-liner:** <!-- one sentence verdict summary -->

Cross-references: [acquisition](../00_original/$id.md) | [static](../01_static/$id.md) | [dynamic](../02_dynamic/$id.md) | [screenshots](../50_screenshots/$id/)

---

## Verdict

- **Classification (working):**
- **Why:**

## IOCs (keep ``40_iocs/indicators.csv`` in sync)

| Type | Value | Notes |
|------|-------|-------|
| sha256 | | |

## What you proved

- **Static:**
- **Dynamic:**

## Gaps / next steps

1.

## Public-safe blurb

<!-- Self-contained portfolio paragraph. No internal paths, usernames, VM details, or
     information not suitable for public disclosure. -->
"@
    $findingsDir = Join-Path $root '03_findings'
    if (-not (Test-Path $findingsDir)) { New-Item -ItemType Directory -Path $findingsDir | Out-Null }
    Set-Content -Path $findingsPath -Value $findingsContent -Encoding UTF8
    Write-Host "  [created] 03_findings\$id.md" -ForegroundColor Green
}

# ===========================================================================
# Screenshot folder + SHOT_INDEX.txt
# ===========================================================================

$shotDir = Join-Path $root "50_screenshots\$id"
if (-not (Test-Path $shotDir)) {
    New-Item -ItemType Directory -Path $shotDir | Out-Null
    Write-Host "  [created] 50_screenshots\$id\" -ForegroundColor Green
}

$shotIndex = Join-Path $shotDir 'SHOT_INDEX.txt'
if (-not (Test-Path $shotIndex)) {
    $shotIndexContent = @"
$id -- screenshots (host) [Type: $Type]

Evidence hygiene checklist (complete before committing screenshots):
  [ ] VM username / hostname NOT visible in captured UI
  [ ] Analyst host machine paths NOT in any screenshot
  [ ] No personal information visible
  [ ] EXIF metadata stripped: run 30_scripts\strip-exif.ps1 -SampleId $id
  [ ] HEIC originals converted to PNG before committing
  [ ] Redact check passed: run 30_scripts\redact-check.ps1 -SampleId $id

Screenshot map (format: FILENAME -- tool/step -- what it shows):

"@
    Set-Content -Path $shotIndex -Value $shotIndexContent -Encoding UTF8
    Write-Host "  [created] 50_screenshots\$id\SHOT_INDEX.txt" -ForegroundColor Green
}

# ===========================================================================
# Append / update samples_tracker.csv
# ===========================================================================

if (Test-Path $csvPath) {
    $tracker = Import-Csv $csvPath
    $existingRow = $tracker | Where-Object { $_.sample_id -eq $id }

    if ($existingRow) {
        $existingRow.status = 'queued'
        $existingRow.notes  = "Scaffolded by new_sample.ps1 [Type: $Type]"
        $tracker | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "  [updated] samples_tracker.csv row for $id (status -> queued)" -ForegroundColor Yellow
    } else {
        $newLine = "$id,,,,queued,,Scaffolded by new_sample.ps1 [Type: $Type]"
        Add-Content -Path $csvPath -Value $newLine -Encoding UTF8
        Write-Host "  [appended] samples_tracker.csv row for $id" -ForegroundColor Green
    }
} else {
    Write-Warning "samples_tracker.csv not found -- skipping CSV update"
}

# ===========================================================================
# Done
# ===========================================================================

Write-Host ""
Write-Host "Scaffold complete: $id (Type: $Type)" -ForegroundColor Cyan
Write-Host ""

$nextSteps = switch ($Type) {
    'PE' {
        "  1. Fill 00_original\$id.md from MalwareBazaar (before VM download)`n" +
        "  2. Download sample inside VM only -- verify SHA256`n" +
        "  3. Static: DIE -> PEStudio -> CFF Explorer -> HxD`n" +
        "  4. Procmon + snapshot -> execute -> revert`n" +
        "  5. Ingest Procmon: 30_scripts\ingest-procmon.ps1 -SampleId $id -ProcmonCsv <path>`n" +
        "  6. Write verdict and IOCs in 03_findings\$id.md`n" +
        "  7. close_sample.ps1 -SampleId $id -Status done -RunValidate -RunExport"
    }
    'Office' {
        "  1. Fill 00_original\$id.md from source`n" +
        "  2. Static (host-safe): olevba --reveal FILE, oledump.py FILE`n" +
        "  3. Dynamic (VM): open in Office with Procmon + snapshot -> revert`n" +
        "  4. Ingest Procmon: 30_scripts\ingest-procmon.ps1 -SampleId $id -ProcmonCsv <path>`n" +
        "  5. Write verdict and IOCs in 03_findings\$id.md`n" +
        "  6. close_sample.ps1 -SampleId $id -Status done -RunValidate -RunExport"
    }
    'Script' {
        "  1. Fill 00_original\$id.md from source`n" +
        "  2. Static: open in text editor, decode obfuscation (CyberChef / PS decode)`n" +
        "  3. Dynamic (VM): execute with Procmon + snapshot -> revert`n" +
        "  4. Ingest Procmon: 30_scripts\ingest-procmon.ps1 -SampleId $id -ProcmonCsv <path>`n" +
        "  5. Write verdict and IOCs in 03_findings\$id.md`n" +
        "  6. close_sample.ps1 -SampleId $id -Status done -RunValidate -RunExport"
    }
    'Archive' {
        "  1. Fill 00_original\$id.md from source`n" +
        "  2. List archive contents (7z l FILE) -- do not extract to host`n" +
        "  3. Hash inner files inside VM, check against Bazaar / VT`n" +
        "  4. Dynamic (VM): extract + run inner payload with Procmon + snapshot -> revert`n" +
        "  5. Ingest Procmon: 30_scripts\ingest-procmon.ps1 -SampleId $id -ProcmonCsv <path>`n" +
        "  6. Write verdict and IOCs in 03_findings\$id.md`n" +
        "  7. close_sample.ps1 -SampleId $id -Status done -RunValidate -RunExport"
    }
}

Write-Host "Next steps ($Type workflow):" -ForegroundColor White
Write-Host $nextSteps -ForegroundColor Gray
