# 01_static

**Static triage notes — one file per sample, no execution required.**

Each `sample_XX.md` in this folder documents everything you can learn about a file
*without running it*: structure, entropy, packer, imports, strings, resources, and any
oddities visible through static tooling alone.

---

## What goes here

| Section | Examples |
|---------|---------|
| Identity anchor | SHA256, filename, date analyzed, VM user |
| DIE results | PE type/arch, compiler, packer, overlay |
| PEStudio results | Entropy, imports, strings, version resource, manifest, sections |
| CFF Explorer results | File vs PE size, version strings, timestamps, section table |
| HxD hex view | Magic bytes, section name strings, embedded artifacts visible in hex |
| Strings (optional) | Interesting printable strings (URLs, registry paths, error messages) |
| Hash reconcile note | Explain if any tool-reported hash differs from the full-file Bazaar hash |
| Static summary | One-paragraph portfolio-ready writeup of what the static pass proved |
| Screenshot index | Which screenshots map to which tools |
| Cross-references | Links to all other phase files |

## What does NOT go here

- Any copy of the actual binary, DLL, or script
- Runtime observations (those go in `02_dynamic/`)
- Verdict and final classification (those go in `03_findings/`)
- Host machine paths, real usernames, or internal infrastructure details

## Tips

- Fill the **hash reconcile** note any time a tool's hash panel does not match Bazaar.
  PE tools often hash only the mapped image, not the full file; that is expected on
  overlay-heavy samples.
- Record **exact version strings** from the tool UI — CFF / PEStudio version resource
  fields are frequently where malware plants its fake or give-away branding.
- Entropy alone does not confirm packing; cross-reference with DIE's packer detection
  and the presence of a known packer section name (`.upx0`, `.upx1`, etc.).
- Note **section count and names** in the hex view — recognising NSIS `.ndata`, UPX
  `.upx0`/`.upx1`, or anomalous names is a quick triage signal.

---

## Complete example (made-up — for reference only)

> **This entire block is a fabricated example.**
> Sample ID, hashes, paths, company names, and all behavioral details are invented
> for illustration. They do not correspond to any real file in this repository.

---

### sample_EX -- static triage

| Field | Value |
|-------|-------|
| **SHA256** | `4f3a8b2c1d9e7f06a5b4c3d2e1f09876543abcdef1234567890abcdef12345678` |
| **Name / tag (Bazaar)** | `InvoiceHelper_Setup.exe` |
| **Date analyzed** | 2026-04-15 (file timestamps on VM) |
| **VM user** | `win11` |

**Performed on VM:** 2026-04-15 — User `win11` — Sample opened as
`C:\Users\win11\Downloads\4f3a8b2c...\4f3a8b2c1d9e7f06a5b4c3d2e1f09876543abcdef1234567890abcdef12345678.exe`

**Host evidence:** `50_screenshots/sample_EX/` — files `shot_001.png` through `shot_006.png`.

#### Session results

| Step | Done? | Notes |
|------|-------|-------|
| Static (DIE / PEStudio / CFF / HxD) | Yes | Full pass, all four tools. |
| Strings (Strings2 / FLOSS) | Partial | Ran on unpacked copy; selected output below. |
| Execution | No | Deferred to `02_dynamic` pass. |

---

#### Hash reconcile

**Reference truth:** `Get-FileHash` on the full `.exe` matches MalwareBazaar SHA256
`4f3a8b2c…12345678`.

**CFF note:** CFF Explorer's "MD5" line in General Info shows
`d41d8cd9...` — this is the hash of the **PE-mapped image only** (46 KB),
not the full 2.4 MB file. This is expected: UPX packs the original code into an
overlay. Cite full-file hashes for identification; treat CFF's line as tool-internal.

---

#### DIE (shot_004.png)

- **PE type / arch:** PE32 · **I386** · **GUI** · LE · **2.37 MiB** on disk.
- **Linker / compiler:** MinGW-w64 GCC 8.1.0 _(visible after UPX unpack; stub shows UPX)_.
- **Packer:** **UPX 3.96** — section names `.upx0` and `.upx1` detected; DIE flags
  `Packer: UPX`.
- **Heuristic:** `(Heur) Possible Packer/Protector` — high entropy in `.upx1`, single
  original entry point after stub jump.
- **Overlay:** None reported (all payload inside UPX sections).

---

#### PEStudio (shot_003.png)

- **SHA256:** `4F3A8B2C…12345678` (matches case file).
- **Type:** **32-bit** GUI executable.
- **Size:** 2,491,392 bytes · **Entropy: 7.83** (high — consistent with UPX compression).
- **Version resource / description:** **`Adobe Invoice Reader Pro v4.2`** —
  `CompanyName: Adobe Systems Inc.` · `LegalCopyright: © 2023 Adobe Systems Inc.`
  _(fake: version resource impersonates Adobe; no Adobe signing or manifest match)_.
- **Manifest:** No embedded manifest found (red flag — legitimate signed software always
  has one; absence + fake version resource = strong deception signal).
- **Sections:** `.upx0` (raw: 0x0, virtual: 0x1A9000 — unpacked image space),
  `.upx1` (raw: 0x240000 — compressed payload), `.rsrc` (2 resources: icon + version).
- **Imports (packed stub):** 4 imports only — `LoadLibraryA`, `GetProcAddress`,
  `VirtualAlloc`, `VirtualProtect` — classic UPX loader stubs; real imports resolved
  at unpack time.
- **Blacklisted strings (pre-unpack):** `UPX!` magic at `.upx1` tail (confirms UPX).
- **VirusTotal (in UI):** **`18 / 70`** engines flagging — notable detection names:
  `Trojan.GenericKD.47`, `PWS:Win32/Zbot.C`, `Infostealer.AgentTesla`.

---

#### CFF Explorer (shot_001.png)

- **File type:** Portable Executable 32.
- **Sizes:** **File 2.37 MB** (2,491,392 bytes) vs **PE mapped ~1.6 MB** unpacked —
  file/PE size gap consistent with UPX stub + compressed section.
- **Version info:** See PEStudio — `FileDescription: Adobe Invoice Reader Pro`,
  `ProductName: InvoiceHelper`, **`CompanyName: Adobe Systems Inc.`** _(impersonation)_.
- **Timestamps (NTFS on VM):** Created 2026-04-14 09:12:44 · Modified 2026-04-14
  09:12:44 · Accessed 2026-04-15 11:03:22 (local VM time).
- **PE timestamp:** `0x5FC2A3B1` = 2020-11-28 — **suspicious: file appears recently
  dropped but PE header timestamp backdated to 2020**.
- **Section table:**

| # | Name | Virtual size | Raw size | Characteristics |
|---|------|-------------|----------|----------------|
| 0 | `.upx0` | 0x1A9000 | 0x000 | RWX |
| 1 | `.upx1` | 0x240000 | 0x25F200 | RX |
| 2 | `.rsrc` | 0x000A00 | 0x000A00 | R |

---

#### HxD (shot_002.png)

- **Signature:** `MZ` at 0x0 · `PE\0\0` at `0x80` · standard DOS stub.
- **Offset 0x1C8:** ASCII section names visible: `.upx0`, `.upx1` — confirms UPX
  packer without running the file.
- **Offset 0x25F200:** `UPX!` magic string (UPX EOF marker) — standard UPX tail
  signature; version bytes after this marker read `3.96`.
- **No overlay** beyond the UPX-packed binary.

---

#### Interesting strings (after `upx -d` unpack — shot_005.png)

> These come from a **safe static unpack** (`upx -d sample_copy.exe`) run on the VM.
> The unpacked file was **not executed**.

| Category | String | Notes |
|----------|--------|-------|
| URL | `http://192.0.2.47:8080/gate.php` | Hardcoded C2 — TEST-NET address (example) |
| URL | `http://192.0.2.47:8080/log.php` | Secondary logging endpoint |
| Registry | `SOFTWARE\Microsoft\Windows\CurrentVersion\Run` | Persistence key path |
| Registry | `InvoiceHelper` | Value name used for Run key persistence |
| Path | `%APPDATA%\Microsoft\Windows\InvoiceHelper\` | Drop directory |
| Path | `%APPDATA%\Microsoft\Windows\InvoiceHelper\svchost32.exe` | Dropped executable name |
| Credential | `\Google\Chrome\User Data\Default\Login Data` | Chrome credential path |
| Credential | `\Mozilla\Firefox\Profiles\` | Firefox profile path |
| Crypto | `AES_set_encrypt_key` | Suggests AES usage (possibly for C2 comms or exfil) |
| Debug | `[KEYLOG] ` | Keylogger output prefix string — strong infostealer signal |
| Debug | `[CLIP] ` | Clipboard capture prefix |
| Version | `AgentHelper/2.1` | Possible user-agent or internal version string |

---

#### Static summary (portfolio-ready)

The sample is a **32-bit UPX 3.96-packed PE** whose version resource impersonates
**Adobe Systems** with a fictitious "Invoice Reader Pro" product name. The PE timestamp
is **backdated to 2020** despite a recent drop date, a common anti-dating technique.
UPX was stripped with `upx -d` for static string recovery; the unpacked image contains
**hardcoded C2 endpoints**, **Chrome and Firefox credential store paths**, a **Run key
persistence path**, and **keylogger/clipboard capture prefix strings** — a profile
consistent with an **infostealer or RAT**. Static analysis alone does not confirm
execution behavior; dynamic logging is required to prove live network contact and
credential exfiltration.

---

#### Screenshots index

| # | File | Tool | What it shows |
|---|------|------|---------------|
| 1 | `shot_001.png` | **CFF Explorer** | General Info, version resource, section table |
| 2 | `shot_002.png` | **HxD** | MZ header, `.upx0`/`.upx1` names, UPX! marker |
| 3 | `shot_003.png` | **PEStudio** | Entropy, fake version resource, import table |
| 4 | `shot_004.png` | **DIE** | UPX detection, packer heuristics |
| 5 | `shot_005.png` | **Strings2** | Unpacked string output (C2 URLs, paths) |
| 6 | `shot_006.png` | **PEStudio** | VirusTotal hits, blacklisted imports |

Cross-references: [acquisition](../00_original/sample_EX.md) | [dynamic](../02_dynamic/sample_EX.md) | [findings](../03_findings/sample_EX.md) | [screenshots](../50_screenshots/sample_EX/)
