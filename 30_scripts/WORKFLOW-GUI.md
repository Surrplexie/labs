# Workflow GUI -- usage (Windows and Linux)

---

## Disclaimer (read before use)

**This document, the `workflow_gui` source code (`workflow_gui.py`), and any build
scripts in this folder are documentation and local automation helpers only.** They are
not a product, not a service, and not an endorsement of any third-party tool, vendor,
or "official" software distribution channel.

- **No malware is distributed, stored, retained, or delivered by this repository in
  unedited form.** The GUI and scripts only read and write Markdown, CSV, and text under
  your own clone of this logbook. They do not download samples, do not host payloads,
  and do not ship malware. Anything you paste into the GUI is data **you** supply from
  your own sources (for example public threat-intel pages). You alone are responsible
  for what you acquire, where you run it, and how you handle it.

- **No warranty; use entirely at your own risk.** The authors and maintainers assume no
  liability for data loss, incorrect file writes, misconfiguration, security incidents,
  or any outcome from running the GUI, build scripts, or PowerShell helpers. Verify
  backups before bulk operations. Review generated files before commit.

- **This work is not published or promoted as a finished, supported, or maintained
  product.** The `labs` repository does not promise releases, updates, compatibility,
  or continued availability. Nothing here should be interpreted as marketing,
  promotion, or a commitment to ship or maintain software.

- **The only optional binary release from this repo (if ever attached under GitHub
  Releases) is the compiled `workflow_gui` helper** -- and nothing else. If you obtain
  that binary from any source other than your own build from this repository's source,
  **verify cryptographic hashes** against values published by the repository owner you
  trust. Do not trust unlabeled or re-hosted binaries. When in doubt, run from source
  (`workflow_gui.py`) or build yourself with `build_exe.ps1` / `build_linux.sh`.

- **References to Python, PyInstaller, PowerShell, operating-system packages, or other
  tools are illustrative.** They are not guarantees of fitness, security, or licensing
  for your environment. Install and update third-party software only from sources you
  trust and under your own policies.

If any of the above is unacceptable, do not run the GUI or build scripts.

---

## Table of contents

1. [What the GUI is for](#what-the-gui-is-for)
2. [Windows -- run from source](#windows--run-from-source)
3. [Windows -- build and run `.exe`](#windows--build-and-run-exe)
4. [Windows -- first launch and filling the form](#windows--first-launch-and-filling-the-form)
5. [Linux -- run from source](#linux--run-from-source)
6. [Linux -- build and run binary](#linux--build-and-run-binary)
7. [Linux -- first launch, Tools tab, and notes](#linux--first-launch-tools-tab-and-notes)
8. [Quick command reference](#quick-command-reference)

---

## What the GUI is for

The Workflow GUI (v3.0+) helps you **fill any engagement kind** (file, CTF, lab, hunt)
from a single form — no manual file editing for metadata. Key features:

| Feature | Description |
|---------|-------------|
| **New Engagement** | Scaffold + fill all four phase files and frontmatter for any kind |
| **CTF forms** | Platform, category, difficulty, points, solved flag, public-writeup toggle |
| **Lab forms** | Course, module, objectives list, objectives-met toggle |
| **Hunt forms** | Hypothesis, data sources, timebox, detections-found toggle |
| **Screenshots tab** | Browse images, add captions, auto-number as shot_NNN.png, copy to 50_screenshots/slot/, update SHOT_INDEX.txt |
| **Update Engagement** | Kind-aware status, frontmatter patch -- load existing values, change what changed |
| **Tools tab** | Kind-aware: Validate, Export, Redact, EXIF; **file** = Procmon ingest; **hunt** = event ingest + new hunt query scaffold |
| **Thumbnail preview** | Installed `pillow` enables preview in Screenshots tab |

It does not replace safe analysis practice, VM isolation, or your own judgment.

---

## Windows -- run from source

**Prerequisite:** Python 3.10+ on PATH (`python --version`).

```powershell
cd C:\path\to\labs
python 30_scripts\workflow_gui.py
```

If your current directory is not the repo root:

```powershell
python C:\path\to\labs\30_scripts\workflow_gui.py --repo "C:\path\to\labs"
```

**Disclaimer reminder:** Running from source uses **your** Python interpreter. Only
download Python from [python.org](https://www.python.org/) or another channel **you**
trust.

---

## Windows -- build and run `.exe`

From the repo root:

```powershell
cd C:\path\to\labs
powershell -ExecutionPolicy Bypass -File .\30_scripts\build_exe.ps1
.\dist\workflow_gui.exe
```

Optional explicit repo when launching the built binary:

```powershell
.\dist\workflow_gui.exe --repo "C:\path\to\labs"
```

**Disclaimer reminder:** `build_exe.ps1` uses `pip` to install the **pinned** PyInstaller
version from `build_requirements.txt` (not an open-ended upgrade). That touches your
machine's Python environment. The resulting `workflow_gui.exe` is a
large standalone file; treat it like any other executable you did not compile yourself
unless you built it locally. If you ever download a pre-built `workflow_gui` from
Releases, **compare hashes** to published values before running.

---

## Windows -- first launch and filling the form

### Step 1 -- Repo root

1. Start the GUI (source or `.exe` as above).
2. If the status line indicates the repo was not found, click **Browse** and select the
   folder that contains `samples_tracker.csv` (the `labs` root).

### Step 2 -- Settings

Open **Settings**, set **Analyst name**, click **Save Settings**. Settings are stored in
`30_scripts/.workflow_gui_config.json` on your machine (that file is gitignored).

### Step 3 -- New Engagement tab (example data)

Select your **Engagement kind** first -- the form adapts dynamically:

| Kind | Fields shown |
|------|-------------|
| `file` | Sample type (PE/Office/Script/Archive), SHA256, hashes, MB URL, verdict, MITRE, tags |
| `ctf` | Platform (HTB/THM/etc.), category, difficulty, title |
| `lab` | Platform (course name), title/module |
| `hunt` | Title (hypothesis summary) |

**File-kind example** (illustrative only -- replace with your real data):

| Field | Example |
|--------|---------|
| **Sample #** | Click **Auto-detect**, or type a number (e.g. `7` for `sample_07`). |
| **Analyst** | Your handle or name. |
| **Engagement kind** | `file` |
| **Sample type** | `PE` |
| **Date acquired** | `2026-05-11` |
| **SHA256** | Full 64-character hex; MB URL may auto-fill. |
| **SHA1 / MD5** | Paste from the same intel page. |
| **Filename (claimed)** | e.g. `Updater_v2.211.exe` |
| **Verdict** | Often `unknown` or `suspicious` initially. |
| **Confidence** | Often `low` until static/dynamic work is done. |
| **Tags** | Comma-separated, e.g. `nsis, fake-alert, installer` |
| **MITRE IDs** | Comma-separated, e.g. `T1036, T1027` |

**CTF-kind example:**

| Field | Example |
|--------|---------|
| **Sample #** | e.g. `8` |
| **Engagement kind** | `ctf` |
| **Platform** | `HackTheBox` |
| **Category** | `Web` |
| **Difficulty** | `Easy` |
| **Title** | `HTB -- Blunder` |

**Hunt-kind example:**

| Field | Example |
|--------|---------|
| **Sample #** | e.g. `9` |
| **Engagement kind** | `hunt` |
| **Title** | `Hunt: LSASS Access via Mimikatz` |

### Step 4 -- Create

Click **CREATE ENGAGEMENT** (button label reflects selected kind). The GUI calls
`new_engagement.ps1` with the appropriate `-Kind` flag and writes:

- `00_original/sample_XX.md`
- `01_static/sample_XX.md`
- `02_dynamic/sample_XX.md`
- `03_findings/sample_XX.md` (with YAML frontmatter, `engagement_kind` set)
- `50_screenshots/sample_XX/SHOT_INDEX.txt` (if missing)
- Updates `samples_tracker.csv` with kind, title, and `date_started`

Then replace remaining `PENDING` placeholders in the Markdown as you perform real work.

**Disclaimer reminder:** The GUI writes files **you** asked it to write. Review diffs
before `git commit`. It never substitutes for safe handling of real malware outside an
isolated environment.

---

## Linux -- run from source

**Prerequisites:** Python 3.10+ and Tkinter for that Python.

```bash
# Debian / Ubuntu example
sudo apt install python3-tk

# Fedora example
sudo dnf install python3-tkinter
```

Run:

```bash
cd /path/to/labs
python3 30_scripts/workflow_gui.py
```

Explicit repo:

```bash
python3 30_scripts/workflow_gui.py --repo /path/to/labs
```

**Disclaimer reminder:** Package names vary by distribution; only install packages from
**your** distribution's trusted repositories.

---

## Linux -- build and run binary

```bash
cd /path/to/labs
bash ./30_scripts/build_linux.sh
./dist/workflow_gui
```

Custom Python:

```bash
bash ./30_scripts/build_linux.sh --python python3.12
```

**Disclaimer reminder:** `build_linux.sh` installs the **pinned** PyInstaller version from
`build_requirements.txt` via `pip` (not `pip install --upgrade pyinstaller`). That
modifies your user or system Python environment according to how pip is configured.

---

## Linux -- first launch, Tools tab, and notes

### First launch (same as Windows)

1. **Browse** to repo root if needed.
2. **Settings** -- analyst name -- **Save Settings**.

### Filling the New Sample form

Use the same field table as in [Windows -- first launch and filling the form](#windows--first-launch-and-filling-the-form).

Template paths inside generated `00_original` may show a **Windows VM** example path
(`C:\Users\win11\...`) because dynamic analysis in this logbook assumes a Windows VM.
Edit that line if your VM layout differs.

### Tools tab on Linux

The **Tools** tab invokes PowerShell scripts via `pwsh`. Install PowerShell Core if you
want one-click execution:

- [Install PowerShell on Linux](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux)

Without `pwsh`, run the scripts manually from a terminal:

```bash
cd /path/to/labs
pwsh -File ./30_scripts/validate.ps1
```

**Disclaimer reminder:** PowerShell is third-party software from Microsoft; install only
from official distribution instructions you trust.

---

## Quick command reference

| Action | Windows | Linux |
|--------|---------|--------|
| Run from source | `python 30_scripts\workflow_gui.py` | `python3 30_scripts/workflow_gui.py` |
| Run with explicit repo | `python 30_scripts\workflow_gui.py --repo "C:\path\to\labs"` | `python3 30_scripts/workflow_gui.py --repo /path/to/labs` |
| Build standalone | `powershell -ExecutionPolicy Bypass -File .\30_scripts\build_exe.ps1` | `bash ./30_scripts/build_linux.sh` |
| Run standalone | `.\dist\workflow_gui.exe` | `./dist/workflow_gui` |
| Enable thumbnails (Screenshots tab) | `pip install pillow` | `pip3 install pillow` |
| Local config (gitignored) | `30_scripts\.workflow_gui_config.json` | same path |

---

## Closing disclaimer

Nothing in this file grants permission to mishandle malicious software, violates any
law, or substitutes for employer policy, licensing, or air-gapped procedures. **Use at
your own risk.** When using any **pre-built** `workflow_gui` binary from the internet,
**verify hashes** against a trustworthy publisher; prefer building from source in this
repository when you need the highest assurance.

For the broader lab workflow (beyond the GUI), see [`WORKFLOW.md`](../WORKFLOW.md) and
the main [`README.md`](../README.md).
