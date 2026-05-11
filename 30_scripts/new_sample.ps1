#Requires -Version 5.1
<#
.SYNOPSIS
    Backwards-compatible alias for new_engagement.ps1 -Kind file.

.DESCRIPTION
    This script delegates to new_engagement.ps1 with -Kind file.
    It exists so existing commands and documentation using new_sample.ps1 continue to work.

    For all engagement types (CTF, lab, hunt, file) use new_engagement.ps1 directly.
    See: ENGAGEMENTS.md

.PARAMETER NextNumber
    Slot number to create (1-99).

.PARAMETER Analyst
    Analyst name for frontmatter. Defaults to 'Surrplexie'.

.PARAMETER Type
    Sample type. One of: PE (default), Office, Script, Archive.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 7
    powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 7 -Type Office
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 99)]
    [int]$NextNumber,

    [string]$Analyst = 'Surrplexie',

    [ValidateSet('PE', 'Office', 'Script', 'Archive')]
    [string]$Type = 'PE'
)

$engScript = Join-Path $PSScriptRoot 'new_engagement.ps1'
& powershell -ExecutionPolicy Bypass -File $engScript `
    -NextNumber $NextNumber `
    -Kind 'file' `
    -Type $Type `
    -Analyst $Analyst
