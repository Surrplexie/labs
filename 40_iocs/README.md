# 40_iocs

**Consolidated indicator-of-compromise (IOC) table for `file`-kind and `hunt`-kind engagements.**

`indicators.csv` is the single flat file that aggregates IOCs across all engagements
that produce concrete indicators. It is designed for easy sharing, import into SIEM tools,
or cross-referencing with external threat intelligence.

**Scope by engagement kind:**

| Kind | Uses this folder? | What goes here |
|------|-------------------|----------------|
| `file` | **Yes** | File hashes, URLs, IPs, domains, registry keys, mutex names from malware analysis |
| `hunt` | **Yes** | Confirmed IOC candidates from SIEM/Sysmon data: file hashes, IPs, process paths |
| `ctf` | No | CTF flags and platform credentials do **not** go here |
| `lab` | No | Lab credentials and test data do **not** go here |

For `ctf` and `lab` kinds, any indicators found (if applicable) belong in the
`03_findings` frontmatter or the engagement notes -- not in this shared CSV.

---

## Schema

`indicators.csv` columns:

| Column | Description | Examples |
|--------|-------------|---------|
| `sample_id` | Which sample this indicator belongs to | `sample_01` |
| `type` | Indicator type | `sha256`, `md5`, `sha1`, `url`, `ip`, `domain`, `filename`, `imphash`, `ssdeep`, `tlsh`, `software_name`, `ui_string`, `registry_key`, `file_path`, `mutex` |
| `value` | The indicator value | Hash string, URL, domain name, etc. |
| `source` | Where this IOC came from | `malwarebazaar`, `static_pe_version`, `dynamic_procmon`, `dynamic_network` |
| `first_seen` | ISO 8601 datetime when first observed | `2026-05-06T22:23:04Z` |
| `notes` | Brief annotation | `claimed filename -- verify on disk after download` |

## How to add IOCs

**When closing a sample as `static`:** add file identity hashes (SHA256, SHA1, MD5),
imphash, ssdeep, TLSH, and any static strings or URLs found on MalwareBazaar.

**When closing a sample as `dynamic`:** add confirmed network indicators (IPs, domains,
URLs contacted), file drops (paths), registry writes (keys/values), and mutex names.

**Format:** one row per indicator. Do not merge multiple values into one row.

```csv
sample_01,sha256,ffd448f1...,malwarebazaar,2026-05-06T22:23:04Z,file object on MB
sample_01,url,http://itchupdate-ah1.pages.dev/,malwarebazaar_listing,,referenced on Bazaar page
```

## What does NOT go here

- Analyst host machine paths or usernames
- Internal infrastructure details (internal IPs, corporate domains)
- Any information not suitable for public disclosure

## Validation

`validate.ps1` checks that:
- Required columns are present
- All `sample_id` values are known to `samples_tracker.csv`

Run before committing:
```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\validate.ps1
```

## SIEM / tooling use

The CSV can be imported directly into most SIEM platforms or fed to threat intel
pipelines. The `type` column maps to common indicator type vocabularies (STIX,
OpenIOC, MISP).
