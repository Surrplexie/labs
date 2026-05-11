# sample_01 — dynamic triage

**SHA256:** `ffd448f1e3038c6c324570ab12dbf65ddbef471f0ababfb9f2a3bb47eead5bd7`

## Execution observed — **`IMG_6042`**

**Evidence:** `50_screenshots/sample_01/IMG_6042.png` (from `IMG_6042.HEIC`).

Background: **Windows Security → Virus & threat protection** · **Real-time protection** messaging indicates it is **off** (expected in some lab VMs; also what malware often expects).

Overlaid dialogs (user-facing behavior after run):

| Dialog | Title | Message / notes |
|--------|-------|------------------|
| Left | **Error** | **`Critical systeam error 0x00305353321`** — typo **“systeam”** instead of **“system”** (common fake/scam trope). |
| Right | **`HGWJY`** | Gibberish body, e.g. **`jimnb uq0ukc1m ulo0ov lui0kilpa cqch an`** · **OK** / **Cancel**. |

**Interpretation:** Not a normal Windows fault string pattern; aligns with **nuisance / fake error malware or installer stage** distractions. Combine with NSIS branding in **`01_static`**: installer → ran → **immediate suspicious UI**.

### Branch

- ~~A (tools-only)~~ **`IMG_6042` confirms Branch B:** sample **was executed** enough to surface these windows.

---

## Pre-flight — **for your next disciplined run**

_If you repeat for a textbook capture:_

- [ ] Clean **snapshot** baseline.
- [ ] **Procmon** capture from boot or pre-run.
- [ ] **Process Explorer** / **TCPView**.
- [ ] Execute once → export **filtered** log → PNGs → **revert snapshot**.

**(This notebook pass)** used phone evidence only — **Procmon/registry/filesystem/network tables below are placeholders** until filled from a tooling run or VM notes.

---

## Execution (best current knowledge)

- **How launched:** _User ran installer / exe (exact double-click vs context not on photo)._  
- **User context:** _Standard user assumed (adjust if elevated)._

## Process tree

| Parent | Child | Command line / notes |
|--------|--------|---------------------|
| _TBD_ | _TBD_ | Fill from Procmon / ProcExp |

## File system / Registry / Network

_(TBD)_ — Prefer **PMC/CSV excerpts** after filtered Procmon; add **drops under `%TEMP%`**, **Run keys**, etc.

Append confirmed network to **`40_iocs/indicators.csv`**.

## Dynamic summary

After execution, Windows displayed **two fake-looking error dialogs** (misspelled “critical system” string and randomized title/body). Static triage (**`01_static`**) shows the binary is predominantly an **NSIS installer** package; executed behavior aligns with **non-legitimate UX** rather than a normal updater.

## Screenshots

| File | Role |
|------|------|
| `IMG_6042.heic` / `IMG_6042.png` | Post-execution deceptive dialogs |
