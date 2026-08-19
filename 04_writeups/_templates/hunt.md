---
# Long-form threat hunt report (optional -- not validated by 03_findings schema)
writeup_version: 1
related_sample_id: SAMPLE_ID
engagement_kind: hunt

title: "<FILL -- e.g. Scheduled task persistence hunt — narrative report>"
subtitle: "<FILL -- one-liner: hypothesis summary>"

analyst: ANALYST
hypothesis: "<FILL -- one testable, falsifiable sentence: 'Adversaries established persistence via scheduled tasks in the target environment during the collection window.'>"
data_sources:
  - "<FILL -- e.g. Windows Security event log (4698, 4702)>"
  - "<FILL -- e.g. Sysmon event 1 (process creation)>"
timebox: "<FILL -- e.g. 2 hours>"
outcome: "<FILL -- true_positive | false_positive | inconclusive | no_data>"  # set when hunt closes

classification: TLP:CLEAR
distribution: "<FILL -- Internal study / Portfolio (sanitized) / Team debrief>"
detections_found: false   # set true if at least one confirmed detection is documented

date_draft: DATE
date_final: ""

abstract: |
  <FILL -- 4–6 sentences: hypothesis tested, data searched, queries run, key finding
  (true positive / negative / inconclusive), top recommendation.
  No real hostnames, user accounts, or employer infrastructure names.
  Write this last.>

keywords:
  - "<FILL -- e.g. scheduled-task, persistence, T1053.005>"
  - threat-hunt

skills_practiced:
  - "<FILL -- e.g. SPL aggregation, Sigma rule writing>"

query_refs: []   # slugs from 45_hunt_queries/ used or produced in this hunt

evidence_index:
  scope:        ../00_original/SAMPLE_ID.md
  collection:   ../01_static/SAMPLE_ID.md
  analysis:     ../02_dynamic/SAMPLE_ID.md
  outcome:      ../03_findings/SAMPLE_ID.md
  screenshots:  ../50_screenshots/
  hunt_queries: ../../45_hunt_queries/
  iocs_csv:     ../../40_iocs/indicators.csv
---

# <FILL -- hunt title>

> **Engagement:** [`SAMPLE_ID`](../03_findings/SAMPLE_ID.md) · **Outcome:** `<FILL>`

> Sanitize all queries and examples — **no production hostnames, real SAM account names, index names, or employer infrastructure data** in committed text.

---

## Table of contents

1. [Document control](#1-document-control)
2. [Scope and hypothesis](#2-scope-and-hypothesis)
3. [Data and queries](#3-data-and-queries)
4. [Analysis narrative](#4-analysis-narrative)
5. [Findings and detections](#5-findings-and-detections)
6. [False positives](#6-false-positives)
7. [Detection engineering](#7-detection-engineering)
8. [Recommendations and follow-on hunts](#8-recommendations-and-follow-on-hunts)
9. [Limitations](#9-limitations)
10. [Appendices](#10-appendices)

---

## 1. Document control

| Field | Value |
|-------|-------|
| Writeup ID | `<FILL -- e.g. HUNT-2026-001>` |
| Slot | SAMPLE_ID |
| Version | `0.1 draft` |
| Analyst | ANALYST |
| Timebox | `<FILL>` |
| Outcome | `<FILL -- true_positive / false_positive / inconclusive / no_data>` |
| Last updated | DATE |

| Version | Date | Summary |
|---------|------|---------|
| 0.1 | DATE | Initial draft |

---

## 2. Scope and hypothesis

> A well-formed hypothesis is **testable**, **falsifiable**, and states what data you expect to find if it is true.

| Field | Value |
|-------|-------|
| Hypothesis | `<FILL -- e.g. "Adversaries persisted via scheduled tasks during the collection window">` |
| Expected evidence if TRUE | `<FILL -- e.g. "Event 4698 with non-standard task names and suspicious binary paths">` |
| Expected evidence if FALSE | `<FILL -- e.g. "No 4698 events; or all tasks map to known-good binaries">` |
| In scope | `<FILL -- e.g. Windows endpoints, 30-day collection window>` |
| Out of scope | `<FILL -- e.g. Linux hosts, cloud workloads>` |
| Environment | `<lab / simulated log set / sanitized export from production>` |
| Inspired by | `<FILL -- e.g. malware IOC from sample_01, CVE-2025-XXXX, threat intel report>` |

### Success criteria

- [ ] Hypothesis confirmed or refuted with cited evidence
- [ ] At least one detection candidate documented (or explicit "none found")
- [ ] FP reasoning recorded for every candidate
- [ ] Reusable queries extracted to `45_hunt_queries/` if applicable

Canonical scope: [`00_original/SAMPLE_ID.md`](../00_original/SAMPLE_ID.md)

---

## 3. Data and queries

> Collection log: [`01_static/SAMPLE_ID.md`](../01_static/SAMPLE_ID.md).
> Reusable query library: [`45_hunt_queries/`](../../45_hunt_queries/README.md) · [`20_notes/hunt-reference.md`](../../20_notes/hunt-reference.md)

### Data sources used

| Source | Coverage window | Volume | Gaps / caveats |
|--------|-----------------|--------|----------------|
| `<FILL -- e.g. Windows Security (4698)>` | `<FILL>` | `<FILL -- approximate event count>` | `<FILL>` |

### Query log

| # | Query slug | Platform | Purpose | Result count | Verdict |
|---|-----------|----------|---------|--------------|---------|
| 1 | `<FILL>` | `<SPL / KQL / Sigma / ES>` | `<FILL>` | `<FILL>` | `<productive / dry / too noisy>` |
| 2 | `<FILL>` | `<>` | `<FILL>` | `<FILL>` | `<>` |

### Query appendix (sanitized pseudocode)

```
# Query 1 — <name>
# Platform: <KQL / SPL / Sigma>
# Replace <INDEX>, <HOST_FIELD>, <USER_FIELD> with your environment values

<FILL -- query body; no real index names, hostnames, or SAM accounts>
```

> Promote reusable queries to [`45_hunt_queries/`](../../45_hunt_queries/README.md) using `new_hunt_query.ps1`.

---

## 4. Analysis narrative

> Analysis log: [`02_dynamic/SAMPLE_ID.md`](../02_dynamic/SAMPLE_ID.md). Tell the **story** here.

### Initial sweep

`<FILL -- first query run, what baseline looked like, volume expectations vs reality>`

### Anomaly identification

`<FILL -- what stood out: rare parent-child chains, unusual command-line patterns, volume spikes, timing anomalies>`

### Pivoting

`<FILL -- how you chased the anomaly: additional queries, IOC lookups, cross-reference to other data sources>`

### Timeline (sanitized)

| Relative time | Event | Significance | Confidence |
|---------------|-------|--------------|------------|
| `<FILL>` | `<FILL>` | `<FILL>` | `<high / med / low>` |

---

## 5. Findings and detections

> Outcome summary: [`03_findings/SAMPLE_ID.md`](../03_findings/SAMPLE_ID.md).

| # | Finding | Type | Confidence | Evidence pointer |
|---|---------|------|------------|-----------------|
| 1 | `<FILL>` | `<true_positive / benign_TP / FP>` | `<high / med / low>` | `<02_dynamic section or screenshot>` |

### Hypothesis verdict

**Result:** `<Confirmed / Refuted / Inconclusive / No data>`

`<FILL -- 1 paragraph: was the hypothesis true? What evidence was decisive? What remains uncertain?>`

### Confirmed IOCs (for `40_iocs`)

> Add rows to [`40_iocs/indicators.csv`](../../40_iocs/indicators.csv) **only for confirmed hunt IOCs** in this environment.

| Type | Value (sanitized) | Confidence | Notes |
|------|-------------------|------------|-------|
| `<FILL>` | `<FILL -- no real IPs; use CIDR notation or pseudonymized value>` | `<>` | `<>` |

---

## 6. False positives

> Document every FP candidate — this is the most reusable part of the writeup for tuning future detections.

| Candidate event | Why it triggered | Why it is benign | Mitigation for alert |
|-----------------|------------------|------------------|----------------------|
| `<FILL>` | `<FILL>` | `<FILL -- e.g. matches known software update path>` | `<FILL -- e.g. exclude by publisher hash>` |

---

## 7. Detection engineering

> See [`20_notes/detection-catalog.md`](../../20_notes/detection-catalog.md) for cross-engagement detection tracking.

### Proposed detection

| Field | Value |
|-------|-------|
| Detection name | `<FILL>` |
| Logic summary | `<FILL -- what event + fields + threshold>` |
| Data required | `<FILL -- log source, minimum field set>` |
| Expected FP rate | `<FILL -- e.g. 1–2 / day on a 500-host environment>` |
| Maturity | `<idea / prototype / tunable / production-ready>` |

### Sigma sketch

```yaml
# title: <FILL>
# status: experimental
# logsource:
#   product: windows
#   service: security
# detection:
#   selection:
#     EventID: <FILL>
#     <field>: '<FILL>'
#   condition: selection
# falsepositives:
#   - <FILL>
# level: medium
```

> Promote finalized rules to [`45_hunt_queries/`](../../45_hunt_queries/README.md).

### MITRE ATT&CK mapping

| ID | Name | How observed | Confidence |
|----|------|--------------|------------|
| `<FILL>` | `<FILL>` | `<FILL>` | `<high / med / low>` |

---

## 8. Recommendations and follow-on hunts

### Immediate recommendations

1. `<FILL -- e.g. deploy alert candidate from §7 after 1-week FP baseline>`
2. `<FILL>`

### Follow-on hunt hypotheses

| New hypothesis | Data needed | Priority |
|----------------|-------------|----------|
| `<FILL -- e.g. "Same actor also used WMI subscriptions">` | `<FILL>` | high / med / low |

---

## 9. Limitations

| Limitation | Impact on findings | Mitigation for next hunt |
|------------|-------------------|--------------------------|
| `<FILL -- e.g. only 30 days of logs available>` | `<FILL>` | `<FILL>` |

---

## 10. Appendices

### Appendix A — Event ID reference

| Event ID | Source | Meaning | Used in this hunt |
|----------|--------|---------|-------------------|
| `<FILL>` | `<FILL>` | `<FILL>` | yes / no |

### Appendix B — Screenshot / export manifest

| File | Description |
|------|-------------|
| `<FILL>` | `<one-line description>` |

_(Full index: [`50_screenshots/SHOT_INDEX.txt`](../50_screenshots/SHOT_INDEX.txt))_

### Appendix C — References

| Resource | URL |
|----------|-----|
| ATT&CK technique page | `<FILL>` |
| Threat intel report | `<FILL>` |
| Tool documentation | `<FILL>` |

---

## Final checklist before commit

- [ ] No real hostnames, SAM account names, index names, or employer infrastructure data
- [ ] All query blocks use placeholder values (`<INDEX>`, `<HOST_FIELD>`, `<TARGET_IP>`)
- [ ] `40_iocs/indicators.csv` updated only for **confirmed** indicators — not FP candidates
- [ ] Reusable queries promoted to `45_hunt_queries/` and slugs added to `query_refs` in frontmatter
- [ ] Hypothesis verdict in §5 matches `outcome` frontmatter field
- [ ] `03_findings/SAMPLE_ID.md` outcome matches this narrative
- [ ] `20_notes/detection-catalog.md` updated if a new detection was proposed
- [ ] `redact-check.ps1` passed with no errors
