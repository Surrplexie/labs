---
# Long-form malware / artifact analysis report (optional -- not validated by 03_findings schema)
writeup_version: 1
related_sample_id: SAMPLE_ID
engagement_kind: file

title: "<FILL -- e.g. Long-form analysis: <name_tag> (SHA256 …)>"
subtitle: "<FILL -- optional one-line hook>"

analyst: ANALYST
reviewers: []

classification: TLP:CLEAR  # TLP:CLEAR | TLP:GREEN | TLP:AMBER | TLP:RED
distribution: "<FILL -- e.g. Public portfolio / hiring packet / internal notes>"

date_draft: DATE
date_final: ""  # set when you freeze the narrative

vm_profile: "<FILL -- e.g. Win11 x64, Defender off, snapshot name>"
tooling_snapshot: "<FILL -- DIE / PEStudio / CFF / Procmon / Wireshark versions>"

abstract: |
  <FILL -- 3–5 sentences: what the object is, what you did, strongest conclusion,
  explicit scope limits (e.g. no memory forensics).>

keywords:
  - "<FILL>"
  - malware-analysis

evidence_index:
  acquisition: ../00_original/SAMPLE_ID.md
  static:      ../01_static/SAMPLE_ID.md
  dynamic:     ../02_dynamic/SAMPLE_ID.md
  findings:    ../03_findings/SAMPLE_ID.md
  screenshots: ../50_screenshots/SAMPLE_ID/
  iocs_csv:    ../40_iocs/indicators.csv
---

# <FILL -- same as title>

> **Related engagement:** [`SAMPLE_ID`](../03_findings/SAMPLE_ID.md) · **Kind:** `file` · **Classification:** `<FILL>`

---

## Table of contents

1. [Document control](#1-document-control)
2. [Executive summary](#2-executive-summary)
3. [Scope and assumptions](#3-scope-and-assumptions)
4. [Static analysis highlights](#4-static-analysis-highlights)
5. [Dynamic analysis highlights](#5-dynamic-analysis-highlights)
6. [Behavior timeline](#6-behavior-timeline)
7. [Network analysis](#7-network-analysis)
8. [MITRE ATT&CK mapping](#8-mitre-attck-mapping)
9. [Detection engineering](#9-detection-engineering)
10. [Recommendations](#10-recommendations)
11. [Limitations and follow-on work](#11-limitations-and-follow-on-work)
12. [Appendices](#12-appendices)

---

## 1. Document control

| Field | Value |
|-------|-------|
| Writeup ID | `<FILL -- e.g. W-2026-001>` |
| Slot | SAMPLE_ID |
| Version | `0.1` draft / `1.0` final |
| Analyst | ANALYST |
| Last updated | DATE |

| Version | Date | Summary |
|---------|------|---------|
| 0.1 | DATE | Initial draft |

---

## 2. Executive summary

**Audience:** `<FILL -- e.g. hiring manager / IR lead / future you>`

`<FILL -- 1 tight paragraph: verdict class, why it matters, what evidence tier supports it.>`

**BLUF:**

- **Verdict:** `<benign | suspicious | malicious | unknown>` — `<one sentence why>`
- **Primary risk:** `<FILL>`
- **Primary evidence:** `<FILL -- cite phase files or screenshot IDs>`
- **Confidence:** `<high | medium | low>` — `<one sentence uncertainty>`

**Quick reference**

| Attribute | Value |
|-----------|-------|
| Object type | `<FILL -- PE32 / script / archive / …>` |
| Claimed name | `<FILL>` |
| Size (bytes) | `<FILL>` |
| Compiler / packer | `<FILL>` |
| Persistence observed | `<yes / no / unknown>` |
| Network C2 observed | `<yes / no / unknown>` |

---

## 3. Scope and assumptions

### In scope
- [ ] `<FILL>`
- [ ] `<FILL>`

### Out of scope
- [ ] `<FILL -- e.g. full unpacking / memory forensics>`

### Environment fidelity

| Control | Documented? |
|---------|-------------|
| VM snapshot baseline | `<yes / no>` |
| Network posture | `<isolated / NAT / blocked>` |
| AV / EDR state during run | `<FILL>` |

---

## 4. Static analysis highlights

> Full tool-by-tool log: [`01_static/SAMPLE_ID.md`](../01_static/SAMPLE_ID.md). Synthesize here; do not paste every DIE/PEStudio line.

### Format and packaging

`<FILL -- magic, format, nested containers, overlay, entropy interpretation>`

### Imports and capabilities

`<FILL -- cluster by theme: execution, injection, persistence, credential access, network, anti-analysis>`

### Strings and configuration

| Category | Examples | Confidence |
|----------|----------|------------|
| URLs / domains | `<FILL>` | `<>` |
| File paths | `<FILL>` | `<>` |
| Registry keys | `<FILL>` | `<>` |
| Mutex / named objects | `<FILL>` | `<>` |

### Evasion indicators (static only)

`<FILL -- VM checks, timing, opaque predicates, TLS callbacks; or "none observed">`

### Static-only conclusion

`<FILL -- bridge to dynamic, or explain why you stopped at static>`

---

## 5. Dynamic analysis highlights

> Canonical run log: [`02_dynamic/SAMPLE_ID.md`](../02_dynamic/SAMPLE_ID.md).

### Run card

| Field | Value |
|-------|-------|
| Launch vector | `<double-click / cmdline / injected>` |
| Integrity level | `<standard / elevated>` |
| Instrumentation | `<Procmon / TCPView / Wireshark / debugger / none>` |

### Key effects (file system, registry, process)

`<FILL -- children, drops, Run keys, services; cite Procmon evidence IDs>`

### Persistence mechanisms observed

| Mechanism | Observed? | Evidence |
|-----------|-----------|----------|
| Run / RunOnce | `< >` | `<>` |
| Scheduled task | `< >` | `<>` |
| Service | `< >` | `<>` |
| Other | `< >` | `<>` |

### Dynamic-only conclusion

`<FILL>`

---

## 6. Behavior timeline

> Each row should map to a defensible artifact.

| Offset | Phase | Event | Evidence |
|--------|-------|-------|----------|
| T+0s | Pre-run | `<FILL>` | `<>` |
| T+… | Execution | `<FILL>` | `<>` |
| T+… | Post-run | `<FILL>` | `<>` |

---

## 7. Network analysis

### Observed traffic

| Time | Protocol | Remote | Process | Notes |
|------|----------|--------|---------|-------|
| `<>` | `<>` | `<>` | `<>` | `<>` |

### DNS and TLS

`<FILL or "not captured">`

### Delivery vs runtime

| Class | Indicator | Observed in lab? |
|-------|-----------|------------------|
| Delivery URL | `<>` | `<>` |
| Runtime C2 | `<>` | `<>` |

---

## 8. MITRE ATT&CK mapping

> [`03_findings`](../03_findings/SAMPLE_ID.md) lists IDs. Here, **justify** each mapping.

| ID | Name | Observation | Data source | Confidence |
|----|------|-------------|-------------|------------|
| Txxxx | `<>` | `<>` | `<static / dynamic>` | `<>` |

### Tactic summary

| Tactic | Techniques | Why applicable |
|--------|------------|----------------|
| `<FILL>` | `<>` | `<>` |

---

## 9. Detection engineering

### Rule ideas (Sigma / KQL / Splunk sketch)

```
<FILL -- pseudocode; avoid vendor-specific secrets>
```

### YARA / file hunting

`<FILL>`

### Behavioral process / command-line hunts

`<FILL>`

### False positive analysis

| Detection idea | Expected FP | Mitigation |
|----------------|-------------|------------|
| `<>` | `<>` | `<>` |

### Threat intelligence context

`<FILL -- public cluster names, blog links, attribution caveats; or "none sought">`

---

## 10. Recommendations

### For defenders

1. `<FILL>`
2. `<FILL>`

### For analysts continuing this engagement

1. `<FILL>`
2. `<FILL>`

---

## 11. Limitations and follow-on work

| Gap | Impact | Suggested next step |
|-----|--------|---------------------|
| `<>` | `<>` | `<>` |

**What would change the verdict**

`<FILL>`

---

## 12. Appendices

### Appendix A — Hash bundle

| Algorithm | Hash |
|-----------|------|
| SHA256 | `<>` |
| SHA1 | `<>` |
| MD5 | `<>` |
| imphash | `<>` |
| ssdeep | `<>` |

### Appendix B — Provenance

| Stage | Detail |
|-------|--------|
| Public source | `<FILL -- e.g. MalwareBazaar URL>` |
| Download method | `<FILL -- VM browser / API>` |
| Hash verification | `<FILL -- algorithm, match yes/no>` |

### Appendix C — Tool command log

```text
<FILL -- exact commands you ran; scrub secrets>
```

### Appendix D — Screenshot manifest

| File | Description |
|------|-------------|
| `<FILL>` | `<>` |

_(See also [`SHOT_INDEX.txt`](../50_screenshots/SAMPLE_ID/SHOT_INDEX.txt).)_

### Appendix E — References

| Type | Citation |
|------|----------|
| MalwareBazaar | `<URL>` |
| Vendor / blog | `<URL>` |
| ATT&CK | `<URL>` |

---

## Final checklist before commit

- [ ] No analyst host paths, internal-only hostnames, or secrets
- [ ] EXIF stripped on any new screenshots
- [ ] IOC CSV (`40_iocs/indicators.csv`) updated for any new confirmed indicators
- [ ] `03_findings/SAMPLE_ID.md` still accurate relative to this writeup
- [ ] Classification / distribution matches what you are publishing
- [ ] `redact-check.ps1` passed
