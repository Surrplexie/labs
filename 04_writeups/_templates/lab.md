---
# Long-form training lab report (optional -- not validated by 03_findings schema)
writeup_version: 1
related_sample_id: SAMPLE_ID
engagement_kind: lab

title: "<FILL -- e.g. THM Introductory Researching — portfolio narrative>"
subtitle: "<FILL -- one-liner: what skill this lab builds>"

analyst: ANALYST
course: PLATFORM_VAL      # e.g. TryHackMe / TCM Security / SANS / HTB Academy / OffSec
module: TITLE_VAL         # room name / course module / lab title
course_url: "<FILL -- public URL if available; omit if internal/paid behind login>"

environment: "<FILL -- VM label or cloud environment; no IPs, no passwords>"
time_expected: "<FILL -- advertised lab duration, e.g. '30 min'>"
time_actual: "<FILL -- how long it actually took you>"

classification: TLP:CLEAR
distribution: "<FILL -- Personal study notes / Portfolio (public-safe) / Employer internal>"

date_draft: DATE
date_final: ""

objectives_met: false    # set true when all objectives are checked off in §3

abstract: |
  <FILL -- 3–5 sentences: course/platform and module name, what skills the lab covers,
  whether objectives were met, one concrete takeaway or surprise.
  Write this last.>

skills_practiced:
  - "<FILL -- e.g. network enumeration with nmap>"
  - "<FILL -- e.g. privilege escalation via misconfigured sudoers>"

keywords:
  - "<FILL -- course or platform name>"
  - lab

evidence_index:
  brief:       ../00_original/SAMPLE_ID.md
  steps:       ../01_static/SAMPLE_ID.md
  results:     ../02_dynamic/SAMPLE_ID.md
  reflection:  ../03_findings/SAMPLE_ID.md
  screenshots: ../50_screenshots/SAMPLE_ID/
---

# <FILL -- lab / module title>

> **Engagement:** [`SAMPLE_ID`](../03_findings/SAMPLE_ID.md) · **Course:** PLATFORM_VAL · **Module:** TITLE_VAL

> **No lab credentials, VPN configs, course answer keys, or internal IPs** in committed text.

---

## Table of contents

1. [Document control](#1-document-control)
2. [Lab context](#2-lab-context)
3. [Objectives rubric](#3-objectives-rubric)
4. [Procedure highlights](#4-procedure-highlights)
5. [Results and proof](#5-results-and-proof)
6. [Reflection and gaps](#6-reflection-and-gaps)
7. [Skills delta](#7-skills-delta)
8. [Connection to malware / detection work](#8-connection-to-malware--detection-work)
9. [Portfolio blurb](#9-portfolio-blurb)
10. [Appendices](#10-appendices)

---

## 1. Document control

| Field | Value |
|-------|-------|
| Writeup ID | `<FILL -- e.g. LAB-2026-001>` |
| Slot | SAMPLE_ID |
| Version | `0.1 draft` |
| Analyst | ANALYST |
| Last updated | DATE |

| Version | Date | Summary |
|---------|------|---------|
| 0.1 | DATE | Initial draft |

> Cross-reference: [`20_notes/lab-curriculum-map.md`](../20_notes/lab-curriculum-map.md) — update the index row for this slot.

---

## 2. Lab context

| Field | Value |
|-------|-------|
| Course / platform | PLATFORM_VAL |
| Module / room | TITLE_VAL |
| Public URL | `<FILL or 'private/internal'>` |
| Environment | `<FILL -- VM label only; no IPs>` |
| Expected time | `<FILL>` |
| Actual time | `<FILL>` |
| Prereqs listed | `<FILL -- what the platform says you should know first>` |

### Learning objectives (paraphrased from lab page)

1. `<FILL>`
2. `<FILL>`
3. `<FILL>`

Canonical brief: [`00_original/SAMPLE_ID.md`](../00_original/SAMPLE_ID.md)

---

## 3. Objectives rubric

> Check each row when complete. Sync `objectives_met: true` in frontmatter when all are met.

| # | Objective | Met | Evidence / notes |
|---|-----------|-----|-----------------|
| 1 | `<FILL>` | no | `<link to 02_dynamic section or screenshot>` |
| 2 | `<FILL>` | no | `<FILL>` |
| 3 | `<FILL>` | no | `<FILL>` |

Sync with `objectives_met` field in [`03_findings/SAMPLE_ID.md`](../03_findings/SAMPLE_ID.md).

---

## 4. Procedure highlights

> Full step log: [`01_static/SAMPLE_ID.md`](../01_static/SAMPLE_ID.md). **Summarize your decisions here** — do not paste the entire lab walkthrough.

### Steps that mattered most

| Step | Command / action | Why this step was non-obvious | What you learned |
|------|------------------|-------------------------------|------------------|
| `<FILL>` | `<FILL>` | `<FILL>` | `<FILL>` |

### Confusion points and lookups

`<FILL -- what you had to stop and research; links to docs or Stack Overflow you relied on>`

### Commands run (scrubbed)

```bash
# <FILL -- key commands; scrub any IPs, usernames, passwords, or answer strings>
```

---

## 5. Results and proof

> Results log: [`02_dynamic/SAMPLE_ID.md`](../02_dynamic/SAMPLE_ID.md).

### Completion summary

`<FILL -- what worked, what failed, how you recovered from errors>`

### Proof pointers (no secrets)

| Artifact | Location | Notes |
|----------|----------|-------|
| Completion screenshot | `50_screenshots/SAMPLE_ID/<file>` | `<FILL>` |
| Task answer proof | `<paraphrase or hash; never the raw answer string>` | `<>` |

---

## 6. Reflection and gaps

### Key takeaways

1. `<FILL -- what you will remember / do differently next time>`
2. `<FILL>`
3. `<FILL>`

### What I would do differently

`<FILL -- if you did this lab again from scratch, what would you change?>`

### Confusion that remains

`<FILL -- concepts still fuzzy after finishing the lab; candidates for follow-on study>`

### Follow-on labs / reading

| Next step | Why | Priority |
|-----------|-----|----------|
| `<FILL>` | `<FILL>` | high / med / low |

---

## 7. Skills delta

> Compare your capability **before** and **after** this lab. Update [`20_notes/skills-coverage.md`](../20_notes/skills-coverage.md) with changes.

| Skill | Before | After | Evidence in this engagement |
|-------|--------|-------|-----------------------------|
| `<FILL>` | none / aware / practiced | practiced / solid / expert | `<FILL -- section ref or screenshot>` |

### Skills now ready for a real engagement (malware / CTF / hunt)

`<FILL -- e.g. "Comfortable using Gobuster for directory brute-force; ready to use in CTF web category">`

---

## 8. Connection to malware / detection work

> Optional: link techniques from this lab to a `file` or `hunt` engagement.

`<FILL -- e.g. "Procmon filtering technique from this lab applied to sample_01 dynamic run, §7.3. Allowed me to isolate registry writes 40% faster." or "N/A — fundamentals lab with no direct malware connection yet">`

---

## 9. Portfolio blurb

`<FILL -- 4–6 sentences for resume / LinkedIn / public portfolio. Skills-focused, no course spoilers, no answer strings. Highlight tools, techniques, and depth.>`

---

## 10. Appendices

### Appendix A — Command log (scrubbed)

```bash
<FILL -- full command list; remove IPs, usernames, passwords, answer keys>
```

### Appendix B — Screenshot manifest

| File | Description |
|------|-------------|
| `<FILL>` | `<one-line description>` |

_(Full index: [`50_screenshots/SAMPLE_ID/SHOT_INDEX.txt`](../50_screenshots/SAMPLE_ID/SHOT_INDEX.txt))_

### Appendix C — References

| Resource | URL |
|----------|-----|
| Lab page | `<FILL>` |
| Technique documentation | `<FILL>` |
| Related reading | `<FILL>` |

---

## Final checklist before commit

- [ ] No passwords, VPN keys, course answer keys, or internal IPs anywhere in this file
- [ ] Target IPs and usernames replaced with `<TARGET_IP>` / `<USERNAME>` in command blocks
- [ ] Objectives rubric in §3 matches `objectives_met` value in frontmatter
- [ ] `objectives_met` in frontmatter matches `03_findings/SAMPLE_ID.md`
- [ ] `20_notes/lab-curriculum-map.md` row updated for this slot
- [ ] Skills delta in §7 updated in `20_notes/skills-coverage.md`
- [ ] EXIF stripped from all new screenshots
- [ ] `redact-check.ps1` passed with no errors
