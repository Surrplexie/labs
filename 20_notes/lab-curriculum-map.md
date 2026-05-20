# Lab curriculum map

**Maps training labs to `sample_XX` slots** — hand-maintained. Update when you scaffold or close a `lab` engagement.

Primary artifact per lab: `03_findings/sample_XX.md` (reflection + `skills[]`). Optional narrative: `04_writeups/sample_XX.md`.

---

## Active and completed labs

| Course / platform | Module / room | Slot | Status | Skills (summary) | Notes |
|-----------------|---------------|------|--------|------------------|-------|
| _Example: TryHackMe_ | _Introductory Researching_ | _sample_08_ | _reviewed_ | _OSINT, web research_ | _Delete row when empty_ |

---

## Planned / backlog

| Course | Module | Target slot | Prerequisites |
|--------|--------|-------------|---------------|
| | | | |

---

## Scaffold command

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 `
    -NextNumber 8 -Kind lab -Platform "TryHackMe" -Title "Module name"
```

---

## Rules

- **No** lab passwords, VPN keys, or target IPs in this file — VM names and course titles only.
- Link slots: [`../03_findings/sample_XX.md`](../03_findings/sample_XX.md)
- Track depth in [`skills-coverage.md`](./skills-coverage.md) when you close a lab.
