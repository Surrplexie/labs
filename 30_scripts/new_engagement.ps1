#Requires -Version 5.1
<#
.SYNOPSIS
    Scaffold a new engagement slot across all phase folders.

.DESCRIPTION
    Supports four engagement kinds. Each kind gets type-specific templates in the
    standard four phase folders (00_original, 01_static, 02_dynamic, 03_findings),
    a 50_screenshots folder, and a row in samples_tracker.csv.

    Kinds:
      file   - malware/artifact triage (PE / Office / Script / Archive)
      ctf    - CTF or HackTheBox/TryHackMe challenge
      lab    - guided course / training lab / module
      hunt   - hypothesis-driven threat detection exercise

    Phase folder meaning by kind:
      file:  acquisition -> static triage -> dynamic triage -> findings/IOCs
      ctf:   challenge brief -> recon/enum -> solve attempt -> writeup
      lab:   lab brief/objectives -> steps/procedure -> results -> reflection
      hunt:  scope/hypothesis -> data collection -> analysis -> outcome

.PARAMETER NextNumber
    Slot number to create (1-99). Zero-padded to sample_XX.

.PARAMETER Kind
    Engagement kind. One of: file (default), ctf, lab, hunt.

.PARAMETER Type
    File sample type (only used when Kind=file).
    One of: PE (default), Office, Script, Archive.

.PARAMETER Analyst
    Analyst name for frontmatter. Defaults to 'Surrplexie'.

.PARAMETER Platform
    Platform name for ctf/lab kinds. E.g. "HackTheBox", "TryHackMe", "PicoCTF".

.PARAMETER Title
    Short title / challenge name. Used as name_tag in the tracker.

.EXAMPLE
    # File sample (PE, default)
    powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 7

    # File sample (Office document)
    powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 7 -Kind file -Type Office

    # CTF challenge
    powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 7 -Kind ctf -Platform "HackTheBox" -Title "Lame"

    # Training lab
    powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 8 -Kind lab -Platform "TryHackMe" -Title "Introductory Researching"

    # Threat hunt
    powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 9 -Kind hunt -Title "Lateral movement via SMB"
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 99)]
    [int]$NextNumber,

    [ValidateSet('file', 'ctf', 'lab', 'hunt')]
    [string]$Kind = 'file',

    [ValidateSet('PE', 'Office', 'Script', 'Archive')]
    [string]$Type = 'PE',

    [string]$Analyst = 'Surrplexie',
    [string]$Platform = '',
    [string]$Title    = '',

    [switch]$OverwriteEmpty,
    [switch]$ReserveOnly
)

$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root '00_original'))) {
    Write-Error "Cannot find 00_original under repo root: $root"
    exit 1
}

$id   = 'sample_{0:D2}' -f $NextNumber
$date = Get-Date -Format 'yyyy-MM-dd'

# ---------------------------------------------------------------------------
# Guard: slot already in use
# ---------------------------------------------------------------------------
$csvPath = Join-Path $root 'samples_tracker.csv'
if (Test-Path $csvPath) {
    $tracker = Import-Csv $csvPath
    $existing = $tracker | Where-Object { $_.sample_id -eq $id }
    if ($existing -and $existing.status.Trim().ToLower() -ne 'empty') {
        if ($OverwriteEmpty) {
            Write-Warning "Slot $id is not empty (status '$($existing.status)'). Refusing overwrite."
            exit 1
        }
        Write-Warning "Slot $id already exists with status '$($existing.status)'. Use a different number or clear the slot first."
        exit 1
    }
    if ($existing -and $existing.status.Trim().ToLower() -eq 'empty') {
        $OverwriteEmpty = $true
    }
}

Write-Host ""
if ($Kind -eq 'file') {
    Write-Host "Scaffolding $id (Kind: file / Type: $Type) ..." -ForegroundColor Cyan
} else {
    Write-Host "Scaffolding $id (Kind: $Kind) ..." -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function New-PhaseFile {
    param([string]$dir, [string]$content)
    $folder = Join-Path $root $dir
    if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
    $path = Join-Path $folder "$id.md"
    if ((Test-Path $path) -and -not $OverwriteEmpty) {
        Write-Warning "  $dir\$id.md already exists -- skipping."
        return
    }
    $verb = if (Test-Path $path) { 'Updated' } else { 'Created' }
    Set-Content -Path $path -Value $content -Encoding UTF8
    Write-Host "  $verb`: $dir\$id.md" -ForegroundColor Green
}

# ============================================================
# ====  FILE TEMPLATES  ======================================
# ============================================================

# ---- FILE: 00_original ----
$tmplFileOriginal = @'
# SAMPLE_ID -- original receipt (host log)

**Purpose:** Record identification and sourcing before/at acquisition. Binaries stay VM-only.

| Field | Value |
|-------|-------|
| **Sample ID** | SAMPLE_ID |
| **MalwareBazaar URL** | <!-- https://malwarebazaar.abuse.ch/sample/SHA256/ --> |
| **SHA256** | <!-- 64-char hex --> |
| **SHA1** | <!-- 40-char hex --> |
| **MD5** | <!-- 32-char hex --> |
| **File name (claimed)** | <!-- e.g. invoice.exe --> |
| **Mime / type** | <!-- application/x-dosexec --> |
| **Size** | <!-- bytes --> |
| **First seen (Bazaar)** | <!-- YYYY-MM-DD --> |
| **Bazaar verdict** | <!-- unknown / malicious --> |
| **Vendor detections** | <!-- count --> |

## Delivery and context

| Field | Value |
|-------|-------|
| **Delivery method** | <!-- web / email / unknown --> |
| **Reporter** | <!-- handle or blank --> |
| **Tags (Bazaar)** | <!-- exe / doc / etc --> |
| **Magika** | <!-- pebin / etc --> |
| **TrID (top)** | <!-- top match --> |

## Hashes for clustering

| Field | Value | Notes |
|-------|-------|-------|
| **imphash** | | Clustering hint only |
| **ssdeep** | | Fuzzy similarity |
| **TLSH** | | Locality-sensitive hash |

## URLs from Bazaar page

| Kind | URL |
|------|-----|
| | |

## YARA rules flagged

| Rule | Author | Implication |
|------|--------|-------------|
| | | |

## Acquisition checklist (VM)

- [ ] Download inside VM only.
- [ ] SHA256 verified on VM.
- [ ] Sample path on VM noted.
- [ ] Never copy binary to host.

## Cross-references

- Static: [01_static/SAMPLE_ID.md](../01_static/SAMPLE_ID.md)
- Dynamic: [02_dynamic/SAMPLE_ID.md](../02_dynamic/SAMPLE_ID.md)
- Findings: [03_findings/SAMPLE_ID.md](../03_findings/SAMPLE_ID.md)
- IOCs: [40_iocs/indicators.csv](../40_iocs/indicators.csv)
- Screenshots: [50_screenshots/SAMPLE_ID/](../50_screenshots/SAMPLE_ID/)
'@

# ---- FILE: 01_static (PE) ----
$tmplStaticPE = @'
# SAMPLE_ID -- static triage (PE)

| Field | Value |
|-------|-------|
| **SHA256** | <!-- from 00_original --> |
| **Name / tag** | <!-- claimed filename --> |
| **Date analyzed** | DATE |
| **VM user** | win11 |

> CFF Explorer may show a PE-image-only hash on overlay-heavy samples. Full-file hash from Get-FileHash is the canonical reference.

## DIE

- **PE type / arch:** <!-- PE32 / PE32+ / I386 / AMD64 / GUI / Console -->
- **Linker / compiler:** <!-- e.g. MSVC 14.x -->
- **Packer / installer:** <!-- UPX / NSIS / none -->
- **Overlay:** <!-- offset and size if present -->
- **Heuristic:** <!-- any flags -->

## PEStudio

- **Entropy:** <!-- 0.0 - 8.0 -->
- **Version resource:** <!-- FileDescription / ProductName / CompanyName -->
- **Manifest:** <!-- embedded or absent -->
- **Imports:** <!-- count; any blacklisted? -->
- **Sections:** <!-- list with notable flags -->
- **VirusTotal (in UI):** <!-- N/66 -->

## CFF Explorer

- **File size:** <!-- bytes --> | **PE image size:** <!-- bytes; note gap if overlay present -->
- **Version info:** <!-- FileDescription / ProductName string -->
- **PE timestamp:** <!-- hex + decoded date -->
- **Section table:** <!-- names and notable characteristics -->

## HxD

- **Magic:** <!-- MZ at 0x0, PE\0\0 at offset -->
- **Section names visible:** <!-- .text .rdata .ndata .upx0 etc -->
- **Notable hex patterns:** <!-- any embedded markers -->

## Static summary (portfolio-ready)

<!-- One paragraph: packaging, entropy, version resource, any deception signals, next steps. -->

## Screenshot map

| # | File | Tool | What it shows |
|---|------|------|---------------|
| | | | |

Cross-references: [acquisition](../00_original/SAMPLE_ID.md) | [dynamic](../02_dynamic/SAMPLE_ID.md) | [findings](../03_findings/SAMPLE_ID.md) | [screenshots](../50_screenshots/SAMPLE_ID/)
'@

$tmplStaticOffice = @'
# SAMPLE_ID -- static triage (Office document)

| Field | Value |
|-------|-------|
| **SHA256** | <!-- from 00_original --> |
| **Filename** | <!-- e.g. invoice_March.docm --> |
| **Date analyzed** | DATE |
| **VM user** | win11 |

## olevba / oletools

- **Macros present:** <!-- yes / no -->
- **Auto-exec triggers:** <!-- AutoOpen / Document_Open / etc -->
- **Suspicious keywords:** <!-- Shell / CreateObject / URLDownloadToFile -->
- **VBA code summary:** <!-- brief description -->

## oledump

- **Stream list:** <!-- stream index, size, name, indicator -->
- **Notable streams:** <!-- which ones contain macros or objects -->

## Strings (interesting output)

| String | Type | Notes |
|--------|------|-------|
| | URL | |
| | Path | |
| | Command | |

## Static summary (portfolio-ready)

<!-- packaging, macro presence, triggers, command fragments, confidence level. -->

## Screenshot map

| # | File | Tool | What it shows |
|---|------|------|---------------|
| | | | |

Cross-references: [acquisition](../00_original/SAMPLE_ID.md) | [dynamic](../02_dynamic/SAMPLE_ID.md) | [findings](../03_findings/SAMPLE_ID.md) | [screenshots](../50_screenshots/SAMPLE_ID/)
'@

$tmplStaticScript = @'
# SAMPLE_ID -- static triage (script)

| Field | Value |
|-------|-------|
| **SHA256** | <!-- from 00_original --> |
| **Script type** | <!-- PS1 / VBS / HTA / BAT / JS / PY / other --> |
| **Filename** | <!-- claimed name --> |
| **Date analyzed** | DATE |
| **VM user** | win11 |

## Structure overview

- **Obfuscation:** <!-- none / base64 / XOR / char array / concat / other -->
- **Encoding:** <!-- UTF-8 / UTF-16LE / ASCII -->
- **Approximate LOC:** <!-- lines of code -->
- **Key functions / blocks:** <!-- brief list -->

## Deobfuscation notes

<!-- Steps taken to decode: layer 1, layer 2, etc. Paste decoded snippets. -->

## Extracted strings / artifacts

| String | Type | Notes |
|--------|------|-------|
| | URL | |
| | Command | |
| | Registry | |

## Static summary (portfolio-ready)

<!-- obfuscation layers, decoded behavior, confidence level. -->

Cross-references: [acquisition](../00_original/SAMPLE_ID.md) | [dynamic](../02_dynamic/SAMPLE_ID.md) | [findings](../03_findings/SAMPLE_ID.md) | [screenshots](../50_screenshots/SAMPLE_ID/)
'@

$tmplStaticArchive = @'
# SAMPLE_ID -- static triage (archive / container)

| Field | Value |
|-------|-------|
| **SHA256** | <!-- from 00_original --> |
| **Archive format** | <!-- ZIP / RAR / 7z / ISO / CAB / TAR / other --> |
| **Filename** | <!-- claimed name --> |
| **Date analyzed** | DATE |
| **VM user** | win11 |

## Archive manifest (list without extracting)

| Inner file | SHA256 (if tool shows) | DIE type | Notes |
|-----------|----------------------|----------|-------|
| | | | |

## Extraction notes

- **Password protected:** <!-- yes / no / attempted wordlist -->
- **Nested archives:** <!-- any zip-in-zip or similar -->
- **Extraction tool:** <!-- 7-Zip / unzip / other -->

## Inner files: initial static notes

<!-- For each inner PE/script/doc, brief notes. Full analysis goes in a child engagement slot if warranted. -->

## Static summary (portfolio-ready)

Cross-references: [acquisition](../00_original/SAMPLE_ID.md) | [dynamic](../02_dynamic/SAMPLE_ID.md) | [findings](../03_findings/SAMPLE_ID.md) | [screenshots](../50_screenshots/SAMPLE_ID/)
'@

# ---- FILE: 02_dynamic (PE) ----
$tmplDynamicPE = @'
# SAMPLE_ID -- dynamic triage (PE)

| Field | Value |
|-------|-------|
| **SHA256** | <!-- from 00_original --> |
| **Date analyzed** | DATE |
| **VM type** | Windows 11 lab VM (user win11) |
| **AV / real-time protection** | Off |
| **Snapshot name** | <!-- e.g. clean_DATE --> |
| **Instrumentation** | <!-- Procmon / ProcExp / TCPView / Wireshark --> |

Cross-references: [findings](../03_findings/SAMPLE_ID.md) | [static](../01_static/SAMPLE_ID.md) | [acquisition](../00_original/SAMPLE_ID.md) | [screenshots](../50_screenshots/SAMPLE_ID/)

---

## Pre-flight

- [ ] Clean snapshot restored.
- [ ] Procmon started (filter by process name).
- [ ] Process Explorer open.
- [ ] TCPView open.
- [ ] AV confirmed off.

## Execution

- **How launched:** <!-- double-click / cmd / PowerShell -->
- **On-disk name:** <!-- path on VM -->
- **User context:** <!-- standard / elevated -->
- **Immediate UX:** <!-- what appeared on screen -->

## Process tree

| PID | Parent PID | Name | Command line / notes |
|-----|-----------|------|---------------------|
| | | | |

## File system (Procmon WriteFile / CreateFile)

| Path | Operation | Notes |
|------|-----------|-------|
| | | |

## Registry (Procmon RegSetValue)

| Key | Value name | Data | Notes |
|-----|-----------|------|-------|
| | | | |

## Network (TCPView / Wireshark)

| Proto | Remote host | Port | Notes |
|-------|------------|------|-------|
| | | | |

## Post-run observations

- Services: <!-- any new? -->
- Scheduled tasks: <!-- any new? -->
- Injected modules: <!-- any? -->
- VM snapshot reverted: [ ]

## Dynamic summary (portfolio-ready)

<!-- What the sample did: drops, persistence, network, deception. -->
'@

$tmplDynamicOffice = @'
# SAMPLE_ID -- dynamic triage (Office document)

| Field | Value |
|-------|-------|
| **SHA256** | <!-- from 00_original --> |
| **Date analyzed** | DATE |
| **VM type** | Windows 11 lab VM (user win11) |
| **AV / macro security** | Off / enabled all macros |
| **Snapshot name** | <!-- e.g. clean_DATE --> |
| **Instrumentation** | <!-- Procmon / ProcExp / TCPView --> |

Cross-references: [findings](../03_findings/SAMPLE_ID.md) | [static](../01_static/SAMPLE_ID.md) | [acquisition](../00_original/SAMPLE_ID.md)

---

## Pre-flight

- [ ] Clean snapshot restored.
- [ ] Procmon started.
- [ ] Macro security set to "Enable All Macros" (or security dialog forced accept).
- [ ] Office version on VM noted: <!-- Word 2016 / 2019 / 365 -->

## Execution

- **File opened with:** <!-- Word / Excel / other -->
- **Macro prompt:** <!-- appeared / bypassed / auto-executed -->
- **Immediate UX:** <!-- document content, lure, any visible activity -->

## Process tree

| PID | Parent | Name | Command line / notes |
|-----|--------|------|---------------------|
| | WINWORD.EXE | | |

## File system (Procmon -- key events)

| Path | Operation | Notes |
|------|-----------|-------|
| | | |

## Registry (Procmon -- key events)

| Key | Value name | Data | Notes |
|-----|-----------|------|-------|
| | | | |

## Network

| Proto | Remote | Port | Notes |
|-------|--------|------|-------|
| | | | |

## Dynamic summary (portfolio-ready)
'@

$tmplDynamicScript = @'
# SAMPLE_ID -- dynamic triage (script)

| Field | Value |
|-------|-------|
| **SHA256** | <!-- from 00_original --> |
| **Date analyzed** | DATE |
| **VM type** | Windows 11 lab VM (user win11) |
| **Execution context** | <!-- PowerShell 5.1 / wscript / cscript / node --> |
| **Snapshot name** | <!-- e.g. clean_DATE --> |

Cross-references: [findings](../03_findings/SAMPLE_ID.md) | [static](../01_static/SAMPLE_ID.md)

---

## Pre-flight

- [ ] Clean snapshot restored.
- [ ] Procmon started.
- [ ] Script execution policy noted: <!-- Bypass / Unrestricted / etc -->

## Execution

- **Run with:** <!-- powershell -ep bypass .\script.ps1 / wscript script.vbs -->
- **Terminal / console visible:** <!-- yes/no -->
- **Immediate visible behavior:** <!-- any console output, windows, UI -->

## Process tree

| PID | Parent | Name | Command line |
|-----|--------|------|-------------|
| | | | |

## File system

| Path | Operation | Notes |
|------|-----------|-------|
| | | |

## Network

| Proto | Remote | Port | Notes |
|-------|--------|------|-------|
| | | | |

## Dynamic summary (portfolio-ready)
'@

$tmplDynamicArchive = @'
# SAMPLE_ID -- dynamic triage (archive)

| Field | Value |
|-------|-------|
| **SHA256** | <!-- outer archive --> |
| **Date analyzed** | DATE |
| **VM type** | Windows 11 lab VM (user win11) |
| **Snapshot name** | <!-- e.g. clean_DATE --> |

Cross-references: [findings](../03_findings/SAMPLE_ID.md) | [static](../01_static/SAMPLE_ID.md)

---

## Extraction and execution

- **Extracted to:** <!-- VM path -->
- **Inner file(s) of interest:** <!-- list -->
- **Executed:** <!-- which inner file, how -->

## Process tree (from inner executable)

| PID | Parent | Name | Command line |
|-----|--------|------|-------------|
| | | | |

## File system

| Path | Operation | Notes |
|------|-----------|-------|
| | | |

## Network

| Proto | Remote | Port | Notes |
|-------|--------|------|-------|
| | | | |

## Dynamic summary (portfolio-ready)
'@

# ---- FILE: 03_findings ----
$mitreByType = @{
    'PE'      = '- T1027    # Obfuscated Files or Information'
    'Office'  = '- T1566.001  # Spearphishing Attachment'
    'Script'  = '- T1059.001  # Command and Scripting Interpreter: PowerShell'
    'Archive' = '- T1027    # Obfuscated Files or Information'
}
$tagsByType  = @{
    'PE'      = '  - exe'
    'Office'  = '  - office'
    'Script'  = '  - script'
    'Archive' = '  - archive'
}
$mitreSeed = $mitreByType[$Type]
$tagSeed   = $tagsByType[$Type]

$tmplFindingsFile = @'
---
schema_version: 1
engagement_kind: file
sample_id: SAMPLE_ID
name_tag: ""
sha256: ""
phase: findings
analyst: ANALYST
date_acquired: "DATE"
date_analyzed: "DATE"
status: queued
verdict: unknown
sample_type: SAMPLE_TYPE
family_guess: ""
family_confidence: medium
tags:
TAG_SEED
mitre_techniques:
MITRE_SEED
mb_url: ""
procmon_run: false
dynamic_complete: false
---

# SAMPLE_ID -- findings (portfolio slice)

**SHA256:** ``<!-- fill -->``

**Confidence:** <!-- overall confidence statement with reasoning -->

**Analyst one-liner:** <!-- single sentence summary -->

Cross-references: [acquisition](../00_original/SAMPLE_ID.md) | [static](../01_static/SAMPLE_ID.md) | [dynamic](../02_dynamic/SAMPLE_ID.md) | [screenshots](../50_screenshots/SAMPLE_ID/) | [IOCs](../40_iocs/indicators.csv)

## Verdict

- **Classification:** <!-- benign / suspicious / malicious / unknown -->
- **Why (static):** <!-- key static signals -->
- **Why (dynamic):** <!-- key dynamic signals; or "not yet run" -->

## IOCs (keep 40_iocs/indicators.csv in sync)

| Type | Value | Notes |
|------|-------|-------|
| sha256 | | Canonical sample |
| sha1 | | |
| md5 | | |

## What you proved

- <!-- Claim 1: evidence source, confidence level -->
- <!-- Claim 2: evidence source, confidence level -->

## Gaps / next steps

1. <!-- What is not yet confirmed -->

## Public-safe blurb

<!-- Portfolio paragraph: no internal paths, usernames, or PII. -->
'@

# ============================================================
# ====  CTF TEMPLATES  =======================================
# ============================================================

$tmplCtfOriginal = @'
# SAMPLE_ID -- CTF challenge brief

**Kind:** CTF  |  **Platform:** PLATFORM_VAL  |  **Status:** assigned

| Field | Value |
|-------|-------|
| **Engagement ID** | SAMPLE_ID |
| **Platform** | PLATFORM_VAL |
| **Challenge name** | TITLE_VAL |
| **Category** | <!-- web / pwn / rev / crypto / forensics / misc / osint / ... --> |
| **Difficulty** | <!-- easy / medium / hard / insane --> |
| **Points** | <!-- e.g. 20 --> |
| **Analyst** | ANALYST |
| **Date started** | DATE |

## Challenge description

<!-- Paste or paraphrase the challenge prompt here. Do NOT include raw flags. -->

## Initial attack surface

<!-- What is given: IP, URL, file download, source code, description text. -->

## Resources / attachments

| Resource | Notes |
|---------|-------|
| <!-- IP:PORT or URL --> | |
| <!-- filename.zip --> | |

## Cross-references

- Recon: [01_static/SAMPLE_ID.md](../01_static/SAMPLE_ID.md)
- Solve: [02_dynamic/SAMPLE_ID.md](../02_dynamic/SAMPLE_ID.md)
- Writeup: [03_findings/SAMPLE_ID.md](../03_findings/SAMPLE_ID.md)
- Screenshots: [50_screenshots/SAMPLE_ID/](../50_screenshots/SAMPLE_ID/)
'@

$tmplCtfRecon = @'
# SAMPLE_ID -- CTF recon / enumeration

**Platform:** PLATFORM_VAL  |  **Challenge:** TITLE_VAL

## Target info

| Field | Value |
|-------|-------|
| **IP / URL** | <!-- target address --> |
| **OS** | <!-- if known --> |
| **Open ports** | <!-- nmap summary --> |

## Enumeration log

| Step | Tool | Command | Output / notes |
|------|------|---------|----------------|
| 1 | nmap | `nmap -sC -sV -oN nmap.txt <IP>` | |
| 2 | | | |

## Service details

<!-- Per open port/service: version, interesting endpoints, auth prompts. -->

## Web (if applicable)

| Path | Response | Notes |
|------|---------|-------|
| `/` | 200 | |
| `/admin` | | |

## Interesting findings / leads

<!-- Credentials, version strings, misconfigurations, file paths, user names. -->

## Screenshot map

| # | File | What it shows |
|---|------|---------------|
| | | |

Cross-references: [brief](../00_original/SAMPLE_ID.md) | [solve](../02_dynamic/SAMPLE_ID.md) | [writeup](../03_findings/SAMPLE_ID.md) | [screenshots](../50_screenshots/SAMPLE_ID/)
'@

$tmplCtfSolve = @'
# SAMPLE_ID -- CTF solve attempt

**Platform:** PLATFORM_VAL  |  **Challenge:** TITLE_VAL

## Approach log

| # | Action | Tool / command | Result |
|---|--------|----------------|--------|
| 1 | | | |
| 2 | | | |

## Exploits / techniques attempted

| Technique | Status | Notes |
|-----------|--------|-------|
| | Tried | |
| | Worked | |

## Rabbit holes

<!-- Dead ends worth documenting so you don't repeat them. -->

## Flag capture

> **PUBLIC-SAFE NOTE:** Do not paste raw flags in this file if the challenge is
> still active. Use a placeholder like `[FLAG REDACTED -- challenge active]`
> until writeup release is permitted. Check `public_writeup_safe` in the
> findings frontmatter.

- **Solved:** [ ]
- **Method summary:** <!-- short description: "exploited SQLi -> LFI -> RCE -> root.txt" -->
- **Flag format / hint only:** <!-- e.g. "HTB{...}" -- redact the actual value -->

## Screenshot map

| # | File | What it shows |
|---|------|---------------|
| | | |

Cross-references: [brief](../00_original/SAMPLE_ID.md) | [recon](../01_static/SAMPLE_ID.md) | [writeup](../03_findings/SAMPLE_ID.md)
'@

$tmplCtfFindings = @'
---
schema_version: 2
engagement_id: SAMPLE_ID
engagement_kind: ctf
title: "TITLE_VAL"
analyst: ANALYST
platform: "PLATFORM_VAL"
category: ""
difficulty: ""
points: 0
date_started: "DATE"
date_closed: ""
status: recon
outcome: unknown
solved: false
public_writeup_safe: false
confidence: medium
tags:
  - ctf
skills:
  - ""
---

# SAMPLE_ID -- CTF writeup

**Platform:** PLATFORM_VAL  |  **Challenge:** TITLE_VAL

> **Note:** Only publish full writeup (including method) after `public_writeup_safe: true`.
> Ensure the challenge is retired or writeup release is explicitly permitted.

## Summary

| Field | Value |
|-------|-------|
| **Platform** | PLATFORM_VAL |
| **Category** | |
| **Difficulty** | |
| **Points** | |
| **Solved** | false |

## Methodology

<!-- Narrative of the full solve path from initial access to flag. -->

## Key steps

| Step | What | Why it worked |
|------|------|---------------|
| 1 | | |

## What you learned

<!-- New technique, tool, or concept encountered in this challenge. -->

## Gaps / what did not work

<!-- For incomplete challenges: what was tried, where stuck. -->

## Public-safe blurb (portfolio)

<!-- One paragraph suitable for a portfolio or resume. No raw flags, no live credentials. -->
'@

# ============================================================
# ====  LAB TEMPLATES  =======================================
# ============================================================

$tmplLabOriginal = @'
# SAMPLE_ID -- lab brief / objectives

**Kind:** Lab  |  **Platform:** PLATFORM_VAL  |  **Status:** not_started

| Field | Value |
|-------|-------|
| **Engagement ID** | SAMPLE_ID |
| **Course / platform** | PLATFORM_VAL |
| **Module / lab name** | TITLE_VAL |
| **Environment** | <!-- VM name only - no IPs, no credentials --> |
| **Analyst** | ANALYST |
| **Date started** | DATE |

## Learning objectives

1. <!-- Objective 1 -->
2. <!-- Objective 2 -->
3. <!-- Objective 3 -->

## Prerequisites

<!-- Tools or knowledge expected before starting. -->

## Environment setup

- [ ] VPN / access connected (credentials NOT stored here)
- [ ] Lab VM started / container running
- [ ] Required tools installed: <!-- list -->

## Resources

| Resource | Notes |
|---------|-------|
| <!-- Lab URL --> | |
| <!-- Supporting docs --> | |

## Cross-references

- Steps: [01_static/SAMPLE_ID.md](../01_static/SAMPLE_ID.md)
- Results: [02_dynamic/SAMPLE_ID.md](../02_dynamic/SAMPLE_ID.md)
- Reflection: [03_findings/SAMPLE_ID.md](../03_findings/SAMPLE_ID.md)
- Screenshots: [50_screenshots/SAMPLE_ID/](../50_screenshots/SAMPLE_ID/)
'@

$tmplLabSteps = @'
# SAMPLE_ID -- lab steps / procedure

**Course:** PLATFORM_VAL  |  **Lab:** TITLE_VAL

## Step log

| Step | Action | Command / tool | Expected output | Actual output |
|------|--------|----------------|-----------------|---------------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |

## Commands reference

```
# Paste key commands here for quick re-use
```

## Observations per step

<!-- Notes on each step: what worked, what didn't, and why. -->

## Questions raised

<!-- Things to look up or follow up on after the lab. -->

## Screenshot map

| # | File | What it shows |
|---|------|---------------|
| | | |

Cross-references: [brief](../00_original/SAMPLE_ID.md) | [results](../02_dynamic/SAMPLE_ID.md) | [reflection](../03_findings/SAMPLE_ID.md)
'@

$tmplLabResults = @'
# SAMPLE_ID -- lab results

**Course:** PLATFORM_VAL  |  **Lab:** TITLE_VAL

## Objectives completion

| Objective | Met? | Evidence / notes |
|-----------|------|-----------------|
| <!-- Obj 1 --> | [ ] | |
| <!-- Obj 2 --> | [ ] | |
| <!-- Obj 3 --> | [ ] | |

## Errors / issues encountered

| Issue | Root cause | Resolution |
|-------|-----------|-----------|
| | | |

## Output / proof

<!-- Paste final output, hashes, or references to screenshots. No credentials. -->

## Screenshot map

| # | File | What it shows |
|---|------|---------------|
| | | |

Cross-references: [brief](../00_original/SAMPLE_ID.md) | [steps](../01_static/SAMPLE_ID.md) | [reflection](../03_findings/SAMPLE_ID.md)
'@

$tmplLabFindings = @'
---
schema_version: 2
engagement_id: SAMPLE_ID
engagement_kind: lab
title: "TITLE_VAL"
analyst: ANALYST
course: "PLATFORM_VAL"
module: "TITLE_VAL"
environment: ""
date_started: "DATE"
date_closed: ""
status: not_started
outcome: unknown
objectives_met: false
confidence: high
tags:
  - lab
skills:
  - ""
---

# SAMPLE_ID -- lab reflection

**Course:** PLATFORM_VAL  |  **Lab:** TITLE_VAL

## Final objectives status

| Objective | Met | Notes |
|-----------|-----|-------|
| | [ ] | |

## Key takeaways

<!-- What was learned or reinforced. Specific technique, tool, or concept. -->

## Challenges

<!-- What was hard and why. -->

## Skills demonstrated

<!-- Enumerate skills exercised: useful for portfolio / resume. -->

## Next steps / follow-on labs

<!-- Related labs or reading that builds on this one. -->

## Public-safe blurb (portfolio)

<!-- One paragraph. No credentials, no instance IPs, no raw challenge flags. -->
'@

# ============================================================
# ====  HUNT TEMPLATES  ======================================
# ============================================================

$tmplHuntOriginal = @'
# SAMPLE_ID -- hunt scope

**Kind:** Hunt  |  **Status:** scoped

| Field | Value |
|-------|-------|
| **Engagement ID** | SAMPLE_ID |
| **Hypothesis** | TITLE_VAL |
| **Data sources** | <!-- Event Logs / Sysmon / EDR / SIEM --> |
| **Time box** | <!-- e.g. 2 hours --> |
| **Environment** | <!-- lab / simulated / real-data-sanitized --> |
| **Analyst** | ANALYST |
| **Date started** | DATE |

## Hypothesis

<!-- Full hypothesis statement: "Attacker used X technique to achieve Y in environment Z." -->

## Data sources

| Source | Access method | Notes |
|--------|--------------|-------|
| <!-- Windows Event Log --> | <!-- local / SIEM query --> | |
| <!-- Sysmon --> | | |

## Tools

| Tool | Purpose |
|------|---------|
| | |

## Out of scope

<!-- What this hunt explicitly does NOT cover. -->

## Cross-references

- Collection: [01_static/SAMPLE_ID.md](../01_static/SAMPLE_ID.md)
- Analysis: [02_dynamic/SAMPLE_ID.md](../02_dynamic/SAMPLE_ID.md)
- Outcome: [03_findings/SAMPLE_ID.md](../03_findings/SAMPLE_ID.md)
- Screenshots: [50_screenshots/SAMPLE_ID/](../50_screenshots/SAMPLE_ID/)
'@

$tmplHuntCollection = @'
# SAMPLE_ID -- hunt data collection

**Hypothesis:** TITLE_VAL

## Queries run

| Query | Tool / source | Results count | Notes |
|-------|--------------|---------------|-------|
| | | | |

## Raw findings (before filtering)

<!-- Paste or summarise relevant log entries, events, or records. Sanitise any PII. -->

## Event IDs / sources referenced

| Event ID | Source | Meaning |
|---------|--------|---------|
| 4688 | Security | Process creation |
| 1 | Sysmon | Process creation |
| | | |

## Screenshot map

| # | File | What it shows |
|---|------|---------------|
| | | |

Cross-references: [scope](../00_original/SAMPLE_ID.md) | [analysis](../02_dynamic/SAMPLE_ID.md) | [outcome](../03_findings/SAMPLE_ID.md)
'@

$tmplHuntAnalysis = @'
# SAMPLE_ID -- hunt analysis

**Hypothesis:** TITLE_VAL

## Timeline

| Time (relative) | Event | Source | Notes |
|----------------|-------|--------|-------|
| T+00:00 | | | |

## Patterns observed

<!-- Recurring behaviors, process chains, network patterns. -->

## Correlation

<!-- How different data sources corroborate each other. -->

## False positives encountered

| Signal | Why it is a FP | Notes |
|--------|---------------|-------|
| | | |

## Detections / IOC candidates

| Type | Value | Confidence | Notes |
|------|-------|-----------|-------|
| | | | |

Cross-references: [scope](../00_original/SAMPLE_ID.md) | [collection](../01_static/SAMPLE_ID.md) | [outcome](../03_findings/SAMPLE_ID.md)
'@

$tmplHuntFindings = @'
---
schema_version: 2
engagement_id: SAMPLE_ID
engagement_kind: hunt
title: "TITLE_VAL"
analyst: ANALYST
hypothesis: "TITLE_VAL"
data_sources:
  - ""
timebox: ""
date_started: "DATE"
date_closed: ""
status: scoped
outcome: unknown
detections_found: false
confidence: medium
tags:
  - hunt
skills:
  - ""
---

# SAMPLE_ID -- hunt outcome

**Hypothesis:** TITLE_VAL

## Outcome

| Field | Value |
|-------|-------|
| **Hypothesis confirmed?** | <!-- yes / no / partial / inconclusive --> |
| **Detections found** | <!-- count or none --> |
| **Confidence** | <!-- high / medium / low --> |
| **Time spent** | |

## Confirmed detections

| Type | Value | Confidence | Evidence |
|------|-------|-----------|----------|
| | | | |

## Confidence reasoning

<!-- Why you rate confidence at this level: data quality, coverage gaps, etc. -->

## Gaps / what would improve this hunt

<!-- Missing data sources, better queries, longer time box, additional tools. -->

## Recommendations

<!-- Concrete next steps: alert rule, SIEM query to productionize, follow-on hunt. -->

## Public-safe blurb (portfolio)

<!-- One paragraph. No internal hostnames, user accounts, or sensitive org data. -->
'@

# ============================================================
# ====  SHOT INDEX  ==========================================
# ============================================================

$tmplShotIndex = @'
# SHOT_INDEX.txt
# Screenshot index and evidence hygiene checklist for SAMPLE_ID
# Kind: KIND_VAL
#
# MAP: file -> what it shows
# ----------------------------

# HYGIENE CHECKLIST
# ------------------
# [ ] All screenshots taken inside VM only
# [ ] HEIC / iPhone originals converted to PNG (pillow / heif-convert / Preview)
# [ ] exiftool strip run before commit: strip-exif.ps1
# [ ] No screenshots contain host machine username, internal paths, or credentials
# [ ] SHOT_INDEX updated with file list below
'@

# ============================================================
# ====  SELECT AND WRITE TEMPLATES  ==========================
# ============================================================

$titleVal    = if ($Title)    { $Title }    else { '' }
$platformVal = if ($Platform) { $Platform } else { '' }

function Apply-Template {
    param([string]$t)
    $t = $t.Replace('SAMPLE_ID', $id)
    $t = $t.Replace('ANALYST',   $Analyst)
    $t = $t.Replace('DATE',      $date)
    $t = $t.Replace('TITLE_VAL',    $titleVal)
    $t = $t.Replace('PLATFORM_VAL', $platformVal)
    $t = $t.Replace('KIND_VAL',     $Kind)
    $t = $t.Replace('SAMPLE_TYPE',  $Type)
    $t = $t.Replace('TAG_SEED',     $tagSeed)
    $t = $t.Replace('MITRE_SEED',   $mitreSeed)
    return $t
}

switch ($Kind) {
    'file' {
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
        New-PhaseFile '00_original' (Apply-Template $tmplFileOriginal)
        New-PhaseFile '01_static'   (Apply-Template $tmplStatic)
        New-PhaseFile '02_dynamic'  (Apply-Template $tmplDynamic)
        New-PhaseFile '03_findings' (Apply-Template $tmplFindingsFile)
    }
    'ctf' {
        New-PhaseFile '00_original' (Apply-Template $tmplCtfOriginal)
        New-PhaseFile '01_static'   (Apply-Template $tmplCtfRecon)
        New-PhaseFile '02_dynamic'  (Apply-Template $tmplCtfSolve)
        New-PhaseFile '03_findings' (Apply-Template $tmplCtfFindings)
    }
    'lab' {
        New-PhaseFile '00_original' (Apply-Template $tmplLabOriginal)
        New-PhaseFile '01_static'   (Apply-Template $tmplLabSteps)
        New-PhaseFile '02_dynamic'  (Apply-Template $tmplLabResults)
        New-PhaseFile '03_findings' (Apply-Template $tmplLabFindings)
    }
    'hunt' {
        New-PhaseFile '00_original' (Apply-Template $tmplHuntOriginal)
        New-PhaseFile '01_static'   (Apply-Template $tmplHuntCollection)
        New-PhaseFile '02_dynamic'  (Apply-Template $tmplHuntAnalysis)
        New-PhaseFile '03_findings' (Apply-Template $tmplHuntFindings)
    }
}

# ============================================================
# ====  SCREENSHOTS FOLDER + SHOT_INDEX  =====================
# ============================================================

$ssDir      = Join-Path $root "50_screenshots\$id"
$shotIndex  = Join-Path $ssDir 'SHOT_INDEX.txt'
$gitkeep    = Join-Path $ssDir '.gitkeep'

if (-not (Test-Path $ssDir)) {
    New-Item -ItemType Directory -Path $ssDir | Out-Null
    Write-Host "  Created: 50_screenshots\$id\" -ForegroundColor Green
}

if ((-not (Test-Path $shotIndex)) -or $OverwriteEmpty) {
  $shotVerb = if (Test-Path $shotIndex) { 'Updated' } else { 'Created' }
  Set-Content -Path $shotIndex -Value (Apply-Template $tmplShotIndex) -Encoding UTF8
  Write-Host "  $shotVerb`: 50_screenshots\$id\SHOT_INDEX.txt" -ForegroundColor Green
}

if (-not (Get-ChildItem $ssDir -File | Where-Object { $_.Name -ne 'SHOT_INDEX.txt' })) {
    New-Item -ItemType File -Path $gitkeep -Force | Out-Null
}

# ============================================================
# ====  TRACKER UPDATE  ======================================
# ============================================================

$initStatus = switch ($Kind) {
    'ctf'  { 'assigned' }
    'lab'  { 'not_started' }
    'hunt' { 'scoped' }
    default { 'queued' }
}

if (Test-Path $csvPath) {
    $tracker = Import-Csv $csvPath
    $existing = $tracker | Where-Object { $_.sample_id -eq $id }

    # Determine column names present
    $cols = $tracker[0].PSObject.Properties.Name

    if ($existing) {
        if ($ReserveOnly) {
            if ($cols -contains 'engagement_kind') { $existing.engagement_kind = $Kind }
            if ($cols -contains 'notes' -and [string]::IsNullOrWhiteSpace($existing.notes)) {
                $existing.notes = 'Reserve -- fill when assigned'
            }
            $tracker | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
            Write-Host "  Tracker: $id kept empty (reserve slot)" -ForegroundColor Green
        } else {
            $existing.status          = $initStatus
            $existing.name_tag        = $titleVal
            if ($cols -contains 'engagement_kind') { $existing.engagement_kind = $Kind }
            if ($cols -contains 'platform')        { $existing.platform        = $platformVal }
            if ($cols -contains 'date_started')    { $existing.date_started    = $date }
            $tracker | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
            Write-Host "  Updated tracker: $id -> $initStatus" -ForegroundColor Green
        }
    } else {
        $newRow = [ordered]@{}
        foreach ($col in $cols) { $newRow[$col] = '' }
        $newRow['sample_id'] = $id
        $newRow['status']    = if ($ReserveOnly) { 'empty' } else { $initStatus }
        $newRow['name_tag']  = $titleVal
        if ($cols -contains 'engagement_kind') { $newRow['engagement_kind'] = $Kind }
        if ($cols -contains 'platform')        { $newRow['platform']        = $platformVal }
        if ($cols -contains 'date_started')    { $newRow['date_started']    = if ($ReserveOnly) { '' } else { $date } }
        if ($cols -contains 'notes')           { $newRow['notes']           = 'Reserve -- fill when assigned' }

        $tracker += [pscustomobject]$newRow
        $tracker | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "  Appended tracker: $id ($($newRow['status']))" -ForegroundColor Green
    }
} else {
    Write-Warning "samples_tracker.csv not found; tracker not updated."
}

# ============================================================
# ====  SUMMARY  =============================================
# ============================================================

Write-Host ""
Write-Host "Done. $id scaffolded ($Kind)." -ForegroundColor Green
Write-Host ""

switch ($Kind) {
    'file' {
        Write-Host "Next steps (file):" -ForegroundColor Yellow
        Write-Host "  1. Find sample on MalwareBazaar / your source"
        Write-Host "  2. Fill 00_original\$id.md with hash set and URLs"
        Write-Host "  3. Download to VM only, verify SHA256"
        Write-Host "  4. Run static tools; fill 01_static\$id.md"
        Write-Host "  5. Run with Procmon; fill 02_dynamic\$id.md"
        Write-Host "  6. Fill 03_findings\$id.md with verdict and IOCs"
        Write-Host "  7. Run: .\30_scripts\close_sample.ps1 -SampleId $id -Status done -RunValidate -RunExport"
    }
    'ctf' {
        Write-Host "Next steps (ctf):" -ForegroundColor Yellow
        Write-Host "  1. Fill 00_original\$id.md with challenge description"
        Write-Host "  2. Enumerate target; fill 01_static\$id.md"
        Write-Host "  3. Attempt solve; fill 02_dynamic\$id.md"
        Write-Host "  4. After solve (and writeup is permitted): fill 03_findings\$id.md"
        Write-Host "  5. Run: .\30_scripts\close_sample.ps1 -SampleId $id -Status writeup_done -RunValidate -RunExport"
    }
    'lab' {
        Write-Host "Next steps (lab):" -ForegroundColor Yellow
        Write-Host "  1. Fill 00_original\$id.md with objectives"
        Write-Host "  2. Work through lab; log steps in 01_static\$id.md"
        Write-Host "  3. Record results in 02_dynamic\$id.md"
        Write-Host "  4. Write reflection in 03_findings\$id.md"
        Write-Host "  5. Run: .\30_scripts\close_sample.ps1 -SampleId $id -Status reviewed -RunValidate -RunExport"
    }
    'hunt' {
        Write-Host "Next steps (hunt):" -ForegroundColor Yellow
        Write-Host "  1. Fill 00_original\$id.md with hypothesis and scope"
        Write-Host "  2. Run queries; log findings in 01_static\$id.md"
        Write-Host "  3. Analyse patterns; fill 02_dynamic\$id.md"
        Write-Host "  4. Write outcome in 03_findings\$id.md"
        Write-Host "  5. Run: .\30_scripts\close_sample.ps1 -SampleId $id -Status closed -RunValidate -RunExport"
    }
}
