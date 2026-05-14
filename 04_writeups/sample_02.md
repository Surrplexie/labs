---
# Writeup document metadata (optional YAML -- not validated by 03_findings schema)
writeup_version: 1
related_sample_id: sample_02
engagement_kind: file
# ctf | lab | hunt -- adjust sections if not file-kind

title: "<FILL -- e.g. Long-form analysis: <name_tag> (SHA256 …)>"
subtitle: "<FILL -- optional one-line hook>"

analyst: "<FILL>"
reviewers: [] # optional list

classification: TLP:CLEAR # TLP:CLEAR | TLP:GREEN | TLP:AMBER | TLP:RED -- pick what you are willing to share
distribution: "<FILL -- e.g. Public portfolio / hiring packet / internal notes>"

date_draft: "YYYY-MM-DD"
date_final: "" # set when you freeze the narrative

vm_profile: "<FILL -- e.g. Win11 x64, Defender state, snapshot name>"
tooling_snapshot: "<FILL -- DIE / PEStudio / CFF / HxD / Procmon / Wireshark versions + build dates>"

abstract: |
  <FILL -- 3–6 sentences: what the object is, what you did, strongest conclusion,
  explicit scope limits (e.g. no memory forensics).>

keywords:
  - "<FILL>"
  - "<FILL>"

evidence_index:
  acquisition: ../00_original/sample_02.md
  static: ../01_static/sample_02.md
  dynamic: ../02_dynamic/sample_02.md
  findings: ../03_findings/sample_02.md
  screenshots: ../50_screenshots/sample_02/
  iocs_csv: ../40_iocs/indicators.csv
---

<!-- Same slot ID as other phase folders: replace <FILL> throughout when you author the long-form report. -->

# <FILL -- same as title>

> **Related engagement:** [`sample_02`](../03_findings/sample_02.md) · **Kind:** `<FILL>` · **Classification:** `<FILL>`

---

## Table of contents

1. [Document control](#1-document-control)
2. [Executive summary](#2-executive-summary)
3. [Scope, assumptions, and non-goals](#3-scope-assumptions-and-non-goals)
4. [Provenance and chain of custody (public)](#4-provenance-and-chain-of-custody-public)
5. [Executive technical snapshot](#5-executive-technical-snapshot)
6. [Static analysis (expanded)](#6-static-analysis-expanded)
7. [Dynamic analysis (expanded)](#7-dynamic-analysis-expanded)
8. [Behavior timeline](#8-behavior-timeline)
9. [Network analysis](#9-network-analysis)
10. [Host-based indicators and artifacts](#10-host-based-indicators-and-artifacts)
11. [MITRE ATT&CK mapping (narrative)](#11-mitre-attck-mapping-narrative)
12. [Detection engineering](#12-detection-engineering)
13. [Threat intelligence context](#13-threat-intelligence-context)
14. [Recommendations](#14-recommendations)
15. [Limitations, gaps, and follow-on work](#15-limitations-gaps-and-follow-on-work)
16. [Ethics, safety, and legal notes](#16-ethics-safety-and-legal-notes)
17. [References and prior art](#17-references-and-prior-art)
18. [Appendices](#18-appendices)

---

## 1. Document control

| Field | Value |
|--------|--------|
| Writeup ID | `<FILL -- e.g. W-2026-001>` |
| Version | `0.1` draft / `1.0` final |
| Analyst | `<FILL>` |
| Review status | `<FILL -- self-reviewed / peer-reviewed>` |
| Last updated | `<FILL YYYY-MM-DD>` |
| Canonical hash (sample) | `<FILL SHA256>` |

**Revision log**

| Version | Date | Author | Summary of change |
|---------|------|--------|---------------------|
| 0.1 | YYYY-MM-DD | `<FILL>` | Initial draft |
| | | | |

---

## 2. Executive summary

**Audience:** `<FILL -- e.g. hiring manager / IR lead / future you>`

`<FILL -- 1 tight paragraph: verdict class, why it matters, what evidence tier supports it (static only / static + partial dynamic / full instrumentation).>`

**Bottom line up front (BLUF):**

- **Verdict:** `<benign | suspicious | malicious | unknown>` — `<one sentence why>`.
- **Primary risk:** `<FILL>`
- **Primary evidence:** `<FILL -- cite phase files or screenshot IDs>`
- **Confidence:** `<high | medium-high | medium | low>` — `<one sentence uncertainty>`

---

## 3. Scope, assumptions, and non-goals

### In scope

- [ ] `<FILL>`
- [ ] `<FILL>`

### Out of scope (explicit non-goals)

- [ ] `<FILL -- e.g. full reverse engineering / unpacking inner payload>`
- [ ] `<FILL>`

### Assumptions

| # | Assumption | Risk if wrong |
|---|------------|----------------|
| A1 | `<FILL>` | `<FILL>` |
| A2 | `<FILL>` | `<FILL>` |

### Environment fidelity

| Control | Documented? |
|---------|----------------|
| VM snapshot baseline | `<yes / no -- FILL>` |
| Time sync (VM clock) | `<FILL>` |
| Network posture (isolated / NAT / blocked) | `<FILL>` |
| AV / EDR state during run | `<FILL>` |

---

## 4. Provenance and chain of custody (public)

> Describe only **public** acquisition paths. No host machine paths. VM paths are acceptable if policy allows (see `WORKFLOW.md`).

| Stage | Detail |
|--------|--------|
| Public source | `<FILL -- e.g. MalwareBazaar URL>` |
| First seen (source) | `<FILL>` |
| How you selected the object | `<FILL>` |
| Download method | `<FILL -- VM browser / API>` |
| Hash verification | `<FILL -- algorithm, match yes/no>` |
| Naming on disk in VM | `<FILL -- e.g. SHA256-as-folder pattern>` |

**Source excerpt (paraphrase, no paste of private feeds):**

`<FILL>`

---

## 5. Executive technical snapshot

| Attribute | Value |
|-----------|--------|
| Object type | `<FILL -- PE32 / script / archive / …>` |
| Claimed name | `<FILL>` |
| Size (bytes) | `<FILL>` |
| Compiler / packer / installer (summary) | `<FILL>` |
| Entry behavior (one line) | `<FILL>` |
| Persistence observed | `<yes / no / unknown>` |
| Network C2 observed | `<yes / no / unknown>` |

**High-signal static facts**

`<FILL -- bullet list: entropy, section anomalies, manifest, suspicious imports, overlay>`

**High-signal dynamic facts**

`<FILL -- bullet list: children, paths, registry, sockets -- or state "not instrumented">`

---

## 6. Static analysis (expanded)

> For tool-by-tool notes, the phase log is canonical: [`01_static/sample_02.md`](../01_static/sample_02.md). Here, **synthesize** and add interpretation that did not fit the triage template.

### 6.1 Object identity and format

`<FILL -- magic, format, container vs payload, nested objects>`

### 6.2 Compilation and packaging story

| Question | Answer |
|----------|--------|
| What toolchain signals exist? | `<FILL>` |
| Installer vs raw PE? | `<FILL>` |
| Overlay / appended data? | `<FILL offset/size/interpretation>` |
| Entropy interpretation | `<FILL>` |

### 6.3 Imports, capabilities, and API surface

`<FILL -- cluster imports into themes: execution, injection, persistence, credential access, network, anti-analysis>`

### 6.4 Strings, configuration, and weak signals

| Category | Examples found | Confidence |
|----------|----------------|------------|
| URLs / domains | `<FILL>` | `<>` |
| File paths | `<FILL>` | `<>` |
| Registry keys (static) | `<FILL>` | `<>` |
| Mutex / named objects | `<FILL>` | `<>` |
| Error / decoy UI text | `<FILL>` | `<>` |

### 6.5 Cryptography and encoding

`<FILL -- AES/RC4/XOR/Base64 blobs, crypto APIs, cert pinning hints, or "none observed">`

### 6.6 Anti-analysis and evasion (static indicators only)

`<FILL -- VM checks, timing, opaque predicates, section names, TLS callbacks mention if seen>`

### 6.7 Static-only conclusion (before execution)

`<FILL -- 1 short paragraph bridging to dynamic or explaining why you stopped at static>`

---

## 7. Dynamic analysis (expanded)

> Canonical run log: [`02_dynamic/sample_02.md`](../02_dynamic/sample_02.md)

### 7.1 Run card (reproducibility)

| Field | Value |
|--------|--------|
| Execution count | `<FILL>` |
| Launch vector | `<double-click / cmdline / injected / user-assisted>` |
| Integrity level | `<standard user / elevated>` |
| Instrumentation | `<Procmon / ProcExp / TCPView / Wireshark / debugger / none>` |
| Capture window | `<FILL duration>` |
| Snapshot revert | `<yes / no>` |

### 7.2 Process lifecycle

`<FILL -- narrative or table: parent → child, PIDs if captured, exit codes>`

### 7.3 File system effects

`<FILL -- drops, staging, self-copy, extension patterns; cite Procmon evidence IDs or CSV filter>`

### 7.4 Registry effects

`<FILL -- Run keys, IFEO, services, COM hijacks, file associations>`

### 7.5 Persistence assessment

| Mechanism | Observed? | Evidence pointer |
|-----------|-----------|------------------|
| Run / RunOnce | `<>` | `<>` |
| Scheduled task | `<>` | `<>` |
| Service | `<>` | `<>` |
| WMI subscription | `<>` | `<>` |
| Startup folder | `<>` | `<>` |
| Other | `<>` | `<>` |

### 7.6 User-visible behavior

`<FILL -- dialogs, fake errors, installer UX, decoys; link screenshot filenames>`

### 7.7 Dynamic-only conclusion

`<FILL>`

---

## 8. Behavior timeline

> Build a **linear story**. Each row should be defensible from an evidence artifact.

| UTC / local | Phase | Event | Evidence |
|-------------|-------|-------|----------|
| T+0s | Pre-run | `<FILL>` | `<>` |
| T+… | Execution | `<FILL>` | `<>` |
| T+… | Post-run | `<FILL>` | `<>` |

---

## 9. Network analysis

### 9.1 Observed traffic

| Time | Protocol | Local | Remote | Process | Notes |
|------|----------|-------|--------|---------|-------|
| `<>` | `<>` | `<>` | `<>` | `<>` | `<>` |

### 9.2 DNS

`<FILL or "not captured">`

### 9.3 TLS / JA3 / fingerprints

`<FILL or "not analyzed">`

### 9.4 Delivery vs runtime network

| Class | Indicator | Observed in lab? | Source |
|-------|-----------|------------------|--------|
| Delivery URL | `<>` | `<>` | `<Bazaar / other>` |
| Runtime C2 | `<>` | `<>` | `<dynamic / unknown>` |

---

## 10. Host-based indicators and artifacts

### 10.1 Consolidated IOC table (writeup-local)

> Keep [`40_iocs/indicators.csv`](../40_iocs/indicators.csv) authoritative for automation. This table may add **context** columns.

| Type | Value | First seen | Observed? | Notes |
|------|-------|------------|-----------|-------|
| sha256 | `<>` | `<>` | `<>` | `<>` |
| … | … | … | … | … |

### 10.2 Forensic artifact paths (VM-safe)

`<FILL -- only VM profile paths you are willing to publish>`

### 10.3 File system YARA / hunt ideas

`<FILL>`

---

## 11. MITRE ATT&CK mapping (narrative)

> [`03_findings`](../03_findings/sample_02.md) lists IDs; here, **justify** each mapping with technique → observation → confidence.

### 11.1 Tactic overview

| Tactic | Techniques cited | Why this tactic applies |
|--------|--------------------|-------------------------|
| `<FILL>` | `<>` | `<>` |

### 11.2 Technique deep rows

| ID | Name | Observation | Data source | Confidence |
|----|------|-------------|-------------|------------|
| Txxxx | `<>` | `<>` | `<static / dynamic / intel>` | `<>` |

### 11.3 Detections already mapped in `03_findings` but worth elaborating

`<FILL>`

---

## 12. Detection engineering

### 12.1 Sigma / Elastic / Splunk ideas

`<FILL -- pseudocode or rule sketch; avoid vendor-specific secrets>`

### 12.2 YARA / file hunting

`<FILL>`

### 12.3 Behavioral hunts (process / command-line)

`<FILL>`

### 12.4 Network detection

`<FILL>`

### 12.5 False positive analysis

| Detection idea | Expected FP | Mitigation |
|----------------|--------------|------------|
| `<>` | `<>` | `<>` |

---

## 13. Threat intelligence context

`<FILL -- cluster names, public reporting links, caveats about attribution; or "none sought">`

---

## 14. Recommendations

### For defenders

1. `<FILL>`
2. `<FILL>`

### For analysts continuing this engagement

1. `<FILL>`
2. `<FILL>`

### For your own lab hygiene

1. `<FILL>`
2. `<FILL>`

---

## 15. Limitations, gaps, and follow-on work

| Gap | Impact | Suggested next step | Cost / risk |
|-----|--------|---------------------|-------------|
| `<>` | `<>` | `<>` | `<>` |

**What would change the verdict**

`<FILL>`

---

## 16. Ethics, safety, and legal notes

`<FILL -- authorized environment only, no operational use of IOCs against third parties without authorization, regional considerations>`

---

## 17. References and prior art

| Type | Citation |
|------|----------|
| MalwareBazaar | `<URL>` |
| Vendor / blog | `<URL>` |
| ATT&CK | `<URL>` |
| Tool docs | `<URL>` |

---

## 18. Appendices

### Appendix A -- Hash bundle

| Algorithm | Hash |
|-----------|------|
| SHA256 | `<>` |
| SHA1 | `<>` |
| MD5 | `<>` |
| imphash | `<>` |
| ssdeep | `<>` |
| TLSH | `<>` |

### Appendix B -- Section / PE layout notes

`<FILL optional>`

### Appendix C -- Tool command log

```text
<FILL -- exact commands you ran; scrub secrets>
```

### Appendix D -- Screenshot manifest

| File | Description |
|------|-------------|
| `IMG_0001.png` | `<>` |
| … | … |

_(See also [`SHOT_INDEX.txt`](../50_screenshots/sample_02/SHOT_INDEX.txt).)_

### Appendix E -- Glossary

| Term | Definition |
|------|------------|
| `<>` | `<>` |

---

## Final checklist before commit

- [ ] Redaction: no analyst host paths, secrets, or internal-only hostnames
- [ ] EXIF stripped on any new images
- [ ] IOC CSV updated if this writeup introduces **new** indicators not already in `40_iocs`
- [ ] `03_findings` still accurate relative to this writeup (no contradictions)
- [ ] Classification / distribution statement matches what you are publishing
