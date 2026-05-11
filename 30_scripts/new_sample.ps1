<# 
  Creates parallel sample_XX.md across 00_original, 01_static, 02_dynamic, 03_findings
  and a screenshots folder. Run from repo root:
    powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 6
#>
param(
  [Parameter(Mandatory = $true)]
  [int]$NextNumber
)

# Repo root is parent of 30_scripts (this file lives in tests\30_scripts).
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root '00_original'))) {
  Write-Error "Cannot find 00_original under repo root: $root"
  exit 1
}

$id = 'sample_{0:D2}' -f $NextNumber
$dirs = @('00_original', '01_static', '02_dynamic', '03_findings')

$original = @"
# $id — original receipt (host log)

**Sample ID:** ``$id``

| Field | Value |
|--------|--------|
| MalwareBazaar URL |  |
| SHA256 |  |
| SHA1 / MD5 |  |
| Tag / notes |  |

## Acquisition checklist (VM)

- [ ] VM-only download
- [ ] VM path:
- [ ] No binary on host

## Paste area


"@

$static = @"
# $id — static triage

**SHA256:** · **Date:**

## DIE



## PEStudio



## CFF Explorer



## HxD



## Static summary



## Screenshots

``screenshots/$id/``

"@

$dynamic = @"
# $id — dynamic triage

**SHA256:** · **Run date:**

## Pre-flight



## Execution



## Process tree



## File system



## Registry



## Network



## Dynamic summary



## Screenshots

``screenshots/$id/``

"@

$findings = @"
# $id — findings

**SHA256:** · **Confidence:**

## Verdict



## IOCs



## What you proved



## Gaps / next steps



## Public-safe blurb



"@

$map = @{
  '00_original'  = $original
  '01_static'    = $static
  '02_dynamic'   = $dynamic
  '03_findings'  = $findings
}

foreach ($d in $dirs) {
  $dirPath = Join-Path $root $d
  if (-not (Test-Path $dirPath)) { New-Item -ItemType Directory -Path $dirPath | Out-Null }
  $f = Join-Path $dirPath "$id.md"
  if (Test-Path $f) { Write-Warning "Exists: $f"; continue }
  Set-Content -Path $f -Value $map[$d] -Encoding UTF8
}

$shot = Join-Path $root "screenshots\$id"
if (-not (Test-Path $shot)) { New-Item -ItemType Directory -Path $shot | Out-Null }

$csv = Join-Path $root 'samples_tracker.csv'
if (Test-Path $csv) {
  $line = "$id,,,,empty,,Added by new_sample.ps1"
  Add-Content -Path $csv -Value $line -Encoding UTF8
}

Write-Host "Created $id across phase folders and screenshots\$id"
