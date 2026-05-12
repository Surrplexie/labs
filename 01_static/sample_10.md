# sample_10 -- static triage (PE)

| Field | Value |
|-------|-------|
| **SHA256** | <!-- from 00_original --> |
| **Name / tag** | <!-- claimed filename --> |
| **Date analyzed** | 2026-05-12 |
| **VM user** | win11 |

> CFF Explorer may show a PE-image-only hash on overlay-heavy samples. Full-file hash from Get-FileHash is the canonical reference.

## DIE

- **PE type / arch:** <!-- PE32 / PE32+ / I386 / AMD64 / GUI / Console -->
- **Linker / compiler:** <!-- e.g. MSVC 14.x -->
- **Packer / installer:** <!-- UPX / NSIS / none -->
- **Overlay:** <!-- offset and size if present -->
- **Heuristic:** <!-- any flags -->

## PEStudio

- **Entropy:** <!-- 0.0 - 8.0 -->
- **Version resource:** <!-- FileDescription / ProductName / CompanyName -->
- **Manifest:** <!-- embedded or absent -->
- **Imports:** <!-- count; any blacklisted? -->
- **Sections:** <!-- list with notable flags -->
- **VirusTotal (in UI):** <!-- N/66 -->

## CFF Explorer

- **File size:** <!-- bytes --> | **PE image size:** <!-- bytes; note gap if overlay present -->
- **Version info:** <!-- FileDescription / ProductName string -->
- **PE timestamp:** <!-- hex + decoded date -->
- **Section table:** <!-- names and notable characteristics -->

## HxD

- **Magic:** <!-- MZ at 0x0, PE\0\0 at offset -->
- **Section names visible:** <!-- .text .rdata .ndata .upx0 etc -->
- **Notable hex patterns:** <!-- any embedded markers -->

## Static summary (portfolio-ready)

<!-- One paragraph: packaging, entropy, version resource, any deception signals, next steps. -->

## Screenshot map

| # | File | Tool | What it shows |
|---|------|------|---------------|
| | | | |

Cross-references: [acquisition](../00_original/sample_10.md) | [dynamic](../02_dynamic/sample_10.md) | [findings](../03_findings/sample_10.md) | [screenshots](../50_screenshots/sample_10/)
