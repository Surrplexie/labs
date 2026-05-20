# 45_hunt_queries

**Reusable, sanitized hunt queries** — separate from per-slot phase logs in `01_static/`.

| Use this folder | Do not use for |
|-----------------|----------------|
| Splunk SPL, KQL, Sigma, Elastic DSL you will run again | One-off query output pasted from a SIEM (that belongs in `01_static/sample_XX.md`) |
| Detection logic you may productionize later | CTF/lab credentials, flags, or course VPN details |
| Cross-hunt pattern library | Malware file hashes (use `40_iocs/` for confirmed hunt/file IOCs) |

---

## Layout

| Path | Purpose |
|------|---------|
| `_examples/` | Starter templates with placeholders — copy, do not reference from engagements |
| `*.md` | One query per file: YAML frontmatter + fenced query body |
| `INDEX.md` | Hand-maintained catalog (optional; run `export-summary.ps1` does not build this) |

---

## File naming

```
<short-slug>.md
```

Examples: `schtasks-persistence.md`, `sysmon-rare-parent-child.md`

Kebab-case, no spaces. The slug becomes the `query_id` in frontmatter.

---

## Frontmatter contract

```yaml
---
query_id: schtasks-persistence
title: "Scheduled task creation (Sysmon 1 + Security 4698)"
platform: sigma          # splunk | kql | elastic | sigma | other
data_sources:
  - "Windows Security 4698"
  - "Sysmon EventID 1"
mitre_techniques:
  - T1053.005
tags:
  - persistence
  - scheduled-task
related_samples: []      # e.g. [sample_09] after a hunt uses this query
status: draft            # draft | tested | production-candidate
---
```

---

## Link from a hunt engagement

In `01_static/sample_XX.md` (collection phase), reference the library instead of duplicating full query text:

```markdown
| Query | Library ref | Results | Notes |
|-------|-------------|---------|-------|
| Scheduled task creation | [`schtasks-persistence.md`](../../45_hunt_queries/schtasks-persistence.md) | 12 events | Tuned time range |
```

In `03_findings` frontmatter (optional):

```yaml
query_refs:
  - schtasks-persistence
```

---

## Scaffold a new query

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_hunt_query.ps1 -QueryId sysmon-rare-parent-child -Platform kql -Title "Rare parent-child process chains"
```

---

## Sanitization rules

Before commit:

- Replace real hostnames with `HOST_PLACEHOLDER` or `{{host}}`
- Replace real accounts with `USER_PLACEHOLDER` or `{{user}}`
- No employer index names, VPN endpoints, or internal domains (`.corp`, `.local`, …)
- Run `redact-check.ps1` — it scans `.md` and query extensions under this folder

---

## See also

- [`20_notes/hunt-reference.md`](../20_notes/hunt-reference.md) — methodology and event IDs
- [`20_notes/detection-catalog.md`](../20_notes/detection-catalog.md) — detections promoted from hunts or file analysis
- [`40_iocs/README.md`](../40_iocs/README.md) — confirmed IOC rows only
