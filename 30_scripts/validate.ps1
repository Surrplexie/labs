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
     14.  CTF solve depth            - warns if solved CTF has thin/placeholder 02_dynamic.
     15.  Skills field population    - warns if closed non-file engagement has no skills[].
     16.  Hunt query_refs            - warns if hunt references missing 45_hunt_queries files.
     17.  Lab completion depth       - warns if reviewed lab has thin step log or empty objectives.
     18.  Hunt collection depth      - warns if closed hunt has thin 01_static / no query evidence.
     19.  04_writeups kind match     - warns if optional 04 frontmatter engagement_kind != tracker.

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
        $kind = Get-EngagementKind -Row $row -Content $raw
        if ($kind -in @('ctf', 'lab', 'hunt') -and $sv -ne '2') {
            Write-Warn "$id : $kind engagement should use schema_version: 2 (found '$sv'); re-scaffold or edit 03_findings"
            $schemaIssues = $true
        } else {
            Write-Pass "$id : schema_version: $sv (kind: $kind)"
        }
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
# CHECK 14: CTF methodology depth -- solved rows should have non-skeleton 02_dynamic
# ---------------------------------------------------------------------------
Write-Section "14. CTF solve depth check"

$solvedCtfRows = @($nonEmptyRows | Where-Object {
    $k = Get-EngagementKind -Row $_ -Content $null
    $s = $_.status.Trim().ToLower()
    $k -eq 'ctf' -and $s -in @('solved', 'writeup_done')
})

if ($solvedCtfRows.Count -eq 0) {
    Write-Info "No solved CTF engagements to check."
} else {
    $ctfDepthIssues = $false
    foreach ($row in $solvedCtfRows) {
        $id = $row.sample_id.Trim()
        $dynPath = Join-Path $Root "02_dynamic\$id.md"
        if (Test-Path $dynPath) {
            $dynContent = Get-Content $dynPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            $placeholderCount = ([regex]::Matches($dynContent, 'PENDING|TODO|_Not captured_|<FILL')).Count
            $lineCount = ($dynContent -split "`r`n|`n").Count
            if ($lineCount -lt 30) {
                Write-Warn "$id : 02_dynamic is thin ($lineCount lines) for a solved CTF -- add solve steps"
                $ctfDepthIssues = $true
            } elseif ($placeholderCount -gt 5) {
                Write-Warn "$id : 02_dynamic has $placeholderCount unfilled placeholders for a solved CTF"
                $ctfDepthIssues = $true
            } else {
                Write-Pass "$id : 02_dynamic has adequate depth for a solved CTF"
            }
        }
    }
    if (-not $ctfDepthIssues) {
        Write-Pass "All solved CTF engagements have adequate 02_dynamic depth"
    }
}

# ---------------------------------------------------------------------------
# CHECK 15: Skills field populated for closed/solved/done non-file engagements
# ---------------------------------------------------------------------------
Write-Section "15. Skills field population check"

$closedNonFileRows = @($nonEmptyRows | Where-Object {
    $k = Get-EngagementKind -Row $_ -Content $null
    $s = $_.status.Trim().ToLower()
    $k -ne 'file' -and $s -in @('done', 'solved', 'writeup_done', 'reviewed', 'closed', 'objectives_met')
})

if ($closedNonFileRows.Count -eq 0) {
    Write-Info "No closed non-file engagements to check."
} else {
    $skillsIssues = $false
    foreach ($row in $closedNonFileRows) {
        $id = $row.sample_id.Trim()
        $findPath = Join-Path $Root "03_findings\$id.md"
        if (Test-Path $findPath) {
            $fContent = Get-Content $findPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            $skillsMatch = $fContent -match '(?m)^skills\s*:'
            if (-not $skillsMatch) {
                Write-Warn "$id : no skills: field in frontmatter for a closed non-file engagement"
                $skillsIssues = $true
            } else {
                # Check if it has any actual values (not just an empty list)
                $skillsBlock = if ($fContent -match '(?s)skills\s*:\s*\r?\n((\s+-\s+\S+\r?\n)+)') { $Matches[1] } else { '' }
                if ([string]::IsNullOrWhiteSpace($skillsBlock)) {
                    Write-Warn "$id : skills: field appears empty for a closed non-file engagement"
                    $skillsIssues = $true
                } else {
                    Write-Pass "$id : skills field populated"
                }
            }
        }
    }
    if (-not $skillsIssues) {
        Write-Pass "All closed non-file engagements have skills field populated"
    }
}

# ---------------------------------------------------------------------------
# CHECK 16: Hunt query_refs resolve under 45_hunt_queries/
# ---------------------------------------------------------------------------
Write-Section "16. Hunt query_refs library check"

$huntQueryDir = Join-Path $Root '45_hunt_queries'
if (-not (Test-Path $huntQueryDir)) {
    Write-Info "45_hunt_queries/ not present -- skip."
} else {
    $huntRows = @($nonEmptyRows | Where-Object {
        (Get-EngagementKind -Row $_ -Content $null) -eq 'hunt'
    })
    if ($huntRows.Count -eq 0) {
        Write-Info "No hunt engagements to check."
    } else {
        $refIssues = $false
        foreach ($row in $huntRows) {
            $id = $row.sample_id.Trim()
            $findPath = Join-Path $Root "03_findings\$id.md"
            if (-not (Test-Path $findPath)) { continue }
            $raw = Get-Content $findPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if (-not $raw) { continue }

            $refs = @()
            if ($raw -match '(?m)^query_refs\s*:') {
                $block = if ($raw -match '(?s)query_refs\s*:\s*\r?\n((?:\s+-\s+\S+\r?\n)+)') { $Matches[1] } else { '' }
                $refs = [regex]::Matches($block, '(?m)^\s+-\s+(\S+)') | ForEach-Object { $_.Groups[1].Value.Trim() }
            }
            $staticPath = Join-Path $Root "01_static\$id.md"
            if (Test-Path $staticPath) {
                $sRaw = Get-Content $staticPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
                if ($sRaw) {
                    $linkRefs = [regex]::Matches($sRaw, '45_hunt_queries[/\\]([a-z0-9]+(?:-[a-z0-9]+)*)\.md') |
                        ForEach-Object { $_.Groups[1].Value }
                    $refs = @($refs + $linkRefs) | Select-Object -Unique
                }
            }

            if ($refs.Count -eq 0) { continue }

            foreach ($slug in $refs) {
                if ($slug -eq '_examples') { continue }
                $qPath = Join-Path $huntQueryDir "$slug.md"
                if (-not (Test-Path $qPath)) {
                    Write-Warn "$id : query ref '$slug' -- missing 45_hunt_queries\$slug.md"
                    $refIssues = $true
                } else {
                    Write-Pass "$id : query ref '$slug' resolves"
                }
            }
        }
        if (-not $refIssues) {
            Write-Pass "All hunt query_refs resolve (or none declared)"
        }
    }
}

# ---------------------------------------------------------------------------
# CHECK 17: Lab completion depth -- reviewed labs need step log + objectives
# ---------------------------------------------------------------------------
Write-Section "17. Lab completion depth check"

$closedLabRows = @($nonEmptyRows | Where-Object {
    $k = Get-EngagementKind -Row $_ -Content $null
    $s = $_.status.Trim().ToLower()
    $k -eq 'lab' -and $s -in @('reviewed', 'objectives_met')
})

if ($closedLabRows.Count -eq 0) {
    Write-Info "No completed lab engagements to check."
} else {
    $labDepthIssues = $false
    foreach ($row in $closedLabRows) {
        $id = $row.sample_id.Trim()
        $staticPath = Join-Path $Root "01_static\$id.md"
        $findPath   = Join-Path $Root "03_findings\$id.md"

        if (Test-Path $staticPath) {
            $staticContent = Get-Content $staticPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            $lineCount = ($staticContent -split "`r`n|`n").Count
            $phCount   = ([regex]::Matches($staticContent, 'PENDING|TODO|_Not captured_|<FILL>')).Count
            if ($lineCount -lt 25) {
                Write-Warn "$id : 01_static is thin ($lineCount lines) for a completed lab -- log steps"
                $labDepthIssues = $true
            } elseif ($phCount -gt 8) {
                Write-Warn "$id : 01_static has $phCount unfilled placeholders for a completed lab"
                $labDepthIssues = $true
            } else {
                Write-Pass "$id : 01_static step log has adequate depth"
            }
        }

        if (Test-Path $findPath) {
            $fContent = Get-Content $findPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            $hasObjectives = $fContent -match '(?m)^objectives\s*:'
            $objMet        = (Get-FrontmatterValue -Content $fContent -Key 'objectives_met') -eq 'true'
            $objList       = $fContent -match '(?s)objectives\s*:\s*\r?\n(\s+-\s+\S+)'
            if (-not $hasObjectives -and -not $objMet) {
                Write-Warn "$id : 03_findings missing objectives_met or objectives list for completed lab"
                $labDepthIssues = $true
            } elseif (-not $objList -and -not $objMet) {
                Write-Warn "$id : 03_findings objectives appear empty for completed lab"
                $labDepthIssues = $true
            } else {
                Write-Pass "$id : 03_findings objectives documented"
            }
        }
    }
    if (-not $labDepthIssues) {
        Write-Pass "All completed lab engagements have adequate depth"
    }
}

# ---------------------------------------------------------------------------
# CHECK 18: Hunt collection depth -- closed hunts need queries in 01_static
# ---------------------------------------------------------------------------
Write-Section "18. Hunt collection depth check"

$closedHuntRows = @($nonEmptyRows | Where-Object {
    $k = Get-EngagementKind -Row $_ -Content $null
    $s = $_.status.Trim().ToLower()
    $k -eq 'hunt' -and $s -eq 'closed'
})

if ($closedHuntRows.Count -eq 0) {
    Write-Info "No closed hunt engagements to check."
} else {
    $huntDepthIssues = $false
    foreach ($row in $closedHuntRows) {
        $id = $row.sample_id.Trim()
        $staticPath = Join-Path $Root "01_static\$id.md"
        if (-not (Test-Path $staticPath)) { continue }

        $staticContent = Get-Content $staticPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        $lineCount   = ($staticContent -split "`r`n|`n").Count
        $phCount     = ([regex]::Matches($staticContent, 'PENDING|TODO|_Not captured_|<FILL>')).Count
        $hasQueryLib = $staticContent -match '45_hunt_queries'
        $hasQueryTable = $staticContent -match '(?s)## Queries run.*\|[^\s|][^|]*\|'

        if ($lineCount -lt 25 -and -not $hasQueryLib) {
            Write-Warn "$id : 01_static is thin ($lineCount lines) for a closed hunt -- log queries and findings"
            $huntDepthIssues = $true
        } elseif ($phCount -gt 8 -and -not $hasQueryLib) {
            Write-Warn "$id : 01_static has $phCount unfilled placeholders for a closed hunt"
            $huntDepthIssues = $true
        } elseif (-not $hasQueryTable -and -not $hasQueryLib) {
            Write-Warn "$id : 01_static missing query log (Queries run table or 45_hunt_queries link)"
            $huntDepthIssues = $true
        } else {
            Write-Pass "$id : 01_static has adequate hunt collection depth"
        }
    }
    if (-not $huntDepthIssues) {
        Write-Pass "All closed hunt engagements have adequate collection depth"
    }
}

# ---------------------------------------------------------------------------
# CHECK 19: 04_writeups engagement_kind vs tracker (optional file only)
# ---------------------------------------------------------------------------
Write-Section "19. 04_writeups engagement_kind consistency"

$writeupKindIssues = $false
$writeupChecked    = 0

foreach ($row in $nonEmptyRows) {
    $id          = $row.sample_id.Trim()
    $writeupPath = Join-Path $Root "04_writeups\$id.md"
    if (-not (Test-Path $writeupPath)) { continue }

    $writeupChecked++
    $trackerKind = Get-EngagementKind -Row $row -Content $null
    $wuRaw       = Get-Content $writeupPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue

    if (-not (Has-Frontmatter -Content $wuRaw)) {
        Write-Warn "$id : 04_writeups\$id.md has no YAML frontmatter -- run scaffold_writeup.ps1 -Kind $trackerKind -Overwrite"
        $writeupKindIssues = $true
        continue
    }

    $wuKind = Get-FrontmatterValue -Content $wuRaw -Key 'engagement_kind'
    if ([string]::IsNullOrWhiteSpace($wuKind)) {
        Write-Warn "$id : 04_writeups missing engagement_kind (tracker: $trackerKind)"
        $writeupKindIssues = $true
    } elseif ($wuKind.Trim().ToLower() -ne $trackerKind) {
        Write-Warn "$id : 04_writeups engagement_kind '$wuKind' != tracker '$trackerKind'"
        $writeupKindIssues = $true
    } else {
        Write-Pass "$id : 04_writeups kind matches tracker ($trackerKind)"
    }
}

if ($writeupChecked -eq 0) {
    Write-Info "No 04_writeups files for active engagements (optional layer)."
} elseif (-not $writeupKindIssues) {
    Write-Pass "All 04_writeups files match tracker engagement_kind"
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
