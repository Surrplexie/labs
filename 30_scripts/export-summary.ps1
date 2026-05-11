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

    INDEX.md sections:
      1. Summary stats
      2. Active samples table (non-empty slots only)
      3. Detail cards (one per active sample)
      4. Cross-reference: By Tag
      5. Cross-reference: By MITRE Technique
      6. Reserve slots (empty slots, collapsed to a small table)

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
# MITRE technique name lookup (extend as new techniques are documented)
# ---------------------------------------------------------------------------

$MITRE_NAMES = @{
    'T1036'      = 'Masquerading'
    'T1036.005'  = 'Masquerading: Match Legitimate Name or Location'
    'T1027'      = 'Obfuscated Files or Information'
    'T1027.002'  = 'Obfuscated Files: Software Packing'
    'T1059'      = 'Command and Scripting Interpreter'
    'T1059.001'  = 'Command and Scripting Interpreter: PowerShell'
    'T1059.003'  = 'Command and Scripting Interpreter: Windows Command Shell'
    'T1055'      = 'Process Injection'
    'T1082'      = 'System Information Discovery'
    'T1083'      = 'File and Directory Discovery'
    'T1112'      = 'Modify Registry'
    'T1140'      = 'Deobfuscate/Decode Files or Information'
    'T1204'      = 'User Execution'
    'T1204.002'  = 'User Execution: Malicious File'
    'T1547'      = 'Boot or Logon Autostart Execution'
    'T1547.001'  = 'Boot or Logon Autostart: Registry Run Keys'
    'T1566'      = 'Phishing'
    'T1566.001'  = 'Phishing: Spearphishing Attachment'
    'T1583'      = 'Acquire Infrastructure'
    'T1583.006'  = 'Acquire Infrastructure: Web Services'
    'T1614'      = 'System Location Discovery'
    'T1622'      = 'Debugger Evasion'
}

function Get-MitreName {
    param([string]$Id)
    # Strip inline comment if present (e.g. "T1036    # comment")
    $clean = ($Id -split '#')[0].Trim()
    if ($MITRE_NAMES.ContainsKey($clean)) { return "$clean - $($MITRE_NAMES[$clean])" }
    return $clean
}

# ---------------------------------------------------------------------------
# YAML frontmatter parser (no external deps)
# Supports: scalar strings, quoted strings, inline comments, lists (- item)
# ---------------------------------------------------------------------------

function Read-Frontmatter {
    param([string]$FilePath)

    $result = @{}
    if (-not (Test-Path $FilePath)) { return $result }

    $raw = Get-Content $FilePath -Raw -Encoding UTF8

    if ($raw -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') { return $result }
    $block = $Matches[1]

    $currentKey = $null
    $inList     = $false
    $listValues = @()

    foreach ($line in ($block -split "`r`n|`n")) {
        $line = $line -replace '\s+#.*$', ''

        if ($inList -and $line -match '^\s+-\s+(.+)$') {
            $listValues += $Matches[1].Trim().Trim('"').Trim("'")
            continue
        }

        if ($inList -and $line -match '^\S') {
            $result[$currentKey] = $listValues
            $inList      = $false
            $listValues  = @()
            $currentKey  = $null
        }

        if ($line -match '^(\w[\w_-]*)\s*:\s*(.*)$') {
            $key = $Matches[1].Trim()
            $val = $Matches[2].Trim().Trim('"').Trim("'").Trim()

            if ($val -eq '' -or $null -eq $val) {
                $currentKey = $key
                $inList     = $true
                $listValues = @()
            } else {
                $result[$key] = $val
            }
        }
    }

    if ($inList -and $currentKey) { $result[$currentKey] = $listValues }

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
        status            = Coalesce2 $status            $fm['status']       'empty'
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

# Partition
$activeRecs  = @($records | Where-Object { $_['status'] -ne 'empty' })
$reserveRecs = @($records | Where-Object { $_['status'] -eq 'empty' })

# ---------------------------------------------------------------------------
# Output 1: dist/summary.json
# ---------------------------------------------------------------------------

if (-not $SkipJson) {
    $distDir = Join-Path $Root 'dist'
    if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }
    $jsonPath = Join-Path $distDir 'summary.json'

    # Versioned envelope -- schema_version matches 30_scripts/schema/summary.schema.json
    $envelope = [ordered]@{
        schema_version = 1
        generated_at   = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
        record_count   = $records.Count
        active_count   = $activeRecs.Count
        reserve_count  = $reserveRecs.Count
        records        = @($records)
    }
    $envelope | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Host "[export] Wrote $jsonPath (schema_version: 1)" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Output 2: INDEX.md
# ---------------------------------------------------------------------------

$timestamp  = Get-Date -Format 'yyyy-MM-dd HH:mm UTC'
$totalIoc   = 0; foreach ($r in $records) { $totalIoc += [int]$r['ioc_count'] }
$activeCount = $activeRecs.Count

$sb = [System.Text.StringBuilder]::new()

# ---- Header ----
$null = $sb.AppendLine('<!-- AUTO-GENERATED by 30_scripts/export-summary.ps1 -- do not hand-edit this file -->')
$null = $sb.AppendLine("<!-- Last generated: $timestamp -->")
$null = $sb.AppendLine('')
$null = $sb.AppendLine('# Sample Index')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('> Auto-generated casebook index. Run `30_scripts/export-summary.ps1` to refresh.')
$null = $sb.AppendLine('> Edit YAML frontmatter in `03_findings/sample_XX.md` to update metadata.')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('---')
$null = $sb.AppendLine('')

# ---- Stats ----
$verdictGroups = $activeRecs | Group-Object { $_['verdict'] }
$verdictSummary = ($verdictGroups | ForEach-Object { "$($_.Count) $($_.Name)" }) -join ' / '

$null = $sb.AppendLine('## Summary')
$null = $sb.AppendLine('')
$null = $sb.AppendLine("| Metric | Value |")
$null = $sb.AppendLine("|--------|-------|")
$null = $sb.AppendLine("| Total slots | $($records.Count) |")
$null = $sb.AppendLine("| Active samples | $activeCount |")
$null = $sb.AppendLine("| Reserve slots | $($reserveRecs.Count) |")
$null = $sb.AppendLine("| IOCs logged | $totalIoc |")
if ($verdictSummary) {
    $null = $sb.AppendLine("| Verdicts | $verdictSummary |")
}

# Unique tags across all active samples
$allTags = @()
foreach ($r in $activeRecs) { $allTags += $r['tags'] }
$allTags = @($allTags | Select-Object -Unique | Sort-Object)
if ($allTags.Count -gt 0) {
    $tagLine = ($allTags | ForEach-Object { "``$_``" }) -join ' '
    $null = $sb.AppendLine("| Tags in use | $tagLine |")
}

# Unique MITRE techniques
$allMitre = @()
foreach ($r in $activeRecs) { $allMitre += $r['mitre_techniques'] }
$allMitre = @($allMitre | Select-Object -Unique | Sort-Object)
if ($allMitre.Count -gt 0) {
    $mitreIds = ($allMitre | ForEach-Object { "``$_``" }) -join ' '
    $null = $sb.AppendLine("| MITRE techniques | $mitreIds |")
}

$null = $sb.AppendLine('')
$null = $sb.AppendLine('---')
$null = $sb.AppendLine('')

# ---- Active samples table ----
if ($activeCount -gt 0) {
    $null = $sb.AppendLine('## Active Samples')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| ID | Name / Tag | Status | Verdict | Family | Confidence | IOCs | Link |')
    $null = $sb.AppendLine('|---|---|---|---|---|---|---|---|')

    foreach ($r in $activeRecs) {
        $sid    = $r['sample_id']
        $nt     = if ($r['name_tag'])          { $r['name_tag'] }          else { '(unset)' }
        $vd     = if ($r['verdict'])           { $r['verdict'] }           else { 'unknown' }
        $fam    = if ($r['family_guess'])      { $r['family_guess'] }      else { '(unset)' }
        $conf   = if ($r['family_confidence']) { $r['family_confidence'] } else { '(unset)' }
        $iocN   = if ($r['ioc_count'] -gt 0)  { $r['ioc_count'] }         else { '0' }
        $link   = "[link](03_findings/$sid.md)"
        $null = $sb.AppendLine("| ``$sid`` | $nt | $($r['status']) | $vd | $fam | $conf | $iocN | $link |")
    }

    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
} else {
    $null = $sb.AppendLine('*No active samples yet. Run `30_scripts/new_sample.ps1` to create a slot.*')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- Detail cards ----
if ($activeCount -gt 0) {
    $null = $sb.AppendLine('## Detail Cards')
    $null = $sb.AppendLine('')

    foreach ($r in $activeRecs) {
        $sid = $r['sample_id']
        $nt  = $r['name_tag']
        $null = $sb.AppendLine("### ``$sid`` - $nt")
        $null = $sb.AppendLine('')

        if ($r['sha256']) {
            $null = $sb.AppendLine("**SHA256:** ``$($r['sha256'])``  ")
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
}

# ---- Cross-reference: By Tag ----
if ($allTags.Count -gt 0) {
    $null = $sb.AppendLine('## Cross-Reference: By Tag')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('> Samples grouped by analytical tag. One sample can appear under multiple tags.')
    $null = $sb.AppendLine('')

    foreach ($tag in ($allTags | Sort-Object)) {
        $samplesWithTag = @($activeRecs | Where-Object { $_['tags'] -contains $tag })
        if ($samplesWithTag.Count -eq 0) { continue }

        $null = $sb.AppendLine("### ``$tag``")
        $null = $sb.AppendLine('')
        foreach ($r in $samplesWithTag) {
            $sid  = $r['sample_id']
            $nt   = if ($r['name_tag']) { $r['name_tag'] } else { '(unset)' }
            $vd   = if ($r['verdict'])  { $r['verdict'] }  else { 'unknown' }
            $conf = if ($r['family_confidence']) { $r['family_confidence'] } else { ''  }
            $note = if ($conf) { "$vd ($conf confidence)" } else { $vd }
            $null = $sb.AppendLine("- [``$sid``](03_findings/$sid.md) - $nt -- $note")
        }
        $null = $sb.AppendLine('')
    }

    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- Cross-reference: By MITRE Technique ----
if ($allMitre.Count -gt 0) {
    $null = $sb.AppendLine('## Cross-Reference: By MITRE ATT&CK Technique')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('> Observed or inferred techniques mapped to samples. Not a certified assessment -- triage-level mapping only.')
    $null = $sb.AppendLine('')

    foreach ($techId in ($allMitre | Sort-Object)) {
        $techName = Get-MitreName $techId
        $samplesWithTech = @($activeRecs | Where-Object { $_['mitre_techniques'] -contains $techId })
        if ($samplesWithTech.Count -eq 0) { continue }

        $null = $sb.AppendLine("### ``$techName``")
        $null = $sb.AppendLine('')
        foreach ($r in $samplesWithTech) {
            $sid = $r['sample_id']
            $nt  = if ($r['name_tag']) { $r['name_tag'] } else { '(unset)' }
            $fam = if ($r['family_guess']) { $r['family_guess'] } else { '' }
            $note = if ($fam) { $fam } else { $r['verdict'] }
            $null = $sb.AppendLine("- [``$sid``](03_findings/$sid.md) - $nt ($note)")
        }
        $null = $sb.AppendLine('')
    }

    $null = $sb.AppendLine('> See `20_notes/MITRE-coverage.md` for the full hand-maintained technique coverage tracker.')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- Reserve slots ----
if ($reserveRecs.Count -gt 0) {
    $null = $sb.AppendLine('## Reserve Slots')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('> Unassigned slots. Run `30_scripts/new_sample.ps1 -NextNumber N` to scaffold.')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| ID | Notes |')
    $null = $sb.AppendLine('|---|---|')
    foreach ($r in $reserveRecs) {
        $null = $sb.AppendLine("| ``$($r['sample_id'])`` | empty |")
    }
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- Footer ----
$null = $sb.AppendLine('*Auto-generated -- edit frontmatter in `03_findings/sample_XX.md` and re-run `30_scripts/export-summary.ps1` to update.*')

$indexPath = Join-Path $Root 'INDEX.md'
$sb.ToString() | Set-Content -Path $indexPath -Encoding UTF8
Write-Host "[export] Wrote $indexPath" -ForegroundColor Green
Write-Host "[export] Done. $($records.Count) records ($activeCount active, $($reserveRecs.Count) reserve)." -ForegroundColor Cyan
