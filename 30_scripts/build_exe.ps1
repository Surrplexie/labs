#Requires -Version 5.1
<#
.SYNOPSIS
    Build workflow_gui.exe for Windows using PyInstaller.

.DESCRIPTION
    Installs/upgrades PyInstaller then compiles workflow_gui.py into a
    single self-contained .exe.  Output lands in dist\workflow_gui.exe.

.PARAMETER Python
    Path to the Python executable (default: python).

.PARAMETER SkipPipUpgrade
    Skip the pip install/upgrade step (use if PyInstaller is already installed).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\30_scripts\build_exe.ps1
    powershell -ExecutionPolicy Bypass -File .\30_scripts\build_exe.ps1 -Python python3.12
#>
param(
    [string]$Python       = 'python',
    [switch]$SkipPipUpgrade
)

$ErrorActionPreference = 'Stop'

$Root       = Split-Path $PSScriptRoot -Parent
$Script     = Join-Path $PSScriptRoot  'workflow_gui.py'
$DistDir    = Join-Path $Root 'dist'
$BuildTmp   = Join-Path $DistDir '_build_tmp'
$SpecDir    = Join-Path $DistDir '_spec'
$OutputExe  = Join-Path $DistDir 'workflow_gui.exe'

Write-Host ""
Write-Host "=== Workflow GUI -- Windows Build ===" -ForegroundColor Cyan
Write-Host "  Script : $Script"
Write-Host "  Output : $OutputExe"
Write-Host ""

# -- Check Python ----------------------------------------------------------
Write-Host "Checking Python..." -NoNewline
try {
    $ver = & $Python --version 2>&1
    Write-Host " $ver" -ForegroundColor Green
} catch {
    Write-Host " NOT FOUND" -ForegroundColor Red
    Write-Error "Python not found at '$Python'. Install Python 3.10+ and ensure it is on PATH."
    exit 1
}

# -- Upgrade PyInstaller ---------------------------------------------------
if (-not $SkipPipUpgrade) {
    Write-Host "Installing / upgrading PyInstaller..." -ForegroundColor Cyan
    & $Python -m pip install --upgrade pyinstaller --quiet
    if ($LASTEXITCODE -ne 0) {
        Write-Error "pip install pyinstaller failed."
        exit 1
    }
    Write-Host "  PyInstaller ready." -ForegroundColor Green
}

# -- Create output dirs ----------------------------------------------------
New-Item -ItemType Directory -Force -Path $DistDir   | Out-Null
New-Item -ItemType Directory -Force -Path $BuildTmp  | Out-Null
New-Item -ItemType Directory -Force -Path $SpecDir   | Out-Null

# -- Run PyInstaller -------------------------------------------------------
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

# -- Report ----------------------------------------------------------------
if (Test-Path $OutputExe) {
    $sizeMB = [math]::Round((Get-Item $OutputExe).Length / 1MB, 1)
    Write-Host ""
    Write-Host "Build SUCCEEDED" -ForegroundColor Green
    Write-Host "  $OutputExe  ($sizeMB MB)"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  dist\workflow_gui.exe"
    Write-Host "  dist\workflow_gui.exe --repo C:\path\to\labs"
} else {
    Write-Host "Output file not found after build -- check PyInstaller output above." -ForegroundColor Red
    exit 1
}
