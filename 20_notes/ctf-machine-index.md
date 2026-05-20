# CTF machine index

**Tracks CTF / HackTheBox / TryHackMe work against `sample_XX` slots.**

Primary writeup: `03_findings/sample_XX.md`. Optional long-form: `04_writeups/sample_XX.md` (use `scaffold_writeup.ps1 -Kind ctf`).

---

## Machines and challenges

| Platform | Name | Category | Difficulty | Slot | Status | Solved | Public writeup safe | Notes |
|----------|------|----------|------------|------|--------|--------|---------------------|-------|
| _HackTheBox_ | _Lame_ | _Linux_ | _Easy_ | _sample_07_ | _writeup_done_ | _yes_ | _no_ | _Retired only when platform allows_ |

**Status values:** `assigned`, `recon`, `stuck`, `solved`, `writeup_done` (from tracker / `close_sample.ps1`).

---

## By platform

| Platform | Count | Slots |
|----------|-------|-------|
| _(fill as you add engagements)_ | | |

---

## By category

| Category | Slots |
|----------|-------|
| web | |
| pwn | |
| rev | |
| crypto | |
| forensics | |
| misc | |

---

## Rules

- **Never** store raw flags (`HTB{`, `THM{`, …) — use `solved: yes` and points in tracker `score_flag` if needed.
- Set `public_writeup_safe: true` in `03_findings` only when the machine is retired or writeup release is permitted.
- Tooling reference: [`ctf-tooling-reference.md`](./ctf-tooling-reference.md)
- Pattern notes (optional): [`ctf-patterns/`](./ctf-patterns/README.md)

---

## Scaffold command

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 `
    -NextNumber 7 -Kind ctf -Platform "HackTheBox" -Title "Lame" -WithLongWriteup
```
