# ENGAGEMENTS.md

**Master guide for all engagement types in this logbook.**

This repository supports four engagement kinds. Every engagement uses the same
slot system (`sample_XX` IDs, the same four phase folders, the same tracker,
the same validation and export pipeline). The `engagement_kind` field in the
tracker and frontmatter controls which templates, checklists, and checks apply.

---

## Engagement kinds at a glance

| Kind | What it is | Primary output | Example |
|------|-----------|----------------|---------|
| `file` | A single malware/suspicious artifact | Static triage, dynamic triage, IOCs, verdict | MalwareBazaar PE, weaponised doc |
| `ctf` | A CTF or HackTheBox/TryHackMe challenge | Writeup, methodology, flag proof | HTB machine, CTF web challenge |
| `lab` | A guided course/training lab or module | Step log, objectives met, reflection | TryHackMe room, SANS lab, employer onboarding |
| `hunt` | A hypothesis-driven detection exercise | Detections, queries, timeline, outcome | Splunk threat hunt, SIEM alert triage |

---

## Phase folder mapping by kind

The same four physical folders are used for all kinds. The meaning of each
folder changes based on `engagement_kind`.

| Folder | `file` | `ctf` | `lab` | `hunt` |
|--------|--------|-------|-------|--------|
| `00_original/` | Acquisition receipt + hash set | Challenge brief, category, difficulty | Lab brief, objectives, environment | Hunt scope, hypothesis, data sources |
| `01_static/` | Static triage (DIE / PEStudio / CFF / HxD) | Recon / enumeration notes | Step log (procedure + commands) | Data collection (queries, raw findings) |
| `02_dynamic/` | Dynamic triage (Procmon, ProcExp, TCPView) | Solve attempt (approach, exploits, pivots) | Results (outcomes, errors, screenshots) | Analysis (timeline, correlation, patterns) |
| `03_findings/` | Verdict + IOC table + portfolio blurb | Writeup + methodology + public-safe flag proof | Reflection + objectives met + skills | Outcome + detections + confidence + next steps |

`04_writeups/` and `50_screenshots/` use the same `sample_XX` IDs for all kinds. Long-form
`04_writeups` are optional for every kind; **`03_findings` is the primary finished artifact**
that feeds `INDEX.md` and `dist/portfolio.json`.

---

## Slot reservation & Tier 1 conventions

**Tier 1** means using the existing layout only — no new top-level folders, no second
tracker, no kind-specific directory names. CTF, lab, and hunt work run through the same
`sample_01`–`sample_50` slots as malware; `engagement_kind` and the correct **status
lifecycle** tell the automation which rules apply.

This logbook is **malware-triage primary**. Reserve slots so HTB rooms and course labs do
not collide with MalwareBazaar sample numbers you already associate with file work.

### Recommended slot ranges

| Slots | Kind | Use for |
|-------|------|---------|
| `sample_01`–`30` | `file` | Malware / suspicious artifacts (MalwareBazaar, drops, docs) |
| `sample_31`–`40` | `ctf` | HackTheBox, TryHackMe, PicoCTF, event challenges |
| `sample_41`–`45` | `lab` | Guided course modules, training paths |
| `sample_46`–`50` | `hunt` | Hypothesis-driven detection / SIEM exercises |

These ranges are a **convention**, not enforced by scripts. Empty tracker rows may still
show `engagement_kind: file` until you scaffold — set the correct kind with
`new_engagement.ps1 -Kind ...` when you claim a slot.

**Rules:**

- Pick the next free number **inside the range** for that activity type.
- Do not turn an in-progress malware slot into a CTF entry; use a new number in the CTF range.
- Set `-Kind` at scaffold time; do not rely on fixing `engagement_kind` later after filling templates.

### Folder names are aliases (mental model)

The directories are named for the file-analysis track. For other kinds, read them as phases:

| Path | `file` | `ctf` | `lab` | `hunt` |
|------|--------|-------|-------|--------|
| `00_original/` | Acquisition receipt | Challenge brief | Lab brief / objectives | Scope / hypothesis |
| `01_static/` | Static triage | Recon / enumeration | Step log | Queries / collection |
| `02_dynamic/` | Dynamic triage | Solve attempt | Results / proof | Timeline / analysis |
| `03_findings/` | Verdict + IOC slice | **Writeup** (portfolio) | **Reflection** | **Outcome** |

### Tracker columns by kind

| Column | `file` | `ctf` / `lab` | `hunt` |
|--------|--------|---------------|--------|
| `sha256`, `mb_url` | Fill from Bazaar / acquisition | Leave blank | Blank unless a hash is confirmed |
| `name_tag` | Filename or label | Challenge or module title (`-Title`) | Short hunt title |
| `platform` | Usually empty | HackTheBox, TryHackMe, SANS, etc. | Optional (e.g. tool or dataset name) |
| `score_flag` | Optional notes | Public-safe only: `solved`, `20 pts` — **never** a raw flag | e.g. `closed`, `detections_found` |
| `vm_folder_hint` | VM path to sample on disk | Usually empty | Usually empty |
| `notes` | Analysis reminders | Retired date, writeup-safe reminder | Data sources, timebox |

### Shared artifacts — use or skip

| Artifact | `file` | `ctf` | `lab` | `hunt` |
|----------|--------|-------|-------|--------|
| `00`–`03`, `50_screenshots/` | Yes | Yes | Yes | Yes |
| `40_iocs/indicators.csv` | Yes | **No** | **No** | Yes (confirmed IOCs only) |
| `20_notes/MITRE-coverage.md` | Primary | Optional | Optional | When mapping techniques |
| `20_notes/skills-coverage.md` | Yes | **Yes** | **Yes** | Yes |
| `04_writeups/` | Optional deep report | Optional (usually skip) | Optional | Optional |

CTF/lab indicators belong in `03_findings` tables or frontmatter — not in the shared IOC CSV.

### Status names are kind-specific

Do not use file statuses (`static`, `dynamic`, `done`) on CTF/lab/hunt rows. Use the
lifecycle in [Status lifecycles](#status-lifecycles) below. Wrong statuses confuse
`close_sample.ps1` checklists and `INDEX.md` export grouping.

### Before every commit (all kinds)

```powershell
# If screenshots changed:
powershell -ExecutionPolicy Bypass -File .\30_scripts\strip-exif.ps1 -SampleId sample_XX

powershell -ExecutionPolicy Bypass -File .\30_scripts\redact-check.ps1

# Terminal status for your kind, then validate + regen index:
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 `
    -SampleId sample_XX -Status <kind-terminal-status> -RunValidate -RunExport
```

Kind-terminal statuses: `done` (file), `writeup_done` (ctf), `reviewed` (lab), `closed` (hunt).

After closing a non-file engagement, update [`20_notes/skills-coverage.md`](./20_notes/skills-coverage.md)
from the `skills[]` list in `03_findings` frontmatter.

### Common mistakes

| Mistake | Fix |
|---------|-----|
| HTB work in a slot still `engagement_kind: file` | Scaffold with `-Kind ctf` in the CTF slot range |
| `-Status done` on a CTF row | Use `solved` / `writeup_done` |
| Raw flag in markdown or `score_flag` | Redact; use `[FLAG REDACTED]` until retired |
| Challenge IPs in `40_iocs/indicators.csv` | Keep observables in `03_findings` only |
| Filling malware-only `04_writeups` for a CTF | Put the portfolio narrative in `03_findings` |
| `02_dynamic` left empty but CTF marked solved | Add solve steps — `validate.ps1` check 14 warns on thin logs |

### Tier 1 success criteria

- At least one **closed** `ctf` or `lab` and one **closed** `hunt` visible under the correct section in [`INDEX.md`](./INDEX.md).
- `validate.ps1` exits OK before commit.
- Malware slots in your reserved file range stay free of CTF/lab content.
- No new folders required — only discipline on kind, slot, status, and where data lives.

For step-by-step tracks, see [`WORKFLOW.md`](./WORKFLOW.md) (Tracks A–D).

---

## Status lifecycles

Each kind has its own set of valid statuses. Use `close_sample.ps1 -SampleId N -Status <value>` to advance.

### file
`queued` -> `static` -> `dynamic` -> `done`

### ctf
`assigned` -> `recon` -> `stuck` | `solved` -> `writeup_done`

### lab
`not_started` -> `in_progress` -> `objectives_met` -> `reviewed`

### hunt
`scoped` -> `collecting` -> `analyzing` -> `closed`

---

## Scaffolding a new engagement

All engagement types use the same script with a `-Kind` flag.

```powershell
# File sample (default)
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 7

# CTF challenge (HackTheBox machine)
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 7 -Kind ctf -Platform "HackTheBox" -Title "Lame"

# Training lab (TryHackMe room)
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 8 -Kind lab -Platform "TryHackMe" -Title "Introductory Researching"

# Threat hunt
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 9 -Kind hunt -Title "Lateral movement via SMB"
```

`new_sample.ps1` still works as a backwards-compatible alias for `-Kind file`.

### Optional long-form report (`04_writeups`)

`03_findings` is the required outcome per kind. Use `04_writeups` only when you want a portfolio-deep narrative.

| Kind | Template | Scaffold |
|------|----------|----------|
| `file` | [`04_writeups/_templates/file.md`](./04_writeups/_templates/file.md) | `scaffold_writeup.ps1 -Kind file` |
| `ctf` | [`ctf.md`](./04_writeups/_templates/ctf.md) | `-Kind ctf` |
| `lab` | [`lab.md`](./04_writeups/_templates/lab.md) | `-Kind lab` |
| `hunt` | [`hunt.md`](./04_writeups/_templates/hunt.md) | `-Kind hunt` |

```powershell
# With new engagement
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 `
    -NextNumber 7 -Kind ctf -Platform "HackTheBox" -Title "Lame" -WithLongWriteup

# Standalone (infers kind from tracker when -Kind omitted)
powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 -NextNumber 7 -Kind ctf -Overwrite
```

Pre-seeded `04_writeups/sample_01`–`sample_50` files are **file**-oriented until you scaffold with `-Overwrite`. See [`04_writeups/README.md`](./04_writeups/README.md).

---

## Frontmatter by kind

All findings/writeup files carry YAML frontmatter. `schema_version: 2` is for
any non-file kind, or new file engagements. `schema_version: 1` files are
legacy file engagements and continue to validate under v1 rules.

### Shared fields (all kinds)

```yaml
schema_version: 2
engagement_id: sample_XX
engagement_kind: ctf      # file | ctf | lab | hunt
title: "Challenge Name"
analyst: Surrplexie
date_started: "2026-05-11"
date_closed: "2026-05-11"
status: writeup_done
outcome: success          # success | partial | failed | abandoned
confidence: high          # high | medium | low
tags:
  - web
  - sqli
skills:
  - SQL injection
  - enumeration
```

### file-specific additions (schema v1 or v2)

```yaml
sha256: <64-char hex>
phase: findings
date_acquired: "2026-05-11"
date_analyzed: "2026-05-11"
verdict: malicious         # benign | suspicious | malicious | unknown
family_guess: "AgentTesla"
family_confidence: medium-high
mitre_techniques:
  - T1547.001
mb_url: "https://malwarebazaar.abuse.ch/..."
procmon_run: true
dynamic_complete: true
```

### ctf-specific additions

```yaml
platform: "HackTheBox"    # HackTheBox | TryHackMe | PicoCTF | CTFtime | internal | other
category: "web"           # web | pwn | rev | crypto | forensics | misc | osint | ...
difficulty: "medium"      # easy | medium | hard | insane
points: 20
solved: true
public_writeup_safe: true # only true after challenge is retired / writeup release is allowed
```

### lab-specific additions

```yaml
course: "TryHackMe"
module: "Pre-Security Path"
environment: "thm-vm-01"  # VM name only - no credentials, no IPs
objectives:
  - "Understand Linux fundamentals"
  - "Configure basic networking"
objectives_met: true
```

### hunt-specific additions

```yaml
hypothesis: "Attacker used scheduled tasks for persistence"
data_sources:
  - "Windows Event Log (4698, 4702)"
  - "Sysmon EventID 1 (process creation)"
timebox: "2 hours"
detections_found: true
ioc_count: 0              # real IOCs only; leave 0 if none confirmed
```

---

## Portfolio and INDEX

`export-summary.ps1` groups the `INDEX.md` by kind so the index reads as a
complete portfolio book rather than a single flat sample list.

Sections generated:
- **File analyses** — traditional malware triage table
- **CTF write-ups** — challenge, platform, difficulty, solved status
- **Labs** — course, module, objectives met
- **Threat hunts** — hypothesis, outcome, detections

---

## Evidence rules (apply to all kinds)

- No raw flags, passwords, VPN configs, or lab credentials in any committed file.
- `score_flag` in the tracker is for public-safe summary only (e.g. "solved", "20 pts") - never a raw flag string.
- `redact-check.ps1` also scans for CTF flag patterns (`HTB{`, `flag{`, `THM{`, `picoCTF{`) and lab credential patterns.
- Screenshots follow the same EXIF hygiene rules: strip before commit.

---

## Quick decision guide

```
Is this a single file from MalwareBazaar or a direct drop?  -> Kind: file
Is this a CTF/HackTheBox/TryHackMe challenge?               -> Kind: ctf
Is this a structured training lab or course module?         -> Kind: lab
Is this a detection/threat hunting exercise?                -> Kind: hunt
```

---

## Adding a new kind (future)

1. Add the kind string to the `ValidateSet` in `new_engagement.ps1`.
2. Create templates in `new_engagement.ps1` for all four phases.
3. Add kind-specific status values to `close_sample.ps1`.
4. Add kind-specific checks to `validate.ps1`.
5. Add kind-specific sections to `export-summary.ps1`.
6. Update the schema CHANGELOG.
7. Update this file.

---

*See [README.md](./README.md) for full repo overview.*  
*See [WORKFLOW.md](./WORKFLOW.md) for step-by-step per-kind workflow.*
