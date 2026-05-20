# CTF pattern notes

**Cross-challenge synthesis** — analogous to [`case-series/`](../case-series/README.md) for malware, but for CTF techniques and pivot patterns.

Use when two or more **ctf** slots share a repeatable approach (e.g. "HTB easy Linux privesc via SUID custom binary").

---

## When to create a note

| Create | Skip |
|--------|------|
| Same privesc chain on 2+ machines | One-off challenge with no reusable lesson |
| Recurring web technique (JWT, SSTI) | Full walkthrough (that stays in `03_findings` / `04_writeups`) |

---

## Current patterns

| File | Theme | Slots |
|------|-------|-------|
| _(none yet)_ | | |

---

## Template for a new file

1. Create `kebab-case-name.md` in this folder.
2. Sections: **Summary**, **Slots in this pattern**, **Common steps**, **Tools**, **Pitfalls**, **Links** to `03_findings`.
3. Add a row to the table above.
4. Update [`ctf-machine-index.md`](../ctf-machine-index.md) if useful.

**No raw flags or active-machine spoilers.**
