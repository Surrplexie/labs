# 20_notes

General research, workflow, and synthesis notes for the labs malware triage logbook.
Everything here is hand-maintained -- no auto-generation.

---

## Contents

| File / Folder | Purpose |
|---|---|
| [MITRE-coverage.md](MITRE-coverage.md) | ATT&CK technique coverage tracker -- maps techniques to samples with evidence quality notes |
| [tooling-reference.md](tooling-reference.md) | Quick-reference for DIE, PEStudio, CFF Explorer, HxD, Procmon, ProcExp, TCPView, Wireshark |
| [case-series/](case-series/) | Cross-sample theme notes grouped by packaging type, delivery, or behavioral family |

---

## How to navigate

- Looking for **which samples use a specific technique?**
  See [MITRE-coverage.md](MITRE-coverage.md) or the auto-generated
  `Cross-Reference: By MITRE ATT&CK Technique` section in [INDEX.md](../INDEX.md).

- Looking for **what tool signal means what?**
  See [tooling-reference.md](tooling-reference.md).

- Looking for **patterns across NSIS samples, fake-alert samples, etc.?**
  See [case-series/](case-series/).

- Looking for **a specific sample's findings?**
  See [INDEX.md](../INDEX.md) or go directly to `03_findings/sample_XX.md`.
