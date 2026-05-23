#Requires -Version 5.1
<#
.SYNOPSIS
    [DEPRECATED] Reseed empty reserve slots. No longer used -- slots are on-demand.

.DESCRIPTION
    This script previously pre-seeded sample_02 through sample_50 with placeholder
    phase files across 00_original, 01_static, 02_dynamic, and 03_findings.

    That approach caused repo noise (196 unfilled stubs), wrong engagement_kind on
    CTF/lab/hunt bands, and validate check issues. It was retired when the repo
    moved to on-demand slot creation only.

    HOW TO CREATE A NEW ENGAGEMENT NOW:
      - GUI:    Open workflow_gui.exe -> "New Engagement" tab -> fill kind + title -> Create
      - Script: powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber <N> -Kind <file|ctf|lab|hunt>

    This script exits immediately without making any changes.
    If you truly need to bulk-seed (unusual), use -Force to override.

.PARAMETER Force
    Override the deprecation guard and run the legacy seeding logic.
    WARNING: This will create 196+ stub files in the phase folders again.
#>
param(
    [ValidateRange(1, 99)]
    [int]$From = 2,

    [ValidateRange(1, 99)]
    [int]$To = 50,

    [ValidateSet('PE', 'Office', 'Script', 'Archive')]
    [string]$Type = 'PE',

    [string]$Root = '',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

if (-not $Force) {
    Write-Host ""
    Write-Host "  [DEPRECATED] reseed_empty_slots.ps1 is retired." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Slots are now created on-demand via new_engagement.ps1 (or the GUI)." -ForegroundColor Yellow
    Write-Host "  Pre-seeding 50 stubs causes repo noise and wrong engagement_kind on" -ForegroundColor Yellow
    Write-Host "  CTF/lab/hunt bands." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  To create a new engagement slot:" -ForegroundColor Cyan
    Write-Host "    GUI    : workflow_gui.exe -> New Engagement tab" -ForegroundColor Cyan
    Write-Host "    Script : powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber <N> -Kind <file|ctf|lab|hunt>" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Use -Force to run the legacy bulk-seed (not recommended)." -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

Write-Warning "Running legacy bulk-seed (Force override). This will create phase stubs for slots $From-$To."

$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path $scriptDir -Parent
}

$engScript = Join-Path $scriptDir 'new_engagement.ps1'
if (-not (Test-Path $engScript)) {
    Write-Error "new_engagement.ps1 not found at $engScript"
    exit 1
}

$failures = @()
for ($n = $From; $n -le $To; $n++) {
    Write-Host "--- sample_$("{0:D2}" -f $n) ---" -ForegroundColor White
    & powershell -ExecutionPolicy Bypass -File $engScript `
        -NextNumber $n `
        -Kind file `
        -Type $Type `
        -OverwriteEmpty `
        -ReserveOnly
    if ($LASTEXITCODE -ne 0) {
        $failures += $n
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Finished with failures on slot(s): $($failures -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "Done. Empty reserve slots seeded." -ForegroundColor Green
