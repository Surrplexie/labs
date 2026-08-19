# sample_01 -- static triage

| Field | Value |
|--------|--------|
| **SHA256** | `ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7` |
| **Name / tag (Bazaar)** | `Updater_v2.211.exe` |
| **Date analyzed** | 2026-05-06 (CFF NTFS timestamps on VM) |
| **VM user** | `win11` |

**Performed on VM:** 2026-05-06 (from file timestamps in CFF) -- User `win11` -- Sample opened as  
`C:\Users\win11\Downloads\ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7\ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7.exe`  
_(tab title in shots; may match `Updater_v2.211.exe` if renamed — same SHA256 target.)_

**Host evidence:** `50_screenshots/` — originals `IMG_6038–6042.HEIC`; **`IMG_6038–6042.png`** generated for portability (pillow/heif).

### Session results

| Step | Done? | Notes |
|------|-------|--------|
| Static (DIE / PEStudio / CFF / HxD) | Yes | Transcribed from phone photos below. |
| Execution | Yes | **`IMG_6042`** shows post-run dialogs — dynamic details in **`02_dynamic/sample_01.md`. |

### Hash reconcile (CFF vs “whole file”)

**Reference truth:** MalwareBazaar, checksum sites, and **`Get-FileHash` on the full `.exe`** all agree on **MD5** / **SHA-1** / **SHA256** for the object on disk — that is the hash set you should cite for **file identity** and threat intel.

**Why CFF “General Info” looked different in `IMG_6038`:** CFF (and some other PE tools) do **not** always show a digest of the **entire** on-disk file. For samples where almost all bytes live in an **overlay** (here: **~72 MiB file**, **~46 KiB “PE size”** per CFF), the UI may show MD5/SHA-1 computed over the **PE image / mapped portion only**, or another **subset**, which **will not match** the **full-file** hashes published by MalwareBazaar. Same bytes on disk still have **one** full-file MD5/SHA1 — your external checks confirmed that; treat CFF’s lines as **tool-specific**, not as conflicting evidence.

**Portfolio wording:** “Full-file hashes match MalwareBazaar; CFF digest fields reflect PE-tool semantics and differ from whole-file hashes on overlay-heavy installers.”

---

## Screenshot map

| File | Tool | What it shows |
|------|------|----------------|
| `IMG_6038` / `.png` | **CFF Explorer VIII** | General Info + version resource |
| `IMG_6039` / `.png` | **HxD** | Header / section names in plain hex |
| `IMG_6040` / `.png` | **PEStudio 9.61** | Metadata, entropy, manifest, overlay |
| `IMG_6041` / `.png` | **DIE 3.21** | Compiler, NSIS, overlay, heuristics |
| `IMG_6042` / `.png` | _(Host UI)_ | **Post-execution** fake errors — not static |

---

## DIE (`IMG_6041`)

- **PE type / arch:** PE32 · **I386** · **GUI** · LE · **~72.64 MiB** on disk.
- **Linker / compiler:** Microsoft Linker **6.0** · Microsoft Visual C/C++ **13.10.4035** [C].
- **Installer:** **Nullsoft Scriptable Install System (NSIS) 3.04** — **zlib**, **solid** compression.
- **Heuristic:** `(Heur) Packer: Generic` — notes **Nullsoft-like sections** and **`.ndata`** section offset anomaly (DIE red flag).
- **Overlay:** **Binary** at **offset `0xB600`**, size **`0x04898532`** — identified as **NSIS data** (bulk of the 72 MB is installer payload stream, not the tiny PE image).

## PEStudio (`IMG_6040`)

- **SHA256:** `FFD448F1…` (matches case file).
- **Type:** **32-bit** GUI executable.
- **Size:** 76,167,986 bytes · **Entropy: 8.000** (maximum — consistent with compressed/encrypted NSIS blob + overlay).
- **Version resource / description:** **`pijawoBridge`** (FileDescription / ProductName alignment with CFF).
- **Manifest name:** **`Nullsoft.NSIS.exehead`** — strong NSIS stub signal.
- **Rich header:** references **Visual Studio 2003** tooling line in tree.
- **Libraries / imports:** **7** libraries · **35+** imports (per tree).
- **Resources:** **13** · **Overlay:** signature **unknown** (PEStudio).
- **VirusTotal (in UI):** **`> 1 / 66`** engines flagging (detail needs VT site / API).
- **Entry point:** **`0x0000338F`** in **`.text`** · **Signature:** Microsoft Linker 6.0.

## CFF Explorer (`IMG_6038`)

- **File type:** **Portable Executable 32**.
- **Sizes:** **File 72.64 MB** (76,167,986 bytes) vs **PE size ~45.50 KB** (46,592 bytes) — **huge gap** = almost all bytes are **non-PE payload / NSIS archive** after the PE layout (matches DIE overlay).
- **Version info:** **FileDescription / ProductName:** `pijawoBridge` · **FileVersion** 5.1.5 · **LegalCopyright** `Copyright © 2026 pijawoBridge`.
- **Timestamps (NTFS):** Created 2026-05-06 15:46:08 · Modified 22:43:06 · Accessed 15:52:04 (local VM time).
- **MD5/SHA-1:** See **Hash reconcile** above vs MalwareBazaar.

## HxD (`IMG_6039`)

- **Signature:** **`MZ`** at 0x0 · DOS stub · **`PE\0\0`** at **`0xD0`** (typical PE offset pattern in view).
- **Section names visible in ASCII column:** **`.text`**, **`.rdata`**, **`.data`**, **`.ndata`**, **`.rsrc`** — **`.ndata`** is characteristic of **NSIS**-built installers.

## Static summary (portfolio-ready)

The object is a **32-bit PE** whose on-disk bulk is an **NSIS 3.04 (zlib, solid)** **overlay** (DIE/PEStudio/CFF agree). The embedded **version branding** reads **`pijawoBridge`**. **Global entropy 8.0** and **unknown overlay** in PEStudio match a **compressed installer package** rather than a minimal native binary. **MalwareBazaar’s NSIS-related YARA** aligns with this structure. **Next analytical steps** (beyond this notebook) would be **NSIS extraction / script recovery** if you need inner files **without** running the installer — separate tooling and snapshot discipline apply.

---

## Screenshots index

| # | Files | Content |
|---|--------|---------|
| 1 | `IMG_6038.HEIC` / `IMG_6038.png` | CFF Explorer |
| 2 | `IMG_6039.HEIC` / `IMG_6039.png` | HxD |
| 3 | `IMG_6040.HEIC` / `IMG_6040.png` | PEStudio |
| 4 | `IMG_6041.HEIC` / `IMG_6041.png` | DIE |
| 5 | `IMG_6042.HEIC` / `IMG_6042.png` | **Dynamic** -- fake error UI (`02_dynamic`) |

Cross-references: [acquisition](../00_original/sample_01.md) | [dynamic](../02_dynamic/sample_01.md) | [findings](../03_findings/sample_01.md) | [screenshots](../50_screenshots/)

