# 04_writeups

**Optional long-form narrative reports** — separate from the mandatory pipeline phases.

| Folder | Role |
|--------|------|
| `00_original` … `03_findings` | Tracked engagement phases validated by `validate.ps1` and indexed by `export-summary.ps1`. |
| **`04_writeups`** | Human-readable **deep writeups**: methodology, timelines, detection engineering, and appendices. **Not** required per slot. |

---

## When to use this folder

- You want a **portfolio-grade article** or **internal-style report** that would make `03_findings` too long.
- You need structured sections (executive summary, detection opportunities, chain-of-custody narrative) without changing the machine-oriented `03_findings` frontmatter contract.
- You are combining evidence from **multiple** slots into one story (then set `related_sample_id` accordingly in the writeup YAML).

---

## Naming

| Pattern | Use |
|---------|-----|
| `WRITEUP-TEMPLATE.md` | Canonical blank — copy to `WRITEUP_<topic_or_sample>.md` and fill. |
| `WRITEUP_sample_XX.md` | Per-engagement long form tied to one slot (example name). |

Files here are **not** part of the four-phase integrity check. Keep them free of host paths, credentials, and raw secrets; run `30_scripts/redact-check.ps1` before commit.

---

## Cross-links

Point back to the phase files and evidence:

- `../00_original/sample_XX.md` — acquisition
- `../01_static/sample_XX.md` — static triage
- `../02_dynamic/sample_XX.md` — dynamic triage
- `../03_findings/sample_XX.md` — verdict + IOC slice + portfolio blurb
- `../50_screenshots/sample_XX/` — screenshots + `SHOT_INDEX.txt`
- `../40_iocs/indicators.csv` — consolidated IOC rows

Start from **[`WRITEUP-TEMPLATE.md`](./WRITEUP-TEMPLATE.md)**.
