# Detection catalog

**Cross-engagement detection ideas** promoted from `file` analysis or `hunt` outcomes.

| Source kind | Primary slot artifact | IOC / intel |
|-------------|----------------------|-------------|
| `file` | `03_findings` + optional `04_writeups` § detection engineering | `40_iocs/indicators.csv` |
| `hunt` | `03_findings` + optional `45_hunt_queries/` | Confirmed IOCs only in `40_iocs` |

CTF and lab engagements **do not** belong in this catalog unless you are documenting a detection you built from course material (rare).

---

## Detections

| ID | Name | Kind | Status | MITRE | Query / rule ref | Slots | Notes |
|----|------|------|--------|-------|------------------|-------|-------|
| _DET-001_ | _Example: NSIS dropper file create_ | _file_ | _idea_ | _T1204_ | _04_writeups or inline Sigma sketch_ | _sample_01_ | _Delete when empty_ |

**Status:** `idea` | `draft` | `tested` | `tuned` | `deprecated`

---

## Linking conventions

| Asset | Link format |
|-------|-------------|
| Hunt query library | [`45_hunt_queries/<slug>.md`](../45_hunt_queries/README.md) |
| Hunt engagement | [`03_findings/sample_XX.md`](../03_findings/sample_XX.md) |
| File long-form | [`04_writeups/sample_XX.md`](../04_writeups/README.md) |
| MITRE rollup | [`MITRE-coverage.md`](./MITRE-coverage.md) |

---

## When to add a row

1. You have a **testable** detection hypothesis (Sigma, KQL, Splunk, YARA file-hunt).
2. You can describe expected false positives.
3. The rule is **sanitized** — no employer-specific indexes, hostnames, or accounts.

---

## Scaffold a hunt query

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_hunt_query.ps1 `
    -QueryId nsis-overlay-drop -Platform sigma -Title "High-entropy NSIS overlay write"
```

Then add a catalog row pointing at the query file and any `related_samples`.
