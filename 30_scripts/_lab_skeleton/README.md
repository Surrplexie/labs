# LAB_NAME

Stay in **this folder**. Every phase for this engagement lives here.

| | |
|---|---|
| **Slot** | `SAMPLE_ID` |
| **Kind** | KIND_VAL |
| **Title** | TITLE_VAL |
| **Flow** | `00_original` → `01_static` → `02_dynamic` → `03_findings` |

## Folders

| Folder | What you do here |
|--------|------------------|
| `00_original` | Receipt / challenge brief / lab objectives / hunt scope |
| `01_static` | Static triage / recon / step log / data collection |
| `02_dynamic` | Dynamic triage / solve / results / analysis |
| `03_findings` | Verdict / writeup / reflection / hunt outcome |
| `04_writeups` | Optional long-form report |
| `10_extracted` | Non-executable extracts (file kind) |
| `20_notes` | Scratch notes for **this** lab |
| `30_scripts` | Pointer to repo-root scripts (do not duplicate them) |
| `40_iocs` | Pointer to the global IOC CSV |
| `45_hunt_queries` | Queries used in **this** lab |
| `50_screenshots` | Screenshots (committable after EXIF strip) |
| `55_media` | Recordings / slides / exports (local; gitignored binaries) |
| `CAPTURE.md` | Live dump while the session is running |
| `NOTES_LINK.md` | Bridge to `Downloads\Notes\<course>` |

## Active session

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\open_session.ps1 -SampleId SAMPLE_ID
```

Dump into `CAPTURE.md`, then file into `00` → `03`. Class notes stay in Notes; this folder is the structured copy.
