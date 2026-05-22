#Requires -Version 5.1
<#
.SYNOPSIS
    Seed phase-folder templates for all 50 engagement slots in one pass.

.DESCRIPTION
    For each slot in samples_tracker.csv (01–50), creates the four phase files
    (00_original, 01_static, 02_dynamic, 03_findings) using kind-correct templates.

    Slot 01 is skipped by default (has real content). Reserve slots (no name_tag,
    status empty) are seeded with -ReserveOnly so the tracker status stays 'empty'.
    Active slots (name_tag set, status non-empty) are also skipped by default.

    Calls new_engagement.ps1 for each eligible slot, so all template content stays
    in sync with the main scaffolding system.

.PARAMETER SkipActive
    Skip slots that already have a non-empty status in the tracker (default: true).
    Set -SkipActive:$false to also re-seed active slots that are missing phase files.

.PARAMETER SkipExisting
    Skip any slot that already has all four phase files (default: true).
    Set -SkipExisting:$false to overwrite existing stubs.

.PARAMETER WithWriteup
    Also seed 04_writeups/_stub.md placeholder for each slot seeded.

.PARAMETER SkipSlot1
    Skip sample_01 (default: true). Set -SkipSlot1:$false to include it.

.PARAMETER DryRun
    Print what would be done without making any changes.

.PARAMETER SlotRange
    Comma-separated list or hyphen range of slot numbers to process.
    Default: 1-50. Examples: "2-50", "31-40", "2,5,10".

.EXAMPLE
    # Preview all 50 slots
    powershell -ExecutionPolicy Bypass -File .\30_scripts\seed_all_slots.ps1 -DryRun

    # Seed reserve slots 02-50 (skip sample_01 and any active slots)
    powershell -ExecutionPolicy Bypass -File .\30_scripts\seed_all_slots.ps1

    # Seed only the CTF band (31-40)
    powershell -ExecutionPolicy Bypass -File .\30_scripts\seed_all_slots.ps1 -SlotRange "31-40"

    # Seed and also create 04_writeups stubs
    powershell -ExecutionPolicy Bypass -File .\30_scripts\seed_all_slots.ps1 -WithWriteup
#>

param(
    [bool]$SkipActive   = $true,
    [bool]$SkipExisting = $true,
    [bool]$SkipSlot1    = $true,
    [switch]$WithWriteup,
    [switch]$DryRun,
    [string]$SlotRange  = '1-50'
)

$ErrorActionPreference = 'Stop'

$root       = Split-Path -Parent $PSScriptRoot
$csvPath    = Join-Path $root 'samples_tracker.csv'
$newScript  = Join-Path $PSScriptRoot 'new_engagement.ps1'
$wuScript   = Join-Path $PSScriptRoot 'scaffold_writeup.ps1'

if (-not (Test-Path $csvPath))   { Write-Error "samples_tracker.csv not found."; exit 1 }
if (-not (Test-Path $newScript)) { Write-Error "new_engagement.ps1 not found.";  exit 1 }

# ---------------------------------------------------------------------------
# Parse slot range
# ---------------------------------------------------------------------------
function Parse-SlotRange {
    param([string]$Spec)
    $nums = @()
    foreach ($part in $Spec -split ',') {
        $part = $part.Trim()
        if ($part -match '^(\d+)-(\d+)$') {
            $nums += [int]$Matches[1]..[int]$Matches[2]
        } elseif ($part -match '^\d+$') {
            $nums += [int]$part
        } else {
            Write-Warning "Ignoring unrecognised slot spec: '$part'"
        }
    }
    return $nums | Sort-Object -Unique
}

$targetSlots = Parse-SlotRange -Spec $SlotRange

# ---------------------------------------------------------------------------
# Load tracker
# ---------------------------------------------------------------------------
$tracker = Import-Csv $csvPath

function Get-TrackerRow {
    param([string]$Id)
    return $tracker | Where-Object { $_.sample_id.Trim() -eq $Id } | Select-Object -First 1
}

function Get-SlotKind {
    param([int]$Num, $Row)
    if ($Row -and $Row.PSObject.Properties.Name -contains 'engagement_kind' -and $Row.engagement_kind) {
        $k = $Row.engagement_kind.Trim().ToLower()
        if ($k -in @('file','ctf','lab','hunt')) { return $k }
    }
    # slot band fallback
    if ($Num -ge 1  -and $Num -le 30) { return 'file' }
    if ($Num -ge 31 -and $Num -le 40) { return 'ctf' }
    if ($Num -ge 41 -and $Num -le 45) { return 'lab' }
    if ($Num -ge 46 -and $Num -le 50) { return 'hunt' }
    return 'file'
}

function Has-AllPhaseFiles {
    param([string]$Id)
    $phases = @('00_original','01_static','02_dynamic','03_findings')
    foreach ($p in $phases) {
        if (-not (Test-Path (Join-Path $root "$p\$Id.md"))) { return $false }
    }
    return $true
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
$dryTag  = if ($DryRun) { ' [DRY RUN]' } else { '' }
$seeded  = 0
$skipped = 0

Write-Host ""
Write-Host "=== seed_all_slots.ps1$dryTag ===" -ForegroundColor Cyan
Write-Host "  Range: $SlotRange | SkipActive: $SkipActive | SkipExisting: $SkipExisting | WithWriteup: $($WithWriteup.IsPresent)"
Write-Host ""

foreach ($num in $targetSlots) {
    $id  = 'sample_{0:D2}' -f $num
    $row = Get-TrackerRow -Id $id

    # ---- Skip slot 1 ----
    if ($SkipSlot1 -and $num -eq 1) {
        Write-Host "  SKIP  $id  (slot 1 -- real content; use -SkipSlot1:`$false to include)" -ForegroundColor DarkGray
        $skipped++
        continue
    }

    # ---- Skip active slots ----
    if ($SkipActive -and $row) {
        $status = $row.status.Trim().ToLower()
        $tag    = $row.name_tag.Trim()
        if ($status -notin @('', 'empty') -and $tag -ne '') {
            Write-Host "  SKIP  $id  (active: status='$status', tag='$tag')" -ForegroundColor DarkGray
            $skipped++
            continue
        }
    }

    # ---- Skip if all phase files already exist ----
    if ($SkipExisting -and (Has-AllPhaseFiles -Id $id)) {
        Write-Host "  SKIP  $id  (all phase files already present)" -ForegroundColor DarkGray
        $skipped++
        continue
    }

    $kind = Get-SlotKind -Num $num -Row $row

    Write-Host "  SEED  $id  (kind: $kind)" -ForegroundColor Green

    if (-not $DryRun) {
        $args = @(
            "-ExecutionPolicy", "Bypass",
            "-File", $newScript,
            "-NextNumber", $num,
            "-Kind", $kind,
            "-ReserveOnly"
        )
        & powershell @args
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  new_engagement.ps1 returned $LASTEXITCODE for $id -- continuing"
        }

        if ($WithWriteup -and (Test-Path $wuScript)) {
            $wuArgs = @(
                "-ExecutionPolicy", "Bypass",
                "-File", $wuScript,
                "-SampleId", $id,
                "-Kind", "stub"
            )
            & powershell @wuArgs 2>$null
        }
    }

    $seeded++
}

Write-Host ""
Write-Host "  Seeded: $seeded  |  Skipped: $skipped$dryTag" -ForegroundColor Cyan
if ($DryRun -and $seeded -gt 0) {
    Write-Host "  Re-run without -DryRun to apply." -ForegroundColor Yellow
}
Write-Host ""
