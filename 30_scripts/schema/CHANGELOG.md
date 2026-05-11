# Schema CHANGELOG

Tracks breaking and non-breaking changes to the two machine-readable contracts:

- `frontmatter.schema.json` -- YAML frontmatter in `03_findings/sample_XX.md`
- `summary.schema.json` -- `dist/summary.json` export envelope

---

## Version 1 (current) -- 2026-05-11

**Initial schema.** Both contracts defined at version 1.

### frontmatter.schema.json v1

Required fields:

| Field | Type | Notes |
|-------|------|-------|
| `schema_version` | integer (const: 1) | Must be exactly `1` |
| `sample_id` | string | Pattern `sample_NN` |
| `sha256` | string | 64-char hex |
| `phase` | string (const: findings) | |
| `analyst` | string | |
| `date_acquired` | string | YYYY-MM-DD |
| `date_analyzed` | string | YYYY-MM-DD |
| `status` | enum | queued / static / dynamic / done |
| `verdict` | enum | benign / suspicious / malicious / unknown |
| `family_guess` | string | Working hypothesis |
| `family_confidence` | enum | high / medium-high / medium / low |
| `tags` | string[] | Lowercase hyphenated |
| `mitre_techniques` | string[] | T#### or T####.### |
| `mb_url` | string | https:// |
| `procmon_run` | boolean/string | |
| `dynamic_complete` | boolean/string | |

### summary.schema.json v1

Envelope wraps the records array with:

| Field | Type | Notes |
|-------|------|-------|
| `schema_version` | integer (const: 1) | Must be exactly `1` |
| `generated_at` | string | ISO-8601 UTC timestamp |
| `record_count` | integer | Total records (active + reserve) |
| `active_count` | integer | Non-empty slots |
| `reserve_count` | integer | Empty slots |
| `records` | array | One object per tracker row |

---

## Upgrade guide (future)

When a **breaking change** is needed:

1. Increment `schema_version` in the relevant schema file.
2. Add a row to this CHANGELOG under a new `## Version N` heading.
3. Update `export-summary.ps1` to write the new version number.
4. Update `validate.ps1` check 11 to accept new valid version numbers.
5. Update `workflow_gui.py` template builder if frontmatter fields change.
6. Migrate existing findings files: update `schema_version:` lines in `03_findings/*.md`.

A **non-breaking addition** (new optional field) does not require a version bump --
just add the field to the schema with `additionalProperties: true` and document it here
under the current version with a `(added YYYY-MM-DD)` note.
