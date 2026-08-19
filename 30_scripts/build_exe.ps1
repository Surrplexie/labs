#Requires -Version 5.1
<#
.SYNOPSIS
    Build workflow_gui.exe for Windows using a pinned PyInstaller version.

.DESCRIPTION
    Installs the exact PyInstaller version from build_requirements.txt, then
    compiles workflow_gui.py into a single self-contained .exe.

    Outputs:
      dist\workflow_gui.exe    -- standalone executable
      dist\SHA256SUMS.txt      -- SHA-256 checksum for verification
      %USERPROFILE%\Downloads\workflow_gui-vX.Y.Z.zip  -- exe + checksum (unless -SkipZip)

    The checksum file lets you (or a release consumer) verify the binary
    has not been tampered with:

        # PowerShell verification:
        (Get-FileHash dist\workflow_gui.exe -Algorithm SHA256).Hash.ToUpper()
        # compare to dist\SHA256SUMS.txt

.PARAMETER Python
    Path to the Python executable (default: python).

.PARAMETER SkipPipInstall
    Skip the pip install step (use only if the exact pinned version is already
    installed and you do not want pip to run.

.PARAMETER Clean
    After a successful build, remove dist/_build_tmp and dist/_spec (keeps .exe and SHA256SUMS.txt).

.PARAMETER SkipZip
    Do not write a zip copy of the exe to Downloads.

.PARAMETER ZipTo
    Folder for the zip (default: %USERPROFILE%\Downloads).

.PARAMETER SignThumbprint
    Optional SHA-1 certificate thumbprint for Authenticode signing via signtool.exe.
    Falls back to env WORKFLOW_GUI_SIGN_THUMBPRINT when omitted. Skipped if signtool missing.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\30_scripts\build_exe.ps1
    powershell -ExecutionPolicy Bypass -File .\30_scripts\build_exe.ps1 -Python python3.12
    powershell -ExecutionPolicy Bypass -File .\30_scripts\build_exe.ps1 -SkipPipInstall
    powershell -ExecutionPolicy Bypass -File .\30_scripts\build_exe.ps1 -SkipPipInstall -Clean
    powershell -ExecutionPolicy Bypass -File .\30_scripts\build_exe.ps1 -SkipPipInstall -Clean -SignThumbprint ABCD1234...
    powershell -ExecutionPolicy Bypass -File .\30_scripts\build_exe.ps1 -ZipTo "$env:USERPROFILE\Downloads"
#>
param(
    [string]$Python           = 'python',
    [switch]$SkipPipInstall,
    [switch]$Clean,
    [switch]$SkipZip,
    [string]$ZipTo            = (Join-Path $env:USERPROFILE 'Downloads'),
    [string]$SignThumbprint   = ''
)

$ErrorActionPreference = 'Stop'

$Root       = Split-Path $PSScriptRoot -Parent
$Script     = Join-Path $PSScriptRoot  'workflow_gui.py'
$ReqFile    = Join-Path $PSScriptRoot  'build_requirements.txt'

# Single source of truth for PyInstaller pin
if (-not (Test-Path $ReqFile)) {
    Write-Error "build_requirements.txt not found: $ReqFile"
    exit 1
}
$pinLine = Select-String -Path $ReqFile -Pattern '^\s*pyinstaller==' | Select-Object -First 1
if (-not $pinLine) {
    Write-Error "No pyinstaller== pin in $ReqFile"
    exit 1
}
$PYINSTALLER_VERSION = ($pinLine.Line -replace '^\s*pyinstaller==\s*', '').Trim()
if ([string]::IsNullOrWhiteSpace($PYINSTALLER_VERSION)) {
    Write-Error "Invalid pyinstaller pin in $ReqFile"
    exit 1
}
$DistDir    = Join-Path $Root 'dist'
$BuildTmp   = Join-Path $DistDir '_build_tmp'
$SpecDir    = Join-Path $DistDir '_spec'
$OutputExe  = Join-Path $DistDir 'workflow_gui.exe'
$SumsFile   = Join-Path $DistDir 'SHA256SUMS.txt'

$appVer = '0.0.0'
$verLine = Select-String -Path $Script -Pattern 'APP_VERSION\s*=\s*["'']([^"'']+)["'']' | Select-Object -First 1
if ($verLine -and $verLine.Matches.Count -gt 0) {
    $appVer = $verLine.Matches[0].Groups[1].Value
}

Write-Host ""
Write-Host "=== Labs HUD -- Windows Build ===" -ForegroundColor Cyan
Write-Host "  Script      : $Script"
Write-Host "  Version     : $appVer"
Write-Host "  PyInstaller : $PYINSTALLER_VERSION (pinned)"
Write-Host "  Output      : $OutputExe"
if (-not $SkipZip) {
    Write-Host "  Zip to      : $ZipTo"
}
Write-Host ""

# ---------------------------------------------------------------------------
# Check Python
# ---------------------------------------------------------------------------
Write-Host "Checking Python..." -NoNewline
try {
    $ver = & $Python --version 2>&1
    Write-Host " $ver" -ForegroundColor Green
} catch {
    Write-Host " NOT FOUND" -ForegroundColor Red
    Write-Error "Python not found at '$Python'. Install Python 3.10+ and ensure it is on PATH."
    exit 1
}

# ---------------------------------------------------------------------------
# Check tkinter (required by workflow_gui.py)
# ---------------------------------------------------------------------------
Write-Host "Checking tkinter..." -NoNewline
& $Python -c "import tkinter" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host " NOT FOUND" -ForegroundColor Red
    Write-Host "workflow_gui.py needs tkinter. For this Python install:"
    Write-Host "  python.org: re-run the installer -> Modify -> enable 'tcl/tk and IDLE'"
    Write-Host "  Microsoft Store Python: use the python.org build or a distro that bundles tk"
    Write-Error "tkinter not available for '$Python'."
    exit 1
}
Write-Host " OK" -ForegroundColor Green

# ---------------------------------------------------------------------------
# Install pinned PyInstaller
# ---------------------------------------------------------------------------
if (-not $SkipPipInstall) {
    Write-Host "Installing pinned PyInstaller $PYINSTALLER_VERSION (from build_requirements.txt)..." -ForegroundColor Cyan
    & $Python -m pip install -r $ReqFile --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Error "pip install pyinstaller==$PYINSTALLER_VERSION failed."
        exit 1
    }

    # Confirm installed version matches pin
    $installedVer = (& $Python -m pip show pyinstaller 2>&1 | Select-String 'Version:').ToString() -replace '^Version:\s*', ''
    if ($installedVer.Trim() -ne $PYINSTALLER_VERSION) {
        Write-Host "  WARNING: installed PyInstaller $($installedVer.Trim()) != pinned $PYINSTALLER_VERSION" -ForegroundColor Yellow
        Write-Host "  Continuing -- update build_requirements.txt if this is intentional." -ForegroundColor Yellow
    } else {
        Write-Host "  PyInstaller $PYINSTALLER_VERSION confirmed." -ForegroundColor Green
    }
}

# ---------------------------------------------------------------------------
# Capture source hash before build (reproducibility note)
# ---------------------------------------------------------------------------
$srcHash = (Get-FileHash $Script -Algorithm SHA256).Hash.ToUpper()
Write-Host "  Source hash (workflow_gui.py): $srcHash"

# ---------------------------------------------------------------------------
# Create output dirs
# ---------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $DistDir  | Out-Null
New-Item -ItemType Directory -Force -Path $BuildTmp | Out-Null
New-Item -ItemType Directory -Force -Path $SpecDir  | Out-Null

# ---------------------------------------------------------------------------
# Run PyInstaller
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Building..." -ForegroundColor Cyan

& $Python -m PyInstaller `
    --onefile `
    --windowed `
    --name 'workflow_gui' `
    --distpath $DistDir `
    --workpath $BuildTmp `
    --specpath $SpecDir `
    --noconfirm `
    $Script

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Build FAILED (exit $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Compute and write SHA256SUMS
# ---------------------------------------------------------------------------
if (Test-Path $OutputExe) {
    $exeHash  = (Get-FileHash $OutputExe -Algorithm SHA256).Hash.ToUpper()
    $sizeMB   = [math]::Round((Get-Item $OutputExe).Length / 1MB, 1)
    $buildTs  = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss') + 'Z'
    $pyVerStr = (& $Python --version 2>&1).ToString().Trim()

    $sumsContent = @"
# SHA256SUMS -- workflow_gui Windows build
# Generated  : $buildTs
# Python     : $pyVerStr
# PyInstaller: $PYINSTALLER_VERSION
# Source hash: $srcHash  workflow_gui.py

$exeHash  workflow_gui.exe
"@
    Set-Content -Path $SumsFile -Value $sumsContent -Encoding UTF8

    Write-Host ""
    Write-Host "Build SUCCEEDED" -ForegroundColor Green
    Write-Host "  $OutputExe  ($sizeMB MB)"
    Write-Host "  SHA-256: $exeHash"
    Write-Host "  Checksum file: $SumsFile"
    Write-Host ""
    Write-Host "Verification:"
    Write-Host "  (Get-FileHash dist\workflow_gui.exe -Algorithm SHA256).Hash.ToUpper()"
    Write-Host "  Compare to: $exeHash"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  dist\workflow_gui.exe"
    Write-Host "  dist\workflow_gui.exe --repo C:\path\to\labs"

    $thumb = $SignThumbprint.Trim()
    if (-not $thumb -and $env:WORKFLOW_GUI_SIGN_THUMBPRINT) {
        $thumb = $env:WORKFLOW_GUI_SIGN_THUMBPRINT.Trim()
    }
    if ($thumb) {
        $signtool = Get-Command signtool.exe -ErrorAction SilentlyContinue
        if (-not $signtool) {
            Write-Warning "SignThumbprint set but signtool.exe not on PATH -- binary left unsigned."
        } else {
            Write-Host "Signing with thumbprint $thumb..." -ForegroundColor Cyan
            & signtool.exe sign /sha1 $thumb /fd SHA256 `
                /tr http://timestamp.digicert.com /td SHA256 `
                /d "workflow_gui labs assistant" $OutputExe
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "signtool sign exited $LASTEXITCODE -- binary may be unsigned."
            } else {
                Write-Host "  Authenticode sign succeeded." -ForegroundColor Green
                $exeHash = (Get-FileHash $OutputExe -Algorithm SHA256).Hash.ToUpper()
                $sumsContent = $sumsContent -replace "(?m)^[0-9A-F]{64}  workflow_gui.exe", "$exeHash  workflow_gui.exe"
                Set-Content -Path $SumsFile -Value $sumsContent -Encoding UTF8
                Write-Host "  SHA256SUMS.txt updated after sign." -ForegroundColor DarkGray
            }
        }
    }

    if ($Clean) {
        foreach ($dir in @($BuildTmp, $SpecDir)) {
            if (Test-Path $dir) {
                Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  Removed: $dir" -ForegroundColor DarkGray
            }
        }
    }

    if (-not $SkipZip) {
        if (-not (Test-Path -LiteralPath $ZipTo)) {
            New-Item -ItemType Directory -Force -Path $ZipTo | Out-Null
        }
        $zipName = "workflow_gui-v$appVer.zip"
        $zipPath = Join-Path $ZipTo $zipName
        $stage   = Join-Path $DistDir '_zip_stage'
        if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $stage | Out-Null
        Copy-Item $OutputExe (Join-Path $stage 'workflow_gui.exe')
        Copy-Item $SumsFile  (Join-Path $stage 'SHA256SUMS.txt')
        $readme = @"
Labs HUD v$appVer
=================

Work tab: pick a lab, then Open folder / CAPTURE.md / Notes / Full session.
Each engagement lives in LAB{NN}_{slug}\ (00_original ... 50_screenshots).

Run:
  workflow_gui.exe
  workflow_gui.exe --repo C:\path\to\labs

SHA-256 of workflow_gui.exe is in SHA256SUMS.txt.
This zip is a local convenience copy. The repo does not commit binaries.
"@
        Set-Content -Path (Join-Path $stage 'README.txt') -Value $readme -Encoding UTF8
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zipPath -Force
        Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  Zip: $zipPath" -ForegroundColor Green
    }
} else {
    Write-Host "Output file not found after build -- check PyInstaller output above." -ForegroundColor Red
    exit 1
}
