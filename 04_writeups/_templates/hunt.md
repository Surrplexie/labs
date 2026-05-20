---
# Long-form threat hunt report (optional -- not validated by 03_findings schema)
writeup_version: 1
related_sample_id: SAMPLE_ID
engagement_kind: hunt

title: "<FILL -- e.g. Scheduled task persistence hunt -- narrative report>"
subtitle: "<FILL>"

analyst: ANALYST
hypothesis: "<FILL -- one testable sentence>"
data_sources:
  - "<FILL -- e.g. Windows Security 4698>"
timebox: "<FILL -- e.g. 2 hours>"

classification: TLP:CLEAR
distribution: "<FILL>"
detections_found: false

date_draft: DATE
date_final: ""

abstract: |
  <FILL -- hypothesis, data searched, outcome, top recommendation. No real hostnames or accounts.>

keywords:
  - "<FILL>"
  - threat-hunt
skills_practiced:
  - "<FILL>"

query_refs: []  # optional: slugs from 45_hunt_queries/ used in this hunt

evidence_index:
  scope: ../00_original/SAMPLE_ID.md
  collection: ../01_static/SAMPLE_ID.md
  analysis: ../02_dynamic/SAMPLE_ID.md
  outcome: ../03_findings/SAMPLE_ID.md
  screenshots: ../50_screenshots/SAMPLE_ID/
  hunt_queries: ../45_hunt_queries/
  iocs_csv: ../40_iocs/indicators.csv
---

# <FILL -- hunt title>

> **Related engagement:** [`SAMPLE_ID`](../03_findings/SAMPLE_ID.md) · **Hypothesis:** see frontmatter

Sanitize all queries and examples -- no production hostnames, real user SAM names, or employer data.

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
|--------|--------|
| Writeup ID | `<FILL -- e.g. HUNT-2026-001>` |
| Slot | SAMPLE_ID |
| Analyst | ANALYST |
| Timebox | `<FILL>` |
| Last updated | DATE |

---

## 2. Scope and hypothesis

| Field | Value |
|--------|--------|
| Hypothesis | `<FILL>` |
| In scope | `<FILL>` |
| Out of scope | `<FILL>` |
| Environment | `<lab / simulated / sanitized export>` |

Canonical scope: [`00_original/SAMPLE_ID.md`](../00_original/SAMPLE_ID.md)

### Success criteria

- [ ] Hypothesis confirmed or refuted with cited evidence
- [ ] At least one detection candidate documented (or explicit "none")
- [ ] FP reasoning recorded

---

## 3. Data and queries

> Collection log: [`01_static/SAMPLE_ID.md`](../01_static/SAMPLE_ID.md)

### Data sources

| Source | Coverage window | Notes |
|--------|-----------------|-------|
| `<FILL>` | `<FILL>` | `<FILL>` |

### Query log (sanitized)

| # | Query name | Purpose | Result count | Notes |
|---|------------|---------|--------------|-------|
| 1 | `<FILL>` | `<FILL>` | `<FILL>` | `<FILL>` |

### Query appendix (pseudocode / Sigma sketch)

```
<FILL -- KQL / Splunk / Sigma; use placeholders for index and host>
```

See [`20_notes/hunt-reference.md`](../../20_notes/hunt-reference.md) and reusable queries in [`45_hunt_queries/`](../../45_hunt_queries/README.md).

---

## 4. Analysis narrative

> Analysis log: [`02_dynamic/SAMPLE_ID.md`](../02_dynamic/SAMPLE_ID.md)

### Timeline (sanitized)

| Time | Event | Significance |
|------|-------|--------------|
| `<FILL>` | `<FILL>` | `<FILL>` |

### Pattern summary

`<FILL -- parent-child chains, rare commands, volume anomalies>`

---

## 5. Findings and detections

| # | Finding | Confidence | Evidence pointer |
|---|---------|------------|------------------|
| 1 | `<FILL>` | high / medium / low | `<01_static or 02_dynamic section>` |

### Confirmed IOCs (for `40_iocs`)

> Add rows to [`40_iocs/indicators.csv`](../../40_iocs/indicators.csv) only for **confirmed** hunt IOCs.

| Type | Value (sanitized) | Notes |
|------|-------------------|-------|
| `<FILL>` | `<FILL>` | `<FILL>` |

Outcome summary: [`03_findings/SAMPLE_ID.md`](../03_findings/SAMPLE_ID.md)

---

## 6. False positives

| Candidate | Why ruled out |
|-----------|---------------|
| `<FILL>` | `<FILL>` |

---

## 7. Detection engineering

### Proposed detection

| Field | Value |
|--------|--------|
| Name | `<FILL>` |
| Logic | `<FILL>` |
| Data required | `<FILL>` |
| Expected FP rate | `<FILL>` |

### Tuning notes

`<FILL>`

### MITRE mapping (if applicable)

| ID | Justification |
|----|---------------|
| `<FILL>` | `<FILL>` |

---

## 8. Recommendations and follow-on hunts

1. `<FILL -- e.g. deploy alert, widen time range, new hypothesis>`
2. `<FILL>`

---

## 9. Limitations

| Limitation | Impact |
|------------|--------|
| `<FILL>` | `<FILL>` |

---

## 10. Appendices

### Appendix A -- Event ID reference

| ID | Meaning | Used? |
|----|---------|-------|
| `<FILL>` | `<FILL>` | yes / no |

### Appendix B -- Screenshot / export manifest

| File | Description |
|------|-------------|
| `<FILL>` | `<FILL>` |

---

## Final checklist before commit

- [ ] No real hostnames, user accounts, or employer infrastructure
- [ ] IOC CSV updated only for confirmed indicators
- [ ] `03_findings` outcome matches this narrative
- [ ] `redact-check.ps1` passed
