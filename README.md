# Malware triage lab — host logbook

This folder is your **offline logbook**: hashes, screenshots, notes, IOCs — **no live malware binaries** on this machine. Download and execute samples **only inside the isolated Win11 VM** (revert snapshot after dynamic runs).

---

## Layout (parallel `sample_XX` everywhere)

Same **sample ID** in every phase so reviewers can skim one column of the folder tree:

| Folder | Purpose |
|--------|---------|
| `00_original` | Bazaar link, hashes, acquisition checklist (nothing executable on host). |
| `01_static` | DIE, PEStudio, CFF Explorer, HxD notes. |
| `02_dynamic` | Procmon / Process Explorer / network (leave blank if static-only). |
| `03_findings` | Verdict, IOC table, portfolio blurb. |
| `50_screenshots/sample_XX/` | PNG/JPEG captures for that sample (see each folder’s `SHOT_INDEX.txt`). |
| `samples_tracker.csv` | One row per slot: SHA256, URL, status. |
| `40_iocs/indicators.csv` | Consolidated IOCs for sharing or SIEM/playbooks. |
| `30_scripts/new_sample.ps1` | Scaffold `sample_06`, `sample_07`, … |

**Naming:** `sample_01` … `sample_99` (zero-padded) — same filename in all four phase folders.

---

## Official start (every new MalwareBazaar pick)

1. **Choose a slot** — use the next empty row in `samples_tracker.csv` (e.g. `sample_02`) or run:
   ```powershell
   cd C:\Users\surrp\Downloads\tests
   powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 6
   ```
2. **On the VM only** — download by hash / Bazaar; save path you document in `00_original/sample_XX.md`.
3. **Fill `00_original/sample_XX.md`** — SHA256 (full), link, tags; check acquisition boxes.
4. **Static (no execution)** — DIE → PEStudio → CFF Explorer → HxD as needed; write `01_static/sample_XX.md`; save shots under `50_screenshots/sample_XX/`.
5. **Optional dynamic** — Procmon + Process Explorer (+ TCPView / Wireshark if useful); execute **once**; fill `02_dynamic/sample_XX.md`; **revert snapshot**.
6. **`03_findings/sample_XX.md`** — verdict, IOCs, public-safe paragraph.
7. **Tracker & IOC CSV** — update `samples_tracker.csv` (`status`: `queued` → `static` → `dynamic` → `done`) and append rows to `40_iocs/indicators.csv`.

Tools you have on VM: DIE, PEStudio, CFF Explorer, HxD — map directly to sections in `01_static`.

---

## Showing work to others

- Pick **one `sample_XX`** and point people to four files plus `50_screenshots/sample_XX/`.
- Redact VM usernames and internal paths in screenshots before publishing.
- The **Public-safe blurb** in `03_findings` is your elevator pitch per sample.

---

## Safety (non-negotiable)

- **Host:** no `.exe` / `.dll` / `.scr` / weaponized `.ps1` from samples; documentation and images only here.
- **VM:** NAT is fine; block outbound if you want local-only behavior.
- Always **revert snapshot** after dynamic analysis.
