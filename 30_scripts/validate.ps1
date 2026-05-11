#Requires -Version 5.1
<#
.SYNOPSIS
    Preflight integrity validator for the labs logbook (all engagement kinds).

.DESCRIPTION
    Kind-aware structural checks against samples_tracker.csv.

    Checks:
      1.  CSV schema                 - required columns present.
      2.  Per-engagement phase files - all four phase .md files exist for non-empty slots.
      3.  SHA256 populated           - required for file-kind; optional for others.
      4.  Content depth              - warns if a phase file is an unfilled skeleton.
      5.  Frontmatter presence       - 03_findings must have YAML frontmatter.
      6.  SHA256 cross-check         - tracker vs frontmatter (file-kind only).
      7.  IOC CSV schema             - required columns; sample IDs must be known.
      8.  Orphan files               - phase .md files with no matching tracker row.
      9.  Forbidden extension scan   - hard check for binaries/archives on host.
     10.  Screenshot folder          - warns if non-empty slot has no screenshots folder.
     11.  Schema version             - frontmatter schema_version valid for kind.
     12.  Secret / flag scan         - warns if CTF/lab files contain raw flag patterns.
     13.  Kind field presence        - warns if engagement_kind is missing in tracker.

    Exit code 0 = all checks passed (WARNs allowed).
    Exit code 1 = one or more FAIL checks.

.PARAMETER Root
    Path to the repo root. Defaults to parent of this script's directory.

.PARAMETER FailOnWarn
    Treat WARN-level issues as FAIL. Use in strict CI mode.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\30_scripts\validate.ps1
    powershell -ExecutionPolicy Bypass -File .\30_scripts\validate.ps1 -FailOnWarn
#>

param(
    [string]$Root       = (Split-Path $PSScriptRoot -Parent),
    [switch]$FailOnWarn
)

$ErrorActionPreference = 'Stop'

$script:passes = 0
$script:warns  = 0
$script:fails  = 0

function Write-Pass { param([string]$msg) Write-Host "  [PASS] $msg" -ForegroundColor Green;  $script:passes++ }
function Write-Warn { param([string]$msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow; $script:warns++ }
function Write-Fail { param([string]$msg) Write-Host "  [FAIL] $msg" -ForegroundColor Red;    $script:fails++ }
function Write-Info { param([string]$msg) Write-Host "         $msg" -ForegroundColor DarkGray }
function Write-Section { param([string]$msg) Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Get-FrontmatterValue {
    param([string]$Content, [string]$Key)
    if ($Content -match "(?m)^$Key\s*:\s*[`"']?(.+?)[`"']?\s*$") {
        return $Matches[1].Trim()
    }
    return $null
}

function Has-Frontmatter {
    param([string]$Content)
    return $Content -match '(?s)^---\s*\r?\n.+?\r?\n---'
}

function Get-EngagementKind {
    param($Row, [string]$Content)
    # Try tracker column first
    if ($Row -and $Row.PSObject.Properties.Name -contains 'engagement_kind') {
        $k = $Row.engagement_kind.Trim().ToLower()
        if ($k -ne '') { return $k }
    }
    # Fall back to frontmatter
    if ($Content) {
        $fmKind = Get-FrontmatterValue -Content $Content -Key 'engagement_kind'
        if ($fmKind) { return $fmKind.ToLower() }
    }
    return 'file'
}

# ---------------------------------------------------------------------------
# CHECK 1: CSV schema
# ---------------------------------------------------------------------------
Write-Section "1. samples_tracker.csv schema"

$csvPath = Join-Path $Root 'samples_tracker.csv'
if (-not (Test-Path $csvPath)) {
    Write-Fail "samples_tracker.csv not found at: $csvPath"
    Write-Host "`nCannot continue without tracker. Exiting." -ForegroundColor Red
    exit 1
}

$tracker     = Import-Csv $csvPath
$requiredCols = @('sample_id', 'sha256', 'name_tag', 'status')
$actualCols  = $tracker[0].PSObject.Properties.Name

$missingCols = $requiredCols | Where-Object { $_ -notin $actualCols }
if ($missingCols.Count -gt 0) {
    $missingCols | ForEach-Object { Write-Fail "samples_tracker.csv missing required column: $_" }
    Write-Host "`nCannot continue with malformed tracker. Exiting." -ForegroundColor Red
    exit 1
}
Write-Pass "samples_tracker.csv schema OK ($($tracker.Count) rows, required columns present)"

# ---------------------------------------------------------------------------
# CHECK 13: engagement_kind field
# ---------------------------------------------------------------------------
Write-Section "13. engagement_kind field presence"

if ($actualCols -notcontains 'engagement_kind') {
    Write-Warn "samples_tracker.csv has no engagement_kind column -- run: new_engagement.ps1 or add the column manually. Defaulting all rows to 'file' for this run."
    $kindMissing = $true
} else {
    $kindMissing = $false
    $missingKind = @($tracker | Where-Object { [string]::IsNullOrWhiteSpace($_.engagement_kind) -and $_.status -ne 'empty' })
    if ($missingKind.Count -gt 0) {
        $missingKind | ForEach-Object {
            Write-Warn "$($_.sample_id): engagement_kind is blank for non-empty slot (defaulting to 'file')"
        }
    } else {
        Write-Pass "engagement_kind populated for all non-empty slots"
    }
}

# ---------------------------------------------------------------------------
# CHECK 2-6 + 10: Per-engagement checks
# ---------------------------------------------------------------------------
Write-Section "2-6 + 10. Per-engagement checks"

$PHASE_DIRS    = @('00_original', '01_static', '02_dynamic', '03_findings')
$SKELETON_THRESHOLD = 15

$nonEmptyRows = $tracker | Where-Object { $_.status.Trim().ToLower() -ne 'empty' }

if ($nonEmptyRows.Count -eq 0) {
    Write-Warn "No non-empty engagements found in tracker -- nothing to validate."
}

foreach ($row in $nonEmptyRows) {
    $id     = $row.sample_id.Trim()
    $status = $row.status.Trim()
    $csvHash = $row.sha256.Trim()
    $kind   = if ($kindMissing) { 'file' } else { (Get-EngagementKind -Row $row -Content $null) }

    Write-Host "`n  -- $id (kind: $kind / status: $status)" -ForegroundColor White

    # Check 3: SHA256 -- required for file, optional for others
    if ($kind -eq 'file') {
        if ([string]::IsNullOrWhiteSpace($csvHash)) {
            Write-Fail "$id : sha256 is blank in tracker for file-kind non-empty slot"
        } else {
            Write-Pass "$id : sha256 present in tracker"
        }
    } else {
        if ([string]::IsNullOrWhiteSpace($csvHash)) {
            Write-Info "$id : sha256 blank (optional for kind=$kind)"
        } else {
            Write-Pass "$id : sha256 present in tracker"
        }
    }

    # Check 2: Phase files exist + Check 4: content depth
    foreach ($dir in $PHASE_DIRS) {
        $filePath = Join-Path $Root "$dir\$id.md"
        if (-not (Test-Path $filePath)) {
            Write-Fail "$id : missing phase file $dir\$id.md"
        } else {
            $raw       = Get-Content $filePath -Raw -Encoding UTF8
            $lineCount = ($raw -split "`r`n|`n").Count

            if ($lineCount -lt $SKELETON_THRESHOLD) {
                Write-Warn "$id : $dir\$id.md appears to be an unfilled skeleton ($lineCount lines)"
            } else {
                Write-Pass "$id : $dir\$id.md exists with content ($lineCount lines)"
            }

            # Check 5: frontmatter only on findings file
            if ($dir -eq '03_findings') {
                if (-not (Has-Frontmatter $raw)) {
                    Write-Warn "$id : 03_findings\$id.md has no YAML frontmatter block"
                } else {
                    Write-Pass "$id : 03_findings\$id.md has YAML frontmatter"

                    # Check 6: hash cross-check (file-kind only)
                    if ($kind -eq 'file') {
                        $fmHash = Get-FrontmatterValue -Content $raw -Key 'sha256'
                        if ($fmHash -and $csvHash -and ($fmHash -ne $csvHash)) {
                            Write-Fail "$id : SHA256 mismatch -- tracker: $csvHash vs frontmatter: $fmHash"
                        } elseif ($fmHash -and $csvHash) {
                            Write-Pass "$id : SHA256 matches between tracker and frontmatter"
                        }
                    }
                }
            }
        }
    }

    # Check 10: Screenshots folder
    $ssDir = Join-Path $Root "50_screenshots\$id"
    if (-not (Test-Path $ssDir)) {
        Write-Warn "$id : no screenshots folder at 50_screenshots\$id\"
    } else {
        $imgCount = (Get-ChildItem $ssDir -File | Measure-Object).Count
        Write-Pass "$id : screenshots folder present ($imgCount file(s))"
    }
}

# ---------------------------------------------------------------------------
# CHECK 7: IOC CSV schema
# ---------------------------------------------------------------------------
Write-Section "7. 40_iocs/indicators.csv schema"

$iocPath     = Join-Path $Root '40_iocs\indicators.csv'
$requiredIocCols = @('sample_id', 'type', 'value', 'source', 'first_seen', 'notes')

if (-not (Test-Path $iocPath)) {
    Write-Warn "40_iocs/indicators.csv not found -- create it when IOCs are extracted"
} else {
    $iocs       = Import-Csv $iocPath
    $iocColsActual = if ($iocs.Count -gt 0) { $iocs[0].PSObject.Properties.Name } else { @() }

    $missingIocCols = $requiredIocCols | Where-Object { $_ -notin $iocColsActual }
    if ($missingIocCols.Count -gt 0) {
        $missingIocCols | ForEach-Object { Write-Fail "indicators.csv missing column: $_" }
    } else {
        Write-Pass "indicators.csv schema OK ($($iocs.Count) rows)"
    }

    $trackerIds = $tracker | Select-Object -ExpandProperty sample_id
    $iocs | Select-Object -ExpandProperty sample_id -Unique | ForEach-Object {
        $iocId = $_
        if ($iocId -notin $trackerIds) {
            Write-Warn "indicators.csv references unknown sample_id '$iocId' (not in tracker)"
        }
    }
}

# ---------------------------------------------------------------------------
# CHECK 8: Orphan phase files
# ---------------------------------------------------------------------------
Write-Section "8. Orphan phase file detection"

$trackerIds = $tracker | Select-Object -ExpandProperty sample_id
$orphansFound = $false

foreach ($dir in $PHASE_DIRS) {
    $phaseDir = Join-Path $Root $dir
    if (-not (Test-Path $phaseDir)) { continue }

    Get-ChildItem $phaseDir -Filter '*.md' | Where-Object { $_.Name -ne 'README.md' } | ForEach-Object {
        $baseName = $_.BaseName
        if ($baseName -notin $trackerIds) {
            Write-Warn "Orphan: $dir\$($_.Name) has no matching row in samples_tracker.csv"
            $orphansFound = $true
        }
    }
}
if (-not $orphansFound) {
    Write-Pass "No orphan phase files detected"
}

# ---------------------------------------------------------------------------
# CHECK 9: Forbidden extension scan
# ---------------------------------------------------------------------------
Write-Section "9. Forbidden extension scan"

$FORBIDDEN_EXTS = @(
    '.exe', '.dll', '.sys', '.drv', '.scr', '.com', '.pif',
    '.so', '.dylib', '.elf', '.out', '.bin',
    '.bat', '.cmd', '.vbs', '.vbe', '.hta', '.wsf',
    '.class', '.jar', '.war',
    '.dmp', '.mem', '.raw',
    '.pcap', '.pcapng', '.cap',
    '.iso', '.img', '.vmdk', '.vhd', '.ova', '.qcow2',
    '.msi', '.msix',
    '.xlsm', '.docm', '.pptm'
)

$allFiles = Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\.git[/\\]' } |
    Where-Object { $_.FullName -notmatch '[/\\]dist[/\\]' }

$forbidden = $allFiles | Where-Object { $FORBIDDEN_EXTS -contains $_.Extension.ToLower() }

if ($forbidden.Count -gt 0) {
    foreach ($f in $forbidden) {
        Write-Fail "Forbidden extension: $($f.FullName)"
    }
} else {
    Write-Pass "No forbidden extensions found in working tree"
}

# ---------------------------------------------------------------------------
# CHECK 11: Schema version presence in findings files
# ---------------------------------------------------------------------------
Write-Section "11. Schema version in findings files"

$VALID_SCHEMA_VERSIONS = @('1', '2')
$schemaIssues = $false

foreach ($row in $nonEmptyRows) {
    $id           = $row.sample_id.Trim()
    $findingsPath = Join-Path $Root "03_findings\$id.md"
    if (-not (Test-Path $findingsPath)) { continue }

    $raw    = Get-Content $findingsPath -Raw -Encoding UTF8
    $sv     = Get-FrontmatterValue -Content $raw -Key 'schema_version'
    $fmKind = Get-FrontmatterValue -Content $raw -Key 'engagement_kind'

    if ($null -eq $sv -or $sv -eq '') {
        Write-Warn "$id : 03_findings\$id.md missing schema_version (add schema_version: 1 for file, or 2 for ctf/lab/hunt)"
        $schemaIssues = $true
    } elseif ($sv -notin $VALID_SCHEMA_VERSIONS) {
        Write-Warn "$id : schema_version is '$sv', expected 1 or 2"
        $schemaIssues = $true
    } else {
        Write-Pass "$id : schema_version: $sv (kind: $(if ($fmKind) { $fmKind } else { 'file/legacy' }))"
    }
}
if (-not $schemaIssues -and $nonEmptyRows.Count -gt 0) {
    Write-Pass "All active findings files carry a valid schema_version"
}

# ---------------------------------------------------------------------------
# CHECK 12: Secret / flag pattern scan (CTF and lab kinds)
# ---------------------------------------------------------------------------
Write-Section "12. Secret and flag pattern scan"

# Patterns that should never be committed in plain text
$flagPatterns = @(
    'HTB\{[^}]+\}',
    'THM\{[^}]+\}',
    'flag\{[^}]+\}',
    'picoCTF\{[^}]+\}',
    'ctf\{[^}]+\}',
    'DUCTF\{[^}]+\}',
    'password\s*=\s*\S+',
    'passwd\s*=\s*\S+',
    'vpn_key\s*=\s*\S+',
    'token\s*=\s*[A-Za-z0-9+/=]{20,}'
)

$mdFiles = Get-ChildItem -Path $Root -Recurse -Filter '*.md' -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\.git[/\\]' } |
    Where-Object { $_.FullName -notmatch '[/\\]dist[/\\]' } |
    Where-Object { $_.FullName -notmatch '[/\\]30_scripts[/\\]' }

$flagIssues = $false
foreach ($f in $mdFiles) {
    $content = Get-Content $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    foreach ($pat in $flagPatterns) {
        if ($content -match $pat) {
            $rel = $f.FullName.Replace($Root, '').TrimStart('\/')
            Write-Warn "Possible raw flag/credential in $rel (pattern: $pat)"
            $flagIssues = $true
        }
    }
}
if (-not $flagIssues) {
    Write-Pass "No raw flag or credential patterns found in committed markdown files"
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  PASS : $($script:passes)" -ForegroundColor Green
Write-Host "  WARN : $($script:warns)"  -ForegroundColor Yellow
Write-Host "  FAIL : $($script:fails)"  -ForegroundColor Red
Write-Host "============================================" -ForegroundColor Cyan

$effectiveFails = $script:fails
if ($FailOnWarn) { $effectiveFails += $script:warns }

if ($effectiveFails -gt 0) {
    Write-Host "  Result: FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "  Result: OK" -ForegroundColor Green
    exit 0
}
