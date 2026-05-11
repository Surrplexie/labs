#Requires -Version 5.1
<#
.SYNOPSIS
    Scaffolds a new sample slot across all phase folders.

.DESCRIPTION
    Creates four phase .md files, a 50_screenshots/sample_XX/ folder with a
    SHOT_INDEX.txt hygiene checklist, and appends a row to samples_tracker.csv.

    Files created:
      00_original/sample_XX.md   - acquisition receipt and hash record
      01_static/sample_XX.md     - static triage (DIE, PEStudio, CFF, HxD)
      02_dynamic/sample_XX.md    - dynamic triage (Procmon, ProcExp, network)
      03_findings/sample_XX.md   - verdict, IOCs, YAML frontmatter, portfolio blurb
      50_screenshots/sample_XX/  - screenshot folder with SHOT_INDEX.txt

.PARAMETER NextNumber
    The slot number to create (1-99). The ID will be zero-padded (e.g., 7 -> sample_07).

.PARAMETER Analyst
    Analyst name written into the YAML frontmatter. Defaults to 'Surrplexie'.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 7
    powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 7 -Analyst Surrplexie
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 99)]
    [int]$NextNumber,

    [string]$Analyst = 'Surrplexie'
)

$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root '00_original'))) {
    Write-Error "Cannot find 00_original under repo root: $root"
    exit 1
}

$id   = 'sample_{0:D2}' -f $NextNumber
$dirs = @('00_original', '01_static', '02_dynamic', '03_findings')

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

# ---------------------------------------------------------------------------
# Templates - single-quoted here-strings; SAMPLE_ID replaced after
# NOTE: all content is ASCII-safe for PS 5.1 CP1252 script loading
# ---------------------------------------------------------------------------

$tmplOriginal = @'
# SAMPLE_ID -- original receipt (host log)

**Purpose:** Record identification and sourcing before/at acquisition. Binaries stay VM-only.
Populate from MalwareBazaar *before* download.

| Field | Value |
|--------|--------|
| **Sample ID** | `SAMPLE_ID` |
| **MalwareBazaar URL** | |
| **SHA256** | |
| **SHA1** | |
| **MD5** | |
| **File name (claimed)** | |
| **MIME / type** | |
| **Size** | |
| **First seen (Bazaar)** | |
| **Last seen** | |
| **Bazaar verdict** | |
| **Vendor detections** | |

## Delivery & context

| Field | Value |
|--------|--------|
| **Delivery method** | |
| **Reporter** | |
| **Tags** | |
| **Magika** | |
| **TrID (top)** | |

## Hashes for clustering / lookups

| Field | Value | Notes |
|--------|--------|--------|
| **imphash** | | |
| **ssdeep** | | |
| **TLSH** | | |
| **dhash icon** | | |

## URLs referenced on Bazaar page (IOC leads)

| Kind | URL / note |
|------|------------|
| | |

## YARA rules flagged

| Rule | Author | Implication (rough) |
|------|--------|---------------------|
| | | |

## Bazaar intelligence snippets

| Metric | Value |
|--------|--------|
| `# of uploads` | |
| `# of downloads` | |
| **Origin country** | |

## Acquisition checklist (VM)

- [ ] Download **inside VM only** (Bazaar login / API)
- [ ] **SHA256 verified on VM** -- matches Bazaar value
- [ ] VM path documented (no sensitive analyst-machine paths here)
- [ ] Optional: clean **snapshot taken before** first run
- [ ] **Never** copy `.exe` / binary to this host logbook PC

## Cross-links

- Static notes: `01_static/SAMPLE_ID.md`
- Dynamic notes: `02_dynamic/SAMPLE_ID.md`
- Findings: `03_findings/SAMPLE_ID.md`
- Screenshots: `50_screenshots/SAMPLE_ID/`
'@

$tmplStatic = @'
# SAMPLE_ID -- static triage

**SHA256:** <!-- fill --> | **Date:** <!-- fill -->

**Host evidence:** `50_screenshots/SAMPLE_ID/`

## Session results

| Step | Done? | Notes |
|------|-------|-------|
| DIE | | |
| PEStudio | | |
| CFF Explorer | | |
| HxD | | |

## Hash reconcile

<!-- Note if any tool hash differs from the full-file Bazaar hash and explain why
     (e.g., CFF may show PE-image-only hash vs whole-file hash on overlay-heavy samples) -->

---

## DIE

<!-- Compiler, linker, installer type, packer heuristic, overlay details -->

## PEStudio

<!-- SHA256 confirm, entropy, version resource, manifest, imports count, overlay, VT hits -->

## CFF Explorer

<!-- File type, file size vs PE image size, version info, NTFS timestamps (VM local time) -->

## HxD

<!-- Signature bytes at 0x0, section names visible in ASCII column, interesting offsets -->

---

## Static summary (portfolio-ready)

<!-- One paragraph suitable for public portfolio:
     structure, tooling evidence, packaging type, confidence level, next steps -->

## Screenshot map

| File | Tool | What it shows |
|------|------|----------------|
| | | |

## Cross-links

- Original: `00_original/SAMPLE_ID.md`
- Dynamic: `02_dynamic/SAMPLE_ID.md`
- Findings: `03_findings/SAMPLE_ID.md`
- Screenshots: `50_screenshots/SAMPLE_ID/`
'@

$tmplDynamic = @'
# SAMPLE_ID -- dynamic triage

**SHA256:** <!-- fill --> | **Run date:** <!-- fill -->

## Pre-flight checklist

- [ ] Clean snapshot baseline confirmed
- [ ] **Procmon** capture started (boot or pre-run)
- [ ] **Process Explorer** open
- [ ] **TCPView** / Wireshark running (if network capture needed)
- [ ] AV / real-time protection status noted

## Execution

- **How launched:** <!-- double-click / cmd / script -->
- **User context:** <!-- standard user / elevated -->
- **Observed UX:** <!-- dialogs, errors, silent, etc. -->

## Process tree

| Parent | Child | Command line / notes |
|--------|--------|---------------------|
| | | |

## File system

| Path | Operation | Notes |
|------|-----------|-------|
| | | |

## Registry

| Key | Value name | Data / notes |
|-----|------------|--------------|
| | | |

## Network

| Proto | Remote host | Port | Notes |
|-------|-------------|------|-------|
| | | | |

## Dynamic summary

<!-- Combine static context with observed runtime behavior.
     Append confirmed network indicators to 40_iocs/indicators.csv -->

## Post-run checklist

- [ ] Procmon log exported and filtered (CSV)
- [ ] Screenshots captured and indexed in SHOT_INDEX.txt
- [ ] IOCs appended to `40_iocs/indicators.csv`
- [ ] VM snapshot **reverted**

## Screenshots

`50_screenshots/SAMPLE_ID/`

## Cross-links

- Original: `00_original/SAMPLE_ID.md`
- Static: `01_static/SAMPLE_ID.md`
- Findings: `03_findings/SAMPLE_ID.md`
'@

# findings template is built dynamically (needs analyst name)

# ---------------------------------------------------------------------------
# Write phase files
# ---------------------------------------------------------------------------

$map = @{
    '00_original' = $tmplOriginal.Replace('SAMPLE_ID', $id)
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

# Findings file with YAML frontmatter
$findingsPath = Join-Path $root "03_findings\$id.md"
if (Test-Path $findingsPath) {
    Write-Warning "Already exists, skipping: $findingsPath"
} else {
    $findingsContent = @"
---
sample_id: $id
sha256: ""
phase: findings
analyst: $Analyst
date_acquired: ""
date_analyzed: ""
status: queued
verdict: unknown
family_guess: ""
family_confidence: ""
tags: []
mitre_techniques: []
mb_url: ""
procmon_run: false
dynamic_complete: false
---

# $id -- findings (portfolio slice)

**SHA256:** <!-- fill --> | **Confidence:** <!-- low / medium / medium-high / high -->

**Analyst one-liner:** <!-- one sentence verdict summary -->

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
     information not suitable for public disclosure. This section is safe to share. -->
"@
    Set-Content -Path $findingsPath -Value $findingsContent -Encoding UTF8
    Write-Host "  [created] 03_findings\$id.md" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Screenshot folder + SHOT_INDEX.txt
# ---------------------------------------------------------------------------

$shotDir = Join-Path $root "50_screenshots\$id"
if (-not (Test-Path $shotDir)) {
    New-Item -ItemType Directory -Path $shotDir | Out-Null
    Write-Host "  [created] 50_screenshots\$id\" -ForegroundColor Green
}

$shotIndex = Join-Path $shotDir 'SHOT_INDEX.txt'
if (-not (Test-Path $shotIndex)) {
    $shotIndexContent = @"
$id -- screenshots (host)

Evidence hygiene checklist (complete before committing screenshots):
  [ ] VM username / hostname NOT visible in captured UI (check window titles, path bars)
  [ ] Analyst host machine paths NOT in any screenshot
  [ ] No personal information visible (email, real names, internal domains)
  [ ] EXIF metadata stripped: run   30_scripts\strip-exif.ps1
  [ ] HEIC originals converted to PNG before committing (HEIC may not render on GitHub)
  [ ] Redact check passed: run       30_scripts\redact-check.ps1

Screenshot map:
  (add rows as you capture -- format: FILENAME -- tool/step -- what it shows)

"@
    Set-Content -Path $shotIndex -Value $shotIndexContent -Encoding UTF8
    Write-Host "  [created] 50_screenshots\$id\SHOT_INDEX.txt" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Append / update samples_tracker.csv
# ---------------------------------------------------------------------------

if (Test-Path $csvPath) {
    $tracker = Import-Csv $csvPath
    $existingRow = $tracker | Where-Object { $_.sample_id -eq $id }

    if ($existingRow) {
        # Slot exists (was empty) -- update in place
        $existingRow.status = 'queued'
        $existingRow.notes  = 'Scaffolded by new_sample.ps1'
        $tracker | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
        Write-Host "  [updated] samples_tracker.csv row for $id (status -> queued)" -ForegroundColor Yellow
    } else {
        # Append new row
        $newLine = "$id,,,,queued,,Scaffolded by new_sample.ps1"
        Add-Content -Path $csvPath -Value $newLine -Encoding UTF8
        Write-Host "  [appended] samples_tracker.csv row for $id" -ForegroundColor Green
    }
} else {
    Write-Warning "samples_tracker.csv not found -- skipping CSV update"
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Scaffold complete: $id" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Fill 00_original\$id.md from MalwareBazaar (before VM download)" -ForegroundColor Gray
Write-Host "  2. Download sample inside VM only -- verify SHA256" -ForegroundColor Gray
Write-Host "  3. Static analysis: DIE -> PEStudio -> CFF Explorer -> HxD" -ForegroundColor Gray
Write-Host "  4. Optional: Procmon-instrumented dynamic run (snapshot + revert)" -ForegroundColor Gray
Write-Host "  5. Write verdict and IOCs in 03_findings\$id.md" -ForegroundColor Gray
Write-Host "  6. Run: close_sample.ps1 -SampleId $id -Status done" -ForegroundColor Gray
Write-Host "  7. Run: export-summary.ps1  (regenerates INDEX.md)" -ForegroundColor Gray
