# Tooling Reference

Quick-reference for static and dynamic analysis tools used in this logbook.
Each section covers: purpose, key signals to read, common gotchas, and
how findings from this tool get recorded in phase files.

---

## Static analysis tools

### DIE (Detect It Easy)

**Purpose:** Identify compiler, linker, packer, installer type, and overlay structure
from PE headers and heuristics. Fast first-pass triage.

**Key fields to record:**

| Field | Where it appears | What to note |
|-------|-----------------|--------------|
| PE type / arch | Top line | PE32 vs PE32+ (32 vs 64-bit), I386 vs x64 |
| Linker / compiler | Compiler tree | Toolchain version -- helps cluster similar builds |
| Installer | Installer tree | NSIS, Inno Setup, WiX, MSI, etc. |
| Compression | Overlay node | zlib, lzma, solid -- affects extraction approach |
| Heuristic | Heur node | Generic packer flags -- investigate further, not a verdict |
| Overlay | Overlay node | Offset + size -- large overlay = installer payload or appended data |

**Gotchas:**
- Heuristic flags ("Generic packer") are leads, not verdicts -- correlate with PEStudio entropy and manifest.
- DIE's NSIS detection is reliable; its generic packer flag has high false-positive rate.
- Linker version (e.g., "Microsoft Linker 6.0") may not match real build date on repacked samples.

**Records in:** `01_static/sample_XX.md` under `## DIE`

---

### PEStudio

**Purpose:** Comprehensive PE metadata analysis -- entropy, imports, version resources,
manifest, strings, overlay, VirusTotal reputation.

**Key fields to record:**

| Field | Where it appears | What to note |
|-------|-----------------|--------------|
| SHA256 | Indicators pane | Confirm matches MalwareBazaar value |
| Entropy (global) | Indicators / entropy | > 7.0 = compressed / encrypted content; 8.0 = max compression |
| FileDescription / ProductName | Version resource | May contain fake or misleading branding |
| Manifest name | Manifest pane | `Nullsoft.NSIS.exehead` = NSIS; `Microsoft.Windows.*` = potential masquerade |
| Libraries / imports | Libraries pane | Low count = minimal stub (inner payload elsewhere) |
| Overlay | Overlay node | Signature "unknown" = raw data, often installer archive |
| VirusTotal | Indicators pane | `> 1/66` = community flag, not a verdict |

**Gotchas:**
- VT score in PEStudio UI may be stale (cached). Always check VT directly for recent data.
- High import count does not mean benign -- many malware samples have rich import tables.
- Version resource fields (`pijawoBridge`) are trivially writable; treat as indicator, not proof.

**Records in:** `01_static/sample_XX.md` under `## PEStudio`

---

### CFF Explorer

**Purpose:** Detailed PE structure view -- section headers, version info, NTFS timestamps,
import/export tables, resources, and raw hex editing capability.

**Key fields to record:**

| Field | Location | What to note |
|-------|----------|--------------|
| File type | General Info | "Portable Executable 32/64" |
| File size vs. PE image size | General Info | Large gap = overlay / appended data |
| FileDescription / ProductName | Version Info | Cross-check with PEStudio |
| FileVersion / LegalCopyright | Version Info | Year in copyright can suggest build era |
| NTFS timestamps | General Info | Created / Modified / Accessed -- **VM local time**, not UTC |
| MD5 / SHA-1 in UI | General Info | May reflect PE-image-only hash, not full-file -- always cross-check |

**Gotchas:**
- **CFF hash fields may NOT match MalwareBazaar.** CFF can compute hash over the PE mapped
  image only, excluding the overlay. This is expected behavior -- document it, don't flag as
  a sample mismatch. Always use `Get-FileHash` on the full binary for authoritative hashes.
- NTFS timestamps are VM-local and easy to forge -- treat as supplementary context only.
- CFF will open any binary, not just PE -- it may misidentify or error on non-PE samples.

**Records in:** `01_static/sample_XX.md` under `## CFF Explorer`

---

### HxD

**Purpose:** Hex editor for raw byte inspection -- signature verification, section name
reading, string hunting, offset mapping.

**Key fields to record:**

| Field | What to look for |
|-------|-----------------|
| Signature bytes | `4D 5A` (MZ) at 0x0 for PE; `50 4B 03 04` (ZIP) -- identify file type by magic bytes |
| `PE\0\0` offset | Typically at 0xD0 or 0xE0 for standard PE stubs |
| Section names | Visible in ASCII column: `.text`, `.rdata`, `.data`, `.ndata`, `.rsrc`, `.UPX0`, etc. |
| String artifacts | URLs, paths, error messages -- visible in ASCII column of data sections |
| Overlay start | After last section -- look for NSIS magic `EF BE AD DE` or compression stream headers |

**Gotchas:**
- Only record what you can visually confirm in HxD -- do not infer from other tools here.
- `.ndata` in the section name column is a definitive NSIS signal (not just NSIS-like).
- HxD byte search is useful for finding magic bytes if the file type is unclear.

**Records in:** `01_static/sample_XX.md` under `## HxD`

---

## Dynamic analysis tools

### Procmon (Process Monitor)

**Purpose:** Real-time capture of process, file system, registry, and network events
from a running system. Ground truth for what the binary actually does.

**Workflow:**
1. Set capture filter BEFORE running the sample (filter by process name or PID)
2. Start capture, run sample once, stop capture
3. Export filtered log to CSV (`File > Save...` as CSV)
4. Analyze: look for drops in `%TEMP%`, Run key writes, suspicious child processes, network callbacks

**Key filter columns:**

| Column | What to note |
|--------|--------------|
| Process Name | The binary name -- also watch for child spawns |
| Operation | `CreateFile`, `WriteFile`, `RegSetValue`, `TCP Connect` |
| Path | Drop paths (`%TEMP%\*.exe`), Run key paths, network destinations |
| Result | `SUCCESS` for completed ops; `NAME NOT FOUND` often from AV-evasion probing |
| Detail | For registry: value data; for network: remote address and port |

**Records in:** `02_dynamic/sample_XX.md` under `## File system`, `## Registry`, `## Network`

---

### Process Explorer

**Purpose:** Process tree visualization, string inspection of running processes,
DLL listing, parent-child relationships.

**Key observations:**

| Signal | Interpretation |
|--------|---------------|
| Hollow or suspended child process | Process injection candidate (T1055) |
| Legitimate process with unexpected parent | Masquerading or process injection |
| High entropy process memory regions | Injected shellcode or packed payload |
| `.exe` spawned from `%TEMP%` | Classic dropper behavior |

**Records in:** `02_dynamic/sample_XX.md` under `## Process tree`

---

### TCPView

**Purpose:** Real-time network connection viewer -- shows active TCP/UDP connections
with process association.

**Key signals:**

| Signal | What to check |
|--------|--------------|
| Unexpected outbound connection | Note remote IP/hostname and port |
| Connection to known-bad IP | Cross-reference with threat intel |
| DNS resolution visible | Record queried hostname as IOC |
| High port ephemeral C2 | Note if non-standard port used |

**Records in:** `02_dynamic/sample_XX.md` under `## Network`; add confirmed hosts to `40_iocs/indicators.csv`

---

### Wireshark

**Purpose:** Full packet capture for network traffic analysis -- protocol dissection,
payload inspection, DNS queries, HTTP requests.

**Useful filters:**

```
dns                          # All DNS queries -- hostname IOCs
http                         # HTTP requests -- URL and User-Agent
ip.addr == <suspicious_ip>   # Filter to one destination
tcp.port == 443              # TLS traffic -- look for SNI in Client Hello
```

**Records in:** `02_dynamic/sample_XX.md` under `## Network`

---

## Common compound signals

These combinations are more meaningful than individual indicators:

| Combination | Interpretation |
|-------------|---------------|
| Entropy 8.0 + `.ndata` section + NSIS manifest | NSIS-compressed installer -- high confidence |
| Low import count + large overlay | Minimal PE stub, payload is elsewhere |
| Misleading version branding + fake error UX | Social engineering / deception malware |
| YARA anti-VM + no Procmon data | Dynamic behavior may differ bare-metal vs. VM |
| Child process from `%TEMP%` + Run key write | Classic dropper + persistence |
| High entropy PE section + no recognizable compiler | Packed or encrypted payload section |
| Network connection immediately after execution | Beaconing, C2 check-in, or exfil |

---

## Hash types and their uses

| Hash | Use case | Gotcha |
|------|----------|--------|
| SHA256 | Primary file identity; MalwareBazaar lookup | Full-file hash; always verify with `Get-FileHash` |
| SHA1 | Legacy identity; some threat intel databases | Weak collision resistance -- secondary only |
| MD5 | Legacy; YARA rules; quick-compare | Collision-vulnerable -- confirm with SHA256 |
| imphash | Import table similarity clustering | Collides across different samples with same import set |
| ssdeep | Fuzzy similarity for near-duplicate samples | Requires holding the binary; use for "similar to" comparisons |
| TLSH | Locality-sensitive hash; better than ssdeep for PE | Requires binary; integrate with VirusTotal or MalwareBazaar |
| dhash (icon) | Icon similarity across samples | Weak alone -- many unrelated programs share stock icons |

---

## Confidence calibration

When writing verdict confidence in `03_findings/`:

| Level | Criteria |
|-------|---------|
| **High** | Multiple independent tooling signals agree + behavioral evidence from controlled Procmon run |
| **Medium-high** | Strong static evidence + limited behavioral observation (e.g., single execution pass, no Procmon) |
| **Medium** | Static-only analysis; behavioral evidence indirect or from screenshots only |
| **Low** | Single indicator or heavily ambiguous tooling output; needs follow-up |
| **Unknown** | No analysis done yet; placeholder |
