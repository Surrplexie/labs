#Requires -Version 5.1
<#
.SYNOPSIS
    Preflight and create an annotated git tag for a workflow_gui GitHub Release.

.DESCRIPTION
    Use when workflow_gui.py (or build harness) changes warrant a new vX.Y.Z binary.
    Pushing the tag triggers .github/workflows/release.yml.

    Align -Tag with APP_VERSION in workflow_gui.py (e.g. v3.0.1 for APP_VERSION 3.0.1).

.PARAMETER Tag
    Release tag (e.g. v3.0.1). If omitted with -Suggest, prints recommendation only.

.PARAMETER Suggest
    Show APP_VERSION, last tag, changed release paths; do not tag.

.PARAMETER DryRun
    Run checks and show the tag command; do not create a tag.

.PARAMETER Push
    After tagging, run: git push origin <Tag>

.PARAMETER SkipValidate
    Skip validate.ps1 and redact-check.ps1 (not recommended for releases).

.PARAMETER AllowBuildOnly
    Allow a tag when only build/release files changed (no workflow_gui.py diff).

.PARAMETER Force
    Allow a dirty working tree (not recommended).

.EXAMPLE
    .\30_scripts\tag_release.ps1 -Suggest
    .\30_scripts\tag_release.ps1 -Tag v3.0.1 -DryRun
    .\30_scripts\tag_release.ps1 -Tag v3.0.1 -Push
#>
param(
    [string]$Tag,
    [switch]$Suggest,
    [switch]$DryRun,
    [switch]$Push,
    [switch]$SkipValidate,
    [switch]$AllowBuildOnly,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$Root    = Split-Path $PSScriptRoot -Parent
$GuiPy   = Join-Path $PSScriptRoot 'workflow_gui.py'
$ReleasePaths = @(
    '30_scripts/workflow_gui.py',
    '30_scripts/build_exe.ps1',
    '30_scripts/build_linux.sh',
    '30_scripts/build_requirements.txt',
    '.github/workflows/release.yml'
)

function Get-AppVersion {
    if (-not (Test-Path $GuiPy)) {
        Write-Error "workflow_gui.py not found: $GuiPy"
        exit 1
    }
    $raw = Get-Content $GuiPy -Raw -Encoding UTF8
    if ($raw -match 'APP_VERSION\s*=\s*["'']([^"'']+)["'']') {
        return $Matches[1].Trim()
    }
    Write-Error "APP_VERSION not found in workflow_gui.py"
    exit 1
}

function Normalize-Tag {
    param([string]$Value)
    $t = $Value.Trim()
    if ($t -notmatch '^v') { $t = "v$t" }
    if ($t -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') {
        Write-Error "Tag must be semver vX.Y.Z (got: $t)"
        exit 1
    }
    return $t
}

function Get-LastReleaseTag {
    Push-Location $Root
    try {
        $t = git tag -l 'v*' --sort=-v:refname 2>$null | Select-Object -First 1
        return $t
    } finally {
        Pop-Location
    }
}

function Get-GitDiffNames {
    param([string]$Range, [string[]]$Paths)
    Push-Location $Root
    try {
        if (-not $Range) {
            # No prior tag: any history for these paths
            $all = @()
            foreach ($p in $Paths) {
                $hits = git log --oneline -1 -- $p 2>$null
                if ($hits) { $all += $p }
            }
            return $all | Select-Object -Unique
        }
        $out = git diff --name-only $Range -- @Paths 2>$null
        return @($out | Where-Object { $_ })
    } finally {
        Pop-Location
    }
}

$appVer   = Get-AppVersion
$lastTag  = Get-LastReleaseTag
$range    = if ($lastTag) { "$lastTag..HEAD" } else { $null }
$changed  = Get-GitDiffNames -Range $range -Paths $ReleasePaths
$guiChanged = @($changed | Where-Object { $_ -eq '30_scripts/workflow_gui.py' }).Count -gt 0

Write-Host ""
Write-Host "=== workflow_gui release tag preflight ===" -ForegroundColor Cyan
Write-Host "  APP_VERSION (workflow_gui.py) : $appVer"
Write-Host "  Last release tag              : $(if ($lastTag) { $lastTag } else { '(none)' })"
Write-Host "  Diff range                    : $(if ($range) { $range } else { 'initial release (all history)' })"
Write-Host ""

if ($changed.Count -gt 0) {
    Write-Host "  Release-related paths changed:" -ForegroundColor Yellow
    $changed | ForEach-Object { Write-Host "    $_" }
} else {
    Write-Host "  No release-related path changes since last tag." -ForegroundColor Yellow
}
Write-Host ""

if ($Suggest -and -not $Tag) {
    $rec = Normalize-Tag "v$appVer"
    Write-Host "Suggested tag: $rec" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next: commit a clean tree, then:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File .\30_scripts\tag_release.ps1 -Tag $rec -Push"
    Write-Host ""
    exit 0
}

if (-not $Tag) {
    $Tag = "v$appVer"
}
$Tag = Normalize-Tag $Tag

$expectedTag = Normalize-Tag "v$appVer"
if ($Tag -ne $expectedTag) {
    Write-Host "  WARNING: -Tag $Tag does not match APP_VERSION ($expectedTag)" -ForegroundColor Yellow
}

# Working tree
Push-Location $Root
try {
    $porcelain = git status --porcelain 2>$null
    if ($porcelain -and -not $Force) {
        Write-Host "  ERROR: Working tree is not clean. Commit or stash first, or use -Force." -ForegroundColor Red
        $porcelain | ForEach-Object { Write-Host "    $_" }
        exit 1
    }
    if ($porcelain -and $Force) {
        Write-Host "  WARNING: Tagging with dirty working tree (-Force)." -ForegroundColor Yellow
    }

    # Duplicate tag
    $tagExists = git rev-parse -q --verify "refs/tags/$Tag" 2>$null
    if ($tagExists) {
        Write-Error "Tag $Tag already exists at $tagExists"
        exit 1
    }

    if (-not $guiChanged -and -not $AllowBuildOnly -and -not $Force) {
        Write-Host "  ERROR: workflow_gui.py unchanged since $(if ($lastTag) { $lastTag } else { 'N/A' })." -ForegroundColor Red
        Write-Host "  Use -AllowBuildOnly for build-harness-only releases, or -Force to override."
        exit 1
    }

    if (-not $SkipValidate) {
        Write-Host "Running validate.ps1..." -ForegroundColor Cyan
        & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate.ps1') -Root $Root
        if ($LASTEXITCODE -ne 0) {
            Write-Error "validate.ps1 failed (exit $LASTEXITCODE). Fix before tagging."
            exit 1
        }
        Write-Host "Running redact-check.ps1..." -ForegroundColor Cyan
        & powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'redact-check.ps1') -Root $Root
        if ($LASTEXITCODE -ne 0) {
            Write-Error "redact-check.ps1 failed (exit $LASTEXITCODE). Fix before tagging."
            exit 1
        }
        Write-Host "  Preflight scripts passed." -ForegroundColor Green
    }

    $msg = "workflow_gui $appVer release"
    Write-Host ""
    Write-Host "  Tag to create : $Tag (annotated)" -ForegroundColor Green
    Write-Host "  Message       : $msg"
    Write-Host "  After push    : GitHub Actions release.yml publishes workflow_gui.exe"
    Write-Host ""

    if ($DryRun) {
        Write-Host "[DryRun] Would run: git tag -a $Tag -m `"$msg`"" -ForegroundColor Cyan
        if ($Push) { Write-Host "[DryRun] Would run: git push origin $Tag" -ForegroundColor Cyan }
        exit 0
    }

    git tag -a $Tag -m $msg
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git tag failed."
        exit 1
    }
    Write-Host "Created tag $Tag at $(git rev-parse --short HEAD)" -ForegroundColor Green

    if ($Push) {
        Write-Host "Pushing tag to origin..." -ForegroundColor Cyan
        git push origin $Tag
        if ($LASTEXITCODE -ne 0) {
            Write-Error "git push origin $Tag failed."
            exit 1
        }
        Write-Host "Pushed $Tag -- watch GitHub Actions for the Release build." -ForegroundColor Green
    } else {
        Write-Host "Tag created locally. Push when ready:"
        Write-Host "  git push origin $Tag"
    }
    Write-Host ""
} finally {
    Pop-Location
}
