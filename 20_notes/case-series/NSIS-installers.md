# Case Series: NSIS-Packaged Malware Delivery

**Theme:** Malware or PUP (potentially unwanted program) distributed using the
Nullsoft Scriptable Install System (NSIS) as a delivery wrapper.

**Why this matters:** NSIS is a legitimate, widely-used open-source installer
framework. Threat actors abuse it because it is easy to produce, difficult to
detect by name alone, produces a self-contained single-file dropper with large
compressed overlays, and blends with legitimate software installation traffic.

---

## Samples in this series

| Sample | Name / Tag | Verdict | Confidence | Link |
|--------|------------|---------|------------|------|
| sample_01 | Updater_v2.211.exe | suspicious | medium-high | [findings](../../03_findings/sample_01.md) |

---

## Structural fingerprint of NSIS-delivered samples

Tooling signals that consistently identify NSIS-packaged binaries:

### DIE (Detect It Easy)
- Installer type: `Nullsoft Scriptable Install System (NSIS)` with version (e.g., 3.04)
- Compression: typically `zlib` or `lzma`, often `solid`
- Heuristic: `(Heur) Packer: Generic` with note about `.ndata` section offset anomaly
- Overlay: large binary block identified as `NSIS data`

### PEStudio
- Manifest name: `Nullsoft.NSIS.exehead` (definitive NSIS stub identifier)
- Entropy: very high (7.8 - 8.0) due to compressed overlay
- Import count: low (~35 imports) -- the PE stub is minimal; the real payload is in the overlay
- Version resource: may contain misleading branding (e.g., `pijawoBridge`)

### CFF Explorer
- File size vs. PE image size: extreme disparity (e.g., 72 MB file, 46 KB PE image)
  The gap is the NSIS archive. Any ratio > 10:1 is worth flagging.
- Section names: `.text`, `.rdata`, `.data`, `.ndata`, `.rsrc` -- `.ndata` is the NSIS marker

### HxD
- `MZ` at 0x0, `PE\0\0` at typical offset
- Section names visible in ASCII column -- look for `.ndata`
- After the PE image (small), the rest of the file is the NSIS archive stream

### YARA / MalwareBazaar
- Rule: `Detect_NSIS_Nullsoft_Installer` (Obscurity Labs LLC) -- reliable positive
- Rule: `Sus_CMD_Powershell_Usage` -- frequent in NSIS samples; high false-positive rate
  (NSIS scripts often contain CMD/PS calls for legitimate purposes)

---

## Behavioral patterns (dynamic)

Observations from sample_01 (limited dynamic pass -- no Procmon instrumentation):

- **Post-execution UI:** Fake/deceptive error dialogs immediately after run
  - Misspelled strings ("systeam" instead of "system") -- common social engineering tell
  - Randomized or gibberish dialog titles/bodies -- suggests automated generation or scripted deception
- **Expected but not yet confirmed:**
  - NSIS extraction of inner payload to `%TEMP%` -- typical NSIS behavior
  - Child process spawning from extracted payload
  - Registry persistence (Run key) -- common but not confirmed without Procmon

---

## NSIS-specific next steps (if you want deeper analysis)

1. **NSIS script extraction without execution:**
   Tools: `7-Zip` (can open NSIS archives), `UniExtract2`, or dedicated NSIS unpacker.
   This exposes the inner installer script and dropped files without running the binary.

2. **Procmon-instrumented execution:**
   Run with a clean snapshot + Procmon filtering on `%TEMP%` paths and registry keys.
   Look for: extracted EXE/DLL, autostart registry writes, network callbacks.

3. **Inner payload hash:**
   After extraction, compute SHA256 of any dropped binaries and search MalwareBazaar
   independently. The outer NSIS wrapper is often a commodity dropper; the inner
   payload may have its own threat intel history.

4. **String extraction from NSIS archive:**
   Run `strings` on the full binary or on the extracted installer script. NSIS scripts
   often contain hard-coded URLs, C2 endpoints, or target paths.

---

## Distinguishing features across NSIS samples

When comparing multiple NSIS-wrapped samples, look for:

| Feature | Unique per sample | Shared across campaign |
|---------|-------------------|------------------------|
| Outer PE SHA256 | Yes | No |
| NSIS version | Often shared | Campaign-level signal |
| Inner payload SHA256 | Yes | Sometimes linked |
| Version branding (`pijawoBridge`) | Sample-specific name | Pattern of fake branding |
| Distribution URL structure | Often unique | Hosting provider may repeat |
| Delivery mechanism (pages.dev + GitHub) | May repeat | Strong campaign indicator |
| Anti-VM YARA hits | Common across NSIS | Weak alone -- corroborate |

---

## Analytical lessons from sample_01

1. **Entropy alone is not a verdict.** Entropy 8.0 is consistent with both legitimate
   compressed installers and malware. The combination of entropy + misleading branding
   + deceptive post-run UI builds the case.

2. **The CFF hash discrepancy is a PE-tool artifact, not evidence of tampering.**
   CFF Explorer may compute hash over the PE image only, not the full file. Always
   validate hash against `Get-FileHash` on the full binary and MalwareBazaar.

3. **YARA rule matches are leads, not verdicts.** `Sus_CMD_Powershell_Usage` fires on
   most NSIS samples including legitimate ones. Use as a starting hypothesis, not
   a conclusion.

4. **The `imphash` clustering signal is noisy at this level.** MalwareBazaar cited
   overlap with GuLoader/RemcosRAT via imphash. This is plausible but imphash can
   collide across unrelated PE stubs. Treat as "worth checking VT" not as attribution.

---

## References and further reading

- NSIS documentation: https://nsis.sourceforge.io/
- MalwareBazaar tag: https://bazaar.abuse.ch/browse/tag/nsis/
- ATT&CK: T1027 (Obfuscated Files), T1036 (Masquerading), T1204.002 (User Execution: Malicious File)
