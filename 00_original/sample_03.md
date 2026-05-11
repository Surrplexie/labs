# sample_03 -- original receipt (host log)

**Purpose:** Record identification and sourcing before/at acquisition. Binaries stay VM-only.
Populate from MalwareBazaar *before* download.

| Field | Value |
|--------|--------|
| **Sample ID** | `sample_03` |
| **MalwareBazaar URL** | |
| **SHA256** | |
| **SHA1** | |
| **MD5** | |
| **File name (claimed)** | |
| **MIME / type** | |
| **Size** | |
| **First seen (Bazaar)** | |
| **Last seen** | |
| **Bazaar verdict** | |
| **Vendor detections** | |

## Delivery & context

| Field | Value |
|--------|--------|
| **Delivery method** | |
| **Reporter** | |
| **Tags** | |
| **Magika** | |
| **TrID (top)** | |

## Hashes for clustering / lookups

| Field | Value | Notes |
|--------|--------|--------|
| **imphash** | | |
| **ssdeep** | | |
| **TLSH** | | |
| **dhash icon** | | |

## URLs referenced on Bazaar page (IOC leads)

| Kind | URL / note |
|------|------------|
| | |

## YARA rules flagged

| Rule | Author | Implication (rough) |
|------|--------|---------------------|
| | | |

## Bazaar intelligence snippets

| Metric | Value |
|--------|--------|
| `# of uploads` | |
| `# of downloads` | |
| **Origin country** | |

## Acquisition checklist (VM)

- [ ] Download **inside VM only** (Bazaar login / API)
- [ ] **SHA256 verified on VM** -- matches Bazaar value
- [ ] VM path documented (no sensitive analyst-machine paths here)
- [ ] Optional: clean **snapshot taken before** first run
- [ ] **Never** copy `.exe` / binary to this host logbook PC

## Cross-links

- Static notes: `01_static/sample_03.md`
- Dynamic notes: `02_dynamic/sample_03.md`
- Findings: `03_findings/sample_03.md`
- Screenshots: `50_screenshots/sample_03/`
