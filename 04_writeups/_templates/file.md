---
# Long-form malware / artifact analysis report (optional -- not validated by 03_findings schema)
writeup_version: 1
related_sample_id: SAMPLE_ID
engagement_kind: file

title: "<FILL -- e.g. Long-form analysis: AgentTesla dropper (SHA256 abc…)>"
subtitle: "<FILL -- one-line hook: what is unusual or interesting about this sample>"

analyst: ANALYST
reviewers: []   # add peer names if reviewed before publishing

classification: TLP:CLEAR  # TLP:CLEAR | TLP:GREEN | TLP:AMBER | TLP:RED
distribution: "<FILL -- Public portfolio / Hiring packet / Internal notes only>"

date_draft: DATE
date_final: ""   # set when you finalize; triggers v1.0 in revision log

vm_profile: "<FILL -- OS, arch, AV state, snapshot name, e.g. Win11 22H2 x64, Defender off, snap-clean>"
tooling_snapshot: "<FILL -- tool names + versions used, e.g. DIE 3.09 / PEStudio 9.40 / Procmon 3.98>"

abstract: |
  <FILL -- 4–6 sentences covering: (1) what the object is and claimed identity,
  (2) what analysis phases you completed, (3) strongest verdict and key evidence,
  (4) explicit scope limits, e.g. "no memory forensics performed", "static only".
  Write this last.>

keywords:
  - "<FILL -- malware family name if known>"
  - "<FILL -- e.g. dropper, stealer, ransomware, loader>"
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

> **Engagement:** [`SAMPLE_ID`](../03_findings/SAMPLE_ID.md) · **Classification:** `<FILL>` · **Distribution:** `<FILL>`

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
| Writeup ID | `<FILL -- e.g. W-2026-001; use ENGAGEMENTS.md numbering>` |
| Slot | SAMPLE_ID |
| Version | `0.1 draft` |
| Analyst | ANALYST |
| Last updated | DATE |

| Version | Date | Summary |
|---------|------|---------|
| 0.1 | DATE | Initial draft |

---

## 2. Executive summary

> **Audience:** `<FILL -- e.g. hiring manager / IR team lead / future you reviewing portfolio>`

`<FILL -- 2–3 sentences: verdict, why it matters, what evidence tier supports it (static only / static + partial dynamic / fully instrumented run).>`

**BLUF:**

- **Verdict:** `<benign | suspicious | malicious | unknown>` — `<one sentence justification>`
- **Primary risk:** `<FILL -- e.g. credential theft via keylogger + SMTP exfil>`
- **Strongest evidence:** `<FILL -- cite exact phase file and section, e.g. 01_static §imports, 02_dynamic §registry>`
- **Confidence:** `<high | medium | low>` — `<one sentence on what would raise or lower it>`

**Quick-reference table**

| Attribute | Value |
|-----------|-------|
| Object type | `<FILL -- PE32 / PE32+ / MSI / script / archive / document>` |
| Claimed name / icon | `<FILL -- e.g. "Invoice.pdf.exe", PDF icon spoofing>` |
| Size | `<FILL bytes>` |
| Compiler / packer / installer | `<FILL -- e.g. MSVC, UPX, NSIS, PyInstaller>` |
| Entry behavior (one line) | `<FILL -- what happens on first execution>` |
| Persistence observed | `yes / no / not tested` |
| Network activity observed | `yes / no / not tested` |
| Anti-analysis observed | `yes / no / not tested` |

---

## 3. Scope and assumptions

### What was analyzed
- [ ] `<FILL -- e.g. PE binary only; dropped DLL not detonated>`
- [ ] `<FILL -- e.g. static + dynamic on Win11 baseline VM>`

### Explicit non-goals
- [ ] `<FILL -- e.g. unpacking inner payload / full reverse engineering>`
- [ ] `<FILL -- e.g. memory forensics / kernel-level hooks>`

### Assumptions

| # | Assumption | Risk if wrong |
|---|------------|---------------|
| A1 | `<FILL -- e.g. sample is not time-limited / date-gated>` | `<FILL>` |
| A2 | `<FILL -- e.g. VM clock is close to real-world date>` | `<FILL>` |

### Environment fidelity

| Control | Status |
|---------|--------|
| VM snapshot taken before run | `yes / no` |
| Network posture during run | `<isolated / NAT / internet-blocked / full internet>` |
| AV / EDR state | `<Defender off / Defender on / EDR product>` |
| Time sync | `<UTC / local / intentionally offset>` |

---

## 4. Static analysis highlights

> Full tool-by-tool log: [`01_static/SAMPLE_ID.md`](../01_static/SAMPLE_ID.md). **Synthesize here** — do not paste every tool output line.

### Format and packaging

`<FILL -- e.g. PE32, not packed by entropy alone; overlay at offset 0x… contains NSIS installer data; inner payload at resource RT_RCDATA #101>`

### Imports and capability clusters

`<FILL -- group by theme. Example themes: execution (CreateProcess, ShellExecute), injection (VirtualAlloc + WriteProcessMemory + CreateRemoteThread), persistence (RegSetValueEx HKCU\Run), credential access (CredEnumerate, DPAPI), network (WinINet / Winsock), anti-analysis (IsDebuggerPresent, timing checks, GetTickCount)>`

### Strings and embedded configuration

| Category | Examples found | Confidence | Notes |
|----------|----------------|------------|-------|
| C2 / URLs / domains | `<FILL or "none">` | `<>` | `<>` |
| File paths (hardcoded) | `<FILL or "none">` | `<>` | `<>` |
| Registry keys | `<FILL or "none">` | `<>` | `<>` |
| Mutex / event names | `<FILL or "none">` | `<>` | `<>` |
| Encoding / crypto hints | `<FILL -- e.g. base64 blobs, RC4 key, AES IV>` | `<>` | `<>` |

### Anti-analysis signals (static)

`<FILL -- e.g. TLS callback, section named .vmp, high entropy, opaque predicates, VM artifact checks; or "none observed in static pass">`

### Static conclusion

`<FILL -- one paragraph: what static tells you confidently, what requires dynamic, key unknowns going in>`

---

## 5. Dynamic analysis highlights

> Canonical run log: [`02_dynamic/SAMPLE_ID.md`](../02_dynamic/SAMPLE_ID.md). Add **interpretation** that didn't fit the triage template.

### Run card

| Field | Value |
|-------|-------|
| Executions performed | `<FILL -- e.g. 3 runs: elevated, standard, + isolated-network>` |
| Launch vector | `<double-click / cmd /c / scheduled task / injected>` |
| Integrity level | `<standard user / elevated / SYSTEM>` |
| Instrumentation active | `<Procmon / ProcExp / TCPView / Wireshark / x64dbg / none>` |
| Capture window | `<FILL -- e.g. 5 min; sample appeared idle after 90 s>` |
| Reverted snapshot after | `yes / no` |

### Key file system effects

`<FILL -- drops, staging, self-copy patterns, extension changes. Cite Procmon filter / evidence IDs from 02_dynamic.>`

### Key registry effects

`<FILL -- Run/RunOnce keys, IFEO debugger hijack, COM hijack, service install, file association changes; or "none observed">`

### Persistence mechanisms

| Mechanism | Observed | Evidence pointer |
|-----------|----------|------------------|
| HKCU/HKLM Run key | `yes / no` | `<02_dynamic §registry>` |
| Scheduled task | `yes / no` | `<>` |
| Windows service | `yes / no` | `<>` |
| WMI subscription | `yes / no` | `<>` |
| Startup folder | `yes / no` | `<>` |
| Other | `yes / no` | `<>` |

### User-visible behavior

`<FILL -- fake error dialogs, installer UX, tray icons, decoy documents opened; link screenshot IDs from 50_screenshots/SAMPLE_ID/>`

### Dynamic conclusion

`<FILL -- how does dynamic change or confirm static verdict? Any new evidence of capability not visible in static?>`

---

## 6. Behavior timeline

> **T+0** = process creation event. Each row must map to a verifiable artifact (Procmon, Wireshark, screenshot).

| Offset | Phase | Event | Evidence |
|--------|-------|-------|----------|
| T+0 s | Process creation | `<parent → child, PID if captured>` | `<Procmon / ProcExp>` |
| T+… | File drop | `<FILL>` | `<Procmon filter ID>` |
| T+… | Registry write | `<FILL>` | `<>` |
| T+… | Network | `<FILL>` | `<TCPView / Wireshark>` |
| T+… | Post-run artifact | `<FILL>` | `<screenshot ID>` |

---

## 7. Network analysis

> Skip this section if sample was run network-isolated and no static network IOCs were found. Note "not applicable" rather than leaving blank.

### Observed traffic

| Time | Protocol | Destination | Process | Classification | Notes |
|------|----------|-------------|---------|----------------|-------|
| `<>` | `<HTTP / HTTPS / DNS / SMTP>` | `<domain or IP>` | `<>` | `<C2 / telemetry / benign>` | `<>` |

### DNS and TLS fingerprints

`<FILL -- resolved domains, JA3 if captured, certificate subject; or "not captured / network isolated">`

### Delivery vs runtime network

| Class | Indicator | Observed in this run? | Confidence |
|-------|-----------|----------------------|------------|
| Delivery URL | `<>` | `<yes / no>` | `<>` |
| Runtime C2 | `<>` | `<yes / no>` | `<>` |
| Data exfil target | `<>` | `<yes / no>` | `<>` |

---

## 8. MITRE ATT&CK mapping

> [`03_findings/SAMPLE_ID.md`](../03_findings/SAMPLE_ID.md) lists technique IDs. **Justify** each here with: technique → specific observation → data source → confidence.
> See [`20_notes/MITRE-coverage.md`](../20_notes/MITRE-coverage.md) for cross-engagement tracking.

| ID | Name | Sub-technique | Observation | Data source | Confidence |
|----|------|---------------|-------------|-------------|------------|
| Txxxx | `<name>` | `.xxx` or — | `<what you actually saw>` | `<static / dynamic / strings>` | `<high / med / low>` |

### Tactic summary

| Tactic | Techniques | Why applicable |
|--------|------------|----------------|
| Initial Access | `<>` | `<>` |
| Execution | `<>` | `<>` |
| Persistence | `<>` | `<>` |
| Defense Evasion | `<>` | `<>` |
| C2 | `<>` | `<>` |

---

## 9. Detection engineering

> See [`20_notes/detection-catalog.md`](../20_notes/detection-catalog.md) for cross-engagement ideas.
> Reusable queries → [`45_hunt_queries/`](../45_hunt_queries/README.md).

### Sigma / KQL / Splunk sketch

```yaml
# <FILL -- Sigma rule or pseudocode; generic field names, no vendor secrets>
# title: Detect <behavior>
# logsource: ...
# detection:
#   selection:
#     ...
#   condition: selection
```

### YARA / file hunting ideas

`<FILL -- string cluster, byte pattern, imphash group, or section name anomaly worth a rule; or "no high-confidence static signature">`

### Process / command-line behavioral hunt

`<FILL -- parent-child chain, command-line pattern, or event sequence that would catch this family generically>`

### False positive analysis

| Detection idea | Expected FP source | Mitigation |
|----------------|--------------------|------------|
| `<>` | `<e.g. legit software with same import>` | `<e.g. add path exclusion>` |

### Threat intelligence context

`<FILL -- known cluster name, public sandbox links, Malpedia family page, blog posts, attribution caveats; or "no public TI cross-referenced">`

---

## 10. Recommendations

### For defenders / blue team

1. `<FILL -- e.g. alert on specific Run key path + image name pattern>`
2. `<FILL -- e.g. block known C2 domains in firewall>`

### For analysts continuing this engagement

1. `<FILL -- e.g. unpack inner stage and re-analyze>`
2. `<FILL -- e.g. rerun with Wireshark to capture full DNS exchange>`

---

## 11. Limitations and follow-on work

| Gap | Impact on verdict | Suggested next step | Effort |
|-----|-------------------|---------------------|--------|
| `<FILL -- e.g. no memory dump taken>` | `<FILL>` | `<FILL>` | `<low / med / high>` |

**What would change the verdict:**

`<FILL -- e.g. "Finding injected shellcode in memory would escalate from suspicious to malicious">`

---

## 12. Appendices

### Appendix A — Hash bundle

| Algorithm | Hash |
|-----------|------|
| SHA256 | `<FILL>` |
| SHA1 | `<FILL>` |
| MD5 | `<FILL>` |
| imphash | `<FILL>` |
| ssdeep | `<FILL>` |
| TLSH | `<FILL>` |

### Appendix B — Provenance

| Stage | Detail |
|-------|--------|
| Public source | `<FILL -- e.g. MalwareBazaar URL, Any.run link>` |
| First seen (source metadata) | `<FILL>` |
| Download method | `<FILL -- VM browser / API / manual transfer>` |
| Hash verified on download | `<yes / no>` |

### Appendix C — Tool command log

```text
<FILL -- exact commands you ran; scrub analyst host paths; VM paths acceptable>
```

### Appendix D — Screenshot manifest

| File | Description |
|------|-------------|
| `<FILL>` | `<one-line description>` |

_(Full index: [`50_screenshots/SAMPLE_ID/SHOT_INDEX.txt`](../50_screenshots/SAMPLE_ID/SHOT_INDEX.txt))_

### Appendix E — References

| Type | Source |
|------|--------|
| MalwareBazaar | `<URL>` |
| Any.run / sandbox | `<URL>` |
| Vendor blog | `<URL>` |
| ATT&CK technique page | `<URL>` |
| Malpedia | `<URL>` |

---

## Final checklist before commit

- [ ] No analyst host paths, internal hostnames, or real credentials anywhere in this file
- [ ] `vm_profile` and `tooling_snapshot` describe the lab environment only (no employer infrastructure)
- [ ] EXIF metadata stripped from all new screenshots in `50_screenshots/SAMPLE_ID/`
- [ ] `40_iocs/indicators.csv` updated for any **new** confirmed indicators introduced here
- [ ] `03_findings/SAMPLE_ID.md` is still accurate and not contradicted by this writeup
- [ ] MITRE table IDs match `03_findings` mitre_techniques list
- [ ] Classification and distribution statement matches what you are actually publishing
- [ ] `redact-check.ps1` passed with no errors
