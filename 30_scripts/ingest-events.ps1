#Requires -Version 5.1
<#
.SYNOPSIS
    Parse a SIEM or Sysmon event CSV export and write structured Markdown tables
    into a hunt engagement's 02_dynamic file.

.DESCRIPTION
    Designed for threat hunt (kind: hunt) engagements.
    Reads a CSV exported from Splunk, Elastic, or a Sysmon evtx-to-CSV conversion,
    then appends structured Markdown tables to the engagement's 02_dynamic/sample_XX.md.

    Tables generated (only if matching rows found):
      - Process creation timeline (Sysmon EventID 1 / EventCode 4688)
      - Network connections (Sysmon EventID 3)
      - File create / write events (Sysmon EventID 11)
      - Registry set value events (Sysmon EventID 13)
      - Process access (Sysmon EventID 10 -- LSASS access / injection)
      - IOC candidate review table (for 40_iocs/indicators.csv consideration)

    Expected CSV columns (flexible -- all auto-detected, missing ones skipped):
      TimeGenerated, EventID, Computer, Image, CommandLine, ParentImage,
      TargetImage, GrantedAccess, DestinationIp, DestinationPort,
      TargetFilename, TargetObject, Details

    The raw CSV is never committed -- only the extracted Markdown tables.

.PARAMETER SampleId
    Engagement slot ID (e.g. sample_11, or bare 11).

.PARAMETER EventCsv
    Full path to SIEM/Sysmon CSV export. Not committed to repo.

.PARAMETER HostFilter
    Comma-separated hostnames to include. Default: all hosts.

.PARAMETER EventIdFilter
    Comma-separated Sysmon EventIDs to include (e.g. "1,3,10,11"). Default: all.

.PARAMETER MaxRows
    Maximum rows per Markdown table before truncation message. Default: 50.

.PARAMETER DryRun
    Print output to console only; do not write any files.

.PARAMETER SkipIocAppend
    Skip appending IOC candidates to 40_iocs/indicators.csv.

.PARAMETER Root
    Repo root path. Defaults to parent of this script's directory.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\30_scripts\ingest-events.ps1 `
        -SampleId sample_11 `
        -EventCsv "C:\analysis\sysmon_export.csv"

    powershell -ExecutionPolicy Bypass -File .\30_scripts\ingest-events.ps1 `
        -SampleId sample_11 `
        -EventCsv "C:\analysis\sysmon_export.csv" `
        -HostFilter "WRK-04,WRK-07" `
        -EventIdFilter "1,3,10,11"

    powershell -ExecutionPolicy Bypass -File .\30_scripts\ingest-events.ps1 `
        -SampleId sample_11 `
        -EventCsv "C:\analysis\sysmon_export.csv" `
        -DryRun
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SampleId,

    [Parameter(Mandatory = $true)]
    [string]$EventCsv,

    [string]$HostFilter      = '',
    [string]$EventIdFilter   = '',
    [int]   $MaxRows         = 50,
    [switch]$DryRun,
    [switch]$SkipIocAppend,
    [string]$Root            = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Normalise SampleId
# ---------------------------------------------------------------------------

if ($SampleId -match '^\d+$') {
    $SampleId = 'sample_{0:D2}' -f [int]$SampleId
}
$SampleId = $SampleId.Trim().ToLower()

# ---------------------------------------------------------------------------
# Validate inputs
# ---------------------------------------------------------------------------

if (-not (Test-Path $EventCsv)) {
    Write-Host "[ERROR] Event CSV not found: $EventCsv" -ForegroundColor Red
    exit 1
}

$dynFile = Join-Path $Root "02_dynamic\$SampleId.md"
if (-not (Test-Path $dynFile)) {
    Write-Host "[ERROR] 02_dynamic\$SampleId.md not found. Run new_engagement.ps1 first." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Load and filter CSV
# ---------------------------------------------------------------------------

Write-Host "[ingest-events] Loading $EventCsv ..." -ForegroundColor Cyan

$allRows = Import-Csv $EventCsv -ErrorAction Stop
$cols = $allRows[0].PSObject.Properties.Name

Write-Host "[ingest-events] $($allRows.Count) total rows, columns: $($cols -join ', ')" -ForegroundColor Gray

# Host filter
$hostList = @()
if ($HostFilter -ne '') {
    $hostList = $HostFilter -split ',' | ForEach-Object { $_.Trim().ToLower() }
}

# EventId filter
$eventIdList = @()
if ($EventIdFilter -ne '') {
    $eventIdList = $EventIdFilter -split ',' | ForEach-Object { $_.Trim() }
}

function Get-Col {
    param($Row, [string[]]$Candidates)
    foreach ($c in $Candidates) {
        if ($cols -contains $c -and -not [string]::IsNullOrWhiteSpace($Row.$c)) {
            return $Row.$c
        }
    }
    return ''
}

$filteredRows = $allRows | Where-Object {
    $eid  = (Get-Col -Row $_ -Candidates @('EventID', 'EventCode', 'event_id')).Trim()
    $host = (Get-Col -Row $_ -Candidates @('Computer', 'host.name', 'computer_name', 'Hostname')).Trim().ToLower()

    $eidOk  = ($eventIdList.Count -eq 0) -or ($eid -in $eventIdList)
    $hostOk = ($hostList.Count -eq 0)    -or ($host -in $hostList)

    $eidOk -and $hostOk
}

Write-Host "[ingest-events] $($filteredRows.Count) rows after filtering." -ForegroundColor Gray

if ($filteredRows.Count -eq 0) {
    Write-Host "[ingest-events] No matching rows. Check -HostFilter and -EventIdFilter values." -ForegroundColor Yellow
    exit 0
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Trim80 {
    param([string]$s)
    if ($s.Length -gt 80) { return $s.Substring(0, 77) + '...' }
    return $s
}

function Format-Table-MD {
    param([string[]]$Headers, [object[]]$Rows, [int]$Max)
    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine('| ' + ($Headers -join ' | ') + ' |')
    $null = $sb.AppendLine('|' + (($Headers | ForEach-Object { '---' }) -join '|') + '|')
    $count = 0
    foreach ($r in $Rows) {
        if ($count -ge $Max) {
            $null = $sb.AppendLine("| *(truncated -- $($Rows.Count - $Max) more rows)* |" + ((' |' * ($Headers.Count - 1))))
            break
        }
        $null = $sb.AppendLine($r)
        $count++
    }
    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# Build sections
# ---------------------------------------------------------------------------

$sections = [System.Text.StringBuilder]::new()
$iocCandidates = [System.Collections.Generic.List[hashtable]]::new()
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm'

$null = $sections.AppendLine('')
$null = $sections.AppendLine("<!-- ingest-events.ps1 appended $timestamp from: $(Split-Path $EventCsv -Leaf) -->")
$null = $sections.AppendLine('')

# ---- Process Creation (EventID 1 / 4688) ----
$procRows = @($filteredRows | Where-Object {
    $eid = (Get-Col -Row $_ -Candidates @('EventID', 'EventCode', 'event_id')).Trim()
    $eid -in @('1', '4688')
})

if ($procRows.Count -gt 0) {
    $null = $sections.AppendLine('#### Process Creation Timeline (Sysmon Event 1 / 4688)')
    $null = $sections.AppendLine('')
    $tableRows = @()
    foreach ($r in $procRows) {
        $ts     = Get-Col -Row $r -Candidates @('TimeGenerated', 'UtcTime', 'time', '@timestamp')
        $host   = Get-Col -Row $r -Candidates @('Computer', 'host.name', 'Hostname')
        $img    = Trim80 (Get-Col -Row $r -Candidates @('Image', 'process.name', 'NewProcessName'))
        $parent = Trim80 (Get-Col -Row $r -Candidates @('ParentImage', 'process.parent.name', 'ParentProcessName'))
        $cmdl   = Trim80 (Get-Col -Row $r -Candidates @('CommandLine', 'process.command_line', 'ProcessCommandLine'))
        $hash   = Get-Col -Row $r -Candidates @('Hashes', 'process.hash.sha256', 'FileHash')
        $tableRows += "| $ts | $host | ``$img`` | ``$parent`` | ``$cmdl`` | $hash |"

        # Flag suspicious patterns for IOC candidates
        if ($img -match '\\Temp\\' -or $img -match '\\AppData\\' -or $img -match '\\Users\\Public\\') {
            $iocCandidates.Add(@{
                type  = 'file_path'
                value = $img
                note  = "Suspicious process image path (Process Creation event)"
            })
        }
    }
    $null = $sections.Append((Format-Table-MD -Headers @('Time', 'Host', 'Image', 'Parent', 'CommandLine', 'Hash') -Rows $tableRows -Max $MaxRows))
    $null = $sections.AppendLine('')
}

# ---- Network Connections (EventID 3) ----
$netRows = @($filteredRows | Where-Object {
    (Get-Col -Row $_ -Candidates @('EventID', 'EventCode', 'event_id')).Trim() -eq '3'
})

if ($netRows.Count -gt 0) {
    $null = $sections.AppendLine('#### Network Connections (Sysmon Event 3)')
    $null = $sections.AppendLine('')
    $tableRows = @()
    foreach ($r in $netRows) {
        $ts   = Get-Col -Row $r -Candidates @('TimeGenerated', 'UtcTime', 'time', '@timestamp')
        $host = Get-Col -Row $r -Candidates @('Computer', 'host.name', 'Hostname')
        $img  = Trim80 (Get-Col -Row $r -Candidates @('Image', 'process.name'))
        $dip  = Get-Col -Row $r -Candidates @('DestinationIp', 'destination.ip', 'DestinationAddress')
        $dp   = Get-Col -Row $r -Candidates @('DestinationPort', 'destination.port')
        $dhost = Get-Col -Row $r -Candidates @('DestinationHostname', 'dns.resolved_ip')
        $proto = Get-Col -Row $r -Candidates @('Protocol', 'network.protocol', 'Transport')
        $tableRows += "| $ts | $host | ``$img`` | $dip | $dp | $dhost | $proto |"

        if ($dip -ne '' -and $dip -notmatch '^10\.' -and $dip -notmatch '^192\.168\.' -and $dip -notmatch '^172\.') {
            $iocCandidates.Add(@{
                type  = 'ip'
                value = $dip
                note  = "External outbound connection (Event 3) from $img port $dp"
            })
        }
    }
    $null = $sections.Append((Format-Table-MD -Headers @('Time', 'Host', 'Image', 'DestIP', 'DestPort', 'DestHost', 'Proto') -Rows $tableRows -Max $MaxRows))
    $null = $sections.AppendLine('')
}

# ---- File Create / Write (EventID 11) ----
$fileRows = @($filteredRows | Where-Object {
    (Get-Col -Row $_ -Candidates @('EventID', 'EventCode', 'event_id')).Trim() -eq '11'
})

if ($fileRows.Count -gt 0) {
    $null = $sections.AppendLine('#### File Create Events (Sysmon Event 11)')
    $null = $sections.AppendLine('')
    $tableRows = @()
    foreach ($r in $fileRows) {
        $ts    = Get-Col -Row $r -Candidates @('TimeGenerated', 'UtcTime', 'time', '@timestamp')
        $host  = Get-Col -Row $r -Candidates @('Computer', 'host.name', 'Hostname')
        $img   = Trim80 (Get-Col -Row $r -Candidates @('Image', 'process.name'))
        $tfile = Trim80 (Get-Col -Row $r -Candidates @('TargetFilename', 'file.path', 'TargetObject'))
        $tableRows += "| $ts | $host | ``$img`` | ``$tfile`` |"

        if ($tfile -match '\\Temp\\' -or $tfile -match '\\AppData\\' -or $tfile -match '\.exe$' -or $tfile -match '\.dll$') {
            $iocCandidates.Add(@{
                type  = 'file_path'
                value = $tfile
                note  = "Suspicious file create (Event 11) by $img"
            })
        }
    }
    $null = $sections.Append((Format-Table-MD -Headers @('Time', 'Host', 'Image', 'TargetFilename') -Rows $tableRows -Max $MaxRows))
    $null = $sections.AppendLine('')
}

# ---- Registry Set Value (EventID 13) ----
$regRows = @($filteredRows | Where-Object {
    (Get-Col -Row $_ -Candidates @('EventID', 'EventCode', 'event_id')).Trim() -eq '13'
})

if ($regRows.Count -gt 0) {
    $null = $sections.AppendLine('#### Registry Set Value (Sysmon Event 13)')
    $null = $sections.AppendLine('')
    $tableRows = @()
    $persistenceKeys = @('Run', 'RunOnce', 'Winlogon', 'Services', 'Schedule', 'AppInit')
    foreach ($r in $regRows) {
        $ts   = Get-Col -Row $r -Candidates @('TimeGenerated', 'UtcTime', 'time', '@timestamp')
        $host = Get-Col -Row $r -Candidates @('Computer', 'host.name', 'Hostname')
        $img  = Trim80 (Get-Col -Row $r -Candidates @('Image', 'process.name'))
        $tobj = Trim80 (Get-Col -Row $r -Candidates @('TargetObject', 'registry.path', 'ObjectName'))
        $det  = Trim80 (Get-Col -Row $r -Candidates @('Details', 'registry.value', 'NewValue'))
        $flag = if ($persistenceKeys | Where-Object { $tobj -match $_ }) { '** PERSISTENCE **' } else { '' }
        $tableRows += "| $ts | $host | ``$img`` | ``$tobj`` | ``$det`` | $flag |"

        if ($flag) {
            $iocCandidates.Add(@{
                type  = 'registry_key'
                value = $tobj
                note  = "Persistence-adjacent registry write (Event 13) by $img"
            })
        }
    }
    $null = $sections.Append((Format-Table-MD -Headers @('Time', 'Host', 'Image', 'TargetObject', 'Details', 'Flag') -Rows $tableRows -Max $MaxRows))
    $null = $sections.AppendLine('')
}

# ---- Process Access / LSASS (EventID 10) ----
$accessRows = @($filteredRows | Where-Object {
    (Get-Col -Row $_ -Candidates @('EventID', 'EventCode', 'event_id')).Trim() -eq '10'
})

if ($accessRows.Count -gt 0) {
    $null = $sections.AppendLine('#### Process Access Events (Sysmon Event 10)')
    $null = $sections.AppendLine('')
    $tableRows = @()
    foreach ($r in $accessRows) {
        $ts      = Get-Col -Row $r -Candidates @('TimeGenerated', 'UtcTime', 'time', '@timestamp')
        $host    = Get-Col -Row $r -Candidates @('Computer', 'host.name', 'Hostname')
        $src     = Trim80 (Get-Col -Row $r -Candidates @('SourceImage', 'process.name', 'Image'))
        $tgt     = Trim80 (Get-Col -Row $r -Candidates @('TargetImage', 'target.process.name'))
        $access  = Get-Col -Row $r -Candidates @('GrantedAccess', 'process.granted_access')
        $flag    = if ($tgt -match 'lsass' -and $access -match '0x1[Ff][Ff][Ff][Ff][Ff]') { '** LSASS FULL ACCESS **' } else { '' }
        $tableRows += "| $ts | $host | ``$src`` | ``$tgt`` | $access | $flag |"

        if ($flag) {
            $iocCandidates.Add(@{
                type  = 'file_path'
                value = $src
                note  = "LSASS PROCESS_ALL_ACCESS (0x1FFFFF) from non-system process (Event 10)"
            })
        }
    }
    $null = $sections.Append((Format-Table-MD -Headers @('Time', 'Host', 'SourceImage', 'TargetImage', 'GrantedAccess', 'Flag') -Rows $tableRows -Max $MaxRows))
    $null = $sections.AppendLine('')
}

# ---- IOC candidate review table ----
if ($iocCandidates.Count -gt 0) {
    $null = $sections.AppendLine('#### IOC Candidates (review before adding to indicators.csv)')
    $null = $sections.AppendLine('')
    $null = $sections.AppendLine('| Type | Value | Confidence | Notes | Add to IOC? |')
    $null = $sections.AppendLine('|------|-------|-----------|-------|-------------|')
    foreach ($ioc in $iocCandidates) {
        $null = $sections.AppendLine("| $($ioc.type) | ``$($ioc.value)`` | medium | $($ioc.note) | [ ] |")
    }
    $null = $sections.AppendLine('')
    $null = $sections.AppendLine('> Review: remove FPs (e.g. AV scanners accessing LSASS), then add confirmed IOCs to `40_iocs/indicators.csv`.')
    $null = $sections.AppendLine('')
}

$output = $sections.ToString()

# ---------------------------------------------------------------------------
# Write output
# ---------------------------------------------------------------------------

if ($DryRun) {
    Write-Host "`n[DRY RUN] Would append to: $dynFile" -ForegroundColor Yellow
    Write-Host "========== Output preview ==========" -ForegroundColor Cyan
    Write-Host $output
    Write-Host "====================================" -ForegroundColor Cyan
    exit 0
}

Add-Content -Path $dynFile -Value $output -Encoding UTF8
Write-Host "[ingest-events] Appended $($filteredRows.Count) rows of tables to: $dynFile" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Append IOC candidates to indicators.csv
# ---------------------------------------------------------------------------

if (-not $SkipIocAppend -and $iocCandidates.Count -gt 0) {
    $iocPath = Join-Path $Root '40_iocs\indicators.csv'
    $now     = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
    foreach ($ioc in $iocCandidates) {
        $csvLine = '"' + $SampleId + '","' + $ioc.type + '","' + ($ioc.value -replace '"', '""') + '","sysmon_event_export","' + $now + '","' + $ioc.note + '"'
        Add-Content -Path $iocPath -Value $csvLine -Encoding UTF8
    }
    Write-Host "[ingest-events] Appended $($iocCandidates.Count) IOC candidate(s) to indicators.csv (review before commit)" -ForegroundColor Green
}

Write-Host "[ingest-events] Done. Review 02_dynamic\$SampleId.md and clean up noise rows before committing." -ForegroundColor Cyan
