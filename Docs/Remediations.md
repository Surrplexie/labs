Dev logs rules; REM-1, REM-2 any of these terms are the new 'updates' like "Update 1", all major logs entered here. Note; REM-1.2, REM-1.4 etc. are only for GitHub commits and pushing, never named here.

**Session arc (2026-05-18 → 2026-05-22):** Tiers 2–5 → **REM-6**–**REM-7** → **REM-8** deferred tier → **REM-9** `04_writeups` overhaul §1–4 → **REM-10** §5–6 (migration utility, close hint, writeup index, validate check 20).

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

**When:** 2026-05-20

**What:** **Schema / validate (tier 3)** + **build / release (tier 4)** — enforce `schema_version: 2` for non-file findings, optional `04` kind check, build cleanup flags, bump GUI to **3.1.1**.

### Part A — Schema and validate

| Change | Detail |
|--------|--------|
| **Check 11 (tightened)** | Active `ctf` / `lab` / `hunt` rows must have `schema_version: 2` in `03_findings` (WARN). `file` may use `1` or `2`. |
| **Check 19 (new)** | If `04_writeups/sample_XX.md` exists for an active slot: WARN when no YAML frontmatter, missing `engagement_kind`, or kind ≠ tracker. Skips slots with no `04` file. |
| **`new_engagement.ps1`** | Already emits `schema_version: 2` for ctf/lab/hunt templates (no change this REM). |
| **Docs** | `03_findings/README.md`, `04_writeups/README.md`, `30_scripts/schema/CHANGELOG.md` |

**Validate count:** **19 checks** (was 18).

### Part B — Build / release

| Change | Detail |
|--------|--------|
| **`build_exe.ps1 -Clean`** | After success, deletes `dist/_build_tmp` and `dist/_spec`. |
| **`build_linux.sh --clean`** | Same behavior on Linux. |
| **`APP_VERSION`** | `3.1.1` in `workflow_gui.py` (patch: validate 19, `-Clean`, REM-6 GUI UX already in tree). |
| **Release tag** | Intended tag: **`v3.1.1`** per [`RELEASE-TAGGING.md`](../RELEASE-TAGGING.md) — run `tag_release.ps1` when ready to publish binary (not pushed from this log). |

### Commands

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\validate.ps1
powershell -ExecutionPolicy Bypass -File .\30_scripts\build_exe.ps1 -SkipPipInstall -Clean
# When ready to ship:
powershell -ExecutionPolicy Bypass -File .\30_scripts\tag_release.ps1 -Tag v3.1.1
```

### Files touched (REM-7)

| File | Change |
|------|--------|
| `30_scripts/validate.ps1` | Checks 11 + 19 |
| `30_scripts/build_exe.ps1`, `build_linux.sh` | `-Clean` / `--clean` |
| `30_scripts/workflow_gui.py` | `APP_VERSION` 3.1.1, validate blurb 19 checks |
| `README.md`, `30_scripts/README.md`, `.github/workflows/integrity.yml` | 19-check docs |
| `03_findings/README.md`, `04_writeups/README.md`, `schema/CHANGELOG.md` | Schema / validate notes |

---

## REM-8

**When:** 2026-05-20

**What:** Closed plan tier **“5. Still defer”** — implement what fits; document what stays out of scope.

### Implemented

| Item | Detail |
|------|--------|
| **PyInstaller bump** | **No bump** — `6.20.0` still PyPI latest. `smoke_gui.ps1` queries PyPI and **warns** on drift (`-StrictPin` fails). |
| **PR / CI smoke** | `workflow_gui.py --smoke-test`; `30_scripts/smoke_gui.ps1`; `integrity.yml` jobs **gui-smoke** (Windows) + **gui-smoke-linux** (`py_compile`). |
| **Code-signing** | Optional `build_exe.ps1 -SignThumbprint` + env `WORKFLOW_GUI_SIGN_THUMBPRINT`; `RELEASE-VERIFICATION.md` section. |

### Permanently deferred (documented)

See [`Docs/DEFERRED.md`](DEFERRED.md):

- **Do not** bundle `30_scripts/*.ps1` inside the exe (thin binary + `--repo` model).
- **Do not** require `04_writeups` in validate (check 19 only when file exists).

### Version

- **`APP_VERSION` → 3.1.2** (adds `--smoke-test`). Tag **`v3.1.2`** when publishing release.

### Commands

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\smoke_gui.ps1
python .\30_scripts\workflow_gui.py --smoke-test
```

### Files touched (REM-8)

| File | Change |
|------|--------|
| `30_scripts/workflow_gui.py` | `--smoke-test`, v3.1.2 |
| `30_scripts/smoke_gui.ps1` | New |
| `30_scripts/build_exe.ps1` | Optional Authenticode sign |
| `.github/workflows/integrity.yml` | gui-smoke jobs |
| `Docs/DEFERRED.md` | New |
| `RELEASE-VERIFICATION.md`, `README.md`, `30_scripts/README.md`, `schema/CHANGELOG.md` | Docs |

---

## REM-9

**When:** 2026-05-22

**What:** **`04_writeups` overhaul — §1 Target model** (documentation only; no script or template structure changes).

### Target model (what `04` is for)

- **Two-layer contract:** `03_findings` = required, indexed, validated, automation-facing; `04_writeups` = optional, human-facing narrative that summarizes and links back — not a duplicate of phase logs.
- **Per-kind guidance** (`file` / `ctf` / `lab` / `hunt`): each has **write `04` when** vs **skip when** plus one line on what `04` is *not* (e.g. CTF: no raw flags, no command paste from `02_dynamic`; hunt: reusable queries → `45_hunt_queries/`).
- **CTF ethics:** `04` walkthrough only when machine is **retired** / writeup permitted — called out explicitly in the CTF table.
- **Relationship diagram:** `03` → `INDEX.md`; `04` → `evidence_index` back to `00`–`03` + `50_screenshots`.

### Documentation updated

- **`04_writeups/README.md`** — full rewrite: two-layer table, four per-kind decision tables, scaffold commands (`-WithLongWriteup`, `-Overwrite` for pre-seeded slots), evidence rules table, validation (check 19 only when file exists), folder structure diagram; removed duplicate check-19 paragraph.
- **`04_writeups/_templates/README.md`** — key sections per template, `engagement_kind` → template map, scaffold commands, “edit templates for structure only” note.
- **`ENGAGEMENTS.md`** — optional `04` section replaced: two-layer model, per-kind when/skip table, updated scaffold examples (`-SampleId`, `-Overwrite` on CTF/lab/hunt slots).

### Hygiene / validate

- **Flag-pattern false positives:** README evidence examples used inline code with platform-flag patterns → `validate.ps1` check 12 WARNs; reworded to generic "challenge flag strings" → **17 PASS, 0 WARN, 0 FAIL**.

### §2 — Problems fixed

| Problem | Fix |
|---------|-----|
| **50 identical pre-seeded stubs** — all `sample_01`–`sample_50.md` were the same 13 KB file-malware outline; CTF/lab/hunt slots had wrong `engagement_kind: file` | **Deleted all 50** — files now created on demand via `scaffold_writeup.ps1` |
| **`file.md` template: 477 lines / 18 sections** — too many sections for a first-pass writeup; optional depth buried required depth | **Trimmed to 12 sections** (~290 lines); merged provenance + TI context + ethics into appendices; moved "quick-ref" table into §2 exec summary |
| **No minimal placeholder** — if you just want to note "I'll write this up later" there was nothing lighter than the full template | **Added `_templates/_stub.md`** — 5-line frontmatter placeholder; upgradeable via `-Overwrite` |
| **`scaffold_writeup.ps1` always warned "already exists. Use -Overwrite"** on CTF/lab/hunt slots because stubs were pre-seeded with wrong kind | Fixed by removing stubs; now no warning on first-time creation; also added `stub` to `ValidateSet` |

### §3 — Recommended folder layout (implemented)

```
04_writeups/
  README.md                ← two-layer model + per-kind when/skip tables
  _templates/
    file.md                ← trimmed: 12 sections, ~290 lines
    ctf.md                 ← story arc, rabbit holes, ethics (unchanged)
    lab.md                 ← objectives rubric, reflection (unchanged)
    hunt.md                ← hypothesis → DE → FP (unchanged)
    _stub.md               ← NEW: minimal 5-line frontmatter placeholder
    README.md              ← template index + kind→file mapping
  sample_01.md             ← created by scaffold_writeup.ps1 on demand
  sample_37.md             ← CTF example (kind: ctf)
  ...                      ← only slots where a long report is needed
```

**Design principles applied:**
- No files pre-seeded — zero noise, zero kind-mismatch WARNs from check 19
- One file per slot, same `sample_XX` ID as `00`–`03`
- `_templates/` is read-only at engagement time — scaffold, then edit the copy
- `_stub.md` bridges "I started this engagement" and "I wrote the full report"

### §4 — Template overhaul (content design, all four kinds)

**file.md (.1)**
- Rewrote all `<FILL>` prompts with specific, actionable guidance (e.g. "group imports by theme: execution / injection / persistence / credential access / network / anti-analysis")
- Merged "Provenance" and "Executive technical snapshot" out of top-level sections into §3 (scope) and §2 (quick-ref table) respectively
- Added `<TARGET_IP>` / `<USERNAME>` placeholder convention to command blocks
- Expanded MITRE table with Sub-technique column and data-source column
- Added Sigma sketch template with YAML comments in §9 detection engineering
- Added TLSH to Appendix A hash bundle; references to `20_notes/MITRE-coverage.md` and `detection-catalog.md`
- Expanded final checklist to 8 items (MITRE consistency, distribution statement added)

**ctf.md (.2)**
- Fixed broken relative path: `../../20_notes/` → `../20_notes/` (scaffolded file lives in `04_writeups/`, not `_templates/`)
- Renamed §3 "Recon summary" → "Challenge analysis" with category-specific guidance block (`fullpwn/web`, `rev/pwn`, `crypto`, `forensics`, `misc`)
- Added "Dead-end hypotheses going in" sub-section to §3 to distinguish pre-solve eliminates from rabbit holes
- Expanded §5 rabbit holes table with "Why it seemed right" and "Why it failed" columns
- Added `course_url` → `platform` field; added `category` and `difficulty` to frontmatter
- Added platform-specific publication policy table to §9 ethics (HTB / THM / picoCTF)
- Added `20_notes/ctf-machine-index.md` cross-reference note in §1 document control
- Expanded final checklist to 8 items (publication gate, target IP scrub, machine index update)

**lab.md (.3)**
- Fixed objectives rubric: replaced `[ ]` inside table cell backticks (non-rendering) with `yes / no` text column
- Added `course_url`, `time_expected`, `time_actual` frontmatter fields
- Added §7 "Skills delta" (before/after table; syncs to `20_notes/skills-coverage.md`)
- Added `20_notes/lab-curriculum-map.md` cross-reference note in §1 document control
- Added "Confusion that remains" sub-section to §6 reflection
- Expanded §4 procedure table with "Why this step was non-obvious" column
- Expanded final checklist to 8 items (answer key scrub, skills-coverage.md update added)

**hunt.md (.4)**
- Fixed broken relative paths: `../../20_notes/` and `../../45_hunt_queries/` → `../20_notes/` and `../45_hunt_queries/`
- Restructured §2 hypothesis: added "Expected evidence if TRUE/FALSE" and "Inspired by" fields for traceability to malware/intel source
- Added "Verdict" column to query log table (productive / dry / too noisy)
- Added `outcome` frontmatter field (`true_positive | false_positive | inconclusive | no_data`)
- Added Sigma sketch block to §7 detection engineering with YAML template and promote-to-45_hunt_queries note
- Added "Follow-on hunt hypotheses" table to §8 recommendations
- Added `20_notes/detection-catalog.md` cross-reference to §7
- Expanded final checklist to 8 items (query_refs frontmatter, detection-catalog update, outcome consistency added)

### Not in REM-9 (planned follow-ups for `04` overhaul)

- New validate rules specific to `04` content quality (e.g. warn on unfilled `<FILL>` placeholders)

### Files touched (REM-9)

| File | Change |
|------|--------|
| `04_writeups/README.md` | Target model rewrite (§1); scaffold + layout section (§2–3) |
| `04_writeups/_templates/README.md` | Template index, `_stub.md` entry, updated scaffold commands |
| `04_writeups/_templates/file.md` | Trimmed 18 → 12 sections; full prompt overhaul (§4) |
| `04_writeups/_templates/ctf.md` | Path fix; category-aware §3; ethics table; checklist (§4) |
| `04_writeups/_templates/lab.md` | Checkboxes fixed; skills delta §7; curriculum links (§4) |
| `04_writeups/_templates/hunt.md` | Path fix; hypothesis structure; outcome field; Sigma sketch (§4) |
| `04_writeups/_templates/_stub.md` | New minimal placeholder |
| `04_writeups/sample_01.md` … `sample_50.md` | **Deleted** (50 pre-seeded stubs removed) |
| `30_scripts/scaffold_writeup.ps1` | Added `stub` to `ValidateSet`; `_stub.md` path resolution |
| `ENGAGEMENTS.md` | Optional `04` section aligned to target model |
| `Docs/Remediations.md` | This log |

---

## REM-10

**When:** 2026-05-22

**What:** `04_writeups` overhaul §5–6 — one-time migration utility + workflow automation (W1 + W2).

### §5 — One-time migration (completed)

The 50 pre-seeded stubs were already deleted in REM-9. The migration utility formalizes future bulk management:

- **`30_scripts/reset_writeup_stubs.ps1`** (new):
  - `-Mode remove` — delete `sample_*.md` files that are stubs (line count ≤ `-Threshold` or `status: placeholder`); skips files with real content
  - `-Mode stub` — create `_stub.md` placeholder for every active slot with no existing `04` file
  - `-Mode kind-from-tracker` — re-scaffold stubs whose `engagement_kind` doesn't match tracker; skips real-content files
  - `-DryRun` — print what would change without touching files
  - `-Threshold` — configurable line-count cut-off (default: 20)

### §6 — Workflow automation

#### W1: Low effort, high value

- **`close_sample.ps1`** — added `-- Optional: 04_writeups long-form report --` hint block to all four final-status closings (`file: done`, `ctf: writeup_done`, `lab: reviewed`, `hunt: closed`). If `04_writeups/sample_XX.md` already exists, shows `[x]` done. If absent, prints the exact `scaffold_writeup.ps1` command for that kind.

#### W2: Medium

- **`30_scripts/update_writeup_index.ps1`** (new):
  - Scans `04_writeups/sample_*.md`, reads frontmatter (`engagement_kind`, `title`, `writeup_version`, `status`, `public_writeup_safe`, `date_draft`, `date_final`)
  - Calculates depth (`stub` ≤ 20 lines / `short` 21–100 / `full` > 100)
  - Writes `04_writeups/INDEX.md` with a table + depth legend + scaffold commands
  - `-DryRun` prints to console instead of writing
- **`04_writeups/INDEX.md`** (new, auto-generated): starts empty (0 rows) — populated as real writeups are added
- **`validate.ps1` check 20** (new, WARN only):
  - Sub-check A: WARN if any existing `04_writeups` file is missing `writeup_version` field
  - Sub-check B: WARN if a CTF `04_writeups` file has `public_writeup_safe: true` but tracker `status != writeup_done` (prevents accidental publication of active-machine writeups)

### Validate

- **20 checks**, 15 PASS / 0 WARN / 0 FAIL on current repo state.

### Files touched (REM-10)

| File | Change |
|------|--------|
| `30_scripts/reset_writeup_stubs.ps1` | New — migration utility (§5) |
| `30_scripts/close_sample.ps1` | Writeup scaffold hint on all 4 final statuses |
| `30_scripts/update_writeup_index.ps1` | New — regenerates `04_writeups/INDEX.md` |
| `04_writeups/INDEX.md` | New — auto-generated index (0 rows initially) |
| `30_scripts/validate.ps1` | Check 20: writeup_version + public_writeup_safe gate |
| `Docs/Remediations.md` | This log |

### Open follow-ups

| Item | Status |
|------|--------|
| **GitHub Release `v3.1.2`** | `tag_release.ps1 -Tag v3.1.2 -Push` when ready |
| **`04` overhaul §7+ (integration)** | export-summary fields, main INDEX column, GUI writeup tab |

### Quick reference — files touched across REM-2–10

| Area | Key paths |
|------|-----------|
| Writeups | `04_writeups/README.md`, `_templates/*`, `INDEX.md`, `scaffold_writeup.ps1`, `reset_writeup_stubs.ps1`, `update_writeup_index.ps1` |
| Hunt queries | `45_hunt_queries/`, `30_scripts/new_hunt_query.ps1` |
| Notes | `20_notes/ctf-machine-index.md`, `lab-curriculum-map.md`, `detection-catalog.md`, `ctf-patterns/` |
| GUI | `30_scripts/workflow_gui.py` (v3.1.2; smoke-test) |
| Tracker / index | `samples_tracker.csv`, `INDEX.md` (REM-6) |
| Validate | `30_scripts/validate.ps1` (checks 16–20) |
| Build / CI | `build_exe.ps1` (sign, `-Clean`), `smoke_gui.ps1`, `integrity.yml` |
| Deferrals | `Docs/DEFERRED.md` |
| Identity docs | `README.md`, `ENGAGEMENTS.md`, `WORKFLOW.md`, `30_scripts/README.md`, `WORKFLOW-GUI.md` |
