#Requires -Version 5.1
<#
.SYNOPSIS
    Bulk manage 04_writeups stubs: remove placeholder files, create missing stubs,
    or re-scaffold with correct kind from tracker.

.DESCRIPTION
    Three modes:

    remove            - Delete 04_writeups/sample_*.md files that are stubs
                        (writeup_status: placeholder OR line count <= Threshold).
                        Files with real content (line count > Threshold) are skipped.

    stub              - Create a minimal _stub.md placeholder for every ACTIVE slot
                        that currently has no 04_writeups file. Does not touch existing files.

    kind-from-tracker - For each existing 04_writeups file whose engagement_kind does not
                        match the tracker, re-scaffold with the correct kind (uses -Overwrite).
                        Only affects stubs (line count <= Threshold); skips real content.

.PARAMETER Mode
    One of: remove | stub | kind-from-tracker

.PARAMETER Threshold
    Line count at or below which a file is considered a stub / safe to overwrite.
    Default: 20. Increase if your stubs are longer.

.PARAMETER DryRun
    Show what would be done without making any changes.

.EXAMPLE
    # Preview what would be removed
    powershell -ExecutionPolicy Bypass -File .\30_scripts\reset_writeup_stubs.ps1 -Mode remove -DryRun

    # Remove all placeholder stubs
    powershell -ExecutionPolicy Bypass -File .\30_scripts\reset_writeup_stubs.ps1 -Mode remove

    # Seed a minimal stub for every active slot without a 04 file
    powershell -ExecutionPolicy Bypass -File .\30_scripts\reset_writeup_stubs.ps1 -Mode stub

    # Fix kind mismatches (stubs only)
    powershell -ExecutionPolicy Bypass -File .\30_scripts\reset_writeup_stubs.ps1 -Mode kind-from-tracker
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('remove', 'stub', 'kind-from-tracker')]
    [string]$Mode,

    [int]$Threshold = 20,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$root        = Split-Path -Parent $PSScriptRoot
$csvPath     = Join-Path $root 'samples_tracker.csv'
$writeupDir  = Join-Path $root '04_writeups'
$scaffoldSc  = Join-Path $PSScriptRoot 'scaffold_writeup.ps1'

if (-not (Test-Path $csvPath)) { Write-Error "samples_tracker.csv not found."; exit 1 }

$tracker    = Import-Csv $csvPath
$activeRows = $tracker | Where-Object { $_.sample_id -ne '' -and $_.status -ne '' -and $_.name_tag -ne '' }

$dryTag = if ($DryRun) { ' [DRY RUN]' } else { '' }

Write-Host "`n=== reset_writeup_stubs.ps1 | mode: $Mode$dryTag ===" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# Helper: is a 04_writeups file a stub (short / placeholder)?
# ---------------------------------------------------------------------------
function Is-Stub {
    param([string]$Path, [int]$Threshold)
    if (-not (Test-Path $Path)) { return $false }
    $lines = (Get-Content $Path -Encoding UTF8 | Measure-Object -Line).Lines
    $raw   = Get-Content $Path -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    $statusVal = if ($raw -match '(?m)^status:\s*(\S+)') { $Matches[1].Trim() } else { '' }
    return ($lines -le $Threshold -or $statusVal -eq 'placeholder')
}

# ---------------------------------------------------------------------------
# Helper: get engagement_kind from tracker row
# ---------------------------------------------------------------------------
function Get-Kind {
    param($Row)
    $k = if ($Row.PSObject.Properties.Name -contains 'engagement_kind' -and $Row.engagement_kind) {
             $Row.engagement_kind.Trim().ToLower()
         } else { 'file' }
    return $k
}

$changed = 0
$skipped = 0

# ---------------------------------------------------------------------------
# MODE: remove
# ---------------------------------------------------------------------------
if ($Mode -eq 'remove') {
    $files = Get-ChildItem $writeupDir -Filter 'sample_*.md' -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        if (Is-Stub -Path $f.FullName -Threshold $Threshold) {
            Write-Host "  REMOVE  $($f.Name)" -ForegroundColor Yellow
            if (-not $DryRun) { Remove-Item $f.FullName -Force }
            $changed++
        } else {
            $lineCount = (Get-Content $f.FullName -Encoding UTF8 | Measure-Object -Line).Lines
            Write-Host "  SKIP    $($f.Name)  ($lineCount lines -- real content)" -ForegroundColor DarkGray
            $skipped++
        }
    }
    if ($changed -eq 0 -and $skipped -eq 0) {
        Write-Host "  No 04_writeups files found." -ForegroundColor DarkGray
    }
}

# ---------------------------------------------------------------------------
# MODE: stub
# ---------------------------------------------------------------------------
if ($Mode -eq 'stub') {
    foreach ($row in $activeRows) {
        $id   = $row.sample_id.Trim()
        $kind = Get-Kind -Row $row
        $dest = Join-Path $writeupDir "$id.md"
        if (Test-Path $dest) {
            Write-Host "  EXISTS  $id.md -- skipping" -ForegroundColor DarkGray
            $skipped++
        } else {
            Write-Host "  CREATE  $id.md  (kind: $kind)" -ForegroundColor Green
            if (-not $DryRun) {
                & powershell -ExecutionPolicy Bypass -File $scaffoldSc -SampleId $id -Kind stub
            }
            $changed++
        }
    }
}

# ---------------------------------------------------------------------------
# MODE: kind-from-tracker
# ---------------------------------------------------------------------------
if ($Mode -eq 'kind-from-tracker') {
    $files = Get-ChildItem $writeupDir -Filter 'sample_*.md' -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $id  = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        $row = $tracker | Where-Object { $_.sample_id -eq $id } | Select-Object -First 1
        if (-not $row) {
            Write-Host "  SKIP    $($f.Name)  (no tracker row)" -ForegroundColor DarkGray
            $skipped++
            continue
        }

        $trackerKind = Get-Kind -Row $row
        $raw         = Get-Content $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        $fileKind    = if ($raw -match '(?m)^engagement_kind:\s*(\S+)') { $Matches[1].Trim().ToLower() } else { '' }

        if ($fileKind -eq $trackerKind) {
            Write-Host "  OK      $($f.Name)  kind: $trackerKind" -ForegroundColor DarkGray
            $skipped++
            continue
        }

        if (-not (Is-Stub -Path $f.FullName -Threshold $Threshold)) {
            Write-Host "  SKIP    $($f.Name)  kind mismatch ($fileKind != $trackerKind) but file has real content -- fix manually" -ForegroundColor Yellow
            $skipped++
            continue
        }

        Write-Host "  RESEED  $($f.Name)  $fileKind -> $trackerKind" -ForegroundColor Cyan
        if (-not $DryRun) {
            & powershell -ExecutionPolicy Bypass -File $scaffoldSc -SampleId $id -Kind stub -Overwrite
        }
        $changed++
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  Changed : $changed  |  Skipped : $skipped$dryTag" -ForegroundColor Cyan
if ($DryRun -and $changed -gt 0) {
    Write-Host "  Re-run without -DryRun to apply." -ForegroundColor Yellow
}
Write-Host ""
