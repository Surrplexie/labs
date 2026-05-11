#Requires -Version 5.1
<#
.SYNOPSIS
    Parses YAML frontmatter from 03_findings/sample_XX.md files and exports
    a machine-readable summary.json and regenerates the repo INDEX.md.

.DESCRIPTION
    Data sources (merged in this priority order):
      1. samples_tracker.csv        - ground truth for sample_id, sha256, mb_url, name_tag, status.
      2. 03_findings/sample_XX.md   - verdict, family, tags, MITRE, dates (via YAML frontmatter).
      3. 40_iocs/indicators.csv     - IOC row count per sample (computed).

    Outputs:
      - INDEX.md at repo root   (committed - human-readable casebook index).
      - dist/summary.json       (gitignored - machine-readable for tooling/scripts).

.PARAMETER Root
    Path to the repo root. Defaults to the parent of this script's directory.

.PARAMETER SkipJson
    Skip writing dist/summary.json (INDEX.md still generated).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\30_scripts\export-summary.ps1
    powershell -ExecutionPolicy Bypass -File .\30_scripts\export-summary.ps1 -SkipJson
#>

param(
    [string]$Root     = (Split-Path $PSScriptRoot -Parent),
    [switch]$SkipJson
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers: YAML frontmatter parser (no external deps)
# Supports: scalar strings, quoted strings, inline comments, lists (- item)
# ---------------------------------------------------------------------------

function Read-Frontmatter {
    param([string]$FilePath)

    $result = @{}
    if (-not (Test-Path $FilePath)) { return $result }

    $raw = Get-Content $FilePath -Raw -Encoding UTF8

    # Extract block between first pair of --- delimiters
    if ($raw -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') { return $result }
    $block = $Matches[1]

    $currentKey  = $null
    $inList      = $false
    $listValues  = @()

    foreach ($line in ($block -split "`r`n|`n")) {
        # Strip inline comments
        $line = $line -replace '\s+#.*$', ''

        # List item under a key
        if ($inList -and $line -match '^\s+-\s+(.+)$') {
            $listValues += $Matches[1].Trim().Trim('"').Trim("'")
            continue
        }

        # New key encountered - flush pending list
        if ($inList -and $line -match '^\S') {
            $result[$currentKey] = $listValues
            $inList      = $false
            $listValues  = @()
            $currentKey  = $null
        }

        # Key: value  (scalar or start of list)
        if ($line -match '^(\w[\w_-]*)\s*:\s*(.*)$') {
            $key = $Matches[1].Trim()
            $val = $Matches[2].Trim().Trim('"').Trim("'").Trim()

            if ($val -eq '' -or $null -eq $val) {
                # Next lines may be list items
                $currentKey = $key
                $inList     = $true
                $listValues = @()
            } else {
                $result[$key] = $val
            }
        }
    }

    # Flush trailing list
    if ($inList -and $currentKey) {
        $result[$currentKey] = $listValues
    }

    return $result
}

# ---------------------------------------------------------------------------
# Load data sources
# ---------------------------------------------------------------------------

$csvPath = Join-Path $Root 'samples_tracker.csv'
if (-not (Test-Path $csvPath)) {
    Write-Error "samples_tracker.csv not found at: $csvPath"
    exit 1
}
$tracker = Import-Csv $csvPath

# IOC count per sample_id
$iocCounts = @{}
$iocPath   = Join-Path $Root '40_iocs\indicators.csv'
if (Test-Path $iocPath) {
    Import-Csv $iocPath | Group-Object sample_id | ForEach-Object {
        $iocCounts[$_.Name] = $_.Count
    }
}

# ---------------------------------------------------------------------------
# Build merged records
# ---------------------------------------------------------------------------

$records = [System.Collections.Generic.List[hashtable]]::new()

foreach ($row in $tracker) {
    $id     = $row.sample_id.Trim()
    $status = $row.status.Trim()

    $findingsFile = Join-Path $Root "03_findings\$id.md"
    $fm           = Read-Frontmatter -FilePath $findingsFile

    $tags    = if ($fm.ContainsKey('tags'))             { [string[]]$fm['tags'] }             else { @() }
    $mitre   = if ($fm.ContainsKey('mitre_techniques')) { [string[]]$fm['mitre_techniques'] } else { @() }
    $iocCnt  = if ($iocCounts.ContainsKey($id))         { [int]$iocCounts[$id] }              else { 0 }

    function Coalesce2 {
        param($a, $b, [string]$default = '')
        if (-not [string]::IsNullOrWhiteSpace("$a")) { return "$a" }
        if (-not [string]::IsNullOrWhiteSpace("$b")) { return "$b" }
        return $default
    }

    $rec = @{
        sample_id         = $id
        sha256            = Coalesce2 $fm['sha256']            $row.sha256
        name_tag          = Coalesce2 $fm['name_tag']          $row.name_tag
        status            = Coalesce2 $fm['status']            $status             'empty'
        verdict           = Coalesce2 $fm['verdict']           ''                  'unknown'
        family_guess      = Coalesce2 $fm['family_guess']      ''                  ''
        family_confidence = Coalesce2 $fm['family_confidence'] ''                  ''
        analyst           = Coalesce2 $fm['analyst']           ''                  ''
        date_acquired     = Coalesce2 $fm['date_acquired']     ''                  ''
        date_analyzed     = Coalesce2 $fm['date_analyzed']     ''                  ''
        mb_url            = Coalesce2 $fm['mb_url']            $row.mb_url         ''
        tags              = $tags
        mitre_techniques  = $mitre
        ioc_count         = $iocCnt
        procmon_run       = Coalesce2 $fm['procmon_run']       ''                  'false'
        dynamic_complete  = Coalesce2 $fm['dynamic_complete']  ''                  'false'
        has_frontmatter   = ($fm.Count -gt 0)
    }

    $records.Add($rec)
}

# ---------------------------------------------------------------------------
# Output 1: dist/summary.json
# ---------------------------------------------------------------------------

if (-not $SkipJson) {
    $distDir = Join-Path $Root 'dist'
    if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }

    $jsonPath = Join-Path $distDir 'summary.json'
    $records | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Host "[export] Wrote $jsonPath" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Output 2: INDEX.md
# ---------------------------------------------------------------------------

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm UTC'

$sb = [System.Text.StringBuilder]::new()

$null = $sb.AppendLine('<!-- AUTO-GENERATED by 30_scripts/export-summary.ps1 -- do not hand-edit this file -->')
$null = $sb.AppendLine("<!-- Last generated: $timestamp -->")
$null = $sb.AppendLine('')
$null = $sb.AppendLine('# Sample Index')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('> Auto-generated casebook index. Run `30_scripts/export-summary.ps1` to refresh.')
$null = $sb.AppendLine('> Source of truth: `samples_tracker.csv` + YAML frontmatter in `03_findings/`.')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('---')
$null = $sb.AppendLine('')

# Summary stats - wrap in @() so .Count returns collection count even when 1 item
$nonEmpty  = @($records | Where-Object { $_['status'] -ne 'empty' })
$totalIoc  = 0; foreach ($r in $records) { $totalIoc += [int]$r['ioc_count'] }
$activeCount = $nonEmpty.Count

$null = $sb.AppendLine("**Slots total:** $($records.Count)  |  **Active:** $activeCount  |  **IOCs logged:** $totalIoc")
$null = $sb.AppendLine('')
$null = $sb.AppendLine('---')
$null = $sb.AppendLine('')

# Main table
$null = $sb.AppendLine('| ID | Name / Tag | Status | Verdict | Family | Confidence | Tags | MITRE | IOCs | Findings |')
$null = $sb.AppendLine('|---|---|---|---|---|---|---|---|---|---|')

foreach ($r in $records) {
    $tagsStr  = if ($r['tags'].Count -gt 0)              { ($r['tags']              | ForEach-Object { "``$_``" }) -join ' ' } else { '(none)' }
    $mitreStr = if ($r['mitre_techniques'].Count -gt 0)  { ($r['mitre_techniques']  | ForEach-Object { "``$_``" }) -join ' ' } else { '(none)' }
    $nameTag  = if ($r['name_tag'])          { $r['name_tag'] }          else { '(unset)' }
    $verdict  = if ($r['verdict'])           { $r['verdict'] }           else { '(unset)' }
    $family   = if ($r['family_guess'])      { $r['family_guess'] }      else { '(unset)' }
    $conf     = if ($r['family_confidence']) { $r['family_confidence'] } else { '(unset)' }
    $iocCell  = if ($r['ioc_count'] -gt 0)  { $r['ioc_count'] }         else { '0' }
    $sid      = $r['sample_id']
    $findLink = "[link](03_findings/$sid.md)"

    $null = $sb.AppendLine("| ``$sid`` | $nameTag | $($r['status']) | $verdict | $family | $conf | $tagsStr | $mitreStr | $iocCell | $findLink |")
}

$null = $sb.AppendLine('')
$null = $sb.AppendLine('---')
$null = $sb.AppendLine('')

# Per-sample detail cards for non-empty slots
$null = $sb.AppendLine('## Detail Cards')
$null = $sb.AppendLine('')

foreach ($r in (@($records | Where-Object { $_['status'] -ne 'empty' }))) {
    $sid = $r['sample_id']
    $nt  = $r['name_tag']
    $null = $sb.AppendLine("### ``$sid`` - $nt")
    $null = $sb.AppendLine('')

    if ($r['sha256']) {
        $null = $sb.AppendLine("**SHA256:** $($r['sha256'])  ")
    }
    if ($r['date_acquired']) {
        $null = $sb.AppendLine("**Acquired:** $($r['date_acquired'])  |  **Analyzed:** $($r['date_analyzed'])  ")
    }
    if ($r['analyst']) {
        $null = $sb.AppendLine("**Analyst:** $($r['analyst'])  ")
    }

    $null = $sb.AppendLine("**Status:** $($r['status'])  ")
    $null = $sb.AppendLine("**Verdict:** $($r['verdict'])  ")

    if ($r['family_guess']) {
        $fg = $r['family_guess']
        $fc = $r['family_confidence']
        $null = $sb.AppendLine("**Family / Type:** $fg ($fc confidence)  ")
    }

    if ($r['tags'].Count -gt 0) {
        $tagLine = ($r['tags'] | ForEach-Object { "``$_``" }) -join ' '
        $null = $sb.AppendLine("**Tags:** $tagLine  ")
    }

    if ($r['mitre_techniques'].Count -gt 0) {
        $mitreLine = ($r['mitre_techniques'] | ForEach-Object { "``$_``" }) -join ' '
        $null = $sb.AppendLine("**MITRE:** $mitreLine  ")
    }

    if ($r['ioc_count'] -gt 0) {
        $null = $sb.AppendLine("**IOCs logged:** $($r['ioc_count'])  ")
    }

    $procmon = if ($r['procmon_run'] -eq 'true') { 'Yes' } else { 'No' }
    $dynComp = if ($r['dynamic_complete'] -eq 'true') { 'Yes' } else { 'No' }
    $null = $sb.AppendLine("**Procmon run:** $procmon  |  **Dynamic complete:** $dynComp  ")

    if ($r['mb_url']) {
        $null = $sb.AppendLine("**MalwareBazaar:** [link]($($r['mb_url']))  ")
    }

    $null = $sb.AppendLine('')
    $null = $sb.AppendLine("**Phase files:** [00_original](00_original/$sid.md) | [01_static](01_static/$sid.md) | [02_dynamic](02_dynamic/$sid.md) | [03_findings](03_findings/$sid.md)")
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

$null = $sb.AppendLine('*Index auto-generated - edit frontmatter in `03_findings/sample_XX.md` and re-run `export-summary.ps1` to update.*')

$indexPath = Join-Path $Root 'INDEX.md'
$sb.ToString() | Set-Content -Path $indexPath -Encoding UTF8
Write-Host "[export] Wrote $indexPath" -ForegroundColor Green

Write-Host "[export] Done. $($records.Count) records processed." -ForegroundColor Cyan
