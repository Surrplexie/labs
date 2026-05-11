# sample_01 — original receipt (host log)

**Purpose:** Record identification and sourcing **before/at acquisition**. Binaries stay **VM-only.** This page is populated from MalwareBazaar **before download**.

| Field | Value |
|--------|--------|
| **Sample ID** | `sample_01` |
| **MalwareBazaar URL** | `https://malwarebazaar.abuse.ch/sample/ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7/` |
| **SHA256** | `ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7` |
| **SHA3-384** | `3bf21d2aee38f1f201e01913a03f5e8883985d43834e1758ba0e904477c0d823587cf3d08fea9b6d1c2a562eaf2cf609` |
| **SHA1** | `e4c0c9b3d3f85cb5e4015825a4ee87282ff8703f` |
| **MD5** | `974e9813d86ec7eafb5a4e62f78d0d55` |
| **humanhash** | `montana-solar-ten-illinois` |
| **File name (claimed)** | `Updater_v2.211.exe` |
| **Mime / type** | `application/x-dosexec` · Executable exe |
| **Size** | 76 167 986 bytes (~72.6 MiB) |
| **First seen (Bazaar)** | 2026-05-06 22:23:04 UTC |
| **Last seen** | Never |
| **Bazaar verdict** | Threat **unknown** (community / vendor signals still triage fodder — not legal proof alone) |
| **Vendor detections (Bazaar summary)** | 5 |

## Delivery & context (from entry)

| Field | Value |
|--------|--------|
| **Delivery method** | Web download |
| **Reporter** | lfr |
| **Tags** | `exe` |
| **Magika** | pebin |
| **TrID (top)** | ~50 % MSVC++ Win32 exe (generic — not a family ID) |

## Hashes useful for clustering / lookups

| Field | Value | Notes |
|--------|--------|--------|
| **imphash** | `b34f154ec913d2d2c435cbd644e91687` | Bazaar cites overlap with GuLoader / RemcosRAT / EpsilonStealer-bearing samples — **hint only**, verify with behavior + your PE view. |
| **ssdeep** | `1572864:5t9IKPUjRWYs+v4//v/bwcEOMOUHwDu8vkjUOle+dclSX7:5UKMjRWwLFOCwS8sjUOle+drX7` | Fuzzy similarity; use after you hold the binary. |
| **TLSH** | `T17AF73308526CD36BEDFEC5BAC7C0D7E1D340C64F9EBA980E635E3898B5414C601DA7A6` | Locality-sensitive hash for near-duplicate search. |
| **dhash icon** | `c427125232324fb0` | Icon similarity signal (many unrelated programs share icons — weak alone). |

## URLs referenced on the Bazaar page (IOC / investigation leads)

Treat as **reporting** URLs until you corroborate in your VM session or tooling.

| Kind | URL / note |
|------|-------------|
| **Pages host** | `http://itchupdate-ah1.pages.dev/` |
| **GitHub (zip delivery)** | `https://github.com/Psychoxox/probable-octo-giggle/releases/download/soffft/Updater_v2.211.zip` |
| **VirusTotal — this exe (SHA256 match)** | `https://www.virustotal.com/gui/file/ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7/detection` |
| **VirusTotal — other hashes on same listing** | `…/file/e2df04df…/detection` · `…/file/c55a367e…/detection` — **different files** than this SHA256 (often parent archive or related artifact); confirm hash on VT before citing as “same file”. |

## YARA rule names flagged (TLP:CLEAR on Bazaar — triage hints)

These are **string/rule matches**, not a confirmed verdict in isolation.

| Rule | Author | What it implies (rough) |
|------|--------|--------------------------|
| `Detect_NSIS_Nullsoft_Installer` | Obscurity Labs LLC | NSIS installer structure (`.ndata` / headers) — may be benign installer wrapped payload or abuse of NSIS. |
| `Sus_CMD_Powershell_Usage` | XiAnzheng | Possible CMD/PowerShell fragments — high false-positive potential; validate in PE strings / installer scripts. |
| `TH_AntiVM_MassHunt_Win_Malware_2026_CYFARE` | CYFARE | Anti-VM / anti-sandbox patterns — **if real for this binary**, dynamic analysis inside a VM/sandbox may look different than bare metal (still ok for learning; interpret evasion gaps). |

## Bazaar intelligence snippets

| Metric | Value |
|--------|--------|
| `# of uploads` | 1 |
| `# of downloads` | 61 |
| **Origin country** | FR (as reported by Bazaar) |

## Acquisition checklist (VM)

- [x] Download **inside VM only** (Bazaar login / API).
- [x] **SHA256 verified on VM:** matches `ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7`.
- [x] Saved path on VM: `C:\Users\win11\Downloads\ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7\` — analysis tabs show **`ffd448f1…bd7.exe`** (same hash object; name may differ from Bazaar `Updater_v2.211.exe`).
- [x] **Sample executed** (user ran it) — post-run UI captured in **`50_screenshots/sample_01/IMG_6042`** (see **`02_dynamic`**). **Revert snapshot** when you are done capturing if the VM is disposable.
- [ ] **Optional redo:** Snapshot **clean** **before** a **Procmon-instrumented** second run.
- [x] **Never** copy `.exe` to this host logbook PC.

## What you filled out today (before download)

- **Hashes + file metadata** → proves traceability (“this notebook is about exactly this Bazaar object”).
- **imphash / YARA names** → research leads for static pass (installer type, scripting, anti-VM).
- **URLs** → network / attribution leads to record in IOC lists and revisit after dynamic runs.
- **VT link for `ffd448f1…`** → optional reputation pre-check — still **follow your lab procedure** instead of trusting a score alone.

## Cross-links

- Static notes: `01_static/sample_01.md`
- Dynamic notes: `02_dynamic/sample_01.md`
- Findings / portfolio: `03_findings/sample_01.md`
- Screenshots (host): `50_screenshots/sample_01/` — see `SHOT_INDEX.txt` there.
