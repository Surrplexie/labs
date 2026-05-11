# 00_original

**Acquisition receipts — one file per sample, host-side only.**

Each `sample_XX.md` in this folder documents the sample's identity and sourcing
*before and at* acquisition. No binaries are stored here or anywhere in this repo.

---

## What goes here

| Field category | Examples |
|---|---|
| MalwareBazaar URL and hash set | SHA256, SHA1, MD5, imphash, ssdeep, TLSH |
| File metadata | Claimed filename, MIME type, size, first/last seen |
| Delivery context | Reporter, tags, Magika result, TrID top match |
| YARA rules flagged on Bazaar | Rule name, author, rough implication |
| Referenced URLs | Hosting pages, delivery zips, VT links |
| Acquisition checklist | VM-only download confirmed, SHA256 verified, path noted |
| Cross-links | To the other three phase files for this sample |

## What does NOT go here

- Any binary, archive, or executable of any kind
- VM snapshots, disk images, memory dumps
- Analyst host machine paths or usernames
- Any file larger than a few KB

## File naming

`sample_01.md` through `sample_99.md` (zero-padded).
The same ID runs across `01_static/`, `02_dynamic/`, `03_findings/`, and `50_screenshots/`.

## Creating a new slot

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_sample.ps1 -NextNumber 7
```

This creates all four phase files, the screenshot folder, and a tracker CSV row in one step.
