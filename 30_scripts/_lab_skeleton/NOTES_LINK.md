# Notes bridge

Class / club notes stay in **Downloads\Notes** (not this public repo).
This lab is the structured logbook copy.

| | |
|---|---|
| **Notes root** | `%USERPROFILE%\Downloads\Notes` (override: `LABS_NOTES_ROOT` or `30_scripts\notes_root.local.txt`) |
| **Course folder** | _not linked yet_ |
| **Live pad** | [`CAPTURE.md`](./CAPTURE.md) |

Link or open both sides:

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\link_notes.ps1 -SampleId SAMPLE_ID -Course "CS50"
powershell -ExecutionPolicy Bypass -File .\30_scripts\open_session.ps1 -SampleId SAMPLE_ID
```

When a class note becomes a lab: paste keepers from the Notes course folder into `00_original` / `01_static`, leave raw class dumps in Notes.
