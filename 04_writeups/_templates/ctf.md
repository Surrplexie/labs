---
# Long-form CTF writeup (optional -- not validated by 03_findings schema)
writeup_version: 1
related_sample_id: SAMPLE_ID
engagement_kind: ctf

title: "<FILL -- e.g. HTB Lame — long-form walkthrough>"
subtitle: "<FILL -- optional one-liner: what technique or lesson this machine teaches>"

analyst: ANALYST
platform: PLATFORM_VAL   # HackTheBox | TryHackMe | PicoCTF | SANS | competition name
category: "<FILL -- web | pwn | rev | crypto | forensics | osint | misc | fullpwn>"
difficulty: "<FILL -- easy | medium | hard | insane | beginner>"
points: "<FILL or 'n/a' for machines>"

classification: TLP:CLEAR
distribution: "<FILL -- Public portfolio after machine retired / Personal notes only>"
public_writeup_safe: false  # set true ONLY when challenge is retired or platform explicitly permits

date_draft: DATE
date_final: ""

abstract: |
  <FILL -- 4–6 sentences: platform, challenge/machine name and category, approach summary,
  key technique used, outcome (user + root / flag captured), and one concrete takeaway.
  No raw flags. Write this last.>

skills_practiced:
  - "<FILL -- e.g. SUID binary exploitation>"
  - "<FILL -- e.g. SMB enumeration, Metasploit>"

keywords:
  - "<FILL -- machine or challenge name>"
  - ctf
  - PLATFORM_VAL

evidence_index:
  brief:       ../00_original/SAMPLE_ID.md
  recon:       ../01_static/SAMPLE_ID.md
  solve:       ../02_dynamic/SAMPLE_ID.md
  findings:    ../03_findings/SAMPLE_ID.md
  screenshots: ../50_screenshots/SAMPLE_ID/
---

# <FILL -- challenge / machine title>

> **Engagement:** [`SAMPLE_ID`](../03_findings/SAMPLE_ID.md) · **Platform:** PLATFORM_VAL · **Category:** `<FILL>` · **Difficulty:** `<FILL>`

> ⚠ **Do not commit raw flags.** Use `[FLAG REDACTED]` or describe proof without the flag string. Full methodology belongs here only when the machine is **retired** or the platform explicitly permits writeups. Set `public_writeup_safe: true` in frontmatter before publishing.

---

## Table of contents

1. [Document control](#1-document-control)
2. [Challenge overview](#2-challenge-overview)
3. [Challenge analysis](#3-challenge-analysis)
4. [Attack / solve narrative](#4-attack--solve-narrative)
5. [Rabbit holes and dead ends](#5-rabbit-holes-and-dead-ends)
6. [Tooling and commands](#6-tooling-and-commands)
7. [Skills and learning outcomes](#7-skills-and-learning-outcomes)
8. [Portfolio blurb](#8-portfolio-blurb)
9. [Ethics and publication](#9-ethics-and-publication)
10. [Appendices](#10-appendices)

---

## 1. Document control

| Field | Value |
|-------|-------|
| Writeup ID | `<FILL -- e.g. CTF-2026-001>` |
| Slot | SAMPLE_ID |
| Version | `0.1 draft` |
| Analyst | ANALYST |
| Last updated | DATE |
| Machine retired / writeup permitted | `yes / no / unknown` |

| Version | Date | Summary |
|---------|------|---------|
| 0.1 | DATE | Initial draft |

> Cross-reference: [`20_notes/ctf-machine-index.md`](../20_notes/ctf-machine-index.md) — update the index row for this slot.

---

## 2. Challenge overview

| Field | Value |
|-------|-------|
| Platform | PLATFORM_VAL |
| Challenge / machine | TITLE_VAL |
| Category | `<FILL>` |
| Difficulty | `<FILL>` |
| Points / rating | `<FILL or 'n/a'>` |
| Target | `<FILL -- IP/URL description only; never paste VPN config or credentials>` |
| Solve date | DATE |

### Objective (in your own words)

`<FILL -- what the challenge asks you to do, paraphrased. No spoilers if machine is still active.>`

### Constraints and publication status

- [ ] Platform ToS respected (no active-machine flags shared)
- [ ] `public_writeup_safe` in [`03_findings/SAMPLE_ID.md`](../03_findings/SAMPLE_ID.md) matches this document
- [ ] Machine retired or platform permits writeup before this file is pushed to any public repo

Canonical brief: [`00_original/SAMPLE_ID.md`](../00_original/SAMPLE_ID.md)

---

## 3. Challenge analysis

> Full enumeration / recon log: [`01_static/SAMPLE_ID.md`](../01_static/SAMPLE_ID.md). Synthesize here — not every tool output.
>
> **Category guidance (adapt this section to your challenge type):**
> - `fullpwn / web / osint` → attack surface enumeration (ports, services, tech stack)
> - `rev / pwn` → binary overview (file type, protections, entry point, key functions)
> - `crypto` → cipher/protocol identification, known weaknesses, parameter space
> - `forensics` → artifact type, metadata, file structure, extraction approach
> - `misc` → challenge format, given files, initial observations

### Attack surface / initial observations

`<FILL -- what you found in the first pass: open ports, file types, obvious misconfigs, hint from challenge description>`

### Key findings before exploit / solve

| Finding | Why it mattered | Confidence at this stage |
|---------|-----------------|--------------------------|
| `<FILL>` | `<FILL>` | `<high / med / low>` |

### Dead-end hypotheses going in

`<FILL -- what looked promising initially but you ruled out before starting. Helps distinguish §5 rabbit holes from pre-solve eliminates.>`

---

## 4. Attack / solve narrative

> Solve log: [`02_dynamic/SAMPLE_ID.md`](../02_dynamic/SAMPLE_ID.md). Tell the **story** here — what you tried, what worked, and why.

### 4.1 Initial foothold / first step

`<FILL -- first actionable thing that moved you forward>`

### 4.2 Escalation / progression

`<FILL -- privilege escalation, lateral movement, additional flags, chained exploits>`

### 4.3 Final flag / solve (redacted)

| Stage | Proof (no raw flag value) |
|-------|---------------------------|
| User / first flag | `<e.g. captured DATE; self-check hash stored locally>` |
| Root / final flag | `<FILL>` |

### 4.4 "How I would teach this"

`<FILL -- 2–3 sentences: what concept does this challenge teach, and what is the single most important thing a learner should take away?>`

---

## 5. Rabbit holes and dead ends

> This section is what makes a writeup valuable beyond a solution paste — it shows thinking process.

| Attempt | Time spent | Why it seemed right | Why it failed | Lesson |
|---------|------------|--------------------|--------------  |--------|
| `<FILL>` | `<FILL>` | `<FILL>` | `<FILL>` | `<FILL>` |

---

## 6. Tooling and commands

> See [`20_notes/ctf-tooling-reference.md`](../20_notes/ctf-tooling-reference.md) for the persistent tooling notes.

| Tool | Version | Role in this challenge |
|------|---------|------------------------|
| `<FILL>` | `<>` | `<FILL>` |

### Key commands (scrubbed)

```bash
# <FILL -- commands used; scrub target-specific IPs and credentials>
# Replace real IPs with <TARGET_IP> placeholder
```

### Category-specific notes

`<FILL -- e.g. for pwn: libc version and offsets; for crypto: key parameters and attack name; for web: CVE or CWE reference; or "N/A">`

---

## 7. Skills and learning outcomes

> Align with `skills[]` in [`03_findings/SAMPLE_ID.md`](../03_findings/SAMPLE_ID.md) and update [`20_notes/skills-coverage.md`](../20_notes/skills-coverage.md).

| Skill / technique | Depth after this challenge | Evidence in this engagement |
|-------------------|-----------------------------|------------------------------|
| `<FILL>` | intro / practiced / solid / expert | `<FILL -- section ref or screenshot>` |

### What to do next to deepen this area

`<FILL -- e.g. "Practice similar SUID chains on HackTheBox 'Beep'; read GTFObins for comprehensive list">`

---

## 8. Portfolio blurb

> Use or extend the public-safe blurb from `03_findings` when `public_writeup_safe: true`.

`<FILL -- 4–6 sentences safe for LinkedIn / resume packet / GitHub portfolio. No spoilers for active machines. Focus on skills demonstrated, tools used, and what you learned.>`

---

## 9. Ethics and publication

**Publication checklist:**

- Raw flags, VPN keys, and credentials **never** belong in this repo (active or retired)
- Full methodology may only be published when: (a) machine is officially retired, OR (b) platform explicitly allows writeups for this challenge
- [`redact-check.ps1`](../30_scripts/redact-check.ps1) scans for common flag patterns automatically

**When in doubt:** keep `public_writeup_safe: false` and push only to a private repo until the machine retires.

**Platform-specific rules:**

| Platform | Policy summary | Link |
|----------|---------------|------|
| HackTheBox | Writeups only after machine retired | https://help.hackthebox.com/en/articles/5188390 |
| TryHackMe | Most rooms allow writeups; check individual room | https://tryhackme.com/terms |
| picoCTF | Check each competition's rules | competition-specific |
| Other | `<FILL>` | `<FILL>` |

---

## 10. Appendices

### Appendix A — Screenshot manifest

| File | Description |
|------|-------------|
| `<FILL>` | `<one-line description>` |

_(Full index: [`50_screenshots/SAMPLE_ID/SHOT_INDEX.txt`](../50_screenshots/SAMPLE_ID/SHOT_INDEX.txt))_

### Appendix B — References

| Resource | URL |
|----------|-----|
| Platform writeup policy | `<FILL>` |
| CVE / exploit reference | `<FILL>` |
| Tool documentation | `<FILL>` |
| Related writeup / blog | `<FILL>` |

---

## Final checklist before commit

- [ ] No raw flags or credentials anywhere in this file
- [ ] Machine is retired OR `public_writeup_safe: false` and file is in private repo only
- [ ] `public_writeup_safe` is consistent between this file and `03_findings/SAMPLE_ID.md`
- [ ] Target IPs replaced with `<TARGET_IP>` in all command blocks
- [ ] EXIF stripped from any new screenshots
- [ ] `20_notes/ctf-machine-index.md` row updated for this slot
- [ ] Skills table aligns with `03_findings` `skills[]` field
- [ ] `redact-check.ps1` passed with no errors
