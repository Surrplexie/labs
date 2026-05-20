---
# Long-form training lab report (optional -- not validated by 03_findings schema)
writeup_version: 1
related_sample_id: SAMPLE_ID
engagement_kind: lab

title: "<FILL -- e.g. THM Introductory Researching -- portfolio narrative>"
subtitle: "<FILL>"

analyst: ANALYST
course: PLATFORM_VAL
module: TITLE_VAL
environment: "<FILL -- VM name only; no IPs or passwords>"

classification: TLP:CLEAR
distribution: "<FILL -- e.g. Personal study notes / portfolio>"

date_draft: DATE
date_final: ""
objectives_met: false  # set true when lab is complete

abstract: |
  <FILL -- what the lab taught, whether objectives were met, one concrete takeaway.>

skills_practiced:
  - "<FILL>"
keywords:
  - "<FILL>"
  - lab

evidence_index:
  brief: ../00_original/SAMPLE_ID.md
  steps: ../01_static/SAMPLE_ID.md
  results: ../02_dynamic/SAMPLE_ID.md
  reflection: ../03_findings/SAMPLE_ID.md
  screenshots: ../50_screenshots/SAMPLE_ID/
---

# <FILL -- lab title>

> **Related engagement:** [`SAMPLE_ID`](../03_findings/SAMPLE_ID.md) · **Course:** PLATFORM_VAL · **Module:** TITLE_VAL

**No lab credentials, VPN configs, or internal IPs** in committed text.

---

## Table of contents

1. [Document control](#1-document-control)
2. [Lab context](#2-lab-context)
3. [Objectives rubric](#3-objectives-rubric)
4. [Procedure highlights](#4-procedure-highlights)
5. [Results and proof](#5-results-and-proof)
6. [Reflection and gaps](#6-reflection-and-gaps)
7. [Connection to malware work](#7-connection-to-malware-work)
8. [Portfolio blurb](#8-portfolio-blurb)
9. [Appendices](#9-appendices)

---

## 1. Document control

| Field | Value |
|--------|--------|
| Writeup ID | `<FILL -- e.g. LAB-2026-001>` |
| Slot | SAMPLE_ID |
| Analyst | ANALYST |
| Last updated | DATE |

---

## 2. Lab context

| Field | Value |
|--------|--------|
| Course / platform | PLATFORM_VAL |
| Module / room | TITLE_VAL |
| Environment | `<FILL -- VM label only>` |
| Time spent | `<FILL>` |

### Learning objectives (from lab page, paraphrased)

1. `<FILL>`
2. `<FILL>`

Canonical brief: [`00_original/SAMPLE_ID.md`](../00_original/SAMPLE_ID.md)

---

## 3. Objectives rubric

| # | Objective | Met? | Evidence |
|---|-----------|------|----------|
| 1 | `<FILL>` | `[ ]` | `<link to 02_dynamic or screenshot>` |
| 2 | `<FILL>` | `[ ]` | `<FILL>` |

Sync with `objectives_met` in [`03_findings/SAMPLE_ID.md`](../03_findings/SAMPLE_ID.md).

---

## 4. Procedure highlights

> Full step log: [`01_static/SAMPLE_ID.md`](../01_static/SAMPLE_ID.md)

Do not paste the entire lab walkthrough -- summarize **your** work and decisions.

### Steps that mattered

| Step | Command / action | What you learned |
|------|------------------|------------------|
| `<FILL>` | `<FILL>` | `<FILL>` |

### Confusion points and lookups

`<FILL -- what you had to research, docs you used>`

---

## 5. Results and proof

> Results log: [`02_dynamic/SAMPLE_ID.md`](../02_dynamic/SAMPLE_ID.md)

### Completion summary

`<FILL -- what worked, what failed, how you fixed errors>`

### Proof pointers (no secrets)

| Artifact | Location |
|----------|----------|
| Screenshot | `50_screenshots/SAMPLE_ID/<file>` |
| Output snippet | `<paraphrase or redacted excerpt>` |

---

## 6. Reflection and gaps

### Key takeaways

1. `<FILL>`
2. `<FILL>`

### What I would do differently

`<FILL>`

### Follow-on labs / reading

| Next step | Why |
|-----------|-----|
| `<FILL>` | `<FILL>` |

---

## 7. Connection to malware work

> Optional: link skills from this lab to a `file` engagement (e.g. "Procmon filtering from this lab applied in sample_XX").

`<FILL or "N/A -- general security fundamentals only">`

---

## 8. Portfolio blurb

`<FILL -- resume-safe summary; skills-focused, no course spoilers>`

---

## 9. Appendices

### Appendix A -- Command log (scrubbed)

```bash
<FILL>
```

### Appendix B -- Screenshot manifest

| File | Description |
|------|-------------|
| `<FILL>` | `<FILL>` |

---

## Final checklist before commit

- [ ] No passwords, VPN keys, or lab IPs
- [ ] `objectives_met` consistent with `03_findings`
- [ ] EXIF stripped; `redact-check.ps1` passed
