#Requires -Version 5.1
<#
.SYNOPSIS
    Open the lab folder, CAPTURE.md, and the linked Notes course (if any).

.EXAMPLE
    powershell -File .\30_scripts\open_session.ps1 -SampleId 1
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$SampleId,

    [switch]$SkipNotes
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_paths.ps1')
$root = Split-Path -Parent $PSScriptRoot

if ($SampleId -match '^\d+$') {
    $SampleId = 'sample_{0:D2}' -f [int]$SampleId
}

$csvPath = Join-Path $root 'samples_tracker.csv'
$trackerRow = $null
if (Test-Path $csvPath) {
    $trackerRow = Import-Csv $csvPath | Where-Object { $_.sample_id -eq $SampleId } | Select-Object -First 1
}

$labDir = Get-LabDir -Root $root -SampleId $SampleId -TrackerRow $trackerRow
if (-not $labDir -or $labDir -eq $root) {
    Write-Error "No LAB folder for $SampleId. Run new_engagement.ps1 first."
    exit 1
}

Write-Host "Opening $labDir" -ForegroundColor Cyan
Start-Process explorer.exe -ArgumentList $labDir

$capture = Join-Path $labDir 'CAPTURE.md'
if (Test-Path -LiteralPath $capture) {
    Invoke-Item -LiteralPath $capture
}

if (-not $SkipNotes) {
    $course = ''
    if ($trackerRow -and ($trackerRow.PSObject.Properties.Name -contains 'notes_course')) {
        $course = "$($trackerRow.notes_course)".Trim()
    }
    if (-not $course -and $trackerRow -and ($trackerRow.PSObject.Properties.Name -contains 'platform')) {
        $course = "$($trackerRow.platform)".Trim()
    }
    $linkMd = Join-Path $labDir 'NOTES_LINK.md'
    if (-not $course -and (Test-Path -LiteralPath $linkMd)) {
        $raw = Get-Content -LiteralPath $linkMd -Raw -Encoding UTF8
        if ($raw -match 'Course folder\s*\|\s*`([^`]+)`') { $course = Split-Path $Matches[1] -Leaf }
    }
    $courseDir = $null
    if ($course) { $courseDir = Get-NotesCourseDir -Course $course }
    if ($courseDir) {
        Write-Host "Opening Notes: $courseDir" -ForegroundColor Cyan
        Start-Process explorer.exe -ArgumentList $courseDir
    } else {
        Write-Host "No Notes course linked. Run: .\30_scripts\link_notes.ps1 -SampleId $SampleId -Course `"CS50`"" -ForegroundColor Yellow
    }
}

Write-Host "Stay in the lab folder. Dump into CAPTURE.md, then file into 00 -> 03." -ForegroundColor Green
