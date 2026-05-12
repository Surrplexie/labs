# sample_09 -- dynamic triage (PE)

| Field | Value |
|-------|-------|
| **SHA256** | <!-- from 00_original --> |
| **Date analyzed** | 2026-05-12 |
| **VM type** | Windows 11 lab VM (user win11) |
| **AV / real-time protection** | Off |
| **Snapshot name** | <!-- e.g. clean_2026-05-12 --> |
| **Instrumentation** | <!-- Procmon / ProcExp / TCPView / Wireshark --> |

Cross-references: [findings](../03_findings/sample_09.md) | [static](../01_static/sample_09.md) | [acquisition](../00_original/sample_09.md) | [screenshots](../50_screenshots/sample_09/)

---

## Pre-flight

- [ ] Clean snapshot restored.
- [ ] Procmon started (filter by process name).
- [ ] Process Explorer open.
- [ ] TCPView open.
- [ ] AV confirmed off.

## Execution

- **How launched:** <!-- double-click / cmd / PowerShell -->
- **On-disk name:** <!-- path on VM -->
- **User context:** <!-- standard / elevated -->
- **Immediate UX:** <!-- what appeared on screen -->

## Process tree

| PID | Parent PID | Name | Command line / notes |
|-----|-----------|------|---------------------|
| | | | |

## File system (Procmon WriteFile / CreateFile)

| Path | Operation | Notes |
|------|-----------|-------|
| | | |

## Registry (Procmon RegSetValue)

| Key | Value name | Data | Notes |
|-----|-----------|------|-------|
| | | | |

## Network (TCPView / Wireshark)

| Proto | Remote host | Port | Notes |
|-------|------------|------|-------|
| | | | |

## Post-run observations

- Services: <!-- any new? -->
- Scheduled tasks: <!-- any new? -->
- Injected modules: <!-- any? -->
- VM snapshot reverted: [ ]

## Dynamic summary (portfolio-ready)

<!-- What the sample did: drops, persistence, network, deception. -->
