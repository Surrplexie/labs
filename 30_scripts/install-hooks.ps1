#Requires -Version 5.1
<#
.SYNOPSIS
    Install the pre-push git hook from .github/hooks/ into .git/hooks/.

.DESCRIPTION
    Copies .github/hooks/pre-push to .git/hooks/pre-push so it runs
    automatically before every git push.

    On Windows, git executes hooks via sh.exe (bundled with Git for Windows).
    The hook is a POSIX shell script that detects and calls PowerShell or pwsh
    automatically.

    To skip the hook in an emergency: git push --no-verify

.PARAMETER Uninstall
    Remove the installed hook instead of installing it.

.EXAMPLE
    # Install
    powershell -ExecutionPolicy Bypass -File .\30_scripts\install-hooks.ps1

    # Uninstall
    powershell -ExecutionPolicy Bypass -File .\30_scripts\install-hooks.ps1 -Uninstall
#>
param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$Root       = Split-Path $PSScriptRoot -Parent
$Source     = Join-Path $Root '.github\hooks\pre-push'
$GitHooks   = Join-Path $Root '.git\hooks'
$Dest       = Join-Path $GitHooks 'pre-push'

if ($Uninstall) {
    if (Test-Path $Dest) {
        Remove-Item $Dest -Force
        Write-Host "Uninstalled: $Dest" -ForegroundColor Yellow
    } else {
        Write-Host "Hook not installed (nothing to remove)." -ForegroundColor DarkGray
    }
    exit 0
}

# --- Preflight checks -------------------------------------------------------

if (-not (Test-Path $Source)) {
    Write-Host "ERROR: source hook not found at: $Source" -ForegroundColor Red
    Write-Host "       Ensure you are running from the labs repo root." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $GitHooks)) {
    Write-Host "ERROR: .git/hooks/ not found at: $GitHooks" -ForegroundColor Red
    Write-Host "       Run this script from inside the git repository." -ForegroundColor Red
    exit 1
}

# --- Install ----------------------------------------------------------------

if (Test-Path $Dest) {
    $backup = "$Dest.bak"
    Copy-Item $Dest $backup -Force
    Write-Host "Backed up existing hook to: $backup" -ForegroundColor DarkGray
}

Copy-Item $Source $Dest -Force

# Git on Windows requires the hook file to have Unix line endings (LF only).
# Replace CRLF -> LF in-place.
$content = [System.IO.File]::ReadAllText($Dest)
$content = $content -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($Dest, $content, [System.Text.Encoding]::UTF8)

Write-Host ""
Write-Host "Hook installed successfully." -ForegroundColor Green
Write-Host "  Source : $Source"
Write-Host "  Dest   : $Dest"
Write-Host ""
Write-Host "The hook will run validate.ps1 and redact-check.ps1 before every push."
Write-Host "To skip in an emergency: git push --no-verify"
Write-Host ""

# Check that PowerShell is callable from sh (Git's hook runner)
$gitExe = Get-Command git -ErrorAction SilentlyContinue
if ($gitExe) {
    Write-Host "Git found: $($gitExe.Source)" -ForegroundColor DarkGray
}

$shExe = Get-Command sh -ErrorAction SilentlyContinue
if (-not $shExe) {
    Write-Host "WARN: 'sh' not found on PATH." -ForegroundColor Yellow
    Write-Host "      Git for Windows bundles sh.exe in its bin/ folder." -ForegroundColor Yellow
    Write-Host "      If the hook doesn't fire, ensure Git for Windows is installed." -ForegroundColor Yellow
}
