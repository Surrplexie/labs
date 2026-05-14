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
- You are combining evidence from **multiple** slots into one story — pick one file as the host document and set `related_sample_id` in its YAML to the primary slot; link other slots in the body.

---

## Naming

| Pattern | Use |
|---------|-----|
| `sample_01.md` … `sample_50.md` | Same convention as other phase folders: **one long-form scaffold per slot ID**. Edit `04_writeups/sample_NN.md` when you want a deep writeup for that engagement. |

Files here are **not** part of the four-phase integrity check. Keep them free of host paths, credentials, and raw secrets; run `30_scripts/redact-check.ps1` before commit.

---

## Cross-links

Each `sample_NN.md` frontmatter `evidence_index` already points at the matching phase paths, for example for `sample_01`:

- [`../00_original/sample_01.md`](../00_original/sample_01.md) — acquisition
- [`../01_static/sample_01.md`](../01_static/sample_01.md) — static triage
- [`../02_dynamic/sample_01.md`](../02_dynamic/sample_01.md) — dynamic triage
- [`../03_findings/sample_01.md`](../03_findings/sample_01.md) — verdict + IOC slice + portfolio blurb
- [`../50_screenshots/sample_01/`](../50_screenshots/sample_01/) — screenshots + `SHOT_INDEX.txt`
- [`../40_iocs/indicators.csv`](../40_iocs/indicators.csv) — consolidated IOC rows

Open **[`sample_01.md`](./sample_01.md)** (or the `sample_NN.md` that matches your slot) and replace every `<FILL>` placeholder when you author the report.
