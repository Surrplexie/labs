#Requires -Version 5.1
<#
.SYNOPSIS
    Scans all committed .md and .csv files for potential PII or host-machine identity leaks.

.DESCRIPTION
    Checks for patterns that should not appear in a public repository:

      1. Windows paths containing non-VM usernames
         Any C:\Users\<name>\ path where <name> is not in the allowed VM username list.
         Default allowed: win11. Extend with -AllowedVmUsers.

      2. Email addresses
         Matches common email patterns. False positives possible in IOC data -- review
         each match manually.

      3. Internal hostname patterns
         Hostnames ending in .local, .internal, .corp, .lan, .home.
         Also bare NetBIOS-style names if they appear in path context.

      4. Analyst machine absolute paths
         Paths starting with C:\Users\ (or similar) that contain a username not in
         the allowed list, when appearing outside of obvious IOC table context.

    Exit code 0 = clean (no matches).
    Exit code 1 = one or more potential issues found.

.PARAMETER Root
    Path to repo root. Defaults to parent of script directory.

.PARAMETER AllowedVmUsers
    Additional VM usernames to treat as safe (besides 'win11').
    Example: -AllowedVmUsers analyst,sandbox

.PARAMETER IncludeIocFiles
    By default the IOC CSV (40_iocs/) is skipped because it legitimately contains
    external URLs and indicators. Pass this flag to scan it too.

.PARAMETER SampleId
    Limit scan to files for one sample ID (e.g., sample_01).

.EXAMPLE
    # Full repo scan
    powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1

    # One sample only
    powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1 -SampleId sample_01

    # Add extra allowed VM username
    powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1 -AllowedVmUsers analyst,vm_user
#>

param(
    [string]$Root           = (Split-Path $PSScriptRoot -Parent),
    [string[]]$AllowedVmUsers = @(),
    [switch]$IncludeIocFiles,
    [string]$SampleId       = ''
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

$baseAllowedUsers = @('win11', 'SYSTEM', 'Public', 'Default', 'Default User', 'All Users')
$allowedUsers     = ($baseAllowedUsers + $AllowedVmUsers) | Select-Object -Unique

# Build a regex alternation of safe usernames (case-insensitive)
$safeUserPattern = ($allowedUsers | ForEach-Object { [regex]::Escape($_) }) -join '|'

# Pattern 1: Windows user paths with non-safe username
# Matches C:\Users\<name>\ or C:/Users/<name>/
$patternWinPath = [regex]::new(
    "(?i)C:[/\\]Users[/\\](?!($safeUserPattern)[/\\])[^/\\<>\s`"']{2,}[/\\]",
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)

# Pattern 2: Email addresses (standard format)
$patternEmail = [regex]::new(
    '\b[A-Za-z0-9._%+\-]{2,}@[A-Za-z0-9.\-]{2,}\.[A-Za-z]{2,}\b'
)

# Pattern 3: Internal TLD hostnames
$patternInternalHost = [regex]::new(
    '(?i)\b[\w\-]{2,}\.(local|internal|corp|lan|home|intranet|domain)\b'
)

# Pattern 4: UNC paths  \\hostname\share
$patternUnc = [regex]::new(
    '\\\\[A-Za-z0-9\-_]{2,}\\[A-Za-z0-9\-_$]{1,}'
)

$patterns = @(
    @{ Name = 'Win-path non-VM user'; Regex = $patternWinPath;    Severity = 'FAIL' }
    @{ Name = 'Email address';        Regex = $patternEmail;       Severity = 'WARN' }
    @{ Name = 'Internal hostname';    Regex = $patternInternalHost; Severity = 'WARN' }
    @{ Name = 'UNC path';             Regex = $patternUnc;         Severity = 'WARN' }
)

# ---------------------------------------------------------------------------
# Collect files to scan
# ---------------------------------------------------------------------------

$skipDirs = @('.git', 'dist', '30_scripts')

$allFiles = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $rel  = $_.FullName.Substring($Root.Length).TrimStart('\', '/')
        $skip = $false
        foreach ($d in $skipDirs) {
            if ($rel -like "$d\*" -or $rel -like "$d/*") { $skip = $true; break }
        }
        if (-not $IncludeIocFiles -and $rel -like '40_iocs*') { $skip = $true }
        -not $skip
    } |
    Where-Object {
        $ext = $_.Extension.ToLower()
        $rel = $_.FullName.Substring($Root.Length).TrimStart('\', '/')
        if ($ext -in @('.md', '.csv', '.txt')) { return $true }
        if ($rel -like '45_hunt_queries*' -and $ext -in @('.kql', '.spl', '.yaml', '.yml')) { return $true }
        return $false
    }

if ($SampleId -ne '') {
    $allFiles = $allFiles | Where-Object { $_.Name -like "*$SampleId*" -or $_.FullName -like "*$SampleId*" }
}

# ---------------------------------------------------------------------------
# Scan
# ---------------------------------------------------------------------------

$totalFinds = 0
$fails      = 0
$warns      = 0

Write-Host ""
Write-Host "Redact check -- scanning $($allFiles.Count) file(s)" -ForegroundColor Cyan
Write-Host "  Allowed VM usernames: $($allowedUsers -join ', ')" -ForegroundColor DarkGray
Write-Host ""

foreach ($file in $allFiles) {
    $rel     = $file.FullName.Substring($Root.Length).TrimStart('\', '/')
    $lines   = Get-Content $file.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { continue }

    $fileHits = @()

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line   = $lines[$i]
        $lineNo = $i + 1

        foreach ($p in $patterns) {
            $matches = $p.Regex.Matches($line)
            foreach ($m in $matches) {
                $fileHits += [PSCustomObject]@{
                    Line     = $lineNo
                    Severity = $p.Severity
                    Pattern  = $p.Name
                    Match    = $m.Value
                    Context  = $line.Trim()
                }
                $totalFinds++
                if ($p.Severity -eq 'FAIL') { $fails++ } else { $warns++ }
            }
        }
    }

    if ($fileHits.Count -gt 0) {
        Write-Host "  $rel" -ForegroundColor White
        foreach ($hit in $fileHits) {
            $color = if ($hit.Severity -eq 'FAIL') { 'Red' } else { 'Yellow' }
            Write-Host "    [$($hit.Severity)] Line $($hit.Line): [$($hit.Pattern)] --> $($hit.Match)" -ForegroundColor $color
            Write-Host "         $($hit.Context)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Files scanned : $($allFiles.Count)"
Write-Host "  Matches found : $totalFinds"
Write-Host "  FAIL          : $fails" -ForegroundColor $(if ($fails -gt 0) { 'Red' } else { 'Green' })
Write-Host "  WARN          : $warns" -ForegroundColor $(if ($warns -gt 0) { 'Yellow' } else { 'Green' })
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($totalFinds -eq 0) {
    Write-Host "  Result: CLEAN -- no redaction issues found" -ForegroundColor Green
    exit 0
} elseif ($fails -gt 0) {
    Write-Host "  Result: FAIL -- review FAIL items before committing" -ForegroundColor Red
    Write-Host "  Note : WARN items may be legitimate IOCs or false positives -- review manually" -ForegroundColor DarkGray
    exit 1
} else {
    Write-Host "  Result: WARN -- review items above (may be false positives in IOC context)" -ForegroundColor Yellow
    Write-Host "  Run with -IncludeIocFiles to also scan 40_iocs/ if needed" -ForegroundColor DarkGray
    exit 0
}
