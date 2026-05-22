#Requires -Version 5.1
<#
.SYNOPSIS
    Scaffold a kind-specific long-form writeup in 04_writeups from _templates.

.DESCRIPTION
    Copies 04_writeups/_templates/{kind}.md to 04_writeups/sample_NN.md with
    placeholders replaced. Does not run validate -- 04_writeups is optional.

.PARAMETER SampleId
    Slot ID (e.g. sample_07). Use this OR -NextNumber.

.PARAMETER NextNumber
    Slot number 1-99 (zero-padded to sample_XX). Use this OR -SampleId.

.PARAMETER Kind
    Template to use: file, ctf, lab, hunt. Defaults to engagement_kind from
    samples_tracker.csv when omitted.

.PARAMETER Analyst
    Analyst name for frontmatter (default: Surrplexie).

.PARAMETER Platform
    Platform string for ctf/lab templates.

.PARAMETER Title
    Title / challenge / module name.

.PARAMETER Overwrite
    Replace an existing 04_writeups file.

.EXAMPLE
    powershell -File .\30_scripts\scaffold_writeup.ps1 -NextNumber 7 -Kind ctf -Platform HackTheBox -Title Lame

.EXAMPLE
    powershell -File .\30_scripts\scaffold_writeup.ps1 -SampleId sample_01 -Kind file -Overwrite
#>
param(
    [string]$SampleId,
    [ValidateRange(1, 99)]
    [int]$NextNumber = 0,

    [ValidateSet('file', 'ctf', 'lab', 'hunt', 'stub')]
    [string]$Kind,

    [string]$Analyst  = 'Surrplexie',
    [string]$Platform = '',
    [string]$Title    = '',

    [switch]$Overwrite
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root '04_writeups'))) {
    Write-Error "Cannot find 04_writeups under repo root: $root"
    exit 1
}

if ($NextNumber -gt 0) {
    $SampleId = 'sample_{0:D2}' -f $NextNumber
}
if ([string]::IsNullOrWhiteSpace($SampleId)) {
    Write-Error 'Provide -SampleId or -NextNumber.'
    exit 1
}
if ($SampleId -notmatch '^sample_\d{2}$') {
    Write-Error "Invalid SampleId '$SampleId' (expected sample_NN)."
    exit 1
}

$csvPath = Join-Path $root 'samples_tracker.csv'
if (-not $Kind -and (Test-Path $csvPath)) {
    $row = Import-Csv $csvPath | Where-Object { $_.sample_id -eq $SampleId } | Select-Object -First 1
    if ($row -and $row.PSObject.Properties.Name -contains 'engagement_kind' -and $row.engagement_kind) {
        $Kind = $row.engagement_kind.Trim().ToLower()
    }
}
if (-not $Kind) { $Kind = 'file' }

$templateFile  = if ($Kind -eq 'stub') { '_stub.md' } else { "$Kind.md" }
$templatePath = Join-Path $root "04_writeups\_templates\$templateFile"
if (-not (Test-Path $templatePath)) {
    Write-Error "Template not found: $templatePath (kind=$Kind)"
    exit 1
}

$outDir  = Join-Path $root '04_writeups'
$outPath = Join-Path $outDir "$SampleId.md"

if ((Test-Path $outPath) -and -not $Overwrite) {
    Write-Warning "04_writeups\$SampleId.md already exists. Use -Overwrite to replace."
    exit 1
}

if (-not $Title -and (Test-Path $csvPath)) {
    $row = Import-Csv $csvPath | Where-Object { $_.sample_id -eq $SampleId } | Select-Object -First 1
    if ($row) {
        if (-not $Title -and $row.name_tag) { $Title = $row.name_tag.Trim() }
        if (-not $Platform -and $row.PSObject.Properties.Name -contains 'platform' -and $row.platform) {
            $Platform = $row.platform.Trim()
        }
    }
}

$date = Get-Date -Format 'yyyy-MM-dd'
$content = Get-Content $templatePath -Raw -Encoding UTF8
$content = $content.Replace('SAMPLE_ID', $SampleId)
$content = $content.Replace('ANALYST', $Analyst)
$content = $content.Replace('DATE', $date)
$content = $content.Replace('TITLE_VAL', $(if ($Title) { $Title } else { '' }))
$content = $content.Replace('PLATFORM_VAL', $(if ($Platform) { $Platform } else { '' }))
$content = $content.Replace('KIND_VAL', $Kind)

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$verb = if (Test-Path $outPath) { 'Updated' } else { 'Created' }
Set-Content -Path $outPath -Value $content -Encoding UTF8
Write-Host "$verb 04_writeups\$SampleId.md from _templates\$Kind.md" -ForegroundColor Green
