#Requires -Version 5.1
<#
.SYNOPSIS
    Strips EXIF/metadata from screenshot images before committing.

.DESCRIPTION
    Processes all PNG, JPG, and JPEG files under 50_screenshots/ and removes
    embedded metadata (EXIF, IPTC, XMP, GPS, author, device info, etc.).

    Primary method: exiftool (https://exiftool.org)
      exiftool is the most reliable cross-format metadata stripper.
      Install: winget install exiftool  OR  choco install exiftool  OR  manual download.

    Fallback method (JPEG only): .NET System.Drawing
      Used automatically if exiftool is not found in PATH.
      Does NOT work for PNG (PNG metadata requires exiftool or similar).

    HEIC files:
      HEIC files are detected and flagged. They should be converted to PNG
      before committing (GitHub and most Markdown renderers do not display HEIC).
      exiftool can strip HEIC metadata but cannot convert the format.

.PARAMETER Root
    Path to repo root. Defaults to parent of script directory.

.PARAMETER SampleId
    Limit processing to one sample's screenshot folder (e.g., sample_01).

.PARAMETER DryRun
    Report what would be processed without making changes.

.PARAMETER SkipBackup
    By default exiftool writes a backup of the original file (.jpg_original).
    Pass this flag to use -overwrite_original (no backup created).

.EXAMPLE
    # Strip all screenshots in repo
    powershell -ExecutionPolicy Bypass -File .\30_scripts\strip-exif.ps1

    # Dry run - see what would be processed
    powershell -ExecutionPolicy Bypass -File .\30_scripts\strip-exif.ps1 -DryRun

    # One sample, no backup files
    powershell -ExecutionPolicy Bypass -File .\30_scripts\strip-exif.ps1 -SampleId sample_01 -SkipBackup
#>

param(
    [string]$Root     = (Split-Path $PSScriptRoot -Parent),
    [string]$SampleId = '',
    [switch]$DryRun,
    [switch]$SkipBackup
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_paths.ps1')

# ---------------------------------------------------------------------------
# Locate exiftool
# ---------------------------------------------------------------------------

$exiftool = $null
try {
    $et = Get-Command 'exiftool' -ErrorAction Stop
    $exiftool = $et.Source
} catch {
    $exiftool = $null
}

# Also check common install locations on Windows
if (-not $exiftool) {
    $candidates = @(
        'C:\Windows\exiftool.exe',
        'C:\Program Files\exiftool\exiftool.exe',
        'C:\tools\exiftool\exiftool.exe',
        "$env:LOCALAPPDATA\Programs\exiftool\exiftool.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $exiftool = $c; break }
    }
}

$hasExiftool = ($null -ne $exiftool)

if (-not $hasExiftool) {
    Write-Host ""
    Write-Host "  [INFO] exiftool not found in PATH or common install locations." -ForegroundColor Yellow
    Write-Host "  JPEG files will be processed via .NET fallback (metadata stripped)." -ForegroundColor Yellow
    Write-Host "  PNG files: metadata cannot be stripped without exiftool." -ForegroundColor Yellow
    Write-Host "  HEIC files: cannot be processed without exiftool." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  To install exiftool:" -ForegroundColor DarkGray
    Write-Host "    winget install OliverBetz.ExifTool" -ForegroundColor DarkGray
    Write-Host "    OR: choco install exiftool" -ForegroundColor DarkGray
    Write-Host "    OR: https://exiftool.org/install.html" -ForegroundColor DarkGray
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Locate screenshot files
# ---------------------------------------------------------------------------

if ($SampleId -ne '') {
    $searchRoot = Get-ScreenshotDir -Root $Root -SampleId $SampleId
    if (-not (Test-Path $searchRoot)) {
        Write-Error "Screenshot folder not found: $searchRoot"
        exit 1
    }
    $searchRoots = @($searchRoot)
} else {
    $searchRoots = @(Get-AllScreenshotRoots -Root $Root)
    if ($searchRoots.Count -eq 0) {
        Write-Error "No 50_screenshots folders found under LAB* or repo root."
        exit 1
    }
}

$imgExtensions = @('.png', '.jpg', '.jpeg', '.heic', '.heif')
$allImages = foreach ($searchRoot in $searchRoots) {
    Get-ChildItem -Path $searchRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $imgExtensions -contains $_.Extension.ToLower() }
}

$pngs  = @($allImages | Where-Object { $_.Extension -eq '.png' })
$jpegs = @($allImages | Where-Object { $_.Extension -in @('.jpg', '.jpeg') })
$heics = @($allImages | Where-Object { $_.Extension -in @('.heic', '.heif') })

Write-Host ""
Write-Host "strip-exif -- scanning $($allImages.Count) image(s)" -ForegroundColor Cyan
Write-Host "  PNG  : $($pngs.Count)" -ForegroundColor DarkGray
Write-Host "  JPEG : $($jpegs.Count)" -ForegroundColor DarkGray
Write-Host "  HEIC : $($heics.Count)$(if ($heics.Count -gt 0) { ' (WARNING: convert to PNG before committing)' })" -ForegroundColor $(if ($heics.Count -gt 0) { 'Yellow' } else { 'DarkGray' })
Write-Host ""

if ($allImages.Count -eq 0) {
    Write-Host "  No images found to process." -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# HEIC warning
# ---------------------------------------------------------------------------

if ($heics.Count -gt 0) {
    Write-Host "  [WARN] HEIC/HEIF files detected -- these may not render on GitHub." -ForegroundColor Yellow
    foreach ($h in $heics) {
        $rel = $h.FullName.Substring($Root.Length).TrimStart('\', '/')
        Write-Host "    $rel" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  Convert HEIC to PNG before committing:" -ForegroundColor DarkGray
    Write-Host "    pip install pillow pillow-heif" -ForegroundColor DarkGray
    Write-Host "    python -c `"from PIL import Image; import pillow_heif; pillow_heif.register_heif_opener(); img=Image.open('file.heic'); img.save('file.png')`"" -ForegroundColor DarkGray
    Write-Host ""
}

$processed = 0
$skipped   = 0
$errors    = 0

# ---------------------------------------------------------------------------
# Process with exiftool (all formats)
# ---------------------------------------------------------------------------

if ($hasExiftool) {
    $targets = @($pngs + $jpegs + $heics)

    if ($targets.Count -gt 0) {
        Write-Host "  Using exiftool: $exiftool" -ForegroundColor DarkGray

        $overwriteFlag = if ($SkipBackup) { '-overwrite_original' } else { '' }

        foreach ($img in $targets) {
            $rel = $img.FullName.Substring($Root.Length).TrimStart('\', '/')

            if ($DryRun) {
                Write-Host "  [DRY-RUN] Would strip: $rel" -ForegroundColor DarkCyan
                $processed++
                continue
            }

            try {
                $args = @('-all=', '-q', $img.FullName)
                if ($SkipBackup) { $args = @('-all=', '-overwrite_original', '-q', $img.FullName) }

                $result = & $exiftool @args 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  [OK] $rel" -ForegroundColor Green
                    $processed++
                } else {
                    Write-Host "  [ERR] $rel : exiftool exit $LASTEXITCODE -- $result" -ForegroundColor Red
                    $errors++
                }
            } catch {
                Write-Host "  [ERR] $rel : $_" -ForegroundColor Red
                $errors++
            }
        }
    }
} else {
    # ---------------------------------------------------------------------------
    # Fallback: .NET System.Drawing for JPEG only
    # ---------------------------------------------------------------------------

    if ($jpegs.Count -gt 0) {
        Write-Host "  Using .NET System.Drawing fallback (JPEG only)" -ForegroundColor DarkGray
        Add-Type -AssemblyName System.Drawing

        foreach ($img in $jpegs) {
            $rel = $img.FullName.Substring($Root.Length).TrimStart('\', '/')

            if ($DryRun) {
                Write-Host "  [DRY-RUN] Would strip JPEG: $rel" -ForegroundColor DarkCyan
                $processed++
                continue
            }

            try {
                $src     = [System.Drawing.Image]::FromFile($img.FullName)
                $propIds = @($src.PropertyIdList)
                foreach ($pid in $propIds) {
                    $src.RemovePropertyItem($pid)
                }

                # Save to a temp file then replace
                $tmp = $img.FullName + '.tmp'
                $src.Save($tmp, $src.RawFormat)
                $src.Dispose()

                Remove-Item $img.FullName -Force
                Rename-Item $tmp $img.FullName

                Write-Host "  [OK] $rel (JPEG, .NET method)" -ForegroundColor Green
                $processed++
            } catch {
                Write-Host "  [ERR] $rel : $_" -ForegroundColor Red
                if (Test-Path ($img.FullName + '.tmp')) { Remove-Item ($img.FullName + '.tmp') -Force }
                $errors++
            }
        }
    }

    if ($pngs.Count -gt 0) {
        Write-Host ""
        Write-Host "  [SKIP] $($pngs.Count) PNG file(s) -- install exiftool to process PNG metadata" -ForegroundColor Yellow
        foreach ($p in $pngs) {
            $rel = $p.FullName.Substring($Root.Length).TrimStart('\', '/')
            Write-Host "    $rel" -ForegroundColor DarkGray
        }
        $skipped += $pngs.Count
    }
}

# ---------------------------------------------------------------------------
# Backup files note
# ---------------------------------------------------------------------------

if ($hasExiftool -and -not $SkipBackup -and -not $DryRun -and $processed -gt 0) {
    Write-Host ""
    Write-Host "  Note: exiftool created *.jpg_original / *.png_original backup files." -ForegroundColor DarkGray
    Write-Host "  To clean them up: Get-ChildItem 50_screenshots -Recurse -Filter '*_original' | Remove-Item" -ForegroundColor DarkGray
    Write-Host "  Or re-run with -SkipBackup to skip backup creation." -ForegroundColor DarkGray
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Processed : $processed"  -ForegroundColor Green
Write-Host "  Skipped   : $skipped"   -ForegroundColor Yellow
Write-Host "  Errors    : $errors"    -ForegroundColor $(if ($errors -gt 0) { 'Red' } else { 'Green' })
Write-Host "============================================" -ForegroundColor Cyan

if ($errors -gt 0) { exit 1 } else { exit 0 }
