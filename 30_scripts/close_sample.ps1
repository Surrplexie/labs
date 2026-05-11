#Requires -Version 5.1
<#
.SYNOPSIS
    Closes (or advances) a sample slot: updates tracker status, prints a close checklist,
    and optionally runs validate + export-summary.

.DESCRIPTION
    Lifecycle stages (in order):
      queued  -> static  -> dynamic  -> done

    The script updates samples_tracker.csv with the new status, prints a checklist
    of tasks to complete before the slot is considered closed, and optionally runs
    validate.ps1 and export-summary.ps1 to keep INDEX.md current.

.PARAMETER SampleId
    The sample ID to close, e.g. sample_01 or just 1 (zero-padded automatically).

.PARAMETER Status
    New status to set. One of: queued, static, dynamic, done.

.PARAMETER RunValidate
    If set, run validate.ps1 after updating the tracker.

.PARAMETER RunExport
    If set, run export-summary.ps1 after updating the tracker.

.EXAMPLE
    # Mark sample_07 as static analysis complete
    powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_07 -Status static

    # Mark sample_01 fully done and regenerate index
    powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_01 -Status done -RunExport

    # Full pipeline: update, validate, and export
    powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_01 -Status done -RunValidate -RunExport
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SampleId,

    [Parameter(Mandatory = $true)]
    [ValidateSet('queued', 'static', 'dynamic', 'done')]
    [string]$Status,

    [switch]$RunValidate,
    [switch]$RunExport
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# Normalize sample ID (accept bare number)
if ($SampleId -match '^\d+$') {
    $SampleId = 'sample_{0:D2}' -f [int]$SampleId
}

# ---------------------------------------------------------------------------
# Load tracker
# ---------------------------------------------------------------------------

$csvPath = Join-Path $root 'samples_tracker.csv'
if (-not (Test-Path $csvPath)) {
    Write-Error "samples_tracker.csv not found at: $csvPath"
    exit 1
}

$tracker = Import-Csv $csvPath
$row     = $tracker | Where-Object { $_.sample_id -eq $SampleId }

if (-not $row) {
    Write-Error "Sample ID '$SampleId' not found in samples_tracker.csv"
    exit 1
}

$prevStatus = $row.status

# ---------------------------------------------------------------------------
# Update status
# ---------------------------------------------------------------------------

$row.status = $Status
$tracker | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "  $SampleId status: $prevStatus -> $Status" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# Checklist printed based on target status
# ---------------------------------------------------------------------------

function Write-Check { param([string]$msg) Write-Host "  [ ] $msg" -ForegroundColor White }
function Write-Done  { param([string]$msg) Write-Host "  [x] $msg" -ForegroundColor DarkGray }
function Write-Head  { param([string]$msg) Write-Host "  $msg" -ForegroundColor Yellow }

Write-Host "Close checklist for $SampleId ($Status):" -ForegroundColor Cyan
Write-Host ""

if ($Status -eq 'queued' -or $Status -eq 'static' -or $Status -eq 'dynamic' -or $Status -eq 'done') {
    Write-Head "-- 00_original --"
    Write-Check "SHA256 verified on VM matches MalwareBazaar value"
    Write-Check "All hash fields filled (SHA256, SHA1, MD5, imphash, ssdeep, TLSH)"
    Write-Check "URLs from Bazaar page recorded"
    Write-Check "YARA rule names recorded"
    Write-Check "Acquisition checklist boxes ticked"
    Write-Host ""
}

if ($Status -eq 'static' -or $Status -eq 'dynamic' -or $Status -eq 'done') {
    Write-Head "-- 01_static --"
    Write-Check "DIE: compiler, linker, packer, overlay recorded"
    Write-Check "PEStudio: entropy, version resource, imports, VT hits recorded"
    Write-Check "CFF Explorer: file size vs PE size, version info, timestamps recorded"
    Write-Check "HxD: signature bytes, section names recorded"
    Write-Check "Static summary paragraph written"
    Write-Check "Screenshot map filled in SHOT_INDEX.txt"
    Write-Host ""
}

if ($Status -eq 'dynamic' -or $Status -eq 'done') {
    Write-Head "-- 02_dynamic --"
    Write-Check "Pre-flight checklist complete (snapshot, Procmon, ProcExp, TCPView)"
    Write-Check "Execution details recorded (how launched, user context, observed UX)"
    Write-Check "Process tree populated from Procmon / Process Explorer"
    Write-Check "File system drops documented"
    Write-Check "Registry changes documented"
    Write-Check "Network connections / DNS documented"
    Write-Check "Dynamic summary paragraph written"
    Write-Check "VM snapshot reverted"
    Write-Host ""
}

if ($Status -eq 'done') {
    Write-Head "-- 03_findings --"
    Write-Check "YAML frontmatter fully filled (verdict, family_guess, tags, MITRE, dates)"
    Write-Check "Analyst one-liner written"
    Write-Check "Verdict and reasoning filled"
    Write-Check "IOC table complete"
    Write-Check "What you proved section filled"
    Write-Check "Gaps / next steps noted"
    Write-Check "Public-safe blurb written (no internal paths, usernames, or PII)"
    Write-Host ""

    Write-Head "-- IOC sync --"
    Write-Check "All IOCs appended to 40_iocs\indicators.csv"
    Write-Check "No duplicate IOC rows for $SampleId"
    Write-Host ""

    Write-Head "-- Evidence hygiene --"
    Write-Check "Run: 30_scripts\redact-check.ps1"
    Write-Check "Run: 30_scripts\strip-exif.ps1"
    Write-Check "SHOT_INDEX.txt hygiene checklist ticked"
    Write-Check "No HEIC files committed (convert to PNG)"
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Optional: run validate + export
# ---------------------------------------------------------------------------

if ($RunValidate) {
    Write-Host "Running validate.ps1..." -ForegroundColor DarkCyan
    $validateScript = Join-Path $root '30_scripts\validate.ps1'
    & powershell -ExecutionPolicy Bypass -File $validateScript
    Write-Host ""
}

if ($RunExport) {
    Write-Host "Running export-summary.ps1..." -ForegroundColor DarkCyan
    $exportScript = Join-Path $root '30_scripts\export-summary.ps1'
    & powershell -ExecutionPolicy Bypass -File $exportScript
    Write-Host ""
}

Write-Host "Done. $SampleId marked as '$Status'." -ForegroundColor Green
if (-not $RunValidate -or -not $RunExport) {
    Write-Host ""
    Write-Host "Tip: re-run with -RunValidate -RunExport to verify integrity and refresh INDEX.md" -ForegroundColor DarkGray
}
