# 04_writeups

**Optional long-form narrative reports** — separate from the mandatory pipeline (`00` → `03`).

| Folder | Role |
|--------|------|
| `00_original` … `03_findings` | Tracked phases validated by `validate.ps1` and indexed by `export-summary.ps1`. |
| **`04_writeups`** | Portfolio-deep articles. **Not** required per slot. |
| **`_templates/`** | Kind-specific scaffolds (`file`, `ctf`, `lab`, `hunt`). |

---

## When to use this folder

| Kind | Primary artifact | Use `04_writeups` when… |
|------|------------------|-------------------------|
| `file` | `03_findings` (verdict + IOC slice) | You want employer-grade malware report (MITRE narrative, detection engineering) |
| `ctf` | `03_findings` (methodology writeup) | You want a blog-style walkthrough beyond the phase logs |
| `lab` | `03_findings` (reflection) | You want a curriculum / rubric narrative for portfolio |
| `hunt` | `03_findings` (outcome) | You want detection-engineering depth beyond query logs |

`03_findings` stays the machine-oriented contract and portfolio blurb source. `04` is extra narrative only.

---

## Scaffold a kind-correct writeup

Templates live in [`_templates/`](./_templates/README.md).

```powershell
# After scaffolding an engagement (recommended)
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 `
    -NextNumber 7 -Kind ctf -Platform "HackTheBox" -Title "Lame" -WithLongWriteup

# Or standalone (reads engagement_kind from tracker if -Kind omitted)
powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 `
    -NextNumber 7 -Kind ctf -Platform "HackTheBox" -Title "Lame"

# Replace an existing file-scaffold with a CTF template
powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 `
    -SampleId sample_07 -Kind ctf -Overwrite
```

---

## Naming

| Pattern | Use |
|---------|-----|
| `sample_01.md` … `sample_50.md` | One optional long-form file per slot ID |
| `_templates/*.md` | Source templates (do not edit per engagement) |

Pre-seeded `sample_01`–`sample_50` files use the **file** malware outline. For CTF/lab/hunt slots, run `scaffold_writeup.ps1` with the right `-Kind` (and `-Overwrite` if replacing).

---

## Evidence rules

- No raw flags (`HTB{`, `THM{`, …), passwords, VPN keys, or lab IPs.
- CTF/lab: do **not** use `40_iocs/indicators.csv` (see [`40_iocs/README.md`](../40_iocs/README.md)).
- Hunt: confirmed IOCs may go in `40_iocs` **and** the writeup.
- Run [`redact-check.ps1`](../30_scripts/redact-check.ps1) before commit.

Files here are **not** part of the four-phase integrity check. If a writeup exists for an
active slot, `validate.ps1` **check 19** warns when frontmatter `engagement_kind` does not
match `samples_tracker.csv`. When a writeup exists,
`validate.ps1` **check 19** warns if frontmatter `engagement_kind` does not match
`samples_tracker.csv`.

---

## Cross-links (example `sample_01`)

- [`../00_original/sample_01.md`](../00_original/sample_01.md)
- [`../01_static/sample_01.md`](../01_static/sample_01.md)
- [`../02_dynamic/sample_01.md`](../02_dynamic/sample_01.md)
- [`../03_findings/sample_01.md`](../03_findings/sample_01.md) — canonical findings
- [`../50_screenshots/sample_01/`](../50_screenshots/sample_01/)
- [`../40_iocs/indicators.csv`](../40_iocs/indicators.csv) — **file** and **hunt** only
