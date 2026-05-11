# labs

> **Personal reference repository — public for professional seekers and learners.**
> No releases, versioned packages, or scheduled updates are guaranteed or will ever be provided.

---

## Disclaimer

**Read this before using, citing, or distributing anything from this repository.**

This repository is maintained solely for **personal use** and is made public as a professional reference for security researchers, learners, and portfolio reviewers. It is not a product, a service, or an actively maintained project.

- **No executable samples are stored here, ever.** All content exists exclusively as Markdown (`.md`), CSV, and image files. No binaries, compiled artifacts, weaponized scripts, shellcode, or live malware of any kind are committed or will be committed to this repository.
- **All content is provided for educational and research purposes only.** Nothing here constitutes professional security advice, legal guidance, or operational instruction of any kind.
- **Scope of coverage is broad by design.** Content may reference or document anything within the security research domain, including but not limited to: existing CVEs and vulnerability disclosures, malware file reconnaissance (static and dynamic), threat intelligence indicators, reverse engineering workflows, OSINT methodology, forensic analysis notes, and tooling references.
- **This repository is governed by the [MIT License](./LICENSE).** "MIT" here is interpreted in the context of personal, non-commercial reference use. Redistribution must retain original attribution. No claim of ownership is made over any third-party tool names, vendor data, CVE identifiers, or public intelligence referenced within.
- **No warranties of any kind** — expressed or implied — are made regarding the accuracy, completeness, currency, or fitness for any purpose of any content in this repository.
- **No releases, updates, patches, or continued maintenance are guaranteed or promised.** This logbook may go months without a commit. Absence of updates does not imply abandonment.
- **The author assumes no liability** for any use or misuse of the information contained within, including but not limited to harm resulting from acting on documented techniques, tool references, or indicator data.
- Any tooling references, script fragments, or command examples are illustrative only. Validate everything in your own controlled, isolated environment before applying it anywhere.

---

## Purpose

This is a **personal skills and professional reference** logbook used to document security research workflows — primarily malware triage (static and dynamic), but also general security engineering, threat intelligence, and tooling notes. It is structured to support:

- Portfolio review by professional contacts, recruiters, and peers
- Personal knowledge retention and skill development
- A consistent, version-controlled record of analytical work over time

It is **not** intended for production deployment, operational use, or redistribution as a training dataset.

---

## Who This Is For

| Audience | How to use this repo |
|---|---|
| **Recruiters / hiring managers** | Review the `03_findings/` blurbs and `samples_tracker.csv` for scope and progression |
| **Security learners** | Follow the workflow structure and use the folder layout as a triage template |
| **Researchers** | Reference IOC tables in `40_iocs/` and cross-reference with public threat intel |
| **General public** | Read-only; nothing here is executable or deployable |

---

## What Is (and Is Not) Here

| What's here | What's not here |
|---|---|
| `.md` analysis notes per sample | Executable binaries (`.exe`, `.dll`, `.scr`, etc.) |
| Hash references and acquisition checklists | Live or weaponized scripts |
| IOC tables (CSV) | VM disk images or snapshots |
| Screenshots (`.png` / `.jpeg`) | Any file that can execute on a host machine |
| Workflow and tooling documentation | Compiled code or packages |
| CVE reference notes and vulnerability documentation | Proof-of-concept exploit code |
| OSINT and threat intelligence methodology notes | PII, credentials, or session data of any kind |

---

## Folder Layout

The same **sample ID** (`sample_XX`) runs across every phase folder for consistent cross-referencing:

| Folder | Purpose |
|---|---|
| `00_original/` | MalwareBazaar link, SHA256, acquisition checklist — no executables on host |
| `01_static/` | DIE, PEStudio, CFF Explorer, HxD notes |
| `02_dynamic/` | Procmon / Process Explorer / network captures (VM only) |
| `03_findings/` | Verdict, IOC table, public-safe portfolio blurb |
| `10_extracted/` | Strings, headers, and other extracted artifacts (non-executable) |
| `20_notes/` | General research and workflow notes |
| `30_scripts/` | Reference scaffold scripts (PowerShell, illustrative only) |
| `40_iocs/` | Consolidated IOC CSV for sharing or SIEM reference |
| `50_screenshots/sample_XX/` | PNG/JPEG captures keyed to each sample |
| `samples_tracker.csv` | One row per slot: SHA256, URL, status |

**Naming convention:** `sample_01` … `sample_99` (zero-padded) — consistent across all phase folders.

---

## Workflow Overview

1. **Choose a slot** — use the next empty row in `samples_tracker.csv` or scaffold with:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber <N>
   ```
2. **VM only** — download sample by hash from MalwareBazaar; document path in `00_original/sample_XX.md`.
3. **Fill `00_original/sample_XX.md`** — full SHA256, source link, tags, acquisition checklist.
4. **Static analysis (no execution)** — DIE → PEStudio → CFF Explorer → HxD; document in `01_static/sample_XX.md`; save screenshots under `50_screenshots/sample_XX/`.
5. **Optional dynamic analysis** — Procmon + Process Explorer (+ TCPView / Wireshark as needed); execute once inside VM; fill `02_dynamic/sample_XX.md`; **revert snapshot immediately after**.
6. **Findings** — write verdict, IOCs, and public-safe paragraph in `03_findings/sample_XX.md`.
7. **Update tracker and IOC CSV** — advance status (`queued` → `static` → `dynamic` → `done`) in `samples_tracker.csv`; append rows to `40_iocs/indicators.csv`.

---

## Safety Rules

- **Host machine:** no `.exe`, `.dll`, `.scr`, or weaponized `.ps1` from samples — documentation and images only.
- **VM only:** all download and execution happens inside an isolated, snapshot-backed VM.
- **Always revert snapshot** after any dynamic analysis run.
- Redact VM usernames and internal paths from screenshots before committing.

---

## Showing This Work

- Point reviewers to one `sample_XX` column: four phase files plus `50_screenshots/sample_XX/`.
- The **Public-safe blurb** in each `03_findings/sample_XX.md` serves as a self-contained portfolio entry.

---

## License

MIT © 2026 Surrplexie — see [LICENSE](./LICENSE).

Personal use. Redistribution must retain attribution. Provided as-is, with no warranty of any kind. This license does not grant rights to any third-party content, tools, or data referenced within this repository.
