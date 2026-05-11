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
