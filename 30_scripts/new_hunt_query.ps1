#Requires -Version 5.1
<#
.SYNOPSIS
    Scaffold a reusable hunt query file under 45_hunt_queries/.

.EXAMPLE
    powershell -File .\30_scripts\new_hunt_query.ps1 -QueryId sysmon-rare-parent-child -Platform kql -Title "Rare parent-child chains"

.EXAMPLE
    powershell -File .\30_scripts\new_hunt_query.ps1 -QueryId schtasks-persistence -Platform sigma -Overwrite
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9]+(-[a-z0-9]+)*$')]
    [string]$QueryId,

    [ValidateSet('splunk', 'kql', 'elastic', 'sigma', 'other')]
    [string]$Platform = 'kql',

    [Parameter(Mandatory = $true)]
    [string]$Title,

    [string[]]$DataSources = @(),
    [string[]]$MitreTechniques = @(),
    [string[]]$Tags = @(),

    [switch]$Overwrite
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$dir  = Join-Path $root '45_hunt_queries'
$path = Join-Path $dir "$QueryId.md"

if (-not (Test-Path $dir)) {
    Write-Error "45_hunt_queries folder not found under $root"
    exit 1
}

if ((Test-Path $path) -and -not $Overwrite) {
    Write-Warning "45_hunt_queries\$QueryId.md already exists. Use -Overwrite to replace."
    exit 1
}

$dsYaml = if ($DataSources.Count -gt 0) {
    ($DataSources | ForEach-Object { "  - `"$_`"" }) -join "`n"
} else {
    '  - "<FILL -- e.g. Sysmon EventID 1>"'
}

$mitreYaml = if ($MitreTechniques.Count -gt 0) {
    ($MitreTechniques | ForEach-Object { "  - $_" }) -join "`n"
} else {
    '  - "<FILL -- Txxxx or Txxxx.xxx>"'
}

$tagsYaml = if ($Tags.Count -gt 0) {
    ($Tags | ForEach-Object { "  - $_" }) -join "`n"
} else {
    '  - "<FILL>"'
}

$platformBlock = switch ($Platform) {
    'kql' {
@'
```kql
// Sanitize: HOST_PLACEHOLDER, USER_PLACEHOLDER, index names
<FILL query body>
```
'@
    }
    'splunk' {
@'
```spl
// Sanitize host/account fields before commit
<FILL SPL>
```
'@
    }
    'sigma' {
@'
```yaml
title: <FILL>
status: experimental
logsource:
  product: windows
detection:
  selection:
    <FILL>: <value>
  condition: selection
level: medium
```
'@
    }
    'elastic' {
@'
```json
{
  "query": {
    "bool": {
      "must": [ { "match": { "<FILL>": "<value>" } } ]
    }
  }
}
```
'@
    }
    default {
@'
```
<FILL query body>
```
'@
    }
}

$content = @"
---
query_id: $QueryId
title: "$Title"
platform: $Platform
data_sources:
$dsYaml
mitre_techniques:
$mitreYaml
tags:
$tagsYaml
related_samples: []
status: draft
---

# $Title

> Reusable query — link from hunt `01_static` and optional `query_refs` in `03_findings`.

## Query

$platformBlock

## Tuning notes

- **False positives:** <FILL>
- **Required data:** <FILL>
- **Time range:** <FILL>

## Related engagements

| sample_id | How used |
|-----------|----------|
| | |

---

*Add a row to [`INDEX.md`](../45_hunt_queries/INDEX.md) when this query is ready to catalog.*
"@

$verb = if (Test-Path $path) { 'Updated' } else { 'Created' }
Set-Content -Path $path -Value $content -Encoding UTF8
Write-Host "$verb 45_hunt_queries\$QueryId.md" -ForegroundColor Green
Write-Host "  Next: edit query body, update 45_hunt_queries/INDEX.md, reference from hunt 01_static" -ForegroundColor Yellow
