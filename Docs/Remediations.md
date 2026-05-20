Dev logs rules; REM-1, REM-2 any of these terms are the new 'updates' like "Update 1", all major logs entered here. Note; REM-1.2, REM-1.4 etc. are only for GitHub commits and pushing, never named here.

---

## REM-1

**When:** 2026-05-18 (session start)

**What:** Reviewed `30_scripts/build_exe.ps1`, `.github/workflows/release.yml`, and multi-kind repo layout; produced a **plan** (Tiers 1–5) before implementation. No Tier 2–5 code in this step.

### Build / release pipeline (reviewed)

- **Pin status:** PyInstaller **6.20.0** is current on PyPI; `30_scripts/build_requirements.txt` is the intended single pin source.
- **`build_exe.ps1` role:** Installs pinned PyInstaller, builds `workflow_gui.exe`, writes `dist/SHA256SUMS.txt` with source hash + binary hash + metadata.
- **`release.yml` role:** Integrity gate → pinned install → `build_exe.ps1 -SkipPipInstall` → SBOM → GitHub Release assets (`workflow_gui.exe`, `SHA256SUMS.txt`, `sbom.cdx.json`).
- **Frozen `.exe` model:** Binary shells out to repo `30_scripts/*.ps1`; user must point GUI at full clone (`--repo`); not a self-contained copy of all scripts inside the exe.

### Tier 1 — planned optional build/doc fixes (not all done in later REMs)

- **Docs drift (noted for fix):**
  - `WORKFLOW-GUI.md` had said `pip install --upgrade pyinstaller` → should describe **pinned** install from `build_requirements.txt` (later fixed in repo; see grep).
  - `release.yml` release-notes fragment had broken table row `| $pin | |` → should be `| PyInstaller | $pin |` (later fixed in repo).
  - Root `README.md` had said `schema_version: 1` only in places while v2 exists for ctf/lab/hunt (addressed in **REM-5**).
- **Build script enhancements (discussed; partially present in tree outside this log):**
  - UTC timestamps in `SHA256SUMS.txt` (use `Get-Date -AsUtc` on Windows).
  - **tkinter** pre-check before PyInstaller (GUI needs tkinter).
  - Read PyInstaller version only from `build_requirements.txt` (drop duplicate `$PYINSTALLER_VERSION` constant in script).
  - Optional `-Clean` to remove `dist/_build_tmp` / `dist/_spec` after success.
- **Explicitly deferred in plan:** PyInstaller bump (pin already latest), code-signing, bundling PS1 into exe, mandatory `04_writeups` in validate.

### Multi-kind architecture (agreed baseline for REM-2–5)

- **One slot system:** `sample_01`–`sample_50` (extendable to `sample_99`) across `00_original` → `03_findings`, plus `50_screenshots/`.
- **Four kinds:** `file` (malware primary), `ctf`, `lab`, `hunt` — same folders, **different phase meaning** per kind (`ENGAGEMENTS.md` phase map).
- **`03_findings` = required “done” artifact** per slot; **`04_writeups` = optional** portfolio-deep layer (Tier 2).
- **`40_iocs/indicators.csv`:** `file` + confirmed `hunt` IOCs only — not CTF flags or lab creds.

**Outcome:** User approved phased work; **REM-2 through REM-5** implemented below.

---

## REM-2

**When:** 2026-05-18

**What:** **Tier 2 — Fix `04_writeups` for non-malware** (high value; still under `04_writeups/`, not a new top-level phase).

### Problem

- Pre-seeded `04_writeups/sample_01.md`–`sample_50.md` were **one malware mega-outline** (18 sections: MITRE narrative, detection engineering, chain of custody, YARA hunts, etc.).
- `new_engagement.ps1` did **not** scaffold `04_writeups` — only `00`–`03` + screenshots.
- `04_writeups/README.md` claimed all kinds but templates were file-only.

### New templates (`04_writeups/_templates/`)

| Template | Sections / intent |
|----------|-------------------|
| **`file.md`** | Generated from `sample_01.md` with `SAMPLE_ID` placeholders — full malware long-form report (unchanged structure). |
| **`ctf.md`** | Challenge overview, recon summary, attack narrative, rabbit holes, tooling, skills, portfolio blurb, ethics (no raw flags), redacted flag proof. |
| **`lab.md`** | Objectives rubric, procedure highlights, results/proof, reflection, link to malware work optional, no credentials/IPs. |
| **`hunt.md`** | Scope/hypothesis, query log, analysis narrative, detections, FPs, detection engineering, link to `45_hunt_queries/` (added further in REM-3). |
| **`_templates/README.md`** | Naming, frontmatter contract, scaffold commands. |

**Placeholder tokens at scaffold time:** `SAMPLE_ID`, `ANALYST`, `DATE`, `TITLE_VAL`, `PLATFORM_VAL`, `KIND_VAL`.

### New script: `30_scripts/scaffold_writeup.ps1`

- Copies `_templates/{kind}.md` → `04_writeups/sample_NN.md`.
- Parameters: `-SampleId` or `-NextNumber`, `-Kind`, `-Title`, `-Platform`, `-Analyst`, `-Overwrite`.
- Infers `-Kind` from `samples_tracker.csv` when omitted.
- Refuses overwrite unless `-Overwrite`.

### `new_engagement.ps1` changes

- New switch: **`-WithLongWriteup`** — after scaffolding `00`–`03` + tracker, invokes `scaffold_writeup.ps1` with same kind/title/platform.
- **`-OverwriteEmpty`** passed through as `-Overwrite` for writeup when re-scaffolding empty slot.
- Per-kind “next steps” text mentions optional `scaffold_writeup.ps1` or `04_writeups` path when `-WithLongWriteup` used.

### Documentation

- **`04_writeups/README.md`** — when to use `04` vs `03` per kind; scaffold commands; evidence rules (no flags in `04`).
- **`ENGAGEMENTS.md`** — optional long-form table by kind + examples.
- **`30_scripts/README.md`** — `scaffold_writeup.ps1` in quick reference + `new_engagement` params.
- **Root `README.md`** — Quick nav link to `04_writeups/` README + templates.

### Example commands

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 `
    -NextNumber 7 -Kind ctf -Platform "HackTheBox" -Title "Lame" -WithLongWriteup

powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 `
    -SampleId sample_07 -Kind ctf -Platform "HackTheBox" -Title "Lame" -Overwrite
```

### Validation policy

- **`04_writeups` remains outside `validate.ps1`** — optional; empty `04` does not block commit.

---

## REM-3

**When:** 2026-05-18

**What:** **Tier 3 — New supporting areas beyond `04`** (malware core stays `00`–`03` + `40_iocs`; cross-engagement trackers and hunt query library).

### New folder: `45_hunt_queries/`

- **`README.md`** — purpose (reusable sanitized queries vs one-off paste in `01_static`); frontmatter contract (`query_id`, `platform`, `data_sources`, `mitre_techniques`, `tags`, `related_samples`, `status`); linking from hunt `01_static` and `query_refs` in `03_findings`; sanitization rules.
- **`INDEX.md`** — hand-maintained catalog table (by query_id, platform, MITRE, samples, status).
- **`_examples/`** — `schtasks-persistence.md` (Sigma example), `sysmon-rare-parent-child.kql`, `_examples/README.md` (copy-only, do not reference from live slots).

### New script: `30_scripts/new_hunt_query.ps1`

- Scaffolds `45_hunt_queries/<query_id>.md` (kebab-case enforced).
- `-Platform`: `splunk` | `kql` | `elastic` | `sigma` | `other` — fenced starter block per platform.
- Prompts to update `INDEX.md` after creation.

### New `20_notes/` trackers

| File | Role |
|------|------|
| **`ctf-machine-index.md`** | Platform, machine name, category, difficulty, slot, status, solved, `public_writeup_safe`, notes — no raw flags. |
| **`lab-curriculum-map.md`** | Course/platform, module, slot, status, skills summary — no VPN/passwords/IPs. |
| **`detection-catalog.md`** | Cross-engagement detection ideas (`DET-xxx` rows); links to `45_hunt_queries/`, `04_writeups`, `03_findings`; file + hunt only. |
| **`ctf-patterns/README.md`** | Cross-challenge technique notes (parallel to `case-series/` for malware); template for new pattern files. |

### `20_notes/README.md` rewrite

- Organized by **malware / CTF / lab / hunt / all kinds**.
- Navigation table to `45_hunt_queries/`, MITRE, tooling refs, skills tracker.
- Explicit “what does not live here” (per-slot logs, `40_iocs` scope).

### Wiring into engagement flow

- **`new_engagement.ps1` — hunt `01_static` template:** “Queries run” table column **Library ref / tool**; HTML comment pointing to `45_hunt_queries/README.md`.
- **Hunt `03_findings` template:** `query_refs: []` in YAML.
- **`04_writeups/_templates/hunt.md`:** `query_refs` in frontmatter; `evidence_index.hunt_queries`; link to library in query appendix.
- **`20_notes/hunt-reference.md`:** link to `45_hunt_queries/` + `new_hunt_query.ps1`.
- **`20_notes/case-series/README.md`:** scoped to **file malware**; points CTF to `ctf-patterns/`, hunt to `detection-catalog` + `45_hunt_queries/`.
- **`40_iocs/README.md`:** reinforced — CTF/lab never use CSV; hunt queries ≠ IOC rows; pointer to `detection-catalog.md`.

### `validate.ps1` — new check 16

- **Hunt query_refs library check** for non-empty `hunt` rows:
  - Parses `query_refs:` list in `03_findings/sample_XX.md`.
  - Parses `45_hunt_queries/<slug>.md` links in `01_static/sample_XX.md`.
  - **WARN** if referenced slug missing under `45_hunt_queries/` (skips `_examples`).

### `redact-check.ps1`

- Also scans **`.kql`, `.spl`, `.yaml`, `.yml`** under `45_hunt_queries/` (in addition to `.md`, `.csv`, `.txt` elsewhere).

### `close_sample.ps1` (hunt)

- Checklist: reusable queries linked from `45_hunt_queries/` where applicable.
- On **closed:** `query_refs` resolve under `45_hunt_queries/`.

### `ENGAGEMENTS.md` — Tier 3 section + slot convention

- Supporting areas table (`45_hunt_queries`, ctf-machine-index, lab-curriculum-map, detection-catalog, ctf-patterns, skills-coverage).
- **Recommended slot ranges (convention, not enforced by scripts):**
  - `sample_01`–`30` → `file`
  - `sample_31`–`40` → `ctf`
  - `sample_41`–`45` → `lab`
  - `sample_46`–`50` → `hunt`
- Folder names as **aliases** mental model (`01_static` = recon for CTF, collection for hunt, etc.).

### Root `README.md` (partial)

- Repository tree updated: `45_hunt_queries/`, expanded `20_notes/` file list.

**Validate count after REM-3:** **16 checks** (added check 16).

---

## REM-4

**When:** 2026-05-18 / 2026-05-20

**What:** **Tier 4 — Tooling / GUI (`30_scripts`)** + validate depth for lab/hunt (mirror CTF check 14).

### `workflow_gui.py` → **v3.1.0**

#### New Engagement tab

- **`_file_panel` frame** — hashes (SHA256/SHA1/MD5), FILE INFO (filename, mime, size, MB URL), YARA `ScrolledText` — **grid_remove** entire panel when kind ≠ `file`.
- **`_bazaar_panel` frame** — “First seen (Bazaar UTC)” only — hidden for ctf/lab/hunt.
- **Kind change handler (`_on_kind_change`)** — no longer toggles individual hash/YARA widgets; toggles panels + file-only verdict/confidence/family/Procmon flags + ctf/lab/hunt field sets (unchanged logic for kind-specific rows).
- **MITRE row** — visible for `file` **and** `hunt` only.
- **Skills / outcome** — visible for non-file kinds.

#### Tools tab (kind-aware)

- **Context sample ID** field at top + **Refresh kind** + **From Screenshots tab** (copies screenshot slot into context).
- **Kind label** — shows detected `engagement_kind` from `samples_tracker.csv` via `get_kind_for_slot()`.
- **Sync:** Update Engagement ID change sets context SID; Procmon and Event ingest SID fields follow context.
- **`_tools_hunt_frame` (LabelFrame)** — shown for **`hunt` only:**
  - Event ingest (SIEM/Sysmon CSV), host filter, EventID filter (default `1,3,10,11,13`), dry run.
  - Button **“New hunt query (scaffold)”** → `new_hunt_query.ps1` with `simpledialog` for query_id + title.
- **`_tools_procmon_frame` (LabelFrame)** — shown for **`file` only:** Procmon CSV browse, process filter, dry run, Ingest Procmon.
- **`_tools_kind_note`** — ctf/lab: message to use New/Update Engagement tabs (no ingest UI).
- **Common tools unchanged:** Validate, Export, Redact, Strip EXIF (all kinds).

#### Runtime guards

- **`_run_ingest_procmon`:** `messagebox.showwarning` if slot `engagement_kind` ≠ `file`.
- **`_run_ingest_events`:** warning if slot ≠ `hunt`.

#### Imports / docstring

- `from tkinter import simpledialog` for hunt query scaffold prompts.
- Module docstring: malware primary; v3.1 kind-specific Tools tab.

### `validate.ps1` — checks 17 and 18

| Check | Trigger | Rules |
|-------|---------|--------|
| **17 — Lab completion depth** | `lab` + status `reviewed` or `objectives_met` | WARN if `01_static` &lt; 25 lines or &gt; 8 placeholders (`PENDING`, `TODO`, `<FILL>`, etc.); WARN if `03_findings` missing/empty `objectives` / `objectives_met`. |
| **18 — Hunt collection depth** | `hunt` + status `closed` | WARN if thin `01_static` without `45_hunt_queries` link; WARN if no “Queries run” table content and no library link. |

**Full validate list (18):** 1 CSV schema · 2 phase files · 3 SHA256 file · 4 content depth · 5 frontmatter · 6 SHA256 cross-check · 7 IOC CSV · 8 orphans · 9 forbidden extensions · 10 screenshots · 11 schema_version · 12 secret/flag scan · 13 engagement_kind · 14 CTF solve depth · 15 skills · 16 hunt query_refs · 17 lab depth · 18 hunt collection depth.

### Documentation / CI count sync

- **`WORKFLOW-GUI.md`** — Tools tab row: kind-aware ingest description.
- **`ENGAGEMENTS.md`** — GUI table (file vs hunt vs ctf/lab).
- **Root `README.md`** — 18 checks in automation section; script table `validate.ps1` line fixed (was 15).
- **`30_scripts/README.md`** — validate section 18 checks + summary list.
- **`.github/workflows/integrity.yml`** — comment “18 checks”.
- **`workflow_gui.py` Tools** — Validate button description “18 structural checks”.

### Unchanged by design

- **`04_writeups` not validated** — still optional per slot.

---

## REM-5

**When:** 2026-05-20

**What:** **Tier 5 — Positioning / README identity** (malware primary; secondary tracks explicit for reviewers and future-you).

### Core message

- **One logbook**, not four repos.
- **Primary portfolio signal:** `file` malware triage → `INDEX.md` **File analyses** + `03_findings` blurbs + optional `04_writeups` malware reports.
- **Secondary:** `ctf`, `lab`, `hunt` share slots and automation but appear in **separate INDEX sections** with different status lifecycles and templates.

### `README.md` (root)

- **Tagline block** — “Malware triage logbook (primary)” + secondary tracks sentence.
- **New section: Repository identity** — table (primary/secondary/finished artifact/not second logbook); reviewer read order; slot convention link to `ENGAGEMENTS.md`.
- **Purpose** — malware analysis discipline first; other kinds in same index without diluting identity.
- **Who This Is For** — recruiters → INDEX File analyses first; learners split by WORKFLOW track / ENGAGEMENTS; researchers → `40_iocs` scope.
- **Engagement Kinds** intro — one logbook four kinds; file = default mental model; link to phase folder alias table.
- **Workflow GUI table** — Tools row reflects kind-aware Procmon vs hunt ingest.
- **Script table** — `validate.ps1` = 18 checks (was stale at 15).

### `ENGAGEMENTS.md`

- Opening paragraph: **malware-triage primary**, secondary tracks explained.
- **Portfolio / INDEX presentation** — export grouping: File analyses → CTF → Labs → Hunts; `03_findings` vs `04_writeups`.

### `WORKFLOW.md`

- Intro: **Track A (file) = primary**; Tracks B–D secondary with link to `ENGAGEMENTS.md`.

### `30_scripts/README.md`

- Opening: malware-primary logbook, same scripts for all kinds.
- `validate.ps1`: 18 checks, abbreviated numbered summary including 14–18.

### Minor

- **`30_scripts/workflow_gui.py`** — module docstring alignment.
- **`RELEASE-VERIFICATION.md`** — disclaimer: personal security logbook, malware primary, also CTF/lab/hunt docs.

### Reviewer path (documented)

1. Open [`INDEX.md`](../INDEX.md) after `export-summary.ps1`.
2. Read **File analyses** for malware hiring signal.
3. Use **CTF write-ups**, **Labs**, **Threat hunts** sections only when relevant — same repo, clearly labelled.

---

## REM-6

**When:** 2026-05-20

**What:** **Habits and data (no code)** plus **small automation gaps** from post–REM-5 plan review — slot-band tracker, fresh INDEX, GUI parity for long writeups and band warnings.

### Part A — Habits and data (tracker + export)

| Change | Detail |
|--------|--------|
| **`samples_tracker.csv` slot bands** | Reserve rows pre-labeled: `sample_01`–`30` → `file`, `31`–`40` → `ctf`, `41`–`45` → `lab`, `46`–`50` → `hunt`. Notes column says which band (e.g. “Reserve -- CTF band (slots 31-40)”). `sample_01` stays active `file`. |
| **`sample_01` path scrub** | `vm_folder_hint` no longer has `C:\Users\win11\Downloads\...`; replaced with `VM downloads folder (hash-named subfolder)` (host path kept out of git). |
| **`INDEX.md` + `dist/summary.json`** | Ran `export-summary.ps1` — index now **50 slots**, **49 reserve**, timestamp **2026-05-20** (was stale 2026-05-11 / 6 slots). |

**Convention:** Documented in [`ENGAGEMENTS.md`](../ENGAGEMENTS.md); tracker now matches it for empty reserves. Not enforced by validate (soft convention).

### Part B — Automation (`new_engagement.ps1`, GUI, docs)

| Change | Detail |
|--------|--------|
| **`new_engagement.ps1`** | `Get-ExpectedEngagementKindForSlot` — **Write-Warning** if `-Kind` disagrees with band (01–30 file, 31–40 ctf, 41–45 lab, 46–50 hunt); script still runs. |
| **`workflow_gui.py`** | **`-WithLongWriteup` checkbox** on New Engagement → passes switch to `new_engagement.ps1` (scaffolds `04_writeups` via `scaffold_writeup.ps1`). **Slot # trace** + **Auto-detect** set kind from tracker (then band). **Create** shows Yes/No dialog on band mismatch (mirrors PS warning). Helper: `expected_engagement_kind_for_slot()`. |
| **`WORKFLOW.md`** | Tracks B/C/D: “first use of slot” note — pre-seeded `04` is file-shaped; use `scaffold_writeup.ps1 -Overwrite` or `-WithLongWriteup`. |
| **`WORKFLOW-GUI.md`** | Documents checkbox, slot-band sync, and mismatch warning. |

**GUI version:** Still **v3.1.0** (`APP_VERSION` unchanged — behavior-only patch in source; tag release when ready).

### Commands used

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\export-summary.ps1
powershell -ExecutionPolicy Bypass -File .\30_scripts\validate.ps1
```

**Validate after REM-6:** 15 PASS, 0 WARN, 0 FAIL.

### Files touched (REM-6)

| File | Change |
|------|--------|
| `samples_tracker.csv` | Band `engagement_kind`, reserve notes, `sample_01` vm_folder_hint |
| `INDEX.md`, `dist/summary.json`, `dist/portfolio.json` | Regenerated by export |
| `30_scripts/new_engagement.ps1` | Slot-band warning |
| `30_scripts/workflow_gui.py` | Long writeup checkbox, band hint/warn |
| `WORKFLOW.md` | 04 first-use notes (Tracks B/C/D) |
| `30_scripts/WORKFLOW-GUI.md` | GUI docs |

---

## REM-7

**When:** —

**What:** *Reserved — next remediation entry.*

### Open follow-ups (carry-forward)

| Item | Status |
|------|--------|
| **`build_linux.sh` parity** with `build_exe.ps1` (UTC, tkinter, pin from `build_requirements.txt`) | **Done in tree** (REM-1 review; no REM-6 code change) |
| **`build_exe.ps1 -Clean`** | Not implemented |
| **CI smoke** of `workflow_gui` on PRs | Deferred |
| **Tag `v3.1.0`** (or patch) for GitHub Release after GUI changes | User action when ready — [`RELEASE-TAGGING.md`](../RELEASE-TAGGING.md) |

### Quick reference — files touched across REM-2–6

| Area | Key paths |
|------|-----------|
| Writeups | `04_writeups/_templates/*`, `30_scripts/scaffold_writeup.ps1` |
| Hunt queries | `45_hunt_queries/`, `30_scripts/new_hunt_query.ps1` |
| Notes | `20_notes/ctf-machine-index.md`, `lab-curriculum-map.md`, `detection-catalog.md`, `ctf-patterns/` |
| GUI | `30_scripts/workflow_gui.py` (v3.1.0; REM-6 long-writeup + band UX) |
| Tracker / index | `samples_tracker.csv`, `INDEX.md` (REM-6) |
| Validate | `30_scripts/validate.ps1` (checks 16–18) |
| Identity docs | `README.md`, `ENGAGEMENTS.md`, `WORKFLOW.md`, `30_scripts/README.md`, `WORKFLOW-GUI.md` |
