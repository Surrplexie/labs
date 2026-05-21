#Requires -Version 5.1
<#
.SYNOPSIS
    Headless smoke test for workflow_gui.py (CI and local pre-release).

.DESCRIPTION
    - py_compile on workflow_gui.py
    - tkinter import check
    - workflow_gui.py --smoke-test (no GUI mainloop)
    - Optional PyPI pin drift check vs build_requirements.txt

.PARAMETER Python
    Python executable (default: python).

.PARAMETER StrictPin
    Exit 1 if PyPI latest PyInstaller != pinned version (default: warn only).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\30_scripts\smoke_gui.ps1
#>
param(
    [string]$Python   = 'python',
    [switch]$StrictPin
)

$ErrorActionPreference = 'Stop'
$Root   = Split-Path $PSScriptRoot -Parent
$Script = Join-Path $PSScriptRoot 'workflow_gui.py'
$Req    = Join-Path $PSScriptRoot 'build_requirements.txt'

Write-Host "`n=== workflow_gui smoke test ===" -ForegroundColor Cyan

Write-Host "py_compile..." -NoNewline
& $Python -m py_compile $Script
if ($LASTEXITCODE -ne 0) { Write-Error "py_compile failed"; exit 1 }
Write-Host " OK" -ForegroundColor Green

Write-Host "tkinter import..." -NoNewline
& $Python -c "import tkinter" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host " FAIL" -ForegroundColor Red
    Write-Error "tkinter not available for $Python"
    exit 1
}
Write-Host " OK" -ForegroundColor Green

Write-Host "workflow_gui --smoke-test..." -NoNewline
$out = & $Python $Script --smoke-test 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host " FAIL" -ForegroundColor Red
    Write-Host $out
    exit 1
}
Write-Host " OK" -ForegroundColor Green
Write-Host "  $($out -join ' ')" -ForegroundColor DarkGray

if (Test-Path $Req) {
    $pinLine = Select-String -Path $Req -Pattern '^\s*pyinstaller==' | Select-Object -First 1
    $pinned  = ($pinLine.Line -replace '^\s*pyinstaller==\s*', '').Trim()
    try {
        $pypi    = Invoke-RestMethod -Uri 'https://pypi.org/pypi/pyinstaller/json' -TimeoutSec 15
        $latest  = $pypi.info.version
        if ($pinned -eq $latest) {
            Write-Host "PyInstaller pin: $pinned (matches PyPI latest)" -ForegroundColor Green
        } else {
            $msg = "PyInstaller pin is $pinned but PyPI latest is $latest"
            if ($StrictPin) {
                Write-Host "FAIL: $msg" -ForegroundColor Red
                exit 1
            }
            Write-Host "WARN: $msg (update build_requirements.txt after local build test)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "WARN: Could not query PyPI for PyInstaller version ($($_.Exception.Message))" -ForegroundColor Yellow
    }
}

Write-Host "`nSmoke test PASSED" -ForegroundColor Green
exit 0
