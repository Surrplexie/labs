# 04_writeups

**Optional long-form narrative reports.** Not required per slot — `03_findings` is the indexed, validated, primary artifact for every engagement kind.

---

## Two-layer model

| Layer | File | Role | Audience |
|-------|------|------|----------|
| **Required** | `03_findings/sample_XX.md` | Verdict / outcome · IOC slice · portfolio blurb · YAML for `INDEX.md` | Recruiters, automation, `export-summary.ps1` |
| **Optional** | `04_writeups/sample_XX.md` | Long-form story: hiring packet, walkthrough, course narrative, detection write-up | Humans reading for depth |

`04` **pulls from** `00`–`03` via short summaries and `evidence_index` links. It does not duplicate entire phase logs.

---

## When to write a `04`

### `file` — malware / artifact

| Write `04` when | Skip `04` when |
|-----------------|----------------|
| Employer-grade report needed (MITRE narrative, detection ideas, limitations) | `03_findings` blurb + IOC table is enough |
| Deep analysis warrants a story arc | Analysis is routine; outcome is already clear in `03` |

**`04` is not:** a copy of every `01_static` line, or a second IOC table. Point to `03` findings instead.

---

### `ctf` — HackTheBox / TryHackMe / competition

| Write `04` when | Skip `04` when |
|-----------------|----------------|
| Blog-style walkthrough with story arc, rabbit holes, teaching notes | Challenge is active or writeup is not yet permitted |
| Machine is retired and you want a public-safe narrative beyond `03` | `03_findings` methodology section covers it |

**`04` is not:** raw flags, VPN credentials, or a paste of every command from `02_dynamic` (that stays there).

---

### `lab` — guided course / module

| Write `04` when | Skip `04` when |
|-----------------|----------------|
| Portfolio rubric / curriculum narrative useful for resume or review | `03_findings` reflection + skills list is enough |
| Lab teaches a technique directly applicable to malware work (cross-link to `file` sample) | Lab is a brief exercise with no portfolio value |

**`04` is not:** a paste of the full lab PDF, course credentials, VPN config, or instance IPs.

---

### `hunt` — hypothesis-driven detection

| Write `04` when | Skip `04` when |
|-----------------|----------------|
| Detection-engineering depth beyond `03` outcome (tuning notes, Sigma sketch, FP reasoning) | `03_findings` + `45_hunt_queries/` covers the output |
| Hunt result warrants a formal write-up for team / portfolio | Hunt was a quick negative result |

**`04` is not:** live corporate queries with real hostnames. Sanitize before committing. Reusable queries belong in [`45_hunt_queries/`](../45_hunt_queries/README.md).

---

## Scaffold a kind-correct writeup

Templates live in [`_templates/`](./_templates/README.md). Files are **created on demand** — no stubs are pre-seeded.

```powershell
# At engagement creation (all four phases + 04 in one step)
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 `
    -NextNumber 37 -Kind ctf -Platform "HackTheBox" -Title "Lame" -WithLongWriteup

# After the fact — infers kind from tracker when -Kind omitted
powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 -SampleId sample_37

# Explicit kind + title
powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 `
    -SampleId sample_37 -Kind ctf -Platform "HackTheBox" -Title "Lame"

# Minimal placeholder ("I will write this up later")
powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 `
    -SampleId sample_07 -Kind stub
```

---

## Evidence rules

| Rule | Detail |
|------|--------|
| No raw flags | Challenge flag strings — use `[FLAG REDACTED]` instead |
| No credentials | VPN keys, passwords, lab IPs, course login details |
| No non-VM host paths | Same rules as `redact-check.ps1` everywhere |
| IOC CSV scope | `40_iocs/indicators.csv` — **file** and **hunt** confirmed IOCs only. Never CTF/lab. |
| Hunt queries | Sanitize hostnames and user accounts. Reusable logic → `45_hunt_queries/` |

Run `redact-check.ps1` before committing any `04` file.

---

## Validation

`04_writeups` is **not** part of the four-phase integrity pipeline — empty `04` files never block a commit.

When a `04` file **does** exist for an active slot, `validate.ps1` **check 19** WARNs if the frontmatter `engagement_kind` is missing or does not match `samples_tracker.csv`. Fix with `scaffold_writeup.ps1 -Kind <correct> -Overwrite`.

---

## Folder layout

```
04_writeups/
  README.md              ← this file
  _templates/
    file.md              ← malware long-form (12 sections)
    ctf.md               ← CTF / HTB / THM walkthrough
    lab.md               ← course lab narrative
    hunt.md              ← detection-engineering write-up
    _stub.md             ← minimal placeholder (5-line frontmatter)
    README.md
  sample_01.md           ← created by scaffold_writeup.ps1 when you need it
  sample_37.md           ← CTF example (kind: ctf)
  ...                    ← only slots where you actually write a long report
```

**No stubs are pre-seeded.** Files are created on demand via `scaffold_writeup.ps1`. One `04` file per slot ID maximum; use the same `sample_XX` number as every other phase folder.

---

## Relationship to `03_findings`

```
03_findings/sample_XX.md   ← primary: YAML frontmatter, IOC slice, blurb
        │
        └── 04_writeups/sample_XX.md  ← optional: narrative, context, story
                │
                └── evidence_index links back to 00–03 + 50_screenshots
```

`03` is the truth source for `INDEX.md`. `04` is extra depth — written for a person, not for automation.
