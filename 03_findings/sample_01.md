---
schema_version: 1
sample_id: sample_01
name_tag: "Updater_v2.211.exe"
sha256: ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7
phase: findings
analyst: Surrplexie
date_acquired: "2026-05-06"
date_analyzed: "2026-05-06"
status: static_and_initial_dynamic_done
verdict: suspicious
family_guess: "NSIS installer / fake alert deception"
family_confidence: medium-high
tags:
  - exe
  - nsis
  - fake-alert
  - deceptive-ui
  - installer
  - pijawoBridge
mitre_techniques:
  - T1036    # Masquerading — posed as legitimate updater (Updater_v2.211.exe)
  - T1027    # Obfuscated Files or Information — max-entropy NSIS compressed overlay
  - T1583.006  # Acquire Infrastructure: Web Services — hosted via Pages.dev + GitHub releases
mb_url: "https://malwarebazaar.abuse.ch/sample/ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7/"
procmon_run: false
dynamic_complete: false
---

# sample_01 -- findings (portfolio slice)

**SHA256:** `ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7`

**Confidence:** **Medium-high** on **packaging / type** (NSIS installer, high entropy overlay); **medium** on **malicious intent** (fake error UX + Bazaar/VT hints + lab execution) pending **structured dynamic** (Procmon) if you want higher rigor.

**Analyst one-liner:** Large **NSIS-delivered PE** posing as **`pijawoBridge` / updater** branding; executes to **bogus system error dialogs** (misspelling + gibberish).

Cross-references: [acquisition](../00_original/sample_01.md) | [static](../01_static/sample_01.md) | [dynamic](../02_dynamic/sample_01.md) | [screenshots](../50_screenshots/sample_01/) | [IOCs](../40_iocs/indicators.csv) | [NSIS case series](../20_notes/case-series/NSIS-installers.md)

## Verdict

- **Classification (working):** **Suspicious installer / potentially unwanted or malicious deception** — not a minimal legit system component; inner payload not statically extracted here.
- **Why:** **Static:** NSIS 3.04 + **8.0 entropy** + mismatch between **tiny PE on disk vs 72 MB file** · **Dynamic:** **`IMG_6042`** shows **non-authentic error UI**.

## IOCs (also keep `40_iocs/indicators.csv` in sync)

| Type | Value | Notes |
|------|--------|------|
| sha256 | `ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7` | Canonical sample |
| sha1 | `e4c0c9b3d3f85cb5e4015825a4ee87282ff8703f` | MalwareBazaar |
| md5 | `974e9813d86ec7eafb5a4e62f78d0d55` | MalwareBazaar |
| filename | `Updater_v2.211.exe` | Claimed Bazaar name |
| imphash | `b34f154ec913d2d2c435cbd644e91687` | Bazaar clustering hint only |
| fuzzy_ssdeep | `1572864:5t9IKPUjRWYs+v4//v/bwcEOMOUHwDu8vkjUOle+dclSX7:5UKMjRWwLFOCwS8sjUOle+drX7` | MalwareBazaar |
| tlsh | `T17AF73308526CD36BEDFEC5BAC7C0D7E1D340C64F9EBA980E635E3898B5414C601DA7A6` | MalwareBazaar |
| url | `http://itchupdate-ah1.pages.dev/` | Referenced on Bazaar listing |
| url | `https://github.com/Psychoxox/probable-octo-giggle/releases/download/soffft/Updater_v2.211.zip` | Zip delivery on Bazaar -- hash not verified same PE without compare |
| url | `https://www.virustotal.com/gui/file/ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7/detection` | VT for this SHA256 |
| software_name | `pijawoBridge` | CFF / PEStudio version resource |
| ui_title | `HGWJY` | Post-run dialog (`IMG_6042`) |
| ui_string | `Critical systeam error 0x00305353321` | Typo **systeam** -- fake alert (`IMG_6042`) |
| ui_string | `jimnb uq0ukc1m ulo0ov lui0kilpa cqch an` | Gibberish dialog body (`IMG_6042`) |

## What you proved

- **Static:** **NSIS 3.04** installer structure (DIE + PEStudio `Nullsoft.NSIS.exehead` + **`.ndata`** in HxD) -- **~72.6 MiB** file vs **~46 KiB** PE image -- **entropy 8.0** -- branding **`pijawoBridge`** (version 5.1.5).
- **Acquisition:** MalwareBazaar object with **5** vendor detections (summary), **web download** delivery, **imphash** / YARA leads documented in **`00_original`**.
- **Dynamic:** Post-run **deceptive error dialogs** captured **`IMG_6042`** only -- **no** Procmon-backed process, file, registry, or network proof in this pass.

## Gaps / next steps

1. **Reconcile hashes** on VM (**`00_original`** / **`01_static`**) if CFF vs Bazaar MD5/SHA1 still disagree after fresh `Get-FileHash`.
2. **Optional:** Repeat run with **Procmon** + snapshot discipline for **paths, persistence, children, network**.
3. **Optional:** **NSIS unpack** track (separate tools) if you need inner files **without** execution.

## Public-safe blurb

This sample is a large **32-bit Windows executable** whose structure matches a **Nullsoft (NSIS) installer** with most of the file size stored as **compressed overlay data**. Static tools report **very high entropy** and branding under the name **`pijawoBridge`**. When executed in an analysis virtual machine, it produced **error dialogs** that used a **misspelled “system”** string and **nonsense text**, which is inconsistent with legitimate system software. **Further dynamic logging** (process monitor, network) would be needed to document persistence, secondary downloads, or full behavior.
