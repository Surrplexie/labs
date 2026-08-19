#Requires -Version 5.1
<#
.SYNOPSIS
    Regenerate 04_writeups/INDEX.md from existing long-form writeup files.

.DESCRIPTION
    Scans 04_writeups/sample_*.md, reads YAML frontmatter, and writes
    04_writeups/INDEX.md with a table of all existing long-form reports.

    Fields read from frontmatter:
      engagement_kind, title, writeup_version, status (or writeup_status),
      public_writeup_safe / public_safe, date_draft, date_final

    Exit code 0 always (no failing conditions).

.PARAMETER Root
    Repo root. Defaults to parent of this script's directory.

.PARAMETER DryRun
    Print the generated INDEX.md to the console instead of writing it.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\30_scripts\update_writeup_index.ps1
    powershell -ExecutionPolicy Bypass -File .\30_scripts\update_writeup_index.ps1 -DryRun
#>

param(
    [string]$Root   = (Split-Path $PSScriptRoot -Parent),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_paths.ps1')

$writeupDir = Join-Path $Root '04_writeups'
$outPath    = Join-Path $writeupDir 'INDEX.md'
$csvPath    = Join-Path $Root 'samples_tracker.csv'

if (-not (Test-Path $writeupDir)) {
    Write-Error "04_writeups not found at $writeupDir"; exit 1
}

# ---------------------------------------------------------------------------
# Load tracker for title/platform fallback
# ---------------------------------------------------------------------------
$trackerMap = @{}
if (Test-Path $csvPath) {
    Import-Csv $csvPath | ForEach-Object {
        $trackerMap[$_.sample_id.Trim()] = $_
    }
}

# ---------------------------------------------------------------------------
# Helper: extract a single YAML scalar from raw content
# ---------------------------------------------------------------------------
function Get-YamlValue {
    param([string]$Content, [string]$Key)
    if ($Content -match "(?m)^$Key\s*:\s*(.+)$") {
        return $Matches[1].Trim().Trim('"').Trim("'")
    }
    return ''
}

# ---------------------------------------------------------------------------
# Scan writeup files
# ---------------------------------------------------------------------------
$files = @()
Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^LAB\d+' } |
    ForEach-Object {
        $d = Join-Path $_.FullName '04_writeups'
        if (Test-Path $d) {
            $files += Get-ChildItem $d -Filter 'sample_*.md' -ErrorAction SilentlyContinue
        }
    }
$legacyWriteups = Join-Path $Root '04_writeups'
if (Test-Path $legacyWriteups) {
    $files += Get-ChildItem $legacyWriteups -Filter 'sample_*.md' -ErrorAction SilentlyContinue
}
$files = @($files | Sort-Object FullName)

$rows = @()
foreach ($f in $files) {
    $raw  = Get-Content $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    $id   = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)

    # Extract frontmatter fields
    $kind       = Get-YamlValue -Content $raw -Key 'engagement_kind'
    $title      = Get-YamlValue -Content $raw -Key 'title'
    $version    = Get-YamlValue -Content $raw -Key 'writeup_version'
    $status     = Get-YamlValue -Content $raw -Key 'status'
    if (-not $status) { $status = Get-YamlValue -Content $raw -Key 'writeup_status' }
    $pubSafe    = Get-YamlValue -Content $raw -Key 'public_writeup_safe'
    if (-not $pubSafe) { $pubSafe = Get-YamlValue -Content $raw -Key 'public_safe' }
    $dateDraft  = Get-YamlValue -Content $raw -Key 'date_draft'
    $dateFinal  = Get-YamlValue -Content $raw -Key 'date_final'

    # Tracker fallback for missing title
    if ([string]::IsNullOrWhiteSpace($title) -or $title -match '<FILL') {
        $tRow  = $trackerMap[$id]
        $title = if ($tRow -and $tRow.name_tag) { $tRow.name_tag.Trim() } else { '—' }
    }

    # Clean up placeholder dates
    if ($dateDraft -match 'YYYY|DATE') { $dateDraft = '—' }
    if ([string]::IsNullOrWhiteSpace($dateFinal)) { $dateFinal = '—' }
    if (-not $version) { $version = '—' }
    if (-not $status)  { $status  = '—' }
    if (-not $pubSafe) { $pubSafe = '—' }
    if (-not $kind)    { $kind    = '—' }

    # Line count as rough depth indicator
    $lineCount = (Get-Content $f.FullName -Encoding UTF8 | Measure-Object -Line).Lines
    $depth = if ($lineCount -le 20) { 'stub' } elseif ($lineCount -le 100) { 'short' } else { 'full' }

    $rootResolved = (Resolve-Path $Root).Path
    $relFromRoot  = $f.FullName.Substring($rootResolved.Length).TrimStart('\', '/').Replace('\', '/')
    $slotLink     = "[$id](../$relFromRoot)"

    $rows += [PSCustomObject]@{
        Slot       = $slotLink
        Kind       = $kind
        Depth      = $depth
        Title      = $title
        Status     = $status
        PublicSafe = $pubSafe
        Draft      = $dateDraft
        Final      = $dateFinal
    }
}

# ---------------------------------------------------------------------------
# Build INDEX.md content
# ---------------------------------------------------------------------------
$date  = Get-Date -Format 'yyyy-MM-dd'
$count = $rows.Count

$header = @"
# 04_writeups index

> Auto-generated by ``update_writeup_index.ps1`` on $date. Do not edit manually - run the script to refresh.

**$count long-form writeup(s)** in this logbook.

| Slot | Kind | Depth | Title | Status | Public safe | Draft | Final |
|------|------|-------|-------|--------|-------------|-------|-------|
"@

$tableRows = if ($rows.Count -eq 0) {
    '| - | - | - | *No long-form writeups yet* | - | - | - | - |'
} else {
    ($rows | ForEach-Object {
        "| $($_.Slot) | $($_.Kind) | $($_.Depth) | $($_.Title) | $($_.Status) | $($_.PublicSafe) | $($_.Draft) | $($_.Final) |"
    }) -join "`n"
}

$footer = @'

---

## Depth legend

| Depth | Lines | Meaning |
|-------|-------|---------|
| `stub` | <= 20 | Placeholder only - upgrade with `scaffold_writeup.ps1 -Overwrite` |
| `short` | 21-100 | Partial write-up in progress |
| `full` | > 100 | Complete or near-complete long-form report |

## Scaffold commands

```powershell
# Create a new long-form writeup (infers kind from tracker)
powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 -SampleId sample_XX

# Minimal placeholder
powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 -SampleId sample_XX -Kind stub

# Regenerate this index
powershell -ExecutionPolicy Bypass -File .\30_scripts\update_writeup_index.ps1
```
'@

$content = $header + "`n" + $tableRows + $footer

# ---------------------------------------------------------------------------
# Write or print
# ---------------------------------------------------------------------------
if ($DryRun) {
    Write-Host $content
} else {
    Set-Content -Path $outPath -Value $content -Encoding UTF8
    Write-Host "Written: 04_writeups\INDEX.md  ($count rows)" -ForegroundColor Green
}
