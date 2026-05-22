# 04_writeups — templates

Kind-specific long-form scaffolds. Created on demand via `scaffold_writeup.ps1` — not auto-seeded for every slot.

---

## Templates

| File | Use for | Key sections |
|------|---------|--------------|
| [`file.md`](./file.md) | Malware / artifact (PE, Office, script, archive) | Executive summary · evidence map · static/dynamic highlights · verdict · detection ideas · portfolio paragraph |
| [`ctf.md`](./ctf.md) | HackTheBox, TryHackMe, CTF competitions | Story arc · recon summary · attack path · rabbit holes · skills · publication ethics |
| [`lab.md`](./lab.md) | Guided course labs and modules | Objectives rubric · procedure highlights · results/proof · reflection · skills · malware cross-link |
| [`hunt.md`](./hunt.md) | Hypothesis-driven detection / log analysis | Hypothesis → data → queries → findings → FPs → detection engineering |

---

## When each template applies

```
engagement_kind: file   →  file.md
engagement_kind: ctf    →  ctf.md
engagement_kind: lab    →  lab.md
engagement_kind: hunt   →  hunt.md
```

`scaffold_writeup.ps1` reads `engagement_kind` from `samples_tracker.csv` when `-Kind` is omitted.

---

## Scaffold commands

```powershell
# Infer kind from tracker (recommended)
powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 -SampleId sample_37

# Explicit kind + platform + title
powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 `
    -NextNumber 37 -Kind ctf -Platform "HackTheBox" -Title "Lame"

# Overwrite a pre-seeded file-outline on a CTF/lab/hunt slot
powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 `
    -SampleId sample_37 -Kind ctf -Overwrite
```

Placeholders replaced at scaffold time: `SAMPLE_ID` · `ANALYST` · `DATE` · `TITLE_VAL` · `PLATFORM_VAL` · `KIND_VAL`.

---

## Editing templates

Edit only to change **structure for all future scaffolds** — never edit a template as part of a specific engagement. Once scaffolded, work in `04_writeups/sample_XX.md` directly.
