#Requires -Version 5.1
<#
.SYNOPSIS
    Point a lab folder at a Downloads\Notes course folder.

.DESCRIPTION
    Writes NOTES_LINK.md in the lab and a pointer under
    <NotesRoot>\<Course>\labs\ so class notes and the git logbook stay in one flow.

.PARAMETER SampleId
    Slot id (sample_07) or bare number.

.PARAMETER Course
    Notes course folder name, e.g. "CS50" or "CompTIA Security+ SY0-701".

.EXAMPLE
    powershell -File .\30_scripts\link_notes.ps1 -SampleId 1 -Course "CS50"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$SampleId,

    [Parameter(Mandatory = $true)]
    [string]$Course
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
    $tracker = Import-Csv $csvPath
    $trackerRow = $tracker | Where-Object { $_.sample_id -eq $SampleId } | Select-Object -First 1
}

$labDir = Get-LabDir -Root $root -SampleId $SampleId -TrackerRow $trackerRow
if (-not $labDir -or $labDir -eq $root) {
    Write-Error "No LAB folder for $SampleId. Run new_engagement.ps1 first."
    exit 1
}

$notesRoot = Get-NotesRoot
if (-not $notesRoot) {
    Write-Error "Notes root not found. Set LABS_NOTES_ROOT or create $env:USERPROFILE\Downloads\Notes"
    exit 1
}

$courseDir = Get-NotesCourseDir -Course $Course -Ensure
$labsSub   = Join-Path $courseDir 'labs'
if (-not (Test-Path -LiteralPath $labsSub)) {
    New-Item -ItemType Directory -Path $labsSub -Force | Out-Null
}

$labName = Split-Path $labDir -Leaf
$pointer = Join-Path $labsSub "$labName.md"
@"
# $labName

Structured logbook (git): ``$labDir``

Live pad: ``$labDir\CAPTURE.md``

Screenshots: ``$labDir\50_screenshots\``
Media (local): ``$labDir\55_media\``

Class notes stay in this course folder. Do not copy credentials or raw flags into the git repo.
"@ | Set-Content -LiteralPath $pointer -Encoding UTF8

$linkMd = Join-Path $labDir 'NOTES_LINK.md'
@"
# Notes bridge

Class / club notes stay in **Downloads\Notes** (not this public repo).
This lab is the structured logbook copy.

| | |
|---|---|
| **Notes root** | ``$notesRoot`` |
| **Course folder** | ``$courseDir`` |
| **Pointer in Notes** | ``$pointer`` |
| **Live pad** | [CAPTURE.md](./CAPTURE.md) |

Open both sides:

``````powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\open_session.ps1 -SampleId $SampleId
``````

When a class note becomes a lab: paste keepers from the Notes course folder into ``00_original`` / ``01_static``, leave raw class dumps in Notes.
"@ | Set-Content -LiteralPath $linkMd -Encoding UTF8

if ($trackerRow -and ($trackerRow.PSObject.Properties.Name -contains 'notes_course')) {
    $trackerRow.notes_course = $Course
    $tracker | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
} elseif ($trackerRow) {
    $tracker | ForEach-Object {
        if (-not ($_.PSObject.Properties.Name -contains 'notes_course')) {
            $_ | Add-Member -NotePropertyName 'notes_course' -NotePropertyValue '' -Force
        }
        if ($_.sample_id -eq $SampleId) { $_.notes_course = $Course }
    }
    $tracker | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
}

Write-Host "Linked $SampleId <-> Notes\$Course" -ForegroundColor Green
Write-Host "  Lab:   $labDir"
Write-Host "  Notes: $courseDir"
Write-Host "  Open:  .\30_scripts\open_session.ps1 -SampleId $SampleId"
