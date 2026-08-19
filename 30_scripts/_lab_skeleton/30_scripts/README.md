# 30_scripts (this lab)

Automation is **not** copied here. Use the repo-root scripts so every lab stays in sync:

`..\..\30_scripts\`

From repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\30_scripts\new_engagement.ps1 -NextNumber N
powershell -ExecutionPolicy Bypass -File .\30_scripts\close_sample.ps1 -SampleId SAMPLE_ID
powershell -ExecutionPolicy Bypass -File .\30_scripts\validate.ps1
```
