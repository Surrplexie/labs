#Requires -Version 5.1
<#
.SYNOPSIS
    Reseed empty reserve slots with the current file-kind PE scaffold.

.DESCRIPTION
    Overwrites phase Markdown, SHOT_INDEX.txt, and screenshot folders for tracker
    rows with status empty. Skips non-empty slots (for example sample_01).

.PARAMETER From
    First slot number (default 2).

.PARAMETER To
    Last slot number (default 50).

.PARAMETER Type
    File sample type passed to new_engagement.ps1 (default PE).

.PARAMETER Root
    Repo root. Defaults to parent of 30_scripts.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\30_scripts\reseed_empty_slots.ps1
    powershell -ExecutionPolicy Bypass -File .\30_scripts\reseed_empty_slots.ps1 -From 2 -To 99
#>
param(
    [ValidateRange(1, 99)]
    [int]$From = 2,

    [ValidateRange(1, 99)]
    [int]$To = 50,

    [ValidateSet('PE', 'Office', 'Script', 'Archive')]
    [string]$Type = 'PE',

    [string]$Root = ''
)

$ErrorActionPreference = 'Stop'

if ($From -gt $To) {
    Write-Error "From ($From) cannot be greater than To ($To)."
    exit 1
}

$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path $scriptDir -Parent
}

$engScript = Join-Path $scriptDir 'new_engagement.ps1'
if (-not (Test-Path $engScript)) {
    Write-Error "new_engagement.ps1 not found at $engScript"
    exit 1
}

Write-Host ""
Write-Host "Reseeding empty file slots sample_$("{0:D2}" -f $From) through sample_$("{0:D2}" -f $To) (Type: $Type)" -ForegroundColor Cyan
Write-Host "Repo: $Root"
Write-Host ""

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

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "Finished with failures on slot(s): $($failures -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "Done. Empty reserve slots reseeded." -ForegroundColor Green
