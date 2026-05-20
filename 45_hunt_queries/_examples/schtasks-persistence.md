---
query_id: schtasks-persistence-example
title: "Scheduled task creation (example -- copy and customize)"
platform: sigma
data_sources:
  - "Windows Security 4698"
  - "Sysmon EventID 1"
mitre_techniques:
  - T1053.005
tags:
  - persistence
  - scheduled-task
related_samples: []
status: draft
---

# Scheduled task creation (example)

> Template only. Copy to `45_hunt_queries/schtasks-persistence.md` and sanitize.

## Sigma (placeholder)

```yaml
title: Scheduled Task Created via schtasks
status: experimental
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 1
    Image|endswith: '\schtasks.exe'
    CommandLine|contains: '/create'
  condition: selection
falsepositives:
  - Legitimate software installers
level: medium
```

## Notes

- Tune `CommandLine` filters for your environment.
- Pair with [`20_notes/hunt-reference.md`](../../20_notes/hunt-reference.md) event ID table.
