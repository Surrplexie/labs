# MITRE ATT&CK Coverage Tracker

**Scope:** Triage-level technique mapping from static and dynamic analysis notes.
This is not a certified ATT&CK assessment. Mappings are analytical best-guesses
based on observed artifacts, tool output, and behavioral evidence — they are not
vendor-validated or legally determinative.

**Update:** Hand-edit this file when closing a sample. The `INDEX.md` cross-reference
table is auto-generated from frontmatter; this document carries the reasoning.

---

## Coverage table

| Technique ID | Name | Tactic | Samples | Evidence quality | Notes |
|---|---|---|---|---|---|
| T1036 | Masquerading | Defense Evasion | [sample_01](../03_findings/sample_01.md) | Medium | Posed as `Updater_v2.211.exe`; version resource branding `pijawoBridge` — mismatch between name and embedded identity |
| T1027 | Obfuscated Files or Information | Defense Evasion | [sample_01](../03_findings/sample_01.md) | High | Entropy 8.0 globally; 72 MB file with ~46 KB PE image; bulk stored as NSIS zlib-compressed overlay — standard installer obfuscation |
| T1583.006 | Acquire Infrastructure: Web Services | Resource Development | [sample_01](../03_findings/sample_01.md) | Medium | Sample hosted via `pages.dev` (Cloudflare Pages) and GitHub Releases — free hosting to avoid attribution |

---

## Evidence quality key

| Level | Meaning |
|---|---|
| **High** | Directly observed in tooling output (PE headers, Procmon log, network capture) — artifact is unambiguous |
| **Medium** | Inferred from static indicators or single behavioral observation with corroborating context |
| **Low** | Circumstantial — pattern matches but could have alternative explanation; flag for follow-up |
| **Pending** | Technique suspected but not yet verified in a controlled run |

---

## Tactic coverage heatmap

| Tactic | Count | Techniques |
|---|---|---|
| Defense Evasion | 2 | T1036, T1027 |
| Resource Development | 1 | T1583.006 |
| Execution | 0 | (none documented yet) |
| Persistence | 0 | (none documented yet) |
| Discovery | 0 | (none documented yet) |
| Collection | 0 | (none documented yet) |
| Command & Control | 0 | (none documented yet) |
| Exfiltration | 0 | (none documented yet) |
| Impact | 0 | (none documented yet) |

---

## Techniques seen but not yet formally mapped

<!-- Move items here when you observe a behavior but haven't confirmed the technique ID.
     Format: Behavior description -- candidate technique ID -- blocking gap -->

- NSIS installer script execution of inner payload: candidate T1059 (Command and Scripting Interpreter) or T1204.002 (User Execution: Malicious File) -- not confirmed without NSIS extraction or Procmon-instrumented run.
- Possible anti-VM check (YARA rule `TH_AntiVM_MassHunt`): candidate T1497 (Virtualization/Sandbox Evasion) -- YARA string match is not behavioral proof; needs controlled run on bare metal vs. VM comparison.

---

## Notes on technique scoping

- **T1583 (Acquire Infrastructure)** is a Resource Development technique attributed to
  the *threat actor*, not the malware itself. Mapping it here is a stretch at triage
  level unless attribution is available. Flagged because the infrastructure pattern
  (free hosting + GitHub) is a consistent indicator across similar samples.

- **T1027** covers a broad range of obfuscation. The NSIS overlay compression maps
  most closely to T1027.002 (Software Packing), but since the outer NSIS stub is not
  itself a packer in the traditional sense, T1027 (parent) is used until further
  analysis of the inner payload.

---

## How to update this file

When you close a sample as `done`:

1. For each technique in the sample's frontmatter `mitre_techniques:` list, add or
   update a row in the coverage table above.
2. Update the tactic heatmap counts.
3. Move any "suspected but not mapped" observations from the bottom section into
   the main table once confirmed.
4. Re-run `30_scripts/export-summary.ps1` to refresh `INDEX.md`.
