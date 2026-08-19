#Requires -Version 5.1
<#
.SYNOPSIS
    Parses all engagement frontmatter and exports INDEX.md + dist/summary.json.

.DESCRIPTION
    Kind-aware export. Reads samples_tracker.csv, merges with 03_findings frontmatter,
    and generates:
      - INDEX.md at repo root (committed -- human-readable logbook index)
      - dist/summary.json (gitignored -- machine-readable)

    Outputs:
      - INDEX.md at repo root (committed)
      - dist/summary.json (gitignored, schema_version: 2)
      - dist/portfolio.json (gitignored, public_writeup_safe: true rows only)

    INDEX.md sections:
      1.  Summary stats (per-kind counts)
      2.  All engagements flat table
      3.  File analyses
      4.  CTF write-ups
      5.  Labs
      6.  Threat hunts
      7.  Cross-reference: by skill (all kinds)
      8.  Cross-reference: by platform (ctf/lab kinds)
      9.  Cross-reference: by tag (all kinds)
     10.  Cross-reference: by MITRE technique (file-kind)
     11.  Reserve slots

.PARAMETER Root
    Path to the repo root. Defaults to parent of this script's directory.

.PARAMETER SkipJson
    Skip writing dist/summary.json and dist/portfolio.json (INDEX.md still generated).

.PARAMETER SkipPortfolio
    Skip writing dist/portfolio.json only (summary.json still written if -SkipJson not set).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\30_scripts\export-summary.ps1
    powershell -ExecutionPolicy Bypass -File .\30_scripts\export-summary.ps1 -SkipJson
    powershell -ExecutionPolicy Bypass -File .\30_scripts\export-summary.ps1 -SkipPortfolio
#>

param(
    [string]$Root         = (Split-Path $PSScriptRoot -Parent),
    [switch]$SkipJson,
    [switch]$SkipPortfolio
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_paths.ps1')

# ---------------------------------------------------------------------------
# MITRE technique name lookup
# ---------------------------------------------------------------------------

$MITRE_NAMES = @{
    'T1027'      = 'Obfuscated Files or Information'
    'T1027.002'  = 'Obfuscated Files: Software Packing'
    'T1036'      = 'Masquerading'
    'T1036.005'  = 'Masquerading: Match Legitimate Name or Location'
    'T1041'      = 'Exfiltration Over C2 Channel'
    'T1055'      = 'Process Injection'
    'T1059'      = 'Command and Scripting Interpreter'
    'T1059.001'  = 'Command and Scripting Interpreter: PowerShell'
    'T1059.003'  = 'Command and Scripting Interpreter: Windows Command Shell'
    'T1082'      = 'System Information Discovery'
    'T1083'      = 'File and Directory Discovery'
    'T1112'      = 'Modify Registry'
    'T1140'      = 'Deobfuscate/Decode Files or Information'
    'T1204'      = 'User Execution'
    'T1204.002'  = 'User Execution: Malicious File'
    'T1547'      = 'Boot or Logon Autostart Execution'
    'T1547.001'  = 'Boot or Logon Autostart: Registry Run Keys'
    'T1555.003'  = 'Credentials from Web Browsers'
    'T1566'      = 'Phishing'
    'T1566.001'  = 'Phishing: Spearphishing Attachment'
    'T1583'      = 'Acquire Infrastructure'
    'T1583.006'  = 'Acquire Infrastructure: Web Services'
    'T1614'      = 'System Location Discovery'
    'T1622'      = 'Debugger Evasion'
}

function Get-MitreName {
    param([string]$Id)
    $clean = ($Id -split '#')[0].Trim()
    if ($MITRE_NAMES.ContainsKey($clean)) { return "$clean - $($MITRE_NAMES[$clean])" }
    return $clean
}

# ---------------------------------------------------------------------------
# YAML frontmatter parser
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
            $inList     = $false
            $listValues = @()
            $currentKey = $null
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
# Load data
# ---------------------------------------------------------------------------

$csvPath = Join-Path $Root 'samples_tracker.csv'
if (-not (Test-Path $csvPath)) {
    Write-Error "samples_tracker.csv not found at: $csvPath"
    exit 1
}
$tracker = Import-Csv $csvPath
$cols    = $tracker[0].PSObject.Properties.Name

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

function Coalesce2 {
    param($a, $b, [string]$default = '')
    if (-not [string]::IsNullOrWhiteSpace("$a")) { return "$a" }
    if (-not [string]::IsNullOrWhiteSpace("$b")) { return "$b" }
    return $default
}

$records = [System.Collections.Generic.List[hashtable]]::new()

foreach ($row in $tracker) {
    $id     = $row.sample_id.Trim()
    $status = $row.status.Trim()

    # Kind: prefer tracker column, fall back to 'file'
    $kind = if ($cols -contains 'engagement_kind' -and $row.engagement_kind -ne '') {
                $row.engagement_kind.Trim().ToLower()
            } else { 'file' }

    $platform = if ($cols -contains 'platform') { $row.platform.Trim() } else { '' }
    $dateStarted = if ($cols -contains 'date_started') { $row.date_started.Trim() } else { '' }
    $dateClosed  = if ($cols -contains 'date_closed')  { $row.date_closed.Trim()  } else { '' }
    $scoreFlag   = if ($cols -contains 'score_flag')   { $row.score_flag.Trim()   } else { '' }

    $findingsFile = Get-PhaseFilePath -Root $Root -SampleId $id -Phase '03_findings' -TrackerRow $row
    $fm           = Read-Frontmatter -FilePath $findingsFile
    $labDir       = Get-LabDir -Root $Root -SampleId $id -TrackerRow $row
    $findingsRel  = if ($labDir -and ($labDir -ne $Root)) {
        "$(Split-Path $labDir -Leaf)/03_findings/$id.md"
    } else {
        "03_findings/$id.md"
    }

    $tags   = if ($fm.ContainsKey('tags'))             { [string[]]$fm['tags'] }             else { @() }
    $mitre  = if ($fm.ContainsKey('mitre_techniques')) { [string[]]$fm['mitre_techniques'] } else { @() }
    $skills = if ($fm.ContainsKey('skills'))           { [string[]]$fm['skills'] }           else { @() }
    $iocCnt = if ($iocCounts.ContainsKey($id))         { [int]$iocCounts[$id] }              else { 0 }

    $rec = @{
        sample_id         = $id
        engagement_kind   = $kind
        sha256            = Coalesce2 $fm['sha256']            $row.sha256
        name_tag          = Coalesce2 $fm['title']             (Coalesce2 $fm['name_tag'] $row.name_tag)
        status            = Coalesce2 $status                  $fm['status'] 'empty'
        platform          = Coalesce2 $fm['platform']          $platform
        date_started      = Coalesce2 $fm['date_started']      $dateStarted
        date_closed       = Coalesce2 $fm['date_closed']       $dateClosed
        score_flag        = $scoreFlag
        # file-kind fields
        verdict           = Coalesce2 $fm['verdict']           '' 'unknown'
        family_guess      = Coalesce2 $fm['family_guess']      '' ''
        family_confidence = Coalesce2 $fm['family_confidence'] '' ''
        analyst           = Coalesce2 $fm['analyst']           '' ''
        date_acquired     = Coalesce2 $fm['date_acquired']     '' ''
        date_analyzed     = Coalesce2 $fm['date_analyzed']     '' ''
        mb_url            = Coalesce2 $fm['mb_url']            $row.mb_url ''
        ioc_count         = $iocCnt
        procmon_run       = Coalesce2 $fm['procmon_run']       '' 'false'
        dynamic_complete  = Coalesce2 $fm['dynamic_complete']  '' 'false'
        # ctf-kind fields
        category          = Coalesce2 $fm['category']          '' ''
        difficulty        = Coalesce2 $fm['difficulty']        '' ''
        solved            = Coalesce2 $fm['solved']            '' 'false'
        # lab-kind fields
        course            = Coalesce2 $fm['course']            '' ''
        module            = Coalesce2 $fm['module']            '' ''
        objectives_met    = Coalesce2 $fm['objectives_met']    '' 'false'
        # hunt-kind fields
        hypothesis        = Coalesce2 $fm['hypothesis']        '' ''
        detections_found  = Coalesce2 $fm['detections_found']  '' 'false'
        # shared
        outcome           = Coalesce2 $fm['outcome']           '' ''
        confidence        = Coalesce2 $fm['confidence']        $fm['family_confidence'] ''
        tags              = $tags
        mitre_techniques  = $mitre
        skills            = $skills
        has_frontmatter   = ($fm.Count -gt 0)
        findings_rel      = $findingsRel
    }

    $records.Add($rec)
}

$activeRecs  = @($records | Where-Object { $_['status'] -ne 'empty' })
$reserveRecs = @($records | Where-Object { $_['status'] -eq 'empty' })

$fileRecs     = @($activeRecs | Where-Object { $_['engagement_kind'] -eq 'file' })
$ctfRecs      = @($activeRecs | Where-Object { $_['engagement_kind'] -eq 'ctf' })
$labRecs      = @($activeRecs | Where-Object { $_['engagement_kind'] -eq 'lab' })
$huntRecs     = @($activeRecs | Where-Object { $_['engagement_kind'] -eq 'hunt' })
$schoolRecs   = @($activeRecs | Where-Object { $_['engagement_kind'] -eq 'school' })
$homelabRecs  = @($activeRecs | Where-Object { $_['engagement_kind'] -eq 'homelab' })

# ---------------------------------------------------------------------------
# Output 1: dist/summary.json
# ---------------------------------------------------------------------------

if (-not $SkipJson) {
    $distDir = Join-Path $Root 'dist'
    if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }
    $jsonPath = Join-Path $distDir 'summary.json'

    $envelope = [ordered]@{
        schema_version = 2
        generated_at   = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
        record_count   = $records.Count
        active_count   = $activeRecs.Count
        reserve_count  = $reserveRecs.Count
        file_count     = $fileRecs.Count
        ctf_count      = $ctfRecs.Count
        lab_count      = $labRecs.Count
        hunt_count     = $huntRecs.Count
        records        = @($records)
    }
    $envelope | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Host "[export] Wrote $jsonPath (schema_version: 2)" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Output 1b: dist/portfolio.json  (public_writeup_safe: true rows only)
# ---------------------------------------------------------------------------

if (-not $SkipJson -and -not $SkipPortfolio) {
    $distDir = Join-Path $Root 'dist'
    if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }
    $portfolioPath = Join-Path $distDir 'portfolio.json'

    # Rebuild by re-reading public_writeup_safe from frontmatter
    $portfolioRecs = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($rec in $activeRecs) {
        $sid  = $rec['sample_id']
        $fPath = Get-PhaseFilePath -Root $Root -SampleId $sid -Phase '03_findings'
        $fm2   = Read-Frontmatter -FilePath $fPath
        $safe  = if ($fm2.ContainsKey('public_writeup_safe')) { $fm2['public_writeup_safe'] } else { 'false' }
        if ($safe -eq 'true') {
            # Include only public-safe fields
            $pub = [ordered]@{
                sample_id       = $sid
                engagement_kind = $rec['engagement_kind']
                title           = $rec['name_tag']
                platform        = $rec['platform']
                date_closed     = $rec['date_closed']
                skills          = $rec['skills']
                outcome         = $rec['outcome']
                confidence      = $rec['confidence']
                # kind-specific
                verdict         = $rec['verdict']
                category        = $rec['category']
                difficulty      = $rec['difficulty']
                solved          = $rec['solved']
                detections_found = $rec['detections_found']
                objectives_met  = $rec['objectives_met']
            }
            $portfolioRecs.Add($pub)
        }
    }

    $portfolioEnvelope = [ordered]@{
        schema_version = 2
        generated_at   = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')
        description    = 'Public-safe portfolio slice. Only rows with public_writeup_safe: true.'
        record_count   = $portfolioRecs.Count
        records        = @($portfolioRecs)
    }
    $portfolioEnvelope | ConvertTo-Json -Depth 6 | Set-Content -Path $portfolioPath -Encoding UTF8
    Write-Host "[export] Wrote $portfolioPath ($($portfolioRecs.Count) public-safe records)" -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# Output 2: INDEX.md
# ---------------------------------------------------------------------------

$timestamp   = Get-Date -Format 'yyyy-MM-dd HH:mm UTC'
$totalIoc    = 0; foreach ($r in $records) { $totalIoc += [int]$r['ioc_count'] }
$activeCount = $activeRecs.Count

$sb = [System.Text.StringBuilder]::new()

$null = $sb.AppendLine('<!-- AUTO-GENERATED by 30_scripts/export-summary.ps1 -- do not hand-edit this file -->')
$null = $sb.AppendLine("<!-- Last generated: $timestamp -->")
$null = $sb.AppendLine('')
$null = $sb.AppendLine('# Logbook Index')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('> Auto-generated index. Run `30_scripts/export-summary.ps1` to refresh.')
$null = $sb.AppendLine('> Edit YAML frontmatter in each lab `03_findings/sample_XX.md` to update metadata.')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('---')
$null = $sb.AppendLine('')

# ---- Stats ----
$null = $sb.AppendLine('## Summary')
$null = $sb.AppendLine('')
$null = $sb.AppendLine('| Metric | Value |')
$null = $sb.AppendLine('|--------|-------|')
$null = $sb.AppendLine("| Total slots | $($records.Count) |")
$null = $sb.AppendLine("| Active engagements | $activeCount |")
$null = $sb.AppendLine("| File analyses | $($fileRecs.Count) |")
$null = $sb.AppendLine("| CTF write-ups | $($ctfRecs.Count) |")
$null = $sb.AppendLine("| Labs | $($labRecs.Count) |")
$null = $sb.AppendLine("| School | $($schoolRecs.Count) |")
$null = $sb.AppendLine("| Homelabs | $($homelabRecs.Count) |")
$null = $sb.AppendLine("| Threat hunts | $($huntRecs.Count) |")
$null = $sb.AppendLine("| Reserve slots | $($reserveRecs.Count) |")
$null = $sb.AppendLine("| IOCs logged (file kind) | $totalIoc |")

$allTags = @()
foreach ($r in $activeRecs) { $allTags += $r['tags'] }
$allTags = @($allTags | Select-Object -Unique | Sort-Object)
if ($allTags.Count -gt 0) {
    $tagLine = ($allTags | ForEach-Object { "``$_``" }) -join ' '
    $null = $sb.AppendLine("| Tags in use | $tagLine |")
}

$null = $sb.AppendLine('')
$null = $sb.AppendLine('---')
$null = $sb.AppendLine('')

# ---- All engagements flat table ----
if ($activeCount -gt 0) {
    $null = $sb.AppendLine('## All Engagements')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| ID | Kind | Name / Title | Platform | Status | Outcome | Link |')
    $null = $sb.AppendLine('|---|---|---|---|---|---|---|')

    foreach ($r in $activeRecs) {
        $sid      = $r['sample_id']
        $kindCol  = $r['engagement_kind']
        $nt       = if ($r['name_tag'])  { $r['name_tag'] }  else { '(unset)' }
        $platCol  = if ($r['platform'])  { $r['platform'] }  else { '-' }
        $outcomeCol = switch ($kindCol) {
            'file'  { if ($r['verdict']) { $r['verdict'] } else { 'unknown' } }
            'ctf'   { if ($r['solved'] -eq 'true') { 'solved' } else { $r['status'] } }
            'lab'     { if ($r['objectives_met'] -eq 'true') { 'objectives met' } else { $r['status'] } }
            'school'  { if ($r['objectives_met'] -eq 'true') { 'objectives met' } else { $r['status'] } }
            'homelab' { $r['status'] }
            'hunt'  { if ($r['detections_found'] -eq 'true') { 'detection' } else { $r['status'] } }
            default { $r['status'] }
        }
        $link     = "[link]($($r['findings_rel']))"
        $null = $sb.AppendLine("| ``$sid`` | $kindCol | $nt | $platCol | $($r['status']) | $outcomeCol | $link |")
    }

    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- File analyses section ----
if ($fileRecs.Count -gt 0) {
    $null = $sb.AppendLine('## File Analyses')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| ID | Name / Tag | Status | Verdict | Family | Confidence | IOCs |')
    $null = $sb.AppendLine('|---|---|---|---|---|---|---|')

    foreach ($r in $fileRecs) {
        $sid  = $r['sample_id']
        $nt   = if ($r['name_tag'])          { $r['name_tag'] }          else { '(unset)' }
        $vd   = if ($r['verdict'])           { $r['verdict'] }           else { 'unknown' }
        $fam  = if ($r['family_guess'])      { $r['family_guess'] }      else { '(unset)' }
        $conf = if ($r['family_confidence']) { $r['family_confidence'] } else { '(unset)' }
        $iocN = $r['ioc_count']
        $null = $sb.AppendLine("| [``$sid``]($($r['findings_rel'])) | $nt | $($r['status']) | $vd | $fam | $conf | $iocN |")
    }

    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- CTF write-ups section ----
if ($ctfRecs.Count -gt 0) {
    $null = $sb.AppendLine('## CTF Write-ups')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| ID | Challenge | Platform | Category | Difficulty | Solved | Status |')
    $null = $sb.AppendLine('|---|---|---|---|---|---|---|')

    foreach ($r in $ctfRecs) {
        $sid    = $r['sample_id']
        $nt     = if ($r['name_tag'])   { $r['name_tag'] }   else { '(unset)' }
        $plat   = if ($r['platform'])   { $r['platform'] }   else { '-' }
        $cat    = if ($r['category'])   { $r['category'] }   else { '-' }
        $diff   = if ($r['difficulty']) { $r['difficulty'] } else { '-' }
        $solved = if ($r['solved'] -eq 'true') { 'Yes' } else { 'No' }
        $null = $sb.AppendLine("| [``$sid``]($($r['findings_rel'])) | $nt | $plat | $cat | $diff | $solved | $($r['status']) |")
    }

    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- Labs section ----
if ($labRecs.Count -gt 0) {
    $null = $sb.AppendLine('## Labs')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| ID | Lab name | Course | Objectives met | Status |')
    $null = $sb.AppendLine('|---|---|---|---|---|')

    foreach ($r in $labRecs) {
        $sid  = $r['sample_id']
        $nt   = if ($r['name_tag']) { $r['name_tag'] } else { '(unset)' }
        $crs  = if ($r['course'])   { $r['course'] }   else { '-' }
        $met  = if ($r['objectives_met'] -eq 'true') { 'Yes' } else { 'No' }
        $null = $sb.AppendLine("| [``$sid``]($($r['findings_rel'])) | $nt | $crs | $met | $($r['status']) |")
    }

    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- School section ----
if ($schoolRecs.Count -gt 0) {
    $null = $sb.AppendLine('## School')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| ID | Title | Course | Objectives met | Status |')
    $null = $sb.AppendLine('|---|---|---|---|---|')

    foreach ($r in $schoolRecs) {
        $sid  = $r['sample_id']
        $nt   = if ($r['name_tag']) { $r['name_tag'] } else { '(unset)' }
        $crs  = if ($r['course'])   { $r['course'] }   else { if ($r['platform']) { $r['platform'] } else { '-' } }
        $met  = if ($r['objectives_met'] -eq 'true') { 'Yes' } else { 'No' }
        $null = $sb.AppendLine("| [``$sid``]($($r['findings_rel'])) | $nt | $crs | $met | $($r['status']) |")
    }

    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- Homelabs section ----
if ($homelabRecs.Count -gt 0) {
    $null = $sb.AppendLine('## Homelabs')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| ID | Title | Status |')
    $null = $sb.AppendLine('|---|---|---|')

    foreach ($r in $homelabRecs) {
        $sid  = $r['sample_id']
        $nt   = if ($r['name_tag']) { $r['name_tag'] } else { '(unset)' }
        $null = $sb.AppendLine("| [``$sid``]($($r['findings_rel'])) | $nt | $($r['status']) |")
    }

    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- Threat hunts section ----
if ($huntRecs.Count -gt 0) {
    $null = $sb.AppendLine('## Threat Hunts')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('| ID | Hypothesis | Detections found | Confidence | Status |')
    $null = $sb.AppendLine('|---|---|---|---|---|')

    foreach ($r in $huntRecs) {
        $sid  = $r['sample_id']
        $hyp  = if ($r['hypothesis']) { $r['hypothesis'] } else { if ($r['name_tag']) { $r['name_tag'] } else { '(unset)' } }
        $det  = if ($r['detections_found'] -eq 'true') { 'Yes' } else { 'No' }
        $conf = if ($r['confidence']) { $r['confidence'] } else { '-' }
        $null = $sb.AppendLine("| [``$sid``]($($r['findings_rel'])) | $hyp | $det | $conf | $($r['status']) |")
    }

    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- Cross-reference: By Skill ----
$allSkills = @()
foreach ($r in $activeRecs) { $allSkills += $r['skills'] }
$allSkills = @($allSkills | Where-Object { $_ -ne '' } | Select-Object -Unique | Sort-Object)

if ($allSkills.Count -gt 0) {
    $null = $sb.AppendLine('## Cross-Reference: By Skill')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('> Engagements grouped by demonstrated skill (from ``skills[]`` frontmatter field, all kinds).')
    $null = $sb.AppendLine('')

    foreach ($skill in ($allSkills | Sort-Object)) {
        $recsWithSkill = @($activeRecs | Where-Object { $_['skills'] -contains $skill })
        if ($recsWithSkill.Count -eq 0) { continue }

        $null = $sb.AppendLine("### ``$skill``")
        $null = $sb.AppendLine('')
        foreach ($r in $recsWithSkill) {
            $sid = $r['sample_id']
            $nt  = if ($r['name_tag']) { $r['name_tag'] } else { '(unset)' }
            $knd = $r['engagement_kind']
            $null = $sb.AppendLine("- [``$sid``]($($r['findings_rel'])) [$knd] -- $nt")
        }
        $null = $sb.AppendLine('')
    }

    $null = $sb.AppendLine('> See `20_notes/skills-coverage.md` for the full hand-maintained depth tracker.')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- Cross-reference: By Platform (CTF/Lab kinds) ----
$platformRecs = @($activeRecs | Where-Object { $_['engagement_kind'] -in @('ctf','lab') -and $_['platform'] -ne '' })
if ($platformRecs.Count -gt 0) {
    $platforms = @($platformRecs | ForEach-Object { $_['platform'] } | Select-Object -Unique | Sort-Object)

    $null = $sb.AppendLine('## Cross-Reference: By Platform')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('> CTF and lab engagements grouped by platform / provider.')
    $null = $sb.AppendLine('')

    foreach ($plat in $platforms) {
        $recsWithPlat = @($platformRecs | Where-Object { $_['platform'] -eq $plat })
        if ($recsWithPlat.Count -eq 0) { continue }

        $null = $sb.AppendLine("### $plat")
        $null = $sb.AppendLine('')
        foreach ($r in $recsWithPlat) {
            $sid = $r['sample_id']
            $nt  = if ($r['name_tag']) { $r['name_tag'] } else { '(unset)' }
            $knd = $r['engagement_kind']
            $null = $sb.AppendLine("- [``$sid``]($($r['findings_rel'])) [$knd] -- $nt")
        }
        $null = $sb.AppendLine('')
    }

    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- Cross-reference: By Tag ----
if ($allTags.Count -gt 0) {
    $null = $sb.AppendLine('## Cross-Reference: By Tag')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('> Engagements grouped by analytical tag.')
    $null = $sb.AppendLine('')

    foreach ($tag in ($allTags | Sort-Object)) {
        $samplesWithTag = @($activeRecs | Where-Object { $_['tags'] -contains $tag })
        if ($samplesWithTag.Count -eq 0) { continue }

        $null = $sb.AppendLine("### ``$tag``")
        $null = $sb.AppendLine('')
        foreach ($r in $samplesWithTag) {
            $sid    = $r['sample_id']
            $nt     = if ($r['name_tag']) { $r['name_tag'] } else { '(unset)' }
            $knd    = $r['engagement_kind']
            $null = $sb.AppendLine("- [``$sid``]($($r['findings_rel'])) [$knd] -- $nt")
        }
        $null = $sb.AppendLine('')
    }

    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- Cross-reference: By MITRE (file-kind only) ----
$allMitre = @()
foreach ($r in $fileRecs) { $allMitre += $r['mitre_techniques'] }
$allMitre = @($allMitre | Select-Object -Unique | Sort-Object)

if ($allMitre.Count -gt 0) {
    $null = $sb.AppendLine('## Cross-Reference: By MITRE ATT&CK Technique')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('> File-kind engagements only. Triage-level mapping -- not a certified assessment.')
    $null = $sb.AppendLine('')

    foreach ($techId in ($allMitre | Sort-Object)) {
        $techName = Get-MitreName $techId
        $samplesWithTech = @($fileRecs | Where-Object { $_['mitre_techniques'] -contains $techId })
        if ($samplesWithTech.Count -eq 0) { continue }

        $null = $sb.AppendLine("### ``$techName``")
        $null = $sb.AppendLine('')
        foreach ($r in $samplesWithTech) {
            $sid = $r['sample_id']
            $nt  = if ($r['name_tag']) { $r['name_tag'] } else { '(unset)' }
            $fam = if ($r['family_guess']) { $r['family_guess'] } else { $r['verdict'] }
            $null = $sb.AppendLine("- [``$sid``]($($r['findings_rel'])) - $nt ($fam)")
        }
        $null = $sb.AppendLine('')
    }

    $null = $sb.AppendLine('> See `20_notes/MITRE-coverage.md` for the full hand-maintained coverage tracker.')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('---')
    $null = $sb.AppendLine('')
}

# ---- Reserve slots ----
if ($reserveRecs.Count -gt 0) {
    $null = $sb.AppendLine('## Reserve Slots')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('> Unassigned. Run `30_scripts/new_engagement.ps1 -NextNumber N` to scaffold.')
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

$null = $sb.AppendLine('*Auto-generated -- edit frontmatter in each lab `03_findings/sample_XX.md` and re-run `export-summary.ps1` to update.*')

$indexPath = Join-Path $Root 'INDEX.md'
$sb.ToString() | Set-Content -Path $indexPath -Encoding UTF8
Write-Host "[export] Wrote $indexPath" -ForegroundColor Green
Write-Host "[export] Done. $($records.Count) records ($activeCount active: $($fileRecs.Count) file / $($ctfRecs.Count) ctf / $($labRecs.Count) lab / $($schoolRecs.Count) school / $($homelabRecs.Count) homelab / $($huntRecs.Count) hunt -- $($reserveRecs.Count) reserve)." -ForegroundColor Cyan
