#Requires -Version 5.1
<#
.SYNOPSIS
    Ingest a Procmon CSV export and write structured Markdown tables + IOC candidates
    into the sample's 02_dynamic phase file and 40_iocs/indicators.csv.

.DESCRIPTION
    Takes a Procmon Process Monitor CSV export (File > Save As > CSV format) that
    you produced inside your VM, filters it to the processes of interest, and emits:

      1. Markdown tables for 02_dynamic/sample_XX.md sections:
             - Process tree (unique parent -> child relationships)
             - File system (WriteFile / CreateFile on non-temp system paths)
             - Registry  (RegSetValue / RegCreateKey)
             - Network   (TCP Send / TCP Connect / UDP Send)

      2. IOC candidates appended to 40_iocs/indicators.csv with source tag.

      3. A summary section you can paste into the 02_dynamic dynamic summary.

    The raw Procmon CSV is NEVER committed. It lives on your VM or a scratch
    folder that is gitignored. This script reads it, extracts what matters,
    and writes only sanitized Markdown to the repo.

.PARAMETER SampleId
    The sample ID to target, e.g. sample_07.

.PARAMETER ProcmonCsv
    Full path to the Procmon CSV export file on your machine.
    This file is read but never moved or committed.

.PARAMETER ProcessFilter
    Comma-separated list of process names to include (case-insensitive).
    Defaults to empty (ingest all processes -- you should filter later).
    Example: -ProcessFilter "Updater_v2.211.exe,cmd.exe,powershell.exe"

.PARAMETER Root
    Repo root path. Defaults to parent of script directory.

.PARAMETER DryRun
    Print what would be written without modifying any repo files.

.PARAMETER SkipIocAppend
    Do not append anything to 40_iocs/indicators.csv.

.PARAMETER MaxRows
    Maximum rows to include per table in the Markdown output. Default: 40.
    Use to keep very noisy Procmon exports readable.

.EXAMPLE
    # Basic: ingest all processes
    powershell -ExecutionPolicy Bypass -File .\30_scripts\ingest-procmon.ps1 `
        -SampleId sample_07 `
        -ProcmonCsv "C:\Users\win11\Desktop\procmon_sample_07.csv"

    # Filter to specific processes
    powershell -ExecutionPolicy Bypass -File .\30_scripts\ingest-procmon.ps1 `
        -SampleId sample_07 `
        -ProcmonCsv "C:\Users\win11\Desktop\procmon_sample_07.csv" `
        -ProcessFilter "Updater_v2.211.exe,cmd.exe,powershell.exe"

    # Dry run (preview without writing)
    powershell -ExecutionPolicy Bypass -File .\30_scripts\ingest-procmon.ps1 `
        -SampleId sample_07 `
        -ProcmonCsv "C:\Users\win11\Desktop\procmon_sample_07.csv" `
        -DryRun
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SampleId,

    [Parameter(Mandatory = $true)]
    [string]$ProcmonCsv,

    [string]$ProcessFilter = '',

    [string]$Root          = (Split-Path $PSScriptRoot -Parent),

    [switch]$DryRun,

    [switch]$SkipIocAppend,

    [int]$MaxRows          = 40
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_paths.ps1')

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------

$normalizedId = $SampleId.Trim().ToLower()
if ($normalizedId -match '^\d+$') { $normalizedId = 'sample_{0:D2}' -f [int]$normalizedId }
if ($normalizedId -notmatch '^sample_\d{2}$') {
    Write-Error "SampleId must be like sample_07 or bare number 7. Got: $SampleId"
    exit 1
}

if (-not (Test-Path $ProcmonCsv)) {
    Write-Error "Procmon CSV not found: $ProcmonCsv"
    exit 1
}

$dynamicFile = Get-PhaseFilePath -Root $Root -SampleId $normalizedId -Phase '02_dynamic'
$iocFile     = Join-Path $Root '40_iocs\indicators.csv'

if (-not (Test-Path $dynamicFile)) {
    Write-Error "02_dynamic\$normalizedId.md not found under a LAB folder. Run new_engagement.ps1 first."
    exit 1
}

Write-Host ""
Write-Host "=== ingest-procmon.ps1 ===" -ForegroundColor Cyan
Write-Host "  Sample     : $normalizedId"
Write-Host "  Procmon CSV: $ProcmonCsv"
if ($ProcessFilter) { Write-Host "  Filter     : $ProcessFilter" }
if ($DryRun)        { Write-Host "  DryRun     : YES (no files will be modified)" -ForegroundColor Yellow }
Write-Host ""

# ---------------------------------------------------------------------------
# Load and validate CSV
# ---------------------------------------------------------------------------

Write-Host "Loading CSV..." -NoNewline
try {
    $allRows = Import-Csv $ProcmonCsv -ErrorAction Stop
} catch {
    Write-Error "Failed to parse CSV: $_"
    exit 1
}

# Procmon CSV expected columns (vary slightly by version)
$colMap = @{}
foreach ($col in $allRows[0].PSObject.Properties.Name) {
    $colMap[$col.ToLower().Trim()] = $col
}

# Detect required columns
$requiredKeys = @('process name', 'pid', 'operation', 'path', 'result')
foreach ($k in $requiredKeys) {
    if (-not $colMap.ContainsKey($k)) {
        Write-Error "Procmon CSV missing expected column '$k'. Ensure you exported in CSV format from Procmon."
        exit 1
    }
}

$colProcName = $colMap['process name']
$colPid      = $colMap['pid']
$colOp       = $colMap['operation']
$colPath     = $colMap['path']
$colResult   = $colMap['result']
$colDetail   = $colMap['detail'] ?? 'Detail'   # not always present
$colTime     = $colMap['time of day'] ?? $colMap['time'] ?? ''

Write-Host " $($allRows.Count) rows loaded." -ForegroundColor Green

# ---------------------------------------------------------------------------
# Apply process name filter
# ---------------------------------------------------------------------------

$filterList = @()
if ($ProcessFilter) {
    $filterList = $ProcessFilter -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ }
}

$rows = if ($filterList.Count -gt 0) {
    $allRows | Where-Object { $_.$colProcName.Trim().ToLower() -in $filterList }
} else {
    $allRows
}

$filteredCount = @($rows).Count
Write-Host "  Filtered rows: $filteredCount (of $($allRows.Count))"
if ($filteredCount -eq 0) {
    Write-Host "  No rows matched the filter. Check -ProcessFilter value." -ForegroundColor Yellow
    if ($ProcessFilter) { exit 0 }
}

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

function Truncate-Value {
    param([string]$s, [int]$maxLen = 100)
    if ($s.Length -gt $maxLen) { return $s.Substring(0, $maxLen) + '...' }
    return $s
}

function Is-SystemNoise {
    param([string]$path)
    # Skip very high-frequency system paths that are almost always noise
    $noisePrefixes = @(
        'HKLM\SYSTEM\CurrentControlSet\Control\Nls',
        'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution',
        '\Device\HarddiskVolume',
        'C:\Windows\System32\en-US',
        'C:\Windows\Fonts',
        'C:\Windows\System32\locale.nls'
    )
    foreach ($p in $noisePrefixes) {
        if ($path -like "$p*") { return $true }
    }
    return $false
}

function Is-InterestingFilePath {
    param([string]$path)
    # Focus on user-space and staged drops, not every DLL load
    $interesting = @(
        'C:\Users\',
        'C:\ProgramData\',
        'C:\AppData\',
        'C:\Temp\',
        '%TEMP%',
        '%APPDATA%',
        '%LOCALAPPDATA%',
        'C:\Windows\Temp\',
        '.exe', '.dll', '.bat', '.ps1', '.vbs', '.hta',
        '.lnk', '.job', '.inf', '.ini', '.reg', '.cfg', '.config'
    )
    foreach ($i in $interesting) {
        if ($path -like "*$i*") { return $true }
    }
    return $false
}

function Is-PersistenceKey {
    param([string]$key)
    $persistencePaths = @(
        'Run', 'RunOnce', 'RunServices', 'RunServicesOnce',
        'Startup', 'CurrentVersion\App Paths',
        'Policies\Explorer\Run',
        'SYSTEM\CurrentControlSet\Services',
        'ScheduledTasks', 'TaskScheduler',
        'Winlogon', 'Shell', 'Userinit'
    )
    foreach ($p in $persistencePaths) {
        if ($key -like "*$p*") { return $true }
    }
    return $false
}

# ---------------------------------------------------------------------------
# Extract process tree (unique parent -> child edges)
# ---------------------------------------------------------------------------

Write-Host "  Building process tree..."

$pidToName = @{}
$allRows | ForEach-Object {
    $pid = $_.$colPid.Trim()
    $name = $_.$colProcName.Trim()
    if ($pid -and $name -and -not $pidToName.ContainsKey($pid)) {
        $pidToName[$pid] = $name
    }
}

$processEdges = [System.Collections.Generic.HashSet[string]]::new()
$processRows  = @()

$rows | Where-Object { $_.$colOp.Trim() -like 'Process*' -or $_.$colOp.Trim() -like '*Create*' } |
    ForEach-Object {
        $parent = $_.$colProcName.Trim()
        $path   = $_.$colPath.Trim()
        $op     = $_.$colOp.Trim()
        $detail = if ($colDetail -and $_.$colDetail) { $_.$colDetail.Trim() } else { '' }

        if ($op -match 'Process Create' -and $path) {
            $edge = "$parent|$path"
            if ($processEdges.Add($edge)) {
                $processRows += [PSCustomObject]@{
                    Parent      = $parent
                    Child       = Split-Path $path -Leaf
                    CommandLine = Truncate-Value $detail
                }
            }
        }
    }

# ---------------------------------------------------------------------------
# Extract file system events
# ---------------------------------------------------------------------------

Write-Host "  Extracting file system events..."

$fileOps  = @('WriteFile', 'CreateFile', 'SetEndOfFile', 'SetDispositionInformationFile')
$fileRows = @()
$seen     = [System.Collections.Generic.HashSet[string]]::new()

$rows | Where-Object {
    $fileOps -contains $_.$colOp.Trim() -and
    $_.$colResult.Trim() -eq 'SUCCESS' -and
    -not (Is-SystemNoise $_.$colPath.Trim()) -and
    (Is-InterestingFilePath $_.$colPath.Trim())
} | ForEach-Object {
    $key = "$($_.$colOp.Trim())|$($_.$colPath.Trim())"
    if ($seen.Add($key)) {
        $fileRows += [PSCustomObject]@{
            Process   = $_.$colProcName.Trim()
            Path      = Truncate-Value $_.$colPath.Trim() 90
            Operation = $_.$colOp.Trim()
            Notes     = ''
        }
    }
} | Out-Null

# ---------------------------------------------------------------------------
# Extract registry events
# ---------------------------------------------------------------------------

Write-Host "  Extracting registry events..."

$regOps  = @('RegSetValue', 'RegCreateKey', 'RegOpenKey')
$regRows = @()
$seenReg = [System.Collections.Generic.HashSet[string]]::new()

$rows | Where-Object {
    $regOps -contains $_.$colOp.Trim() -and
    $_.$colResult.Trim() -in @('SUCCESS', 'NAME NOT FOUND', 'REPARSE') -and
    -not (Is-SystemNoise $_.$colPath.Trim())
} | ForEach-Object {
    $key     = "$($_.$colOp.Trim())|$($_.$colPath.Trim())"
    $isPersist = Is-PersistenceKey $_.$colPath.Trim()
    if ($seen.Add($key) -and ($isPersist -or $_.$colOp.Trim() -eq 'RegSetValue')) {
        $detail = if ($colDetail -and $_.$colDetail) { Truncate-Value $_.$colDetail.Trim() 80 } else { '' }
        $regRows += [PSCustomObject]@{
            Process = $_.$colProcName.Trim()
            Key     = Truncate-Value $_.$colPath.Trim() 90
            Op      = $_.$colOp.Trim()
            Detail  = $detail
            IsPersistence = $isPersist
        }
    }
} | Out-Null

# ---------------------------------------------------------------------------
# Extract network events
# ---------------------------------------------------------------------------

Write-Host "  Extracting network events..."

$netOps  = @('TCP Send', 'TCP Connect', 'TCP Reconnect', 'UDP Send', 'TCP Receive')
$netRows = @()
$seenNet = [System.Collections.Generic.HashSet[string]]::new()

$rows | Where-Object {
    $op = $_.$colOp.Trim()
    ($netOps | Where-Object { $op -like "*$_*" }).Count -gt 0 -and
    $_.$colResult.Trim() -ne 'CONNECTION ABORTED'
} | ForEach-Object {
    $pathVal = $_.$colPath.Trim()
    $key = "$($_.$colOp.Trim())|$pathVal"
    if ($seenNet.Add($key)) {
        # path format: "srcIP:port -> dstIP:port" or similar
        $remote = ''
        $port   = ''
        if ($pathVal -match '->') {
            $parts = $pathVal -split '\s*->\s*'
            $dest  = if ($parts.Count -ge 2) { $parts[1] } else { $pathVal }
            if ($dest -match '^(.+):(\d+)$') {
                $remote = $Matches[1]; $port = $Matches[2]
            } else { $remote = $dest }
        } else { $remote = $pathVal }

        $netRows += [PSCustomObject]@{
            Process = $_.$colProcName.Trim()
            Proto   = if ($_.$colOp -match 'UDP') { 'UDP' } else { 'TCP' }
            Remote  = Truncate-Value $remote 60
            Port    = $port
            Op      = $_.$colOp.Trim()
        }
    }
} | Out-Null

# ---------------------------------------------------------------------------
# Build Markdown output
# ---------------------------------------------------------------------------

Write-Host "  Building Markdown..."

$now   = Get-Date -Format 'yyyy-MM-dd HH:mm'
$sb    = [System.Text.StringBuilder]::new()

$null = $sb.AppendLine("<!-- ingest-procmon.ps1 output for $normalizedId -- generated $now -->")
$null = $sb.AppendLine("<!-- Procmon source: $(Split-Path $ProcmonCsv -Leaf) -->")
$null = $sb.AppendLine("<!-- Rows ingested: $filteredCount of $($allRows.Count) total -->")
$null = $sb.AppendLine('')

# --- Process tree ---
$null = $sb.AppendLine('## Process tree (from Procmon)')
$null = $sb.AppendLine('')
if ($processRows.Count -gt 0) {
    $null = $sb.AppendLine('| Parent | Child | Command line / notes |')
    $null = $sb.AppendLine('|--------|--------|---------------------|')
    foreach ($r in ($processRows | Select-Object -First $MaxRows)) {
        $null = $sb.AppendLine("| $($r.Parent) | $($r.Child) | $($r.CommandLine) |")
    }
    if ($processRows.Count -gt $MaxRows) {
        $null = $sb.AppendLine("| _(+$($processRows.Count - $MaxRows) more rows truncated -- increase -MaxRows to see all)_ | | |")
    }
} else {
    $null = $sb.AppendLine('| _No Process Create events found in filtered rows_ | | |')
    $null = $sb.AppendLine('')
    $null = $sb.AppendLine('> Tip: ensure Procmon had Process/Thread category enabled,')
    $null = $sb.AppendLine('> or add the parent process to -ProcessFilter.')
}
$null = $sb.AppendLine('')

# --- File system ---
$null = $sb.AppendLine('## File system (from Procmon -- interesting writes/creates)')
$null = $sb.AppendLine('')
if ($fileRows.Count -gt 0) {
    $null = $sb.AppendLine('| Process | Path | Operation | Notes |')
    $null = $sb.AppendLine('|---------|------|-----------|-------|')
    foreach ($r in ($fileRows | Select-Object -First $MaxRows)) {
        $null = $sb.AppendLine("| $($r.Process) | ``$($r.Path)`` | $($r.Operation) | |")
    }
    if ($fileRows.Count -gt $MaxRows) {
        $null = $sb.AppendLine("| _(+$($fileRows.Count - $MaxRows) more rows truncated)_ | | | |")
    }
} else {
    $null = $sb.AppendLine('| _No interesting file write/create events found_ | | | |')
}
$null = $sb.AppendLine('')

# --- Registry ---
$null = $sb.AppendLine('## Registry (from Procmon -- SetValue + persistence-adjacent keys)')
$null = $sb.AppendLine('')
if ($regRows.Count -gt 0) {
    $null = $sb.AppendLine('| Process | Key | Operation | Detail | Persistence? |')
    $null = $sb.AppendLine('|---------|-----|-----------|--------|--------------|')
    foreach ($r in ($regRows | Select-Object -First $MaxRows)) {
        $flag = if ($r.IsPersistence) { '**YES**' } else { '' }
        $null = $sb.AppendLine("| $($r.Process) | ``$($r.Key)`` | $($r.Op) | $($r.Detail) | $flag |")
    }
    if ($regRows.Count -gt $MaxRows) {
        $null = $sb.AppendLine("| _(+$($regRows.Count - $MaxRows) more rows truncated)_ | | | | |")
    }
} else {
    $null = $sb.AppendLine('| _No RegSetValue or persistence-adjacent registry events found_ | | | | |')
}
$null = $sb.AppendLine('')

# --- Network ---
$null = $sb.AppendLine('## Network (from Procmon -- TCP/UDP connections)')
$null = $sb.AppendLine('')
if ($netRows.Count -gt 0) {
    $null = $sb.AppendLine('| Process | Proto | Remote host | Port | Operation |')
    $null = $sb.AppendLine('|---------|-------|-------------|------|-----------|')
    foreach ($r in ($netRows | Select-Object -First $MaxRows)) {
        $null = $sb.AppendLine("| $($r.Process) | $($r.Proto) | ``$($r.Remote)`` | $($r.Port) | $($r.Op) |")
    }
    if ($netRows.Count -gt $MaxRows) {
        $null = $sb.AppendLine("| _(+$($netRows.Count - $MaxRows) more rows truncated)_ | | | | |")
    }
} else {
    $null = $sb.AppendLine('| _No TCP/UDP network events found in filtered rows_ | | | | |')
}
$null = $sb.AppendLine('')

# --- IOC candidates ---
$iocCandidates = @()

foreach ($r in $fileRows) {
    if ($r.Path -match '\.(exe|dll|bat|ps1|vbs|hta|lnk|tmp)$') {
        $iocCandidates += [PSCustomObject]@{
            sample_id  = $normalizedId
            type       = 'file_path'
            value      = $r.Path
            source     = "dynamic_procmon_$(Get-Date -Format 'yyyyMMdd')"
            first_seen = ''
            notes      = "dropped/written by $($r.Process)"
        }
    }
}

foreach ($r in $regRows) {
    if ($r.IsPersistence) {
        $iocCandidates += [PSCustomObject]@{
            sample_id  = $normalizedId
            type       = 'registry_key'
            value      = $r.Key
            source     = "dynamic_procmon_$(Get-Date -Format 'yyyyMMdd')"
            first_seen = ''
            notes      = "persistence-adjacent key -- $($r.Process)"
        }
    }
}

foreach ($r in ($netRows | Where-Object { $_.Remote -and $_.Remote -ne '' })) {
    $type = if ($r.Remote -match '^\d+\.\d+\.\d+\.\d+$') { 'ip' } else { 'domain' }
    $iocCandidates += [PSCustomObject]@{
        sample_id  = $normalizedId
        type       = $type
        value      = $r.Remote
        source     = "dynamic_procmon_$(Get-Date -Format 'yyyyMMdd')"
        first_seen = ''
        notes      = "$($r.Proto) port $($r.Port) -- $($r.Process)"
    }
}

# Deduplicate IOC candidates by type+value
$seenIoc = [System.Collections.Generic.HashSet[string]]::new()
$iocCandidates = $iocCandidates | Where-Object {
    $seenIoc.Add("$($_.type)|$($_.value)")
}

$null = $sb.AppendLine("## IOC candidates (review before appending to indicators.csv)")
$null = $sb.AppendLine('')
$null = $sb.AppendLine('> These are auto-extracted suggestions. Review each row before treating as confirmed IOC.')
$null = $sb.AppendLine('')
if ($iocCandidates.Count -gt 0) {
    $null = $sb.AppendLine('| Type | Value | Notes |')
    $null = $sb.AppendLine('|------|-------|-------|')
    foreach ($c in $iocCandidates) {
        $null = $sb.AppendLine("| $($c.type) | ``$($c.value)`` | $($c.notes) |")
    }
} else {
    $null = $sb.AppendLine('_No IOC candidates auto-extracted. Check network and file tables above manually._')
}
$null = $sb.AppendLine('')

# --- Stats summary ---
$null = $sb.AppendLine('## Ingest summary')
$null = $sb.AppendLine('')
$null = $sb.AppendLine("| Metric | Count |")
$null = $sb.AppendLine("|--------|-------|")
$null = $sb.AppendLine("| Total Procmon rows | $($allRows.Count) |")
$null = $sb.AppendLine("| Rows after process filter | $filteredCount |")
$null = $sb.AppendLine("| Process Create edges | $($processRows.Count) |")
$null = $sb.AppendLine("| Interesting file events | $($fileRows.Count) |")
$null = $sb.AppendLine("| Registry events | $($regRows.Count) |")
$null = $sb.AppendLine("| Network events | $($netRows.Count) |")
$null = $sb.AppendLine("| IOC candidates | $($iocCandidates.Count) |")
$null = $sb.AppendLine('')

$mdOutput = $sb.ToString()

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

if ($DryRun) {
    Write-Host ""
    Write-Host "=== DRY RUN OUTPUT (would be appended to $dynamicFile) ===" -ForegroundColor Yellow
    Write-Host $mdOutput
    if ($iocCandidates.Count -gt 0) {
        Write-Host "=== IOC candidates (would be appended to indicators.csv) ===" -ForegroundColor Yellow
        $iocCandidates | Format-Table | Out-String | Write-Host
    }
    Write-Host "=== DRY RUN COMPLETE -- no files modified ===" -ForegroundColor Yellow
    exit 0
}

# Append to 02_dynamic file
$divider = "`n`n<!-- ===== ingest-procmon output appended $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===== -->`n"
Add-Content -Path $dynamicFile -Value ($divider + $mdOutput) -Encoding UTF8
Write-Host "  [appended] $dynamicFile" -ForegroundColor Green

# Append IOC candidates to indicators.csv
if (-not $SkipIocAppend -and $iocCandidates.Count -gt 0) {
    if (Test-Path $iocFile) {
        foreach ($c in $iocCandidates) {
            $line = "$($c.sample_id),$($c.type),$($c.value),$($c.source),$($c.first_seen),$($c.notes)"
            Add-Content -Path $iocFile -Value $line -Encoding UTF8
        }
        Write-Host "  [appended] $iocCandidates.Count IOC candidate(s) to $iocFile" -ForegroundColor Green
        Write-Host "             Review newly appended rows -- they are candidates, not verified IOCs." -ForegroundColor Yellow
    } else {
        Write-Host "  [skipped] 40_iocs/indicators.csv not found -- run new_sample.ps1 first or create manually." -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "=== ingest-procmon done ===" -ForegroundColor Cyan
Write-Host "  Process edges  : $($processRows.Count)"
Write-Host "  File events    : $($fileRows.Count)"
Write-Host "  Registry events: $($regRows.Count)"
Write-Host "  Network events : $($netRows.Count)"
Write-Host "  IOC candidates : $($iocCandidates.Count)"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Open 02_dynamic\$normalizedId.md and review appended tables." -ForegroundColor Gray
Write-Host "  2. Remove noise rows, fill in Notes columns, annotate persistence flags." -ForegroundColor Gray
Write-Host "  3. Review IOC candidates in 40_iocs/indicators.csv -- mark or remove false positives." -ForegroundColor Gray
Write-Host "  4. Write or update the dynamic summary paragraph." -ForegroundColor Gray
Write-Host "  5. Run: close_sample.ps1 -SampleId $normalizedId -Status dynamic" -ForegroundColor Gray
