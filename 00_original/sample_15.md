# sample_15 -- original receipt (host log)

**Purpose:** Record identification and sourcing before/at acquisition. Binaries stay VM-only.

| Field | Value |
|-------|-------|
| **Sample ID** | sample_15 |
| **MalwareBazaar URL** | <!-- https://malwarebazaar.abuse.ch/sample/SHA256/ --> |
| **SHA256** | <!-- 64-char hex --> |
| **SHA1** | <!-- 40-char hex --> |
| **MD5** | <!-- 32-char hex --> |
| **File name (claimed)** | <!-- e.g. invoice.exe --> |
| **Mime / type** | <!-- application/x-dosexec --> |
| **Size** | <!-- bytes --> |
| **First seen (Bazaar)** | <!-- YYYY-MM-DD --> |
| **Bazaar verdict** | <!-- unknown / malicious --> |
| **Vendor detections** | <!-- count --> |

## Delivery and context

| Field | Value |
|-------|-------|
| **Delivery method** | <!-- web / email / unknown --> |
| **Reporter** | <!-- handle or blank --> |
| **Tags (Bazaar)** | <!-- exe / doc / etc --> |
| **Magika** | <!-- pebin / etc --> |
| **TrID (top)** | <!-- top match --> |

## Hashes for clustering

| Field | Value | Notes |
|-------|-------|-------|
| **imphash** | | Clustering hint only |
| **ssdeep** | | Fuzzy similarity |
| **TLSH** | | Locality-sensitive hash |

## URLs from Bazaar page

| Kind | URL |
|------|-----|
| | |

## YARA rules flagged

| Rule | Author | Implication |
|------|--------|-------------|
| | | |

## Acquisition checklist (VM)

- [ ] Download inside VM only.
- [ ] SHA256 verified on VM.
- [ ] Sample path on VM noted.
- [ ] Never copy binary to host.

## Cross-references

- Static: [01_static/sample_15.md](../01_static/sample_15.md)
- Dynamic: [02_dynamic/sample_15.md](../02_dynamic/sample_15.md)
- Findings: [03_findings/sample_15.md](../03_findings/sample_15.md)
- IOCs: [40_iocs/indicators.csv](../40_iocs/indicators.csv)
- Screenshots: [50_screenshots/sample_15/](../50_screenshots/sample_15/)
