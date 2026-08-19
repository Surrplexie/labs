#Requires -Version 5.1
<#
.SYNOPSIS
    Shared path helpers for per-lab layout.

    Repo root holds shared catalogs and tooling:
      20_notes, 30_scripts, 40_iocs, 45_hunt_queries, 04_writeups/_templates, Docs, dist

    Each engagement lives in one folder:
      LAB{NN}_{slug}/00_original, 01_static, 02_dynamic, 03_findings, ...
#>

$script:LabHelperDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$script:LAB_WORKFLOW_DIRS = @(
    '00_original',
    '01_static',
    '02_dynamic',
    '03_findings',
    '04_writeups',
    '10_extracted',
    '20_notes',
    '30_scripts',
    '40_iocs',
    '45_hunt_queries',
    '50_screenshots',
    '55_media'
)

function ConvertTo-LabSlug {
    param([string]$Title)
    if ([string]::IsNullOrWhiteSpace($Title)) { return '' }
    $s = $Title.Trim()
    $s = $s -replace '\.(exe|dll|bin|msi|scr|iso)$', ''
    $s = $s -replace '\s+', '_'
    $s = $s -replace '[^A-Za-z0-9._-]', ''
    $s = $s -replace '[_-]{2,}', '_'
    $s = $s.Trim('_').Trim('-').Trim('.')
    if ($s.Length -gt 48) { $s = $s.Substring(0, 48).TrimEnd('_', '-', '.') }
    return $s
}

function Get-LabFolderName {
    param(
        [int]$Number,
        [string]$Title = ''
    )
    $n = '{0:D2}' -f $Number
    $slug = ConvertTo-LabSlug $Title
    if ($slug) { return "LAB${n}_$slug" }
    return "LAB$n"
}

function Get-SampleNumber {
    param([string]$SampleId)
    if ($SampleId -match 'sample_(\d+)') { return [int]$Matches[1] }
    return 0
}

function Get-ExpectedEngagementKindForSlot {
    param([int]$Number)
    if ($Number -ge 1 -and $Number -le 30)  { return 'file' }
    if ($Number -ge 31 -and $Number -le 40) { return 'ctf' }
    if ($Number -ge 41 -and $Number -le 45) { return 'lab' }
    if ($Number -ge 46 -and $Number -le 50) { return 'hunt' }
    if ($Number -ge 51 -and $Number -le 70) { return 'school' }
    if ($Number -ge 71 -and $Number -le 85) { return 'homelab' }
    return $null
}

function Get-LabDir {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$SampleId,
        $TrackerRow = $null
    )

    if ($TrackerRow -and ($TrackerRow.PSObject.Properties.Name -contains 'lab_folder')) {
        $lf = "$($TrackerRow.lab_folder)".Trim()
        if ($lf) {
            $p = Join-Path $Root $lf
            if (Test-Path -LiteralPath $p) { return (Resolve-Path -LiteralPath $p).Path }
        }
    }

    $hits = New-Object System.Collections.Generic.List[string]
    Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^LAB\d+' } |
        ForEach-Object {
            $f = Join-Path $_.FullName "03_findings\$SampleId.md"
            $o = Join-Path $_.FullName "00_original\$SampleId.md"
            if ((Test-Path -LiteralPath $f) -or (Test-Path -LiteralPath $o)) {
                $hits.Add($_.FullName)
            }
        }
    if ($hits.Count -ge 1) { return $hits[0] }

    # Legacy flat layout (pre per-lab folders)
    if (Test-Path -LiteralPath (Join-Path $Root "03_findings\$SampleId.md")) { return $Root }
    if (Test-Path -LiteralPath (Join-Path $Root "00_original\$SampleId.md")) { return $Root }

    return $null
}

function Get-PhaseFilePath {
    param(
        [string]$Root,
        [string]$SampleId,
        [string]$Phase,
        $TrackerRow = $null
    )
    $lab = Get-LabDir -Root $Root -SampleId $SampleId -TrackerRow $TrackerRow
    if ($lab) { return Join-Path $lab "$Phase\$SampleId.md" }
    return Join-Path $Root "$Phase\$SampleId.md"
}

function Get-ScreenshotDir {
    param(
        [string]$Root,
        [string]$SampleId,
        $TrackerRow = $null
    )
    $lab = Get-LabDir -Root $Root -SampleId $SampleId -TrackerRow $TrackerRow
    if ($lab -and ($lab -ne $Root)) { return Join-Path $lab '50_screenshots' }
    return Join-Path $Root "50_screenshots\$SampleId"
}

function Get-AllScreenshotRoots {
    param([string]$Root)
    $dirs = New-Object System.Collections.Generic.List[string]
        Get-ChildItem -LiteralPath $Root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^LAB\d+' } |
        ForEach-Object {
            foreach ($leaf in @('50_screenshots', '55_media')) {
                $ss = Join-Path $_.FullName $leaf
                if (Test-Path -LiteralPath $ss) { $dirs.Add($ss) }
            }
        }
    $legacy = Join-Path $Root '50_screenshots'
    if (Test-Path -LiteralPath $legacy) { $dirs.Add($legacy) }
    return @($dirs)
}

function Get-NotesRoot {
    if ($env:LABS_NOTES_ROOT) {
        $p = $env:LABS_NOTES_ROOT.Trim()
        if ($p) { return $p }
    }
    $local = Join-Path $script:LabHelperDir 'notes_root.local.txt'
    if (Test-Path -LiteralPath $local) {
        $line = (Get-Content -LiteralPath $local -TotalCount 1 -ErrorAction SilentlyContinue)
        if ($line) {
            $p = $line.Trim()
            if ($p) { return $p }
        }
    }
    $default = Join-Path $env:USERPROFILE 'Downloads\Notes'
    if (Test-Path -LiteralPath $default) { return $default }
    return $null
}

function Get-NotesCourseDir {
    param(
        [string]$Course,
        [switch]$Ensure
    )
    $root = Get-NotesRoot
    if (-not $root -or [string]::IsNullOrWhiteSpace($Course)) { return $null }
    $dir = Join-Path $root $Course.Trim()
    if ($Ensure -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $labsSub = Join-Path $dir 'labs'
        if (-not (Test-Path -LiteralPath $labsSub)) {
            New-Item -ItemType Directory -Path $labsSub -Force | Out-Null
        }
    }
    if (Test-Path -LiteralPath $dir) { return (Resolve-Path -LiteralPath $dir).Path }
    return $null
}

function New-LabSkeleton {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LabDir,
        [string]$SampleId = '',
        [string]$Kind = 'file',
        [string]$Title = '',
        [string]$LabName = ''
    )

    if (-not $LabName) { $LabName = Split-Path $LabDir -Leaf }

    $skel = Join-Path $script:LabHelperDir '_lab_skeleton'
    if (Test-Path -LiteralPath $skel) {
        if (-not (Test-Path -LiteralPath $LabDir)) {
            New-Item -ItemType Directory -Path $LabDir | Out-Null
        }
        Copy-Item -Path (Join-Path $skel '*') -Destination $LabDir -Recurse -Force
    } else {
        foreach ($d in $script:LAB_WORKFLOW_DIRS) {
            $p = Join-Path $LabDir $d
            if (-not (Test-Path -LiteralPath $p)) {
                New-Item -ItemType Directory -Path $p | Out-Null
            }
        }
    }

    foreach ($d in $script:LAB_WORKFLOW_DIRS) {
        $p = Join-Path $LabDir $d
        if (-not (Test-Path -LiteralPath $p)) {
            New-Item -ItemType Directory -Path $p | Out-Null
        }
    }

    $replacements = @{
        'LAB_NAME'  = $LabName
        'SAMPLE_ID' = $SampleId
        'KIND_VAL'  = $Kind
        'TITLE_VAL' = $(if ($Title) { $Title } else { $LabName })
    }

    Get-ChildItem -LiteralPath $LabDir -Recurse -Include '*.md', '*.txt' -File -ErrorAction SilentlyContinue |
        ForEach-Object {
            $raw = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            if (-not $raw) { return }
            $updated = $raw
            foreach ($k in $replacements.Keys) {
                $updated = $updated.Replace($k, [string]$replacements[$k])
            }
            if ($updated -ne $raw) {
                Set-Content -LiteralPath $_.FullName -Value $updated -Encoding UTF8
            }
        }
}
