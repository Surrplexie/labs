# 03_findings

**Final phase folder — the synthesis document for every engagement kind.**

| Kind | What this folder holds | Key YAML fields |
|------|------------------------|-----------------|
| `file` | Verdict, IOC table, MITRE mapping, portfolio blurb | `verdict`, `mitre_techniques`, `sha256` |
| `ctf` | Writeup, methodology, skills list, public-safe flag proof | `solved`, `category`, `difficulty`, `skills` |
| `lab` | Reflection, objectives met, skills demonstrated | `objectives_met`, `skills`, `course` |
| `hunt` | Outcome, detections, confidence, recommendations | `detections_found`, `hypothesis`, `outcome` |

All findings files use YAML frontmatter with `schema_version: 1` (file kind) or
`schema_version: 2` (ctf/lab/hunt). See [`30_scripts/schema/CHANGELOG.md`](../30_scripts/schema/CHANGELOG.md).

---

**For `file` engagements:** Findings and portfolio slices — the final word on each analysis.

Each `sample_XX.md` in this folder is the synthesis document that ties the other three
phases together: a YAML frontmatter block (machine-readable metadata), a working
verdict, a complete IOC table, a "what you proved" section, and a public-safe blurb.

This file is the one a recruiter, peer, or automation tool would read to understand
what you found and how confident you are.

---

## What goes here

| Section | Examples |
|---------|---------|
| YAML frontmatter | `schema_version`, `sha256`, `phase`, `analyst`, dates, `verdict`, `tags`, MITRE IDs, `procmon_run`, etc. |
| Confidence statement | Overall confidence level with reasoning |
| Analyst one-liner | Single-sentence summary of the sample and its behavior |
| Verdict block | Classification with justification referencing static and dynamic evidence |
| IOC table | All indicators: hashes, filenames, URLs, IPs, registry keys, drop paths, strings |
| What you proved | Bullet list itemising each claim and its evidence source |
| Gaps / next steps | Honestly list what you did NOT confirm and what would close those gaps |
| Public-safe blurb | A paragraph you could paste into a portfolio, LinkedIn, or resume |
| Cross-references | Links to all other phase files |

## What does NOT go here

- Raw Procmon CSV or tool screenshots (those belong in `02_dynamic/` and `50_screenshots/`)
- Unverified claims — only state what your evidence actually supports
- Sample binaries or any executable artifact
- Internal paths, real usernames, or host machine identity

## Tips on the YAML frontmatter

- `schema_version: 1` must always be present and must equal `1`; `validate.ps1` check 11
  enforces this.
- `verdict` must be one of: `benign`, `suspicious`, `malicious`, `unknown`.
- `family_confidence` must be one of: `high`, `medium-high`, `medium`, `low`.
- `tags` and `mitre_techniques` are arrays; add as many entries as evidence supports —
  do not pad with guesses.
- `procmon_run: true` means you actually captured a Procmon session; `false` means you
  did not (even if you ran the sample).
- `dynamic_complete: true` means you have a full instrumented pass (process tree,
  FS, registry, network all populated); leave `false` if any of those are missing.
- Keep the `mb_url` field even after you have finished analysis — it preserves traceability
  back to the public source record.

## Tips on the IOC table

- Include everything you confirmed through tooling; also include hashes and URLs from
  Bazaar even if you could not verify them dynamically — note the source.
- Use the `type` column consistently so automation can parse it:
  `sha256`, `sha1`, `md5`, `imphash`, `ssdeep`, `tlsh`, `filename`, `url`, `ip`,
  `domain`, `registry_key`, `file_path`, `mutex`, `software_name`, `ui_string`,
  `ui_title`.
- Sync any new IOCs to `40_iocs/indicators.csv` — validate.ps1 check 7 will flag
  mismatches.

## Tips on the "What you proved" section

Write one bullet per claim. Each bullet should have:
1. The claim ("Sample drops a persistence binary")
2. The evidence ("Procmon WriteFile to `%APPDATA%\Microsoft\Windows\InvoiceHelper\svchost32.exe`
   confirmed in `02_dynamic`")
3. The confidence level if not obvious ("high confidence — two independent tool
   captures agree")

If you only have static evidence for a claim, say so and use hedging language
("consistent with", "suggests", "would need dynamic confirmation").

---

## Complete example (made-up — for reference only)

> **This entire block is a fabricated example.**
> Sample ID, hashes, family names, company names, IPs, registry keys, and all
> behavioral details are invented for illustration. They do not correspond to any
> real file in this repository. The IP `192.0.2.47` is from RFC 5737 TEST-NET.

---

```yaml
---
schema_version: 1
sample_id: sample_EX
name_tag: "InvoiceHelper_Setup.exe"
sha256: 4f3a8b2c1d9e7f06a5b4c3d2e1f09876543abcdef1234567890abcdef12345678
phase: findings
analyst: Surrplexie
date_acquired: "2026-04-14"
date_analyzed: "2026-04-15"
status: done
verdict: malicious
family_guess: "AgentTesla-like infostealer / credential harvester"
family_confidence: medium-high
sample_type: PE
tags:
  - exe
  - upx
  - infostealer
  - credential-harvesting
  - persistence
  - fake-version-resource
  - c2
  - lolbin-abuse
mitre_techniques:
  - T1027.002  # Obfuscated Files or Information: Software Packing (UPX)
  - T1036.005  # Masquerading: Match Legitimate Name or Location (svchost32.exe name)
  - T1547.001  # Boot or Logon Autostart Execution: Registry Run Keys
  - T1555.003  # Credentials from Password Stores: Credentials from Web Browsers
  - T1059.003  # Command and Scripting Interpreter: Windows Command Shell (cmd.exe drop)
  - T1041      # Exfiltration Over C2 Channel (encrypted POST /log.php)
  - T1082      # System Information Discovery (UID generation from machine fingerprint)
mb_url: "https://malwarebazaar.abuse.ch/sample/4f3a8b2c1d9e7f06a5b4c3d2e1f09876543abcdef1234567890abcdef12345678/"
procmon_run: true
dynamic_complete: true
---
```

---

### sample_EX -- findings (portfolio slice)

**SHA256:** `4f3a8b2c1d9e7f06a5b4c3d2e1f09876543abcdef1234567890abcdef12345678`

**Confidence:** **Medium-high** on **family / behavior** (credential harvesting +
C2 beaconing confirmed by both static strings and dynamic instrumentation).
**Medium** on exact **family name** (AgentTesla-like behavior profile, but inner
payload not decompiled — needs IDA/Ghidra confirmation for definitive attribution).

**Analyst one-liner:** UPX-packed 32-bit PE impersonating Adobe branding; drops a
persistence copy named `svchost32.exe`, reads Chrome/Firefox credential stores, and
beacons stolen data to a hardcoded IP over HTTP port 8080.

Cross-references: [acquisition](../00_original/sample_EX.md) | [static](../01_static/sample_EX.md) | [dynamic](../02_dynamic/sample_EX.md) | [screenshots](../50_screenshots/sample_EX/) | [IOCs](../40_iocs/indicators.csv)

---

#### Verdict

- **Classification:** **Malicious** — infostealer with persistence and active C2.
- **Why (static):** UPX 3.96 packing; version resource impersonates `Adobe Systems Inc.`
  (unsigned, no manifest); unpacked strings include Chrome/Firefox credential paths,
  AES crypto symbols, keylogger output prefixes, and a hardcoded C2 URL
  (`http://192.0.2.47:8080/gate.php`).
- **Why (dynamic):** Live instrumentation confirmed self-copy to
  `%APPDATA%\…\svchost32.exe`, Run key persistence, Chrome and Firefox Login Data reads
  within 4 seconds, and encrypted POST to C2 (`/log.php`) carrying a ~4 KB blob.
  150-second beacon interval observed.
- **Confidence limit:** Inner disassembly not performed in this pass — AES key and
  exact data format of exfil blob not confirmed; family attribution is behavioral, not
  code-level.

---

#### IOCs (keep `40_iocs/indicators.csv` in sync)

| Type | Value | Notes |
|------|-------|-------|
| sha256 | `4f3a8b2c1d9e7f06a5b4c3d2e1f09876543abcdef1234567890abcdef12345678` | Canonical sample |
| sha1 | `a1b2c3d4e5f678901234567890abcdef12345678` | MalwareBazaar |
| md5 | `1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d` | MalwareBazaar |
| imphash | `f1e2d3c4b5a6978869504132c3b4a596` | Clustering hint only |
| filename | `InvoiceHelper_Setup.exe` | Bazaar claimed name |
| filename | `svchost32.exe` | Dropped persistence binary name |
| file_path | `%APPDATA%\Microsoft\Windows\InvoiceHelper\svchost32.exe` | Drop + execution path |
| file_path | `%APPDATA%\Microsoft\Windows\InvoiceHelper\cfg.dat` | Encrypted config file |
| file_path | `%APPDATA%\Microsoft\Windows\InvoiceHelper\ex_001.bin` | Exfil staging blob |
| registry_key | `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\InvoiceHelper` | Persistence: Run key |
| registry_key | `HKCU\Software\InvoiceHelper` | Config hive |
| ip | `192.0.2.47` | Hardcoded C2 (TEST-NET example) |
| url | `http://192.0.2.47:8080/gate.php` | C2 check-in endpoint |
| url | `http://192.0.2.47:8080/log.php` | C2 exfil/log endpoint |
| software_name | `Adobe Invoice Reader Pro v4.2` | Fake version resource (impersonation) |
| software_name | `AgentHelper/2.1` | Internal version string from unpacked image |
| mutex | _(not observed)_ | No mutex identified in this pass |

---

#### What you proved

- **Packing:** DIE and PEStudio both detected UPX 3.96; `.upx0`/`.upx1` section names
  visible in HxD. `upx -d` unpack succeeded without executing the file.
  _Confidence: high._
- **Fake branding / masquerading:** Version resource claims `Adobe Systems Inc.` but
  the binary is unsigned and has no Microsoft/Adobe Authenticode chain. PEStudio's
  version resource tree and CFF both show the impersonation string.
  _Confidence: high._
- **Credential store access:** Procmon WriteFile/ReadFile events confirm the sample
  opened `Chrome\…\Login Data` and `Firefox\…\logins.json` within 4 seconds of
  execution. Static strings for these paths were found in the unpacked image.
  _Confidence: high (static + dynamic agree)._
- **Persistence via Run key:** `reg.exe` child process (cmd.exe → reg.exe, captured in
  Process Explorer) wrote
  `HKCU\Software\Microsoft\Windows\CurrentVersion\Run\InvoiceHelper`. Confirmed in
  Procmon registry filter.
  _Confidence: high (two independent captures)._
- **Self-copy with misleading name:** Procmon WriteFile confirms the binary copied
  itself to `%APPDATA%\…\svchost32.exe` — name chosen to blend with real `svchost.exe`
  in casual task manager inspection.
  _Confidence: high._
- **C2 beaconing + encrypted exfil:** TCPView and Wireshark both show TCP connections
  to `192.0.2.47:8080`. POST bodies not plaintext; AES usage inferred from static
  strings and Wireshark entropy. 150-second interval observed across two beacon cycles.
  _Confidence: medium-high (behavior confirmed, payload content not decrypted)._
- **Anti-analysis / sandbox check (suspected):** Transient browser default hijack
  attempt (`HKCU\Software\Classes\http\shell\open\command`) self-deleted within 1
  second — possible sandbox awareness, but could be an error path. Not confirmed.
  _Confidence: low — requires repeat run with browser profile present._

---

#### Gaps / next steps

1. **Exfil payload decryption** — The 4 KB `ex_001.bin` blob and network POST body are
   AES-encrypted. Static key recovery (Ghidra or x32dbg after unpack) would confirm
   what data is actually stolen.
2. **Exact family confirmation** — Behavioral profile matches AgentTesla v2/v3 but
   code-level comparison (strings, code patterns in disassembler) not performed. Needed
   for definitive family attribution.
3. **Browser hijack branch** — The `http` protocol handler write-and-delete may only
   fully execute when a real browser profile is present. Repeat on a VM with Firefox /
   Chrome installed and active profiles.
4. **Mutex check** — No mutex was observed, but the tool filter may have missed it.
   Check Process Explorer's handle view for `\Sessions\1\BaseNamedObjects\*` after
   the sample is running.
5. **Persistence verification** — Run key was written; confirm survival after simulated
   reboot (snapshot restore to post-execution state and check autostart list).

---

#### Public-safe blurb

This sample is a **UPX-packed 32-bit Windows executable** whose version resource
fraudulently claims Adobe authorship under the name "Invoice Helper". When executed in
an instrumented virtual machine, it created a persistence copy named `svchost32.exe`
in the user's AppData folder, registered a **startup Run key**, and within four seconds
had **read both Chrome and Firefox credential store files**. It then established an
**encrypted HTTP connection** to a hardcoded IP address, sending an approximately 4 KB
encrypted blob consistent with stolen credential data. The sample exhibits a behavioral
profile aligned with commodity **infostealers** — specifically credential harvesting,
persistence, and C2 exfiltration — though definitive family attribution would require
disassembly of the unpacked image.
