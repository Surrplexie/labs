# 01_static

**Second phase folder — meaning depends on engagement kind.**

| Kind | What this folder holds |
|------|------------------------|
| `file` | Static triage notes (DIE / PEStudio / CFF Explorer / HxD) |
| `ctf` | Recon and enumeration notes (nmap, gobuster, service details) |
| `lab` | Step log (procedure, commands, expected vs actual output) |
| `hunt` | Data collection (queries, raw findings, event IDs) |

---

**For `file` engagements:** Static triage notes — one file per sample, no execution required.

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

---

## Complete example -- CTF (recon / enumeration)

**Engagement:** `sample_EX` -- HackTheBox "Blunder" (Retired), Linux, web category.

---

### Identity anchor

| Field | Value |
|-------|-------|
| Platform | HackTheBox |
| Box name | Blunder |
| OS | Linux |
| IP | 10.10.10.191 |
| Date started | 2026-05-11 |
| Analyst | Surrplexie |

---

### Scan results -- nmap

```
nmap -sC -sV -oA nmap/blunder 10.10.10.191
```

| Port | State | Service | Version |
|------|-------|---------|---------|
| 21/tcp | filtered | ftp | -- |
| 80/tcp | open | http | Apache 2.4.41 (Ubuntu) |
| 443/tcp | closed | -- | -- |

No SSH visible on initial scan. FTP filtered (not accessible). Single attack surface: HTTP port 80.

---

### Web enumeration -- gobuster

```bash
gobuster dir -u http://10.10.10.191 -w /usr/share/seclists/Discovery/Web-Content/common.txt -x php,txt,html -t 40
```

| Path | Status | Notes |
|------|--------|-------|
| `/admin` | 301 | Redirects to `/admin/` |
| `/robots.txt` | 200 | Discloses `/todo.txt` |
| `/todo.txt` | 200 | Note from dev: "fergus must change password" -- username leak |
| `/install.php` | 200 | Bludit CMS install confirmation page |
| `/bl-content/` | 301 | CMS content directory |

**Findings:**
- CMS identified as **Bludit** (confirmed via `/bl-content/` structure and footer comment).
- Username **fergus** leaked via `todo.txt`.
- No FTP access; no SSH open.

---

### CMS version fingerprinting

Access `http://10.10.10.191/admin/` -- login panel visible.  
Page source comment: `Bludit version: 3.9.2`

Searched `searchsploit bludit`:

```
Bludit - Directory Traversal Image File Upload (Metasploit) | php/webapps/47699.rb
Bludit 3.9.2 - Authentication Bruteforce Mitigation Bypass  | php/webapps/48942.py
```

**Two applicable exploits for 3.9.2:**  
1. Brute-force mitigation bypass (need valid password)  
2. Directory traversal upload (need auth first)

Approach: use brute-force bypass to crack `fergus` account, then use upload exploit for foothold.

---

### Wordlist preparation

Bludit 3.9.2 blocks IPs after 10 failed attempts using X-Forwarded-For rotation bypass.
Generated custom wordlist with CeWL from the site:

```bash
cewl -w wordlist.txt -d 2 http://10.10.10.191
```

Result: 249-word custom list from page content.

---

### Credential attempt table

| Username | Wordlist source | Result |
|---------|----------------|--------|
| fergus | cewl output | **HIT** -- password: `RolandDeschain` |
| admin | cewl output | No match |

Authentication to Bludit admin panel confirmed with `fergus:RolandDeschain`.

---

### Summary (for findings)

Static/recon phase confirmed: **Bludit CMS 3.9.2 on Apache 2.4.41**, one authenticated
user (`fergus`) with a weak password recoverable from CeWL wordlist. Two CVEs applicable.
Next phase: exploit directory traversal upload CVE for initial foothold.

---

### Screenshots index

| # | File | Tool | What it shows |
|---|------|------|---------------|
| 1 | `shot_001.png` | **nmap** | Open port summary |
| 2 | `shot_002.png` | **Browser** | Bludit admin login panel |
| 3 | `shot_003.png` | **curl** | `todo.txt` content, fergus username |
| 4 | `shot_004.png` | **gobuster** | Directory listing results |

Cross-references: [brief](../00_original/sample_EX.md) | [solve](../02_dynamic/sample_EX.md) | [findings](../03_findings/sample_EX.md) | [screenshots](../50_screenshots/sample_EX/)

---

## Complete example -- Lab (step log)

**Engagement:** `sample_EX` -- TCM Security "Practical Ethical Hacking", Module 8: Active Directory Lab.

---

### Identity anchor

| Field | Value |
|-------|-------|
| Platform | TCM Security |
| Course | Practical Ethical Hacking |
| Module | 8 -- Active Directory Attacks |
| Environment | Local VMware lab (DC01 + WORKSTATION-01 + WORKSTATION-02) |
| Date | 2026-05-11 |

---

### Objectives

- [ ] 1. Perform LLMNR/NBT-NS poisoning to capture NTLMv2 hashes
- [ ] 2. Crack the captured hash with hashcat
- [ ] 3. Enumerate SMB shares after authentication
- [ ] 4. Identify a pass-the-hash opportunity
- [x] = completed; [ ] = not yet reached

---

### Step 1 -- Set up Responder

**Command:**
```bash
sudo responder -I eth0 -dwv
```

**Expected:** Responder starts listening on all protocols (LLMNR, NBT-NS, MDNS).

**Actual:** Started as expected. Interface `eth0` shows correct lab subnet.

---

### Step 2 -- Trigger LLMNR request

On WORKSTATION-01 (Windows VM), navigated to a non-existent share:
```
\\doesnotexist\share
```

**Expected:** Responder intercepts the LLMNR broadcast and serves a poisoned response.

**Actual:** Within 3 seconds, Responder captured:
```
[SMB] NTLMv2-SSP Hash  : MARVEL\fcastle::MARVEL:babb...
```

Hash captured for user `fcastle`.

---

### Step 3 -- Crack hash with hashcat

Saved hash to `fcastle.hash`, then:
```bash
hashcat -m 5600 fcastle.hash /usr/share/wordlists/rockyou.txt
```

| Field | Value |
|-------|-------|
| Hash type | NTLMv2-SSP (`-m 5600`) |
| Wordlist | rockyou.txt |
| Result | **Password1** (cracked in 12 seconds) |

---

### Notes / errors encountered

- First attempt used `-m 1000` (NTLM) instead of `-m 5600` (NTLMv2-SSP) -- no results.
  Corrected after reviewing the hash format (`::` separator is NTLMv2, not plain NTLM).
- Responder must be stopped before using `crackmapexec`; both bind port 445.

---

### Screenshots index

| # | File | Tool | What it shows |
|---|------|------|---------------|
| 1 | `shot_001.png` | **Responder** | Captured NTLMv2 hash in terminal |
| 2 | `shot_002.png` | **hashcat** | Cracked password output |

Cross-references: [setup](../00_original/sample_EX.md) | [results](../02_dynamic/sample_EX.md) | [reflection](../03_findings/sample_EX.md)

---

## Complete example -- Hunt (data collection)

**Engagement:** `sample_EX` -- Internal hunt: "Detect LSASS credential access via Mimikatz-style tooling."

---

### Identity anchor

| Field | Value |
|-------|-------|
| Hypothesis | An attacker or red-team tool accessed LSASS memory on endpoints in the last 30 days. |
| Data sources | Sysmon Event 10 (ProcessAccess), Sysmon Event 1 (Process creation), Security Event 4688 |
| Time range | 2026-04-11 to 2026-05-11 |
| Scope | All Windows endpoints in SIEM (`wineventlog` + `sysmon` index) |
| Analyst | Surrplexie |
| Platform | Elastic SIEM (local lab replica) |

---

### Query 1 -- LSASS process access (Sysmon Event 10)

```kql
event.code: "10" AND winlog.event_data.TargetImage: *lsass*
```

| Field | Value |
|-------|-------|
| Total hits | 847 |
| Distinct SourceImage values | 12 |
| Suspicious hits | **3** |

**Suspicious results:**

| Timestamp | Host | SourceImage | GrantedAccess |
|-----------|------|------------|---------------|
| 2026-04-22 14:03 | WRK-04 | `C:\Windows\Temp\svch0st.exe` | `0x1FFFFF` (full access) |
| 2026-04-22 14:04 | WRK-04 | `C:\Windows\Temp\svch0st.exe` | `0x1FFFFF` |
| 2026-04-23 09:17 | WRK-04 | `cmd.exe` | `0x1010` (read only -- benign, AV scanner) |

Baseline: AV scanner (`MsMpEng.exe`, `MBAMService.exe`) reads LSASS with `0x1410` regularly -- excluded.
`0x1FFFFF` (PROCESS_ALL_ACCESS) from a non-system binary in `C:\Windows\Temp\` is a strong signal.

---

### Query 2 -- Suspicious process in Temp (pivot from Query 1)

```kql
event.code: "1" AND host.name: "WRK-04" AND process.name: "svch0st.exe"
```

| Timestamp | ParentImage | CommandLine | Hashes |
|-----------|------------|-------------|--------|
| 2026-04-22 13:58 | `powershell.exe` | `C:\Windows\Temp\svch0st.exe -p` | SHA256: `a1b2...` |

Parent was `powershell.exe` with parent `winword.exe` -- confirmed macro dropper chain.

---

### IOC candidates identified

| Type | Value | Confidence | Notes |
|------|-------|-----------|-------|
| SHA256 | `a1b2c3...` | High | Suspicious binary in Temp (Sysmon hash) |
| File path | `C:\Windows\Temp\svch0st.exe` | High | Leet-spelling of svchost.exe |
| Process | `svch0st.exe` | High | LSASS full-access dump |
| Parent chain | `winword.exe -> powershell.exe -> svch0st.exe` | High | Macro -> PS -> credential dump |

---

### Collection summary

Hunt **confirmed hypothesis** with high confidence on one host (WRK-04). Evidence supports
a macro-enabled Word document delivering a PowerShell dropper that executed a credential
dumper (Mimikatz or clone). Full timeline, all supporting queries, and IOCs passed to
`03_findings` for final documentation.

---

### Screenshots index

| # | File | Tool | What it shows |
|---|------|------|---------------|
| 1 | `shot_001.png` | **Elastic SIEM** | Query 1 results, 0x1FFFFF hit highlighted |
| 2 | `shot_002.png` | **Elastic SIEM** | Process creation pivot for svch0st.exe |
| 3 | `shot_003.png` | **Elastic SIEM** | Full parent chain: winword -> powershell -> svch0st |

Cross-references: [brief](../00_original/sample_EX.md) | [analysis](../02_dynamic/sample_EX.md) | [outcome](../03_findings/sample_EX.md)
