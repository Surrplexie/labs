# 10_extracted

> **File-kind engagements only.** This folder holds non-executable artifacts extracted
> from file samples. CTF/lab/hunt engagements do not use this folder.


**Non-executable artifacts extracted from samples during static analysis.**

Anything pulled out of a sample that is itself not executable goes here, keyed
by sample ID. This folder exists so extracted content has a home that is separate
from analysis notes but still tracked with the sample.

---

## What goes here

| Artifact type | Examples | Notes |
|---|---|---|
| String dumps | Output of `strings` tool on PE or overlay | `.txt` format |
| PE section dumps | Raw bytes of a specific section (if non-executable) | Only if safe to share |
| NSIS script extracts | Installer script recovered by 7-Zip / UniExtract2 | `.nsi` or `.txt` |
| Resource files | Icons, manifests, embedded documents pulled from PE resources | |
| Header summaries | Copy-paste of PE header fields for reference | `.txt` or `.md` |
| Decoded payloads (text) | Base64-decoded or XOR-decoded strings that are plaintext | |

## What does NOT go here

- Any file that can execute on a host (no `.exe`, `.dll`, `.scr`, `.bat`, `.ps1` etc.)
- Raw PE files, shellcode blobs, or memory dumps
- Anything with more than nominal risk of accidental execution

## File naming

Use the sample ID as a prefix:

```
10_extracted/
  sample_01_strings.txt
  sample_01_nsis_script.nsi
  sample_01_manifest.xml
  sample_03_decoded_strings.txt
```

## Safety note

Before committing anything to this folder, confirm it is plaintext or a non-executable
format. When in doubt, document the artifact's hash and location in `01_static/sample_XX.md`
instead of committing the artifact itself.
