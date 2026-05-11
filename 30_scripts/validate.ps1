#Requires -Version 5.1
<#
.SYNOPSIS
    Preflight integrity validator for the labs malware triage logbook.

.DESCRIPTION
    Checks structural consistency of the repo against samples_tracker.csv.
    Runs the following checks:
      1.  CSV schema              - required columns present.
      2.  Per-sample phase files  - all four phase .md files exist for non-empty slots.
      3.  SHA256 populated        - any non-empty slot must have a hash on record.
      4.  Content depth           - warns if a phase file looks like an unfilled skeleton (< 15 lines).
      5.  Frontmatter presence    - warns if 03_findings/sample_XX.md has no YAML frontmatter block.
      6.  SHA256 cross-check      - tracker hash vs frontmatter hash in findings file must match.
      7.  IOC CSV schema          - required columns present; all sample_ids known to tracker.
      8.  Orphan files            - phase .md files with no matching tracker row.
      9.  Forbidden extension scan- hard check for executables/archives that should never be on host.
     10.  Screenshot folder       - warns if non-empty slot has no 50_screenshots/sample_XX/ folder.
     11.  Schema version          - warns if 03_findings/sample_XX.md is missing schema_version field.

    Exit code 0 = all checks passed (WARNs allowed).
    Exit code 1 = one or more FAIL checks.

.PARAMETER Root
    Path to the repo root. Defaults to the parent of this script's directory.

.PARAMETER FailOnWarn
    Treat WARN-level issues as FAIL. Use in strict CI mode.

.EXAMPLE
    # Run from anywhere:
    powershell -ExecutionPolicy Bypass -File .\30_scripts\validate.ps1

    # Strict mode:
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
$requiredCols = @('sample_id', 'sha256', 'mb_url', 'name_tag', 'status')
$actualCols  = $tracker[0].PSObject.Properties.Name

$missingCols = $requiredCols | Where-Object { $_ -notin $actualCols }
if ($missingCols.Count -gt 0) {
    $missingCols | ForEach-Object { Write-Fail "samples_tracker.csv missing required column: $_" }
    Write-Host "`nCannot continue with malformed tracker. Exiting." -ForegroundColor Red
    exit 1
}
Write-Pass "samples_tracker.csv schema OK ($($tracker.Count) rows, required columns present)"

# ---------------------------------------------------------------------------
# CHECK 2-6: Per-sample phase files, sha256, content depth, frontmatter, hash cross-check
# ---------------------------------------------------------------------------
Write-Section "2-6. Per-sample checks"

$PHASE_DIRS    = @('00_original', '01_static', '02_dynamic', '03_findings')
$SKELETON_THRESHOLD = 15  # lines - below this is likely an unfilled placeholder

$nonEmptyRows = $tracker | Where-Object { $_.status.Trim().ToLower() -ne 'empty' }

if ($nonEmptyRows.Count -eq 0) {
    Write-Warn "No non-empty samples found in tracker - nothing to validate."
}

foreach ($row in $nonEmptyRows) {
    $id     = $row.sample_id.Trim()
    $status = $row.status.Trim()
    $csvHash = $row.sha256.Trim()

    Write-Host "`n  -- $id (status: $status)" -ForegroundColor White

    # Check 3: SHA256 populated
    if ([string]::IsNullOrWhiteSpace($csvHash)) {
        Write-Fail "$id : sha256 is blank in tracker for non-empty slot"
    } else {
        Write-Pass "$id : sha256 present in tracker"
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
                    Write-Warn "$id : 03_findings\$id.md has no YAML frontmatter block (run export-summary.ps1 after adding it)"
                } else {
                    Write-Pass "$id : 03_findings\$id.md has YAML frontmatter"

                    # Check 6: hash cross-check tracker vs frontmatter
                    $fmHash = Get-FrontmatterValue -Content $raw -Key 'sha256'
                    if ($fmHash -and $csvHash -and ($fmHash -ne $csvHash)) {
                        Write-Fail "$id : SHA256 mismatch - tracker: $csvHash vs frontmatter: $fmHash"
                    } elseif ($fmHash -and $csvHash) {
                        Write-Pass "$id : SHA256 matches between tracker and frontmatter"
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
    Write-Warn "40_iocs/indicators.csv not found - create it when IOCs are extracted"
} else {
    $iocs       = Import-Csv $iocPath
    $iocColsActual = if ($iocs.Count -gt 0) { $iocs[0].PSObject.Properties.Name } else { @() }

    $missingIocCols = $requiredIocCols | Where-Object { $_ -notin $iocColsActual }
    if ($missingIocCols.Count -gt 0) {
        $missingIocCols | ForEach-Object { Write-Fail "indicators.csv missing column: $_" }
    } else {
        Write-Pass "indicators.csv schema OK ($($iocs.Count) rows)"
    }

    # All sample_ids in IOC file must be in tracker
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

$CURRENT_SCHEMA_VERSION = 1
$schemaIssues = $false

foreach ($row in $nonEmptyRows) {
    $id           = $row.sample_id.Trim()
    $findingsPath = Join-Path $Root "03_findings\$id.md"
    if (-not (Test-Path $findingsPath)) { continue }

    $raw = Get-Content $findingsPath -Raw -Encoding UTF8
    $sv  = Get-FrontmatterValue -Content $raw -Key 'schema_version'

    if ($null -eq $sv -or $sv -eq '') {
        Write-Warn "$id : 03_findings\$id.md has no schema_version field (add schema_version: $CURRENT_SCHEMA_VERSION)"
        $schemaIssues = $true
    } elseif ($sv -ne "$CURRENT_SCHEMA_VERSION") {
        Write-Warn "$id : schema_version is '$sv', current is $CURRENT_SCHEMA_VERSION (migration may be needed)"
        $schemaIssues = $true
    } else {
        Write-Pass "$id : schema_version: $sv"
    }
}
if (-not $schemaIssues -and $nonEmptyRows.Count -gt 0) {
    Write-Pass "All active findings files carry schema_version: $CURRENT_SCHEMA_VERSION"
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
