---
# Long-form CTF writeup (optional -- not validated by 03_findings schema)
writeup_version: 1
related_sample_id: SAMPLE_ID
engagement_kind: ctf

title: "<FILL -- e.g. HTB Lame -- long-form walkthrough>"
subtitle: "<FILL -- optional one-line hook>"

analyst: ANALYST
platform: PLATFORM_VAL
category: "<FILL -- web | pwn | rev | crypto | forensics | misc | osint>"
difficulty: "<FILL -- easy | medium | hard | insane>"
points: "<FILL>"

classification: TLP:CLEAR
distribution: "<FILL -- e.g. Public portfolio after machine retired>"
public_writeup_safe: false  # set true only when challenge is retired / release permitted

date_draft: DATE
date_final: ""

abstract: |
  <FILL -- 3-5 sentences: challenge type, approach summary, outcome, what you learned.
  No raw flags.>

skills_practiced:
  - "<FILL>"
keywords:
  - "<FILL>"
  - ctf

evidence_index:
  brief: ../00_original/SAMPLE_ID.md
  recon: ../01_static/SAMPLE_ID.md
  solve: ../02_dynamic/SAMPLE_ID.md
  findings: ../03_findings/SAMPLE_ID.md
  screenshots: ../50_screenshots/SAMPLE_ID/
---

# <FILL -- challenge title>

> **Related engagement:** [`SAMPLE_ID`](../03_findings/SAMPLE_ID.md) · **Platform:** PLATFORM_VAL · **Public-safe:** `<yes/no>`

**Do not commit raw flags.** Use `[FLAG REDACTED]` or describe proof without the string.

---

## Table of contents

1. [Document control](#1-document-control)
2. [Challenge overview](#2-challenge-overview)
3. [Recon summary](#3-recon-summary)
4. [Attack narrative](#4-attack-narrative)
5. [Rabbit holes and dead ends](#5-rabbit-holes-and-dead-ends)
6. [Tooling and commands](#6-tooling-and-commands)
7. [Skills and learning outcomes](#7-skills-and-learning-outcomes)
8. [Portfolio blurb](#8-portfolio-blurb)
9. [Ethics and publication](#9-ethics-and-publication)
10. [Appendices](#10-appendices)

---

## 1. Document control

| Field | Value |
|--------|--------|
| Writeup ID | `<FILL -- e.g. CTF-2026-001>` |
| Slot | SAMPLE_ID |
| Version | `0.1` draft / `1.0` final |
| Analyst | ANALYST |
| Last updated | DATE |

| Version | Date | Summary |
|---------|------|---------|
| 0.1 | DATE | Initial draft |

---

## 2. Challenge overview

| Field | Value |
|--------|--------|
| Platform | PLATFORM_VAL |
| Title | TITLE_VAL |
| Category | `<FILL>` |
| Difficulty | `<FILL>` |
| Points | `<FILL>` |
| Target | `<FILL -- IP/URL description only; no VPN creds>` |

### Objective (paraphrase)

`<FILL -- what the challenge asks you to do, in your own words>`

### Constraints and rules

- [ ] Platform ToS respected (no sharing active flags)
- [ ] `public_writeup_safe` in [`03_findings`](../03_findings/SAMPLE_ID.md) matches this document

Canonical brief: [`00_original/SAMPLE_ID.md`](../00_original/SAMPLE_ID.md)

---

## 3. Recon summary

> Phase log: [`01_static/SAMPLE_ID.md`](../01_static/SAMPLE_ID.md)

### Attack surface

`<FILL -- ports, services, tech stack, obvious misconfigs>`

### Key enumeration commands

```bash
<FILL -- nmap, gobuster, etc.; scrub target-specific secrets if needed>
```

### Interesting findings before exploitation

| Finding | Why it mattered |
|---------|-----------------|
| `<FILL>` | `<FILL>` |

---

## 4. Attack narrative

> Solve log: [`02_dynamic/SAMPLE_ID.md`](../02_dynamic/SAMPLE_ID.md)

Tell the story in order: what you tried, what worked, why.

### 4.1 Initial access

`<FILL>`

### 4.2 Privilege escalation / pivot (if applicable)

`<FILL>`

### 4.3 Flag capture (redacted)

| Flag type | Proof (no raw value) |
|-----------|----------------------|
| User | `<e.g. captured YYYY-MM-DD; hash of flag optional for self-check only>` |
| Root / final | `<FILL>` |

### 4.4 One-paragraph "how I would teach this"

`<FILL>`

---

## 5. Rabbit holes and dead ends

| Attempt | Time spent | Lesson |
|---------|------------|--------|
| `<FILL>` | `<FILL>` | `<FILL>` |

---

## 6. Tooling and commands

| Tool | Role in this challenge |
|------|------------------------|
| `<FILL>` | `<FILL>` |

See also [`20_notes/ctf-tooling-reference.md`](../../20_notes/ctf-tooling-reference.md).

### Command appendix (scrubbed)

```bash
<FILL>
```

---

## 7. Skills and learning outcomes

| Skill | Depth | Evidence in this engagement |
|-------|-------|------------------------------|
| `<FILL>` | intro / practiced / solid | `<FILL>` |

Align with `skills[]` in [`03_findings/SAMPLE_ID.md`](../03_findings/SAMPLE_ID.md).

---

## 8. Portfolio blurb

> Copy or extend the public-safe blurb from `03_findings` when `public_writeup_safe: true`.

`<FILL -- 4-6 sentences safe for LinkedIn / resume packet; no spoilers for active machines>`

---

## 9. Ethics and publication

- Raw flags, VPN keys, and platform credentials **never** belong in this repo.
- Full methodology belongs here only when the machine is retired or writeup release is allowed.
- [`redact-check.ps1`](../../30_scripts/redact-check.ps1) scans for `HTB{`, `THM{`, `flag{`, etc.

---

## 10. Appendices

### Appendix A -- Screenshot manifest

| File | Description |
|------|-------------|
| `<FILL>` | `<FILL>` |

_(See [`SHOT_INDEX.txt`](../50_screenshots/SAMPLE_ID/SHOT_INDEX.txt).)_

### Appendix B -- References

| Resource | URL |
|----------|-----|
| Official writeup policy | `<FILL>` |
| Tool docs | `<FILL>` |

---

## Final checklist before commit

- [ ] No raw flags or credentials
- [ ] `public_writeup_safe` consistent with `03_findings`
- [ ] EXIF stripped on new screenshots
- [ ] `redact-check.ps1` passed
