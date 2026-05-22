#Requires -Version 5.1
<#
.SYNOPSIS
    Advances an engagement slot's lifecycle status and prints a kind-specific checklist.

.DESCRIPTION
    Supports all four engagement kinds (file, ctf, lab, hunt) with separate
    status lifecycles and tailored close checklists for each.

    file  lifecycle: queued -> static -> dynamic -> done
    ctf   lifecycle: assigned -> recon -> stuck | solved -> writeup_done
    lab   lifecycle: not_started -> in_progress -> objectives_met -> reviewed
    hunt  lifecycle: scoped -> collecting -> analyzing -> closed

.PARAMETER SampleId
    Engagement slot ID. e.g. sample_07 or just 7 (zero-padded automatically).

.PARAMETER Status
    New status to set. Must match the kind's lifecycle.

.PARAMETER RunValidate
    Run validate.ps1 after updating the tracker.

.PARAMETER RunExport
    Run export-summary.ps1 after updating the tracker.

.EXAMPLE
    # Advance a file sample to static-complete
    powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_07 -Status static

    # Mark a CTF challenge solved
    powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_08 -Status solved

    # Mark a lab reviewed and regenerate index
    powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_09 -Status reviewed -RunExport

    # Close a hunt with full pipeline
    powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId sample_10 -Status closed -RunValidate -RunExport
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SampleId,

    [Parameter(Mandatory = $true)]
    [ValidateSet(
        # file
        'queued', 'static', 'dynamic', 'done',
        # ctf
        'assigned', 'recon', 'stuck', 'solved', 'writeup_done',
        # lab
        'not_started', 'in_progress', 'objectives_met', 'reviewed',
        # hunt
        'scoped', 'collecting', 'analyzing', 'closed'
    )]
    [string]$Status,

    [switch]$RunValidate,
    [switch]$RunExport
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# Normalize sample ID
if ($SampleId -match '^\d+$') {
    $SampleId = 'sample_{0:D2}' -f [int]$SampleId
}

# ---------------------------------------------------------------------------
# Load tracker
# ---------------------------------------------------------------------------

$csvPath = Join-Path $root 'samples_tracker.csv'
if (-not (Test-Path $csvPath)) {
    Write-Error "samples_tracker.csv not found at: $csvPath"
    exit 1
}

$tracker = Import-Csv $csvPath
$row     = $tracker | Where-Object { $_.sample_id -eq $SampleId }

if (-not $row) {
    Write-Error "Engagement ID '$SampleId' not found in samples_tracker.csv"
    exit 1
}

$prevStatus = $row.status
$cols       = $tracker[0].PSObject.Properties.Name
$kind       = if ($cols -contains 'engagement_kind' -and $row.engagement_kind -ne '') {
                  $row.engagement_kind.Trim().ToLower()
              } else { 'file' }

# ---------------------------------------------------------------------------
# Update status
# ---------------------------------------------------------------------------

$row.status = $Status
$tracker | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "  $SampleId ($kind): $prevStatus -> $Status" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------------------
# Kind-specific checklists
# ---------------------------------------------------------------------------

function Write-Check { param([string]$msg) Write-Host "  [ ] $msg" -ForegroundColor White }
function Write-Done  { param([string]$msg) Write-Host "  [x] $msg" -ForegroundColor DarkGray }
function Write-Head  { param([string]$msg) Write-Host "  $msg"     -ForegroundColor Yellow }

Write-Host "Close checklist for $SampleId ($kind / $Status):" -ForegroundColor Cyan
Write-Host ""

# ---- FILE kind ----
if ($kind -eq 'file') {
    if ($Status -in @('queued', 'static', 'dynamic', 'done')) {
        Write-Head "-- 00_original --"
        Write-Check "SHA256 verified on VM matches MalwareBazaar value"
        Write-Check "All hash fields filled (SHA256, SHA1, MD5, imphash, ssdeep, TLSH)"
        Write-Check "URLs from Bazaar page recorded"
        Write-Check "YARA rule names recorded"
        Write-Check "Acquisition checklist boxes ticked"
        Write-Host ""
    }
    if ($Status -in @('static', 'dynamic', 'done')) {
        Write-Head "-- 01_static --"
        Write-Check "DIE: compiler, linker, packer, overlay recorded"
        Write-Check "PEStudio: entropy, version resource, imports, VT hits recorded"
        Write-Check "CFF Explorer: file size vs PE size, version info, timestamps recorded"
        Write-Check "HxD: signature bytes, section names recorded"
        Write-Check "Static summary paragraph written"
        Write-Check "Screenshot map filled in SHOT_INDEX.txt"
        Write-Host ""
    }
    if ($Status -in @('dynamic', 'done')) {
        Write-Head "-- 02_dynamic --"
        Write-Check "Pre-flight checklist complete (snapshot, Procmon, ProcExp, TCPView)"
        Write-Check "Execution details recorded (how launched, user context, observed UX)"
        Write-Check "Process tree populated from Procmon / Process Explorer"
        Write-Check "File system drops documented"
        Write-Check "Registry changes documented"
        Write-Check "Network connections / DNS documented"
        Write-Check "Dynamic summary paragraph written"
        Write-Check "VM snapshot reverted"
        Write-Host ""
    }
    if ($Status -eq 'done') {
        Write-Head "-- 03_findings --"
        Write-Check "YAML frontmatter fully filled (verdict, family_guess, tags, MITRE, dates)"
        Write-Check "Analyst one-liner written"
        Write-Check "Verdict and reasoning filled"
        Write-Check "IOC table complete"
        Write-Check "What you proved section filled"
        Write-Check "Gaps / next steps noted"
        Write-Check "Public-safe blurb written (no internal paths, usernames, or PII)"
        Write-Host ""

        Write-Head "-- IOC sync --"
        Write-Check "All IOCs appended to 40_iocs\indicators.csv"
        Write-Check "No duplicate IOC rows for $SampleId"
        Write-Host ""

        Write-Head "-- Evidence hygiene --"
        Write-Check "Run: 30_scripts\redact-check.ps1"
        Write-Check "Run: 30_scripts\strip-exif.ps1"
        Write-Check "SHOT_INDEX.txt hygiene checklist ticked"
        Write-Check "No HEIC files committed (convert to PNG)"
        Write-Host ""

        $wuPath = Join-Path $root "04_writeups\$SampleId.md"
        Write-Head "-- Optional: 04_writeups long-form report --"
        if (Test-Path $wuPath) {
            Write-Done "04_writeups\$SampleId.md already exists"
        } else {
            Write-Host "  Scaffold a portfolio-depth malware report (optional):" -ForegroundColor DarkGray
            Write-Host "    powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 -SampleId $SampleId -Kind file" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

# ---- CTF kind ----
if ($kind -eq 'ctf') {
    if ($Status -in @('assigned', 'recon', 'stuck', 'solved', 'writeup_done')) {
        Write-Head "-- 00_original (challenge brief) --"
        Write-Check "Platform, category, difficulty, points filled"
        Write-Check "Challenge description / prompt paraphrased (no raw flags)"
        Write-Check "Target IP/URL or given files documented"
        Write-Host ""
    }
    if ($Status -in @('recon', 'stuck', 'solved', 'writeup_done')) {
        Write-Head "-- 01_static (recon/enum) --"
        Write-Check "Port scan results recorded (nmap)"
        Write-Check "Service versions noted"
        Write-Check "Web directories / endpoints enumerated (if web)"
        Write-Check "Interesting findings / leads documented"
        Write-Host ""
    }
    if ($Status -in @('stuck', 'solved', 'writeup_done')) {
        Write-Head "-- 02_dynamic (solve attempt) --"
        Write-Check "Approach log filled with all tried techniques"
        Write-Check "Rabbit holes documented"
        Write-Check "If solved: method summary written (no raw flag in active challenge)"
        Write-Host ""
    }
    if ($Status -eq 'writeup_done') {
        Write-Head "-- 03_findings (writeup) --"
        Write-Check "YAML frontmatter: schema_version 2, solved, public_writeup_safe set"
        Write-Check "Methodology narrative written"
        Write-Check "Key steps table complete"
        Write-Check "Skills listed"
        Write-Check "Public-safe blurb written"
        Write-Check "Raw flag NOT in the file (use placeholder if challenge still active)"
        Write-Check "public_writeup_safe: true only after challenge is retired / permitted"
        Write-Host ""

        Write-Head "-- Evidence hygiene --"
        Write-Check "Run: 30_scripts\redact-check.ps1"
        Write-Check "Run: 30_scripts\strip-exif.ps1"
        Write-Check "No VPN configs, instance IPs, or lab credentials in any committed file"
        Write-Host ""

        $wuPath = Join-Path $root "04_writeups\$SampleId.md"
        Write-Head "-- Optional: 04_writeups long-form report --"
        if (Test-Path $wuPath) {
            Write-Done "04_writeups\$SampleId.md already exists"
        } else {
            Write-Host "  Scaffold a blog-style walkthrough when machine is retired (optional):" -ForegroundColor DarkGray
            Write-Host "    powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 -SampleId $SampleId -Kind ctf" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

# ---- LAB kind ----
if ($kind -eq 'lab') {
    if ($Status -in @('not_started', 'in_progress', 'objectives_met', 'reviewed')) {
        Write-Head "-- 00_original (lab brief) --"
        Write-Check "Course, module, lab name filled"
        Write-Check "Learning objectives listed"
        Write-Check "Environment noted (VM name only -- no credentials, no IPs)"
        Write-Check "Resources linked"
        Write-Host ""
    }
    if ($Status -in @('in_progress', 'objectives_met', 'reviewed')) {
        Write-Head "-- 01_static (steps) --"
        Write-Check "Step log filled with actions and commands"
        Write-Check "Expected vs actual output noted per step"
        Write-Check "Observations and questions documented"
        Write-Host ""
    }
    if ($Status -in @('objectives_met', 'reviewed')) {
        Write-Head "-- 02_dynamic (results) --"
        Write-Check "Objectives completion table filled"
        Write-Check "Errors and resolutions documented"
        Write-Check "Output / proof noted (no credentials)"
        Write-Host ""
    }
    if ($Status -eq 'reviewed') {
        Write-Head "-- 03_findings (reflection) --"
        Write-Check "YAML frontmatter: schema_version 2, objectives_met set"
        Write-Check "Key takeaways written"
        Write-Check "Skills demonstrated listed"
        Write-Check "Public-safe blurb written"
        Write-Host ""

        Write-Head "-- Evidence hygiene --"
        Write-Check "Run: 30_scripts\redact-check.ps1"
        Write-Check "No lab credentials, VPN keys, or instance IPs in any committed file"
        Write-Host ""

        $wuPath = Join-Path $root "04_writeups\$SampleId.md"
        Write-Head "-- Optional: 04_writeups long-form report --"
        if (Test-Path $wuPath) {
            Write-Done "04_writeups\$SampleId.md already exists"
        } else {
            Write-Host "  Scaffold a curriculum / portfolio narrative (optional):" -ForegroundColor DarkGray
            Write-Host "    powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 -SampleId $SampleId -Kind lab" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

# ---- HUNT kind ----
if ($kind -eq 'hunt') {
    if ($Status -in @('scoped', 'collecting', 'analyzing', 'closed')) {
        Write-Head "-- 00_original (scope) --"
        Write-Check "Hypothesis clearly stated"
        Write-Check "Data sources listed"
        Write-Check "Tools and time box noted"
        Write-Check "Out of scope documented"
        Write-Host ""
    }
    if ($Status -in @('collecting', 'analyzing', 'closed')) {
        Write-Head "-- 01_static (collection) --"
        Write-Check "Reusable queries linked from 45_hunt_queries/ where applicable"
        Write-Check "Queries run and results summarised"
        Write-Check "Event IDs / sources referenced"
        Write-Check "Raw findings sanitised of PII before commit"
        Write-Host ""
    }
    if ($Status -in @('analyzing', 'closed')) {
        Write-Head "-- 02_dynamic (analysis) --"
        Write-Check "Timeline built from collected events"
        Write-Check "Patterns documented"
        Write-Check "False positives noted with reasoning"
        Write-Check "IOC candidates listed"
        Write-Host ""
    }
    if ($Status -eq 'closed') {
        Write-Head "-- 03_findings (outcome) --"
        Write-Check "YAML frontmatter: schema_version 2, detections_found, outcome set"
        Write-Check "query_refs resolve under 45_hunt_queries/ (if listed)"
        Write-Check "Confirmed detections table complete"
        Write-Check "Confidence reasoning written"
        Write-Check "Recommendations noted"
        Write-Check "Public-safe blurb written"
        Write-Host ""

        Write-Head "-- Evidence hygiene --"
        Write-Check "Run: 30_scripts\redact-check.ps1"
        Write-Check "No internal hostnames, user accounts, or org data in committed files"
        Write-Check "Run: 30_scripts\strip-exif.ps1"
        Write-Host ""

        $wuPath = Join-Path $root "04_writeups\$SampleId.md"
        Write-Head "-- Optional: 04_writeups long-form report --"
        if (Test-Path $wuPath) {
            Write-Done "04_writeups\$SampleId.md already exists"
        } else {
            Write-Host "  Scaffold a detection-engineering narrative (optional):" -ForegroundColor DarkGray
            Write-Host "    powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 -SampleId $SampleId -Kind hunt" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

# ---------------------------------------------------------------------------
# Optional: run validate + export
# ---------------------------------------------------------------------------

if ($RunValidate) {
    Write-Host "Running validate.ps1..." -ForegroundColor DarkCyan
    $validateScript = Join-Path $root '30_scripts\validate.ps1'
    & powershell -ExecutionPolicy Bypass -File $validateScript
    Write-Host ""
}

if ($RunExport) {
    Write-Host "Running export-summary.ps1..." -ForegroundColor DarkCyan
    $exportScript = Join-Path $root '30_scripts\export-summary.ps1'
    & powershell -ExecutionPolicy Bypass -File $exportScript
    Write-Host ""
}

Write-Host "Done. $SampleId marked as '$Status'." -ForegroundColor Green
if (-not $RunValidate -or -not $RunExport) {
    Write-Host ""
    Write-Host "Tip: re-run with -RunValidate -RunExport to verify integrity and refresh INDEX.md" -ForegroundColor DarkGray
}
