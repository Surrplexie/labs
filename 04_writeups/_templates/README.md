# 04_writeups templates

Kind-specific long-form scaffolds. **Not** copied automatically for every slot -- use when you want a portfolio-deep report beyond `03_findings`.

| File | Use for |
|------|---------|
| [`file.md`](./file.md) | Malware / artifact triage (PE, Office, script, archive) |
| [`ctf.md`](./ctf.md) | HackTheBox, TryHackMe, CTF challenges |
| [`lab.md`](./lab.md) | Guided course labs and modules |
| [`hunt.md`](./hunt.md) | Hypothesis-driven detection / log hunts |

## Scaffold into a slot

```powershell
# Standalone (infers kind from tracker when -Kind omitted)
powershell -ExecutionPolicy Bypass -File .\30_scripts\scaffold_writeup.ps1 -NextNumber 7 -Kind ctf -Platform HackTheBox -Title Lame

# With new engagement (all four phases + optional 04)
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber 7 -Kind ctf -Platform HackTheBox -Title Lame -WithLongWriteup
```

Placeholders replaced at scaffold time: `SAMPLE_ID`, `ANALYST`, `DATE`, `TITLE_VAL`, `PLATFORM_VAL`, `KIND_VAL`.

Pre-seeded `04_writeups/sample_01.md` … `sample_50.md` remain **file**-oriented until you scaffold or edit manually.
