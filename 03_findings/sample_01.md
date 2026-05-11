---
schema_version: 1
sample_id: sample_01
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

# sample_01 — findings (portfolio slice)

**SHA256:** `ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7`

**Confidence:** **Medium-high** on **packaging / type** (NSIS installer, high entropy overlay); **medium** on **malicious intent** (fake error UX + Bazaar/VT hints + lab execution) pending **structured dynamic** (Procmon) if you want higher rigor.

**Analyst one-liner:** Large **NSIS-delivered PE** posing as **`pijawoBridge` / updater** branding; executes to **bogus system error dialogs** (misspelling + gibberish).

## Verdict

- **Classification (working):** **Suspicious installer / potentially unwanted or malicious deception** — not a minimal legit system component; inner payload not statically extracted here.
- **Why:** **Static:** NSIS 3.04 + **8.0 entropy** + mismatch between **tiny PE on disk vs 72 MB file** · **Dynamic:** **`IMG_6042`** shows **non-authentic error UI**.

## IOCs (also keep `40_iocs/indicators.csv` in sync)

| Type | Value | Notes |
|------|--------|------|
| SHA256 | `ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7` | Canonical sample |
| Branding | `pijawoBridge` | Version resource / PEStudio description |
| Dialog string | `Critical systeam error` | Typo deliberate / fake |
| Dialog title | `HGWJY` | Nonsense title |
| Dialog body | `jimnb uq0ukc1m ulo0ov lui0kilpa cqch an` | Sample gibberish (normalize if you observe variants) |

## What you proved

- **Static:** **NSIS** installer structure (DIE + PEStudio manifest + **`.ndata`** in HxD) · **Overlay** dominates file size · Branding **`pijawoBridge`**.
- **Dynamic:** Post-run **deceptive error dialogs** captured **`IMG_6042`**.

## Gaps / next steps

1. **Reconcile hashes** on VM (**`00_original`** / **`01_static`**) if CFF vs Bazaar MD5/SHA1 still disagree after fresh `Get-FileHash`.
2. **Optional:** Repeat run with **Procmon** + snapshot discipline for **paths, persistence, children, network**.
3. **Optional:** **NSIS unpack** track (separate tools) if you need inner files **without** execution.

## Public-safe blurb

This sample is a large **32-bit Windows executable** whose structure matches a **Nullsoft (NSIS) installer** with most of the file size stored as **compressed overlay data**. Static tools report **very high entropy** and branding under the name **`pijawoBridge`**. When executed in an analysis virtual machine, it produced **error dialogs** that used a **misspelled “system”** string and **nonsense text**, which is inconsistent with legitimate system software. **Further dynamic logging** (process monitor, network) would be needed to document persistence, secondary downloads, or full behavior.
