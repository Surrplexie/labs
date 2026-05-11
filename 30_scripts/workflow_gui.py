#!/usr/bin/env python3
"""
workflow_gui.py  --  Cross-platform malware triage workflow assistant.

Paste sample values once; every phase-file template section is filled
automatically.  Works on Windows (compile with build_exe.ps1) and Linux
(compile with build_linux.sh), or run directly with Python 3.10+.

Usage:
    python workflow_gui.py
    python workflow_gui.py --repo "C:/path/to/labs"
"""

import argparse
import csv
import datetime
import json
import os
import re
import subprocess
import sys
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, scrolledtext, ttk

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

APP_TITLE   = "Workflow HUD -- Labs Triage Assistant"
APP_VERSION = "1.0.0"
CONFIG_FILE = Path(__file__).parent / ".workflow_gui_config.json"

VERDICTS    = ["suspicious", "malicious", "benign", "unknown"]
CONFIDENCES = ["high", "medium-high", "medium", "low"]
STATUSES    = ["queued", "static", "dynamic", "done"]
SAMPLE_TYPES = ["PE", "Office", "Script", "Archive"]

# Per-type MITRE seed tags (shown in form hints)
TYPE_MITRE_HINTS = {
    "PE":      "T1204.002, T1027, T1547.001",
    "Office":  "T1566.001, T1059.001, T1059.003",
    "Script":  "T1059, T1027, T1140",
    "Archive": "T1566.001, T1204.002, T1027",
}
TYPE_TAG_HINTS = {
    "PE":      "exe, pe",
    "Office":  "office-macro, ole",
    "Script":  "script",
    "Archive": "archive, container",
}

# Dark theme palette
C_BG     = "#1e1e2e"
C_PANEL  = "#2a2a3e"
C_ENTRY  = "#313145"
C_ACCENT = "#7c6af7"
C_FG     = "#cdd6f4"
C_DIM    = "#6c7086"
C_OK     = "#a6e3a1"
C_WARN   = "#f9e2af"
C_ERR    = "#f38ba8"
C_WHITE  = "#ffffff"

MONO_FONT = ("Consolas", 9) if sys.platform == "win32" else ("DejaVu Sans Mono", 9)
UI_FONT   = ("Segoe UI", 10) if sys.platform == "win32" else ("DejaVu Sans", 10)
HDR_FONT  = ("Segoe UI Semibold", 12) if sys.platform == "win32" else ("DejaVu Sans Bold", 12)
SEC_FONT  = ("Segoe UI Semibold", 9) if sys.platform == "win32" else ("DejaVu Sans Bold", 9)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def today() -> str:
    return datetime.date.today().isoformat()


def pad2(n: int) -> str:
    return f"{n:02d}"


def find_repo_root(start: Path) -> "Path | None":
    """Walk up from start until samples_tracker.csv is found."""
    p = start.resolve()
    for _ in range(10):
        if (p / "samples_tracker.csv").exists():
            return p
        parent = p.parent
        if parent == p:
            break
        p = parent
    return None


def load_config() -> dict:
    if CONFIG_FILE.exists():
        try:
            return json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    return {}


def save_config(cfg: dict) -> None:
    try:
        CONFIG_FILE.write_text(json.dumps(cfg, indent=2), encoding="utf-8")
    except Exception:
        pass


def next_sample_number(root: Path) -> int:
    tracker = root / "samples_tracker.csv"
    if not tracker.exists():
        return 1
    nums = []
    try:
        with open(tracker, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                m = re.match(r"sample_(\d+)", row.get("sample_id", ""))
                if m:
                    nums.append(int(m.group(1)))
    except Exception:
        pass
    return max(nums) + 1 if nums else 1


def list_active_sample_ids(root: Path) -> list:
    tracker = root / "samples_tracker.csv"
    ids = []
    if tracker.exists():
        try:
            with open(tracker, newline="", encoding="utf-8") as f:
                for row in csv.DictReader(f):
                    sid = row.get("sample_id", "").strip()
                    if sid and row.get("status", "empty").strip() != "empty":
                        ids.append(sid)
        except Exception:
            pass
    return ids


def update_tracker_row(root: Path, sid: str, sha256: str,
                        analyst: str, date_acquired: str) -> None:
    tracker = root / "samples_tracker.csv"
    fieldnames = ["sample_id", "sha256", "status", "analyst", "date_acquired", "notes"]
    rows = []
    updated = False
    if tracker.exists():
        try:
            with open(tracker, newline="", encoding="utf-8") as f:
                for row in csv.DictReader(f):
                    r = dict(row)
                    if r.get("sample_id") == sid and r.get("status", "empty") == "empty":
                        r["status"] = "queued"
                        r["sha256"] = sha256
                        r["analyst"] = analyst
                        r["date_acquired"] = date_acquired
                        updated = True
                    rows.append(r)
        except Exception:
            pass
    if not updated:
        rows.append({
            "sample_id": sid, "sha256": sha256,
            "status": "queued", "analyst": analyst,
            "date_acquired": date_acquired, "notes": "",
        })
    with open(tracker, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def set_tracker_status(root: Path, sid: str, status: str) -> None:
    tracker = root / "samples_tracker.csv"
    if not tracker.exists():
        return
    rows = []
    fieldnames = []
    with open(tracker, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fieldnames = list(reader.fieldnames or [])
        for row in reader:
            r = dict(row)
            if r.get("sample_id") == sid:
                r["status"] = status
            rows.append(r)
    with open(tracker, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def read_frontmatter(findings_path: Path) -> dict:
    """Extract key/value pairs from YAML frontmatter of a findings .md file."""
    out = {}
    if not findings_path.exists():
        return out
    content = findings_path.read_text(encoding="utf-8", errors="replace")
    m = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not m:
        return out
    fm = m.group(1)
    for line in fm.splitlines():
        kv = re.match(r"^(\w[\w_]*):\s*(.*)$", line)
        if kv:
            out[kv.group(1)] = kv.group(2).strip().strip('"').strip("'")
    # Multi-value lists: tags, mitre_techniques
    for key in ("tags", "mitre_techniques"):
        block = re.search(rf"^{key}:\n((?:  - [^\n]+\n?)+)", fm, re.MULTILINE)
        if block:
            items = re.findall(r"^\s+-\s+(.+)$", block.group(1), re.MULTILINE)
            out[key] = ", ".join(i.split("#")[0].strip() for i in items)
    return out


# ---------------------------------------------------------------------------
# Template builders
# ---------------------------------------------------------------------------

def _tag_yaml(raw: str, indent: str = "  ") -> str:
    items = [t.strip() for t in re.split(r"[,\n]+", raw) if t.strip()]
    return "\n".join(f"{indent}- {t}" for t in items) if items else f"{indent}- PENDING"


def _ioc_rows_md(v: dict) -> str:
    rows = []
    if v.get("sha256"):
        rows.append(f"| sha256 | {v['sha256']} | Primary sample |")
    if v.get("md5"):
        rows.append(f"| md5 | {v['md5']} | Full-file hash |")
    if v.get("sha1"):
        rows.append(f"| sha1 | {v['sha1']} | |")
    if v.get("filename"):
        rows.append(f"| filename | {v['filename']} | Claimed name on Bazaar |")
    return "\n".join(rows) if rows else "| PENDING | PENDING | PENDING |"


def build_original(v: dict) -> str:
    sid    = v["sample_id"]
    sha256 = v.get("sha256") or "PENDING"
    mb_url = v.get("mb_url") or f"https://bazaar.abuse.ch/sample/{sha256}/"
    yara   = v.get("yara_rows") or "| PENDING | PENDING | PENDING |"
    return (
        f"# {sid} -- acquisition receipt\n\n"
        f"| Field | Value |\n|---|---|\n"
        f"| **MalwareBazaar URL** | {mb_url} |\n"
        f"| **SHA256** | {sha256} |\n"
        f"| **SHA1** | {v.get('sha1') or 'PENDING'} |\n"
        f"| **MD5** | {v.get('md5') or 'PENDING'} |\n"
        f"| **File name (claimed)** | {v.get('filename') or 'PENDING'} |\n"
        f"| **MIME / type** | {v.get('mime') or 'PENDING'} |\n"
        f"| **Size** | {v.get('size') or 'PENDING'} bytes |\n"
        f"| **First seen (Bazaar)** | {v.get('first_seen') or 'PENDING'} |\n"
        f"| **Date acquired** | {v.get('date_acquired') or today()} |\n\n"
        f"## Delivery context / tags\n\n"
        f"<!-- Paste MalwareBazaar tags and delivery notes here -->\n\n"
        f"## Hash clustering (imphash / ssdeep / TLSH)\n\n"
        f"| Hash type | Value |\n|---|---|\n"
        f"| imphash | PENDING |\n| ssdeep | PENDING |\n| TLSH | PENDING |\n\n"
        f"## URLs on Bazaar page\n\n"
        f"<!-- List any delivery or hosting URLs from the Bazaar page -->\n\n"
        f"## YARA rules flagged\n\n"
        f"| Rule name | Author | Notes |\n|---|---|---|\n{yara}\n\n"
        f"## Acquisition checklist\n\n"
        f"- [ ] Download **inside VM only**\n"
        f"- [ ] **SHA256 verified on VM** -- `Get-FileHash` / `sha256sum` output matches above\n"
        f"- [ ] VM path documented below\n"
        f"- [ ] **Never** copy `.exe` / binary to this host logbook PC\n\n"
        f"VM path: `C:\\\\Users\\\\win11\\\\Downloads\\\\{sha256}\\\\`\n\n"
        f"## Cross-references\n\n"
        f"- Static: [`01_static/{sid}.md`](../01_static/{sid}.md)\n"
        f"- Dynamic: [`02_dynamic/{sid}.md`](../02_dynamic/{sid}.md)\n"
        f"- Findings: [`03_findings/{sid}.md`](../03_findings/{sid}.md)\n"
        f"- Screenshots: [`50_screenshots/{sid}/`](../50_screenshots/{sid}/)\n"
    )


def build_static(v: dict) -> str:
    sid    = v["sample_id"]
    sha256 = v.get("sha256") or "PENDING"
    md5    = v.get("md5") or "PENDING"
    date   = v.get("date_analyzed") or today()
    return (
        f"# {sid} -- static triage\n\n"
        f"| Field | Value |\n|---|---|\n"
        f"| **SHA256** | {sha256} |\n"
        f"| **Date analyzed** | {date} |\n\n"
        f"Cross-references: [{sid} findings](../03_findings/{sid}.md) | "
        f"[acquisition](../00_original/{sid}.md)\n\n---\n\n"
        f"## DIE\n\n"
        f"- **PE type / arch:** PENDING\n"
        f"- **Linker / compiler:** PENDING\n"
        f"- **Installer:** PENDING\n"
        f"- **Heuristic:** PENDING\n"
        f"- **Overlay:** PENDING\n\n"
        f"## PEStudio\n\n"
        f"- **SHA256:** {sha256}\n"
        f"- **Type:** PENDING\n"
        f"- **Size:** PENDING bytes -- **Entropy:** PENDING\n"
        f"- **FileDescription / ProductName:** PENDING\n"
        f"- **Manifest name:** PENDING\n"
        f"- **Libraries / imports:** PENDING libraries -- PENDING imports\n"
        f"- **Flagged imports:** PENDING\n"
        f"- **Overlay:** PENDING\n"
        f"- **VirusTotal (in UI):** PENDING at time of analysis\n\n"
        f"## CFF Explorer\n\n"
        f"- **File type:** PENDING\n"
        f"- **File size:** PENDING bytes -- **PE image size:** PENDING bytes\n"
        f"- **FileDescription / ProductName:** PENDING\n"
        f"- **FileVersion:** PENDING -- **LegalCopyright:** PENDING\n"
        f"- **NTFS timestamps (VM local):** PENDING\n\n"
        f"## HxD\n\n"
        f"- **Signature:** PENDING at 0x0\n"
        f"- **PE header:** PENDING\n"
        f"- **Section names (ASCII column):** PENDING\n"
        f"- **Overlay start:** PENDING\n\n"
        f"## Hash reconcile\n\n"
        f"| Hash type | Bazaar value | CFF Explorer value | Match? |\n|---|---|---|---|\n"
        f"| SHA256 | {sha256} | PENDING | PENDING |\n"
        f"| MD5 | {md5} | PENDING | PENDING |\n\n"
        f"## Static summary (portfolio-ready)\n\n"
        f"<!-- One paragraph synthesizing DIE + PEStudio + CFF + HxD -->\n\nPENDING\n\n"
        f"---\n\n*Generated by workflow_gui.py -- fill PENDING fields during analysis*\n"
    )


def build_dynamic(v: dict) -> str:
    sid    = v["sample_id"]
    sha256 = v.get("sha256") or "PENDING"
    date   = v.get("date_analyzed") or today()
    return (
        f"# {sid} -- dynamic triage\n\n"
        f"| Field | Value |\n|---|---|\n"
        f"| **SHA256** | {sha256} |\n"
        f"| **Date analyzed** | {date} |\n"
        f"| **VM type** | PENDING |\n"
        f"| **AV / real-time protection** | PENDING |\n"
        f"| **Snapshot name** | PENDING |\n\n"
        f"Cross-references: [{sid} findings](../03_findings/{sid}.md) | "
        f"[static](../01_static/{sid}.md)\n\n---\n\n"
        f"## Pre-execution baseline\n\n"
        f"- Open connections before run: PENDING\n"
        f"- Running processes of note: none / PENDING\n\n"
        f"## Execution method\n\n"
        f"- Launched as: double-click / right-click Run as Admin / PENDING\n"
        f"- UAC prompt: yes / no / PENDING\n"
        f"- Immediate visible behavior: PENDING\n\n"
        f"## Process tree (Process Explorer)\n\n"
        f"| Parent | Child | Command line / notes |\n|---|---|---|\n"
        f"| {sid}.exe | PENDING | PENDING |\n\n"
        f"## File system (Procmon WriteFile / CreateFile events)\n\n"
        f"| Path | Operation | Notes |\n|---|---|---|\n"
        f"| PENDING | WriteFile | PENDING |\n\n"
        f"## Registry (Procmon RegSetValue events)\n\n"
        f"| Key | Value name | Data / notes |\n|---|---|---|\n"
        f"| PENDING | PENDING | PENDING |\n\n"
        f"## Network (TCPView / Wireshark)\n\n"
        f"| Proto | Remote host | Port | Notes |\n|---|---|---|---|\n"
        f"| TCP | PENDING | PENDING | PENDING |\n\n"
        f"## Post-run observations\n\n"
        f"<!-- UI changes, scheduled tasks, services, persistence left behind -->\n\n"
        f"## Dynamic summary (portfolio-ready)\n\n"
        f"<!-- One paragraph synthesizing all observations above -->\n\nPENDING\n\n"
        f"---\n\n*Procmon log: PENDING (not committed) -- revert snapshot after run*\n"
    )


def build_findings(v: dict) -> str:
    sid        = v["sample_id"]
    sha256     = v.get("sha256") or ""
    analyst    = v.get("analyst") or "Surrplexie"
    d_acq      = v.get("date_acquired") or today()
    d_an       = v.get("date_analyzed") or today()
    verdict    = v.get("verdict") or "unknown"
    family     = v.get("family") or ""
    conf       = v.get("confidence") or "low"
    stype      = v.get("sample_type") or "PE"
    mb_url     = v.get("mb_url") or (f"https://bazaar.abuse.ch/sample/{sha256}/" if sha256 else "PENDING")
    procmon    = "true" if v.get("procmon_run") else "false"
    dynamic    = "true" if v.get("dynamic_complete") else "false"
    return (
        f"---\n"
        f"schema_version: 1\n"
        f"sample_id: {sid}\n"
        f"sha256: {sha256 or 'PENDING'}\n"
        f"phase: findings\n"
        f"sample_type: {stype}\n"
        f"analyst: {analyst}\n"
        f"date_acquired: \"{d_acq}\"\n"
        f"date_analyzed: \"{d_an}\"\n"
        f"status: queued\n"
        f"verdict: {verdict}\n"
        f"family_guess: \"{family}\"\n"
        f"family_confidence: {conf}\n"
        f"tags:\n{_tag_yaml(v.get('tags', ''))}\n"
        f"mitre_techniques:\n{_tag_yaml(v.get('mitre', ''))}\n"
        f"mb_url: \"{mb_url}\"\n"
        f"procmon_run: {procmon}\n"
        f"dynamic_complete: {dynamic}\n"
        f"---\n"
        f"# {sid} -- findings (portfolio slice) [{stype}]\n\n"
        f"**Analyst one-liner:** PENDING\n\n"
        f"Cross-references: [acquisition](../00_original/{sid}.md) | "
        f"[static](../01_static/{sid}.md) | [dynamic](../02_dynamic/{sid}.md) | "
        f"[screenshots](../50_screenshots/{sid}/)\n\n---\n\n"
        f"## Verdict\n\n"
        f"- **Classification (working):** PENDING\n"
        f"- **Why:** PENDING\n\n"
        f"## IOCs (keep `40_iocs/indicators.csv` in sync)\n\n"
        f"| Type | Value | Notes |\n|---|---|---|\n"
        f"{_ioc_rows_md(v)}\n\n"
        f"## What you proved\n\n"
        f"- **Static:** PENDING\n"
        f"- **Dynamic:** PENDING\n\n"
        f"## Public-safe blurb\n\nPENDING\n\n"
        f"---\n\n*Generated by workflow_gui.py*\n"
    )


def build_shot_index(v: dict) -> str:
    sid      = v["sample_id"]
    analyst  = v.get("analyst") or "Surrplexie"
    date     = v.get("date_acquired") or today()
    return (
        f"SHOT_INDEX -- {sid}\n"
        f"Analyst: {analyst}\n"
        f"Date: {date}\n\n"
        f"FORMAT: filename -- tool version -- what is captured\n"
        f"------------------------------------------------------------\n"
        f"(add rows as you take screenshots)\n\n"
        f"EVIDENCE HYGIENE CHECKLIST\n"
        f"[ ] VM username / hostname NOT visible in captured UI\n"
        f"[ ] Analyst host machine paths NOT in any screenshot\n"
        f"[ ] No personal information visible\n"
        f"[ ] EXIF metadata stripped: run 30_scripts\\strip-exif.ps1 -SampleId {sid}\n"
        f"[ ] HEIC originals converted to PNG before committing\n"
        f"[ ] Redact check passed: run 30_scripts\\redact-check.ps1 -SampleId {sid}\n"
    )


# ---------------------------------------------------------------------------
# GUI helpers
# ---------------------------------------------------------------------------

def _scrollable_frame(parent) -> "tuple[tk.Canvas, ttk.Frame]":
    """Return (canvas, inner_frame) with bound mouse-wheel scrolling."""
    canvas = tk.Canvas(parent, bg=C_BG, highlightthickness=0)
    sb = ttk.Scrollbar(parent, orient="vertical", command=canvas.yview)
    canvas.configure(yscrollcommand=sb.set)
    sb.pack(side="right", fill="y")
    canvas.pack(side="left", fill="both", expand=True)

    frame = ttk.Frame(canvas)
    win_id = canvas.create_window((0, 0), window=frame, anchor="nw")

    def _on_frame_resize(e):
        canvas.configure(scrollregion=canvas.bbox("all"))

    def _on_canvas_resize(e):
        canvas.itemconfig(win_id, width=e.width)

    frame.bind("<Configure>", _on_frame_resize)
    canvas.bind("<Configure>", _on_canvas_resize)

    def _scroll(e):
        delta = -1 * (e.delta // 120) if sys.platform == "win32" else (-1 if e.num == 4 else 1)
        canvas.yview_scroll(delta, "units")

    canvas.bind_all("<MouseWheel>", _scroll)
    canvas.bind_all("<Button-4>", _scroll)
    canvas.bind_all("<Button-5>", _scroll)

    return canvas, frame


def _section_label(parent, text: str, row: int) -> None:
    ttk.Separator(parent, orient="horizontal").grid(
        row=row, column=0, columnspan=3, sticky="ew", padx=10, pady=(12, 0))
    ttk.Label(parent, text=text, font=SEC_FONT,
              foreground=C_ACCENT, background=C_BG).grid(
        row=row + 1, column=0, columnspan=3, sticky="w", padx=12, pady=(2, 4))


def _lbl(parent, text, row, col=0, **kw):
    ttk.Label(parent, text=text, **kw).grid(
        row=row, column=col, sticky="e", padx=(12, 6), pady=3)


def _entry(parent, var, row, col=1, width=None, **kw):
    e = ttk.Entry(parent, textvariable=var, **({"width": width} if width else {}), **kw)
    e.grid(row=row, column=col, sticky="ew", padx=(0, 12), pady=3)
    return e


def _combo(parent, var, values, row, col=1):
    c = ttk.Combobox(parent, textvariable=var, values=values, state="readonly")
    c.grid(row=row, column=col, sticky="ew", padx=(0, 12), pady=3)
    return c


def _append(widget: scrolledtext.ScrolledText, text: str) -> None:
    widget.configure(state="normal")
    widget.insert("end", text)
    widget.see("end")
    widget.configure(state="disabled")


# ---------------------------------------------------------------------------
# Main application window
# ---------------------------------------------------------------------------

class WorkflowApp(tk.Tk):

    def __init__(self, cli_repo: "str | None" = None):
        super().__init__()
        self.title(APP_TITLE)
        self.geometry("860x740")
        self.minsize(720, 600)
        self.configure(bg=C_BG)

        self.cfg       = load_config()
        self.repo_root = None

        # Auto-detect repo root
        search_paths = []
        if cli_repo:
            search_paths.append(Path(cli_repo))
        if self.cfg.get("repo_root"):
            search_paths.append(Path(self.cfg["repo_root"]))
        search_paths += [Path(__file__).parent.parent, Path.cwd()]

        for sp in search_paths:
            found = find_repo_root(sp)
            if found:
                self.repo_root = found
                break

        self._build_styles()
        self._build_ui()
        self._refresh_repo_label()

    # -----------------------------------------------------------------------
    # Styles
    # -----------------------------------------------------------------------

    def _build_styles(self):
        s = ttk.Style(self)
        s.theme_use("clam")
        s.configure(".", background=C_BG, foreground=C_FG,
                    fieldbackground=C_ENTRY, troughcolor=C_PANEL,
                    selectbackground=C_ACCENT, selectforeground=C_WHITE,
                    bordercolor=C_PANEL, lightcolor=C_PANEL, darkcolor=C_PANEL,
                    font=UI_FONT)
        s.configure("TNotebook", background=C_BG, borderwidth=0)
        s.configure("TNotebook.Tab", background=C_PANEL, foreground=C_DIM,
                    padding=[14, 6])
        s.map("TNotebook.Tab",
              background=[("selected", C_ACCENT)],
              foreground=[("selected", C_WHITE)])
        s.configure("TFrame", background=C_BG)
        s.configure("TLabel", background=C_BG, foreground=C_FG)
        s.configure("Dim.TLabel", background=C_BG, foreground=C_DIM)
        s.configure("TEntry", fieldbackground=C_ENTRY, foreground=C_FG,
                    insertcolor=C_FG, borderwidth=1, relief="flat")
        s.configure("TCombobox", fieldbackground=C_ENTRY, foreground=C_FG,
                    background=C_ENTRY, arrowcolor=C_FG)
        s.map("TCombobox", fieldbackground=[("readonly", C_ENTRY)],
              foreground=[("readonly", C_FG)])
        s.configure("TButton", background=C_ACCENT, foreground=C_WHITE,
                    borderwidth=0, padding=[10, 6], relief="flat")
        s.map("TButton", background=[("active", "#9b8fff"), ("pressed", "#6655cc")])
        s.configure("Warn.TButton", background=C_WARN, foreground="#1e1e2e")
        s.configure("TSeparator", background=C_PANEL)
        s.configure("TScrollbar", background=C_PANEL, troughcolor=C_BG,
                    arrowcolor=C_DIM, borderwidth=0)
        s.configure("TCheckbutton", background=C_BG, foreground=C_FG)

    # -----------------------------------------------------------------------
    # Top-level UI
    # -----------------------------------------------------------------------

    def _build_ui(self):
        # Header
        hdr = ttk.Frame(self)
        hdr.pack(fill="x", padx=14, pady=(10, 0))
        ttk.Label(hdr, text=APP_TITLE, font=HDR_FONT).pack(side="left")
        ttk.Label(hdr, text=f"v{APP_VERSION}",
                  style="Dim.TLabel").pack(side="left", padx=(8, 0), pady=(2, 0))

        # Repo bar
        rbar = ttk.Frame(self)
        rbar.pack(fill="x", padx=14, pady=(4, 2))
        ttk.Label(rbar, text="Repo:", style="Dim.TLabel").pack(side="left")
        self._repo_lbl = ttk.Label(rbar, text="(searching...)", style="Dim.TLabel")
        self._repo_lbl.pack(side="left", padx=(6, 10))
        ttk.Button(rbar, text="Browse...", command=self._browse_repo).pack(side="left")

        ttk.Separator(self, orient="horizontal").pack(fill="x", padx=14, pady=4)

        # Notebook
        self._nb = ttk.Notebook(self)
        self._nb.pack(fill="both", expand=True, padx=14, pady=(0, 4))

        self._build_new_sample_tab()
        self._build_update_tab()
        self._build_tools_tab()
        self._build_settings_tab()

        # Status bar
        self._status_var = tk.StringVar(value="Ready.")
        ttk.Label(self, textvariable=self._status_var,
                  style="Dim.TLabel").pack(side="left", padx=14, pady=(0, 8))

    # -----------------------------------------------------------------------
    # Tab: New Sample
    # -----------------------------------------------------------------------

    def _build_new_sample_tab(self):
        outer = ttk.Frame(self._nb)
        self._nb.add(outer, text="  New Sample  ")
        _, frame = _scrollable_frame(outer)
        frame.columnconfigure(1, weight=1)

        self._ns = {}
        R = 0  # running row index

        # -- Sample identity --
        _section_label(frame, "SAMPLE IDENTITY", R); R += 2

        _lbl(frame, "Sample #", R)
        nf = ttk.Frame(frame)
        nf.grid(row=R, column=1, sticky="ew", padx=(0, 12), pady=3)
        self._ns["num"] = tk.StringVar()
        ttk.Entry(nf, textvariable=self._ns["num"], width=6).pack(side="left")
        ttk.Button(nf, text="Auto-detect",
                   command=self._auto_detect_num).pack(side="left", padx=(8, 0))
        R += 1

        _lbl(frame, "Sample type", R)
        self._ns["sample_type"] = tk.StringVar(value="PE")
        tc = _combo(frame, self._ns["sample_type"], SAMPLE_TYPES, R)
        ttk.Label(frame,
                  text="PE=exe/dll  Office=doc/xls  Script=ps1/vbs/js  Archive=zip/iso",
                  style="Dim.TLabel",
                  font=(UI_FONT[0], 8)).grid(row=R, column=2, sticky="w", padx=4)
        self._ns["sample_type"].trace_add("write", self._on_type_change)
        R += 1

        _lbl(frame, "Analyst", R)
        self._ns["analyst"] = tk.StringVar(value=self.cfg.get("analyst", "Surrplexie"))
        _entry(frame, self._ns["analyst"], R); R += 1

        # -- Dates --
        _section_label(frame, "DATES", R); R += 2

        for label, key, default in [
            ("Date acquired",          "date_acquired", today()),
            ("Date analyzed",          "date_analyzed", today()),
            ("First seen (Bazaar UTC)", "first_seen",   ""),
        ]:
            _lbl(frame, label, R)
            self._ns[key] = tk.StringVar(value=default)
            _entry(frame, self._ns[key], R); R += 1

        # -- Hashes --
        _section_label(frame, "HASHES  (paste from MalwareBazaar)", R); R += 2

        for label, key in [("SHA256", "sha256"), ("SHA1", "sha1"), ("MD5", "md5")]:
            _lbl(frame, label, R)
            self._ns[key] = tk.StringVar()
            _entry(frame, self._ns[key], R); R += 1

        self._ns["sha256"].trace_add("write", self._on_sha256_change)

        # -- File info --
        _section_label(frame, "FILE INFO", R); R += 2

        for label, key in [
            ("Filename (claimed)", "filename"),
            ("MIME type",          "mime"),
            ("Size (bytes)",       "size"),
            ("MB URL",             "mb_url"),
        ]:
            _lbl(frame, label, R)
            self._ns[key] = tk.StringVar()
            _entry(frame, self._ns[key], R); R += 1

        ttk.Label(frame, text="MB URL auto-fills when SHA256 is 64 chars",
                  style="Dim.TLabel",
                  font=(UI_FONT[0], 8)).grid(row=R - 1, column=2, sticky="w", padx=4)

        # -- Analysis --
        _section_label(frame, "ANALYSIS METADATA", R); R += 2

        _lbl(frame, "Verdict", R)
        self._ns["verdict"] = tk.StringVar(value=VERDICTS[0])
        _combo(frame, self._ns["verdict"], VERDICTS, R); R += 1

        _lbl(frame, "Confidence", R)
        self._ns["confidence"] = tk.StringVar(value=CONFIDENCES[0])
        _combo(frame, self._ns["confidence"], CONFIDENCES, R); R += 1

        _lbl(frame, "Family guess", R)
        self._ns["family"] = tk.StringVar()
        _entry(frame, self._ns["family"], R); R += 1

        _lbl(frame, "Flags", R)
        chkf = ttk.Frame(frame)
        chkf.grid(row=R, column=1, sticky="w", padx=(0, 12), pady=3)
        self._ns["procmon_run"]      = tk.BooleanVar()
        self._ns["dynamic_complete"] = tk.BooleanVar()
        ttk.Checkbutton(chkf, text="Procmon run",
                        variable=self._ns["procmon_run"]).pack(side="left")
        ttk.Checkbutton(chkf, text="Dynamic complete",
                        variable=self._ns["dynamic_complete"]).pack(side="left", padx=(14, 0))
        R += 1

        # -- Tags and MITRE --
        _section_label(frame, "TAGS AND MITRE TECHNIQUES", R); R += 2

        _lbl(frame, "Tags", R)
        self._ns["tags"] = tk.StringVar()
        _entry(frame, self._ns["tags"], R)
        ttk.Label(frame, text="comma-separated: nsis, fake-alert, installer",
                  style="Dim.TLabel",
                  font=(UI_FONT[0], 8)).grid(row=R, column=2, sticky="w", padx=4)
        R += 1

        _lbl(frame, "MITRE IDs", R)
        self._ns["mitre"] = tk.StringVar()
        _entry(frame, self._ns["mitre"], R)
        ttk.Label(frame, text="comma-separated: T1036, T1027, T1547.001",
                  style="Dim.TLabel",
                  font=(UI_FONT[0], 8)).grid(row=R, column=2, sticky="w", padx=4)
        R += 1

        # -- YARA --
        _section_label(frame, "YARA RULES  (optional -- one pipe-separated row per line)", R)
        R += 2

        _lbl(frame, "YARA rows", R)
        self._ns["yara_txt"] = scrolledtext.ScrolledText(
            frame, height=4, bg=C_ENTRY, fg=C_FG, insertbackground=C_FG,
            relief="flat", font=MONO_FONT)
        self._ns["yara_txt"].grid(row=R, column=1, columnspan=2,
                                   sticky="ew", padx=(0, 12), pady=3)
        self._ns["yara_txt"].insert("end",
            "| RuleName | Author | What it flags |\n"
            "| RuleName2 | Author2 | What it flags |")
        R += 1

        # -- Action buttons --
        _section_label(frame, "", R); R += 2

        bf = ttk.Frame(frame)
        bf.grid(row=R, column=0, columnspan=3, pady=(8, 20))
        ttk.Button(bf, text="   CREATE SAMPLE   ",
                   command=self._on_create_sample).pack(side="left", padx=6)
        ttk.Button(bf, text="  Clear Form  ",
                   command=self._clear_ns_form).pack(side="left", padx=6)

    # -----------------------------------------------------------------------
    # Tab: Update Sample
    # -----------------------------------------------------------------------

    def _build_update_tab(self):
        outer = ttk.Frame(self._nb)
        self._nb.add(outer, text="  Update Sample  ")

        frame = ttk.Frame(outer)
        frame.pack(fill="both", expand=True, padx=14, pady=14)
        frame.columnconfigure(1, weight=1)

        self._up = {}
        R = 0

        _lbl(frame, "Sample ID", R)
        self._up["id"] = tk.StringVar()
        id_cb = ttk.Combobox(frame, textvariable=self._up["id"], state="readonly")
        id_cb.grid(row=R, column=1, sticky="ew", padx=(0, 8), pady=4)
        self._up["id_combo"] = id_cb
        ttk.Button(frame, text="Refresh list",
                   command=self._refresh_sample_list).grid(
            row=R, column=2, padx=(0, 12), pady=4)
        R += 1

        _lbl(frame, "New status", R)
        self._up["status"] = tk.StringVar(value=STATUSES[0])
        _combo(frame, self._up["status"], STATUSES, R); R += 1

        _lbl(frame, "Verdict", R)
        self._up["verdict"] = tk.StringVar(value=VERDICTS[0])
        _combo(frame, self._up["verdict"], VERDICTS, R); R += 1

        _lbl(frame, "Confidence", R)
        self._up["confidence"] = tk.StringVar(value=CONFIDENCES[0])
        _combo(frame, self._up["confidence"], CONFIDENCES, R); R += 1

        _lbl(frame, "Tags (comma-separated)", R)
        self._up["tags"] = tk.StringVar()
        _entry(frame, self._up["tags"], R); R += 1

        _lbl(frame, "MITRE IDs (comma-separated)", R)
        self._up["mitre"] = tk.StringVar()
        _entry(frame, self._up["mitre"], R); R += 1

        bf = ttk.Frame(frame)
        bf.grid(row=R, column=0, columnspan=3, pady=12)
        ttk.Button(bf, text="  UPDATE SAMPLE  ",
                   command=self._on_update_sample).pack(side="left", padx=6)
        ttk.Button(bf, text="  Load existing values  ",
                   command=self._load_existing_values).pack(side="left", padx=6)
        R += 1

        self._up["output"] = scrolledtext.ScrolledText(
            frame, height=12, bg=C_ENTRY, fg=C_FG, insertbackground=C_FG,
            relief="flat", state="disabled", font=MONO_FONT)
        self._up["output"].grid(row=R, column=0, columnspan=3,
                                 sticky="nsew", padx=0, pady=(4, 0))
        frame.rowconfigure(R, weight=1)

    # -----------------------------------------------------------------------
    # Tab: Tools
    # -----------------------------------------------------------------------

    def _build_tools_tab(self):
        outer = ttk.Frame(self._nb)
        self._nb.add(outer, text="  Tools  ")

        ttk.Label(outer,
                  text="Run automation scripts from the repo root.",
                  style="Dim.TLabel").pack(padx=14, pady=(12, 4), anchor="w")

        tool_frame = ttk.Frame(outer)
        tool_frame.pack(fill="x", padx=14, pady=4)

        tools = [
            ("Validate",                "validate.ps1",       "Structural integrity checks (CSV, phase files, schema version, forbidden ext)."),
            ("Export / Regen INDEX.md", "export-summary.ps1", "Parse frontmatter, rebuild INDEX.md and dist/summary.json."),
            ("Redact Check",            "redact-check.ps1",   "Scan for PII and host-machine identity leaks."),
            ("Strip EXIF",              "strip-exif.ps1",     "Strip metadata from 50_screenshots/ images."),
        ]
        for label, script, desc in tools:
            rf = ttk.Frame(tool_frame)
            rf.pack(fill="x", pady=5)
            ttk.Button(rf, text=f"  {label}  ",
                       command=lambda s=script: self._run_ps_script(s)).pack(side="left")
            ttk.Label(rf, text=desc, style="Dim.TLabel").pack(side="left", padx=12)

        # Ingest Procmon -- requires CSV path input
        ttk.Separator(tool_frame, orient="horizontal").pack(fill="x", pady=(8, 4))
        ttk.Label(tool_frame, text="Procmon ingest (requires Procmon CSV from VM)",
                  style="Dim.TLabel").pack(anchor="w", pady=(0, 4))
        pf = ttk.Frame(tool_frame)
        pf.pack(fill="x", pady=4)
        ttk.Label(pf, text="Sample ID:", style="Dim.TLabel").pack(side="left")
        self._procmon_sid = tk.StringVar()
        ttk.Entry(pf, textvariable=self._procmon_sid, width=12).pack(side="left", padx=(4, 10))
        ttk.Label(pf, text="Procmon CSV:", style="Dim.TLabel").pack(side="left")
        self._procmon_csv = tk.StringVar()
        ttk.Entry(pf, textvariable=self._procmon_csv, width=34).pack(side="left", padx=(4, 6))
        ttk.Button(pf, text="Browse", command=self._browse_procmon_csv).pack(side="left", padx=(0, 10))
        pf2 = ttk.Frame(tool_frame)
        pf2.pack(fill="x", pady=(0, 4))
        ttk.Label(pf2, text="Filter processes:", style="Dim.TLabel").pack(side="left")
        self._procmon_filter = tk.StringVar()
        ttk.Entry(pf2, textvariable=self._procmon_filter, width=40).pack(side="left", padx=(4, 10))
        ttk.Label(pf2, text="e.g. malware.exe,cmd.exe (blank=all)", style="Dim.TLabel").pack(side="left")
        pf3 = ttk.Frame(tool_frame)
        pf3.pack(fill="x", pady=(0, 6))
        ttk.Button(pf3, text="  Ingest Procmon  ", command=self._run_ingest_procmon).pack(side="left")
        self._procmon_dryrun = tk.BooleanVar()
        ttk.Checkbutton(pf3, text="Dry run (preview only)", variable=self._procmon_dryrun).pack(side="left", padx=(12, 0))

        ttk.Separator(outer, orient="horizontal").pack(fill="x", padx=14, pady=8)

        self._tools_out = scrolledtext.ScrolledText(
            outer, bg=C_ENTRY, fg=C_FG, insertbackground=C_FG,
            relief="flat", state="disabled", font=MONO_FONT)
        self._tools_out.pack(fill="both", expand=True, padx=14, pady=(0, 12))

    # -----------------------------------------------------------------------
    # Tab: Settings
    # -----------------------------------------------------------------------

    def _build_settings_tab(self):
        outer = ttk.Frame(self._nb)
        self._nb.add(outer, text="  Settings  ")

        frame = ttk.Frame(outer)
        frame.pack(fill="both", expand=True, padx=14, pady=14)
        frame.columnconfigure(1, weight=1)

        self._set = {}
        R = 0

        for label, key, default in [
            ("Analyst name", "analyst",   self.cfg.get("analyst",   "Surrplexie")),
            ("Repo root",    "repo_root", str(self.repo_root or "")),
        ]:
            _lbl(frame, label, R)
            self._set[key] = tk.StringVar(value=default)
            _entry(frame, self._set[key], R)
            R += 1

        bf = ttk.Frame(frame)
        bf.grid(row=R, column=0, columnspan=3, pady=10)
        ttk.Button(bf, text="  Save Settings  ",
                   command=self._save_settings).pack(side="left", padx=6)
        ttk.Button(bf, text="  Browse repo...  ",
                   command=lambda: self._browse_repo(update_settings=True)).pack(side="left", padx=6)
        R += 1

        ttk.Separator(frame, orient="horizontal").grid(
            row=R, column=0, columnspan=3, sticky="ew", padx=0, pady=12)
        R += 1

        info = (
            f"workflow_gui.py  v{APP_VERSION}\n"
            f"Config file: {CONFIG_FILE}\n\n"
            f"Compile to executable:\n"
            f"  Windows  ->  powershell -File .\\30_scripts\\build_exe.ps1\n"
            f"  Linux    ->  bash ./30_scripts/build_linux.sh\n\n"
            f"Outputs binary to dist/workflow_gui(.exe)\n"
        )
        ttk.Label(frame, text=info, style="Dim.TLabel",
                  justify="left").grid(row=R, column=0, columnspan=3, sticky="w")

    # -----------------------------------------------------------------------
    # Event handlers
    # -----------------------------------------------------------------------

    def _on_sha256_change(self, *_):
        sha = self._ns["sha256"].get().strip()
        if len(sha) == 64 and re.fullmatch(r"[0-9a-fA-F]+", sha):
            current_url = self._ns["mb_url"].get().strip()
            if not current_url:
                self._ns["mb_url"].set(f"https://bazaar.abuse.ch/sample/{sha}/")

    def _on_type_change(self, *_):
        """Seed tags and MITRE hint fields when the sample type changes."""
        t = self._ns["sample_type"].get()
        # Only seed if field is currently empty or held a previous type hint
        current_tags  = self._ns["tags"].get().strip()
        current_mitre = self._ns["mitre"].get().strip()
        hint_tags  = TYPE_TAG_HINTS.get(t, "")
        hint_mitre = TYPE_MITRE_HINTS.get(t, "")
        # Replace if blank or if value matches any known hint (user hasn't customised yet)
        all_hints = set(v for v in TYPE_TAG_HINTS.values())
        if not current_tags or current_tags in all_hints:
            self._ns["tags"].set(hint_tags)
        all_mitre = set(v for v in TYPE_MITRE_HINTS.values())
        if not current_mitre or current_mitre in all_mitre:
            self._ns["mitre"].set(hint_mitre)
        self._log(f"Type changed to {t} -- tag/MITRE hints updated.")

    def _auto_detect_num(self):
        if not self.repo_root:
            self._log("No repo root set.")
            return
        n = next_sample_number(self.repo_root)
        self._ns["num"].set(str(n))
        self._log(f"Next sample number: {n}")

    def _on_create_sample(self):
        if not self.repo_root:
            messagebox.showerror("No repo", "Browse to the repo root first.")
            return

        num_str = self._ns["num"].get().strip()
        if not num_str.isdigit():
            messagebox.showerror("Invalid #", "Sample # must be a whole number.")
            return

        n   = int(num_str)
        sid = f"sample_{pad2(n)}"

        # Overwrite guard
        for d in ("00_original", "01_static", "02_dynamic", "03_findings"):
            p = self.repo_root / d / f"{sid}.md"
            if p.exists():
                if not messagebox.askyesno("Overwrite?",
                    f"{sid}.md exists in {d}/.\n\nOverwrite all phase files?"):
                    return
                break

        v = {
            "sample_id":        sid,
            "sha256":           self._ns["sha256"].get().strip(),
            "sha1":             self._ns["sha1"].get().strip(),
            "md5":              self._ns["md5"].get().strip(),
            "filename":         self._ns["filename"].get().strip(),
            "mime":             self._ns["mime"].get().strip(),
            "size":             self._ns["size"].get().strip(),
            "first_seen":       self._ns["first_seen"].get().strip(),
            "mb_url":           self._ns["mb_url"].get().strip(),
            "date_acquired":    self._ns["date_acquired"].get().strip(),
            "date_analyzed":    self._ns["date_analyzed"].get().strip(),
            "analyst":          self._ns["analyst"].get().strip() or "Surrplexie",
            "verdict":          self._ns["verdict"].get(),
            "confidence":       self._ns["confidence"].get(),
            "family":           self._ns["family"].get().strip(),
            "tags":             self._ns["tags"].get().strip(),
            "mitre":            self._ns["mitre"].get().strip(),
            "procmon_run":      self._ns["procmon_run"].get(),
            "dynamic_complete": self._ns["dynamic_complete"].get(),
            "yara_rows":        self._ns["yara_txt"].get("1.0", "end").strip(),
            "sample_type":      self._ns["sample_type"].get(),
        }

        try:
            phases = {
                self.repo_root / "00_original" / f"{sid}.md": build_original(v),
                self.repo_root / "01_static"   / f"{sid}.md": build_static(v),
                self.repo_root / "02_dynamic"  / f"{sid}.md": build_dynamic(v),
                self.repo_root / "03_findings" / f"{sid}.md": build_findings(v),
            }
            for path, content in phases.items():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")

            shot_dir = self.repo_root / "50_screenshots" / sid
            shot_dir.mkdir(parents=True, exist_ok=True)
            idx = shot_dir / "SHOT_INDEX.txt"
            if not idx.exists():
                idx.write_text(build_shot_index(v), encoding="utf-8")

            update_tracker_row(self.repo_root, sid,
                               v["sha256"], v["analyst"], v["date_acquired"])

        except Exception as exc:
            messagebox.showerror("Error", str(exc))
            self._log(f"Error: {exc}")
            return

        messagebox.showinfo("Created",
            f"{sid} scaffolded successfully.\n\n"
            f"  00_original/{sid}.md  - acquisition receipt\n"
            f"  01_static/{sid}.md    - static triage\n"
            f"  02_dynamic/{sid}.md   - dynamic triage\n"
            f"  03_findings/{sid}.md  - findings + frontmatter\n"
            f"  50_screenshots/{sid}/ - screenshot folder\n\n"
            f"samples_tracker.csv updated to 'queued'.\n\n"
            f"Open the .md files and fill any remaining PENDING fields.")
        self._log(f"Created {sid} -- all phase files written.")

    def _clear_ns_form(self):
        for key in ("sha256", "sha1", "md5", "filename", "mime",
                    "size", "first_seen", "mb_url", "tags", "mitre", "family"):
            self._ns[key].set("")
        self._ns["verdict"].set(VERDICTS[0])
        self._ns["confidence"].set(CONFIDENCES[0])
        self._ns["procmon_run"].set(False)
        self._ns["dynamic_complete"].set(False)
        self._ns["date_acquired"].set(today())
        self._ns["date_analyzed"].set(today())
        self._ns["yara_txt"].delete("1.0", "end")
        self._ns["yara_txt"].insert("end",
            "| RuleName | Author | What it flags |\n"
            "| RuleName2 | Author2 | What it flags |")
        self._log("Form cleared.")

    def _refresh_sample_list(self):
        if not self.repo_root:
            return
        ids = list_active_sample_ids(self.repo_root)
        self._up["id_combo"].configure(values=ids)
        if ids:
            self._up["id"].set(ids[-1])
        self._log(f"Loaded {len(ids)} active sample IDs.")

    def _load_existing_values(self):
        sid = self._up["id"].get().strip()
        if not sid or not self.repo_root:
            return
        path = self.repo_root / "03_findings" / f"{sid}.md"
        fm = read_frontmatter(path)
        if not fm:
            self._log(f"No frontmatter found in {path.name}")
            return
        self._up["verdict"].set(fm.get("verdict", VERDICTS[0]))
        self._up["confidence"].set(fm.get("family_confidence", CONFIDENCES[0]))
        self._up["tags"].set(fm.get("tags", ""))
        self._up["mitre"].set(fm.get("mitre_techniques", ""))
        self._log(f"Loaded frontmatter from {path.name}")

    def _on_update_sample(self):
        if not self.repo_root:
            messagebox.showerror("No repo", "Browse to repo root first.")
            return
        sid = self._up["id"].get().strip()
        if not sid:
            messagebox.showerror("No sample", "Select a sample ID first.")
            return

        new_status = self._up["status"].get()
        set_tracker_status(self.repo_root, sid, new_status)

        findings = self.repo_root / "03_findings" / f"{sid}.md"
        if findings.exists():
            content = findings.read_text(encoding="utf-8", errors="replace")

            def _set(text, key, value):
                return re.sub(rf"^({key}:\s*).*$",
                              lambda m: m.group(1) + value,
                              text, flags=re.MULTILINE)

            content = _set(content, "status", new_status)
            content = _set(content, "verdict", self._up["verdict"].get())
            content = _set(content, "family_confidence", self._up["confidence"].get())

            tags_raw = self._up["tags"].get().strip()
            if tags_raw:
                tag_block = _tag_yaml(tags_raw)
                content = re.sub(
                    r"^tags:\n(?:  - [^\n]+\n?)+",
                    f"tags:\n{tag_block}\n",
                    content, flags=re.MULTILINE)

            mitre_raw = self._up["mitre"].get().strip()
            if mitre_raw:
                mitre_block = _tag_yaml(mitre_raw)
                content = re.sub(
                    r"^mitre_techniques:\n(?:  - [^\n]+\n?)+",
                    f"mitre_techniques:\n{mitre_block}\n",
                    content, flags=re.MULTILINE)

            findings.write_text(content, encoding="utf-8")

        msg = (f"Updated {sid}\n"
               f"  samples_tracker.csv status -> {new_status}\n"
               f"  03_findings/{sid}.md frontmatter patched\n\n")
        _append(self._up["output"], msg)
        self._log(f"Updated {sid} -> {new_status}")

    def _run_ps_script(self, script: str, extra_args: list = None):
        if not self.repo_root:
            messagebox.showerror("No repo", "Browse to repo root first.")
            return
        script_path = self.repo_root / "30_scripts" / script
        if not script_path.exists():
            _append(self._tools_out, f"Script not found: {script_path}\n")
            return

        if sys.platform == "win32":
            cmd = ["powershell", "-ExecutionPolicy", "Bypass", "-File", str(script_path)]
        else:
            cmd = ["pwsh", "-File", str(script_path)]
        cmd += (extra_args or [])

        _append(self._tools_out, f"\n--- Running {script} ---\n")
        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True,
                cwd=str(self.repo_root), timeout=90)
            out = (result.stdout or "") + (result.stderr or "")
            _append(self._tools_out, out or "(no output)\n")
            _append(self._tools_out, f"--- Exit code: {result.returncode} ---\n")
            self._log(f"{script} done (exit {result.returncode})")
        except FileNotFoundError:
            _append(self._tools_out,
                "PowerShell / pwsh not found.\n"
                "Windows: PowerShell is built in.\n"
                "Linux: install 'pwsh' (PowerShell Core) or run scripts manually.\n")
        except subprocess.TimeoutExpired:
            _append(self._tools_out, "Timed out (90 s).\n")

    # -----------------------------------------------------------------------
    # Utility
    # -----------------------------------------------------------------------

    def _refresh_repo_label(self):
        if self.repo_root:
            self._repo_lbl.configure(text=str(self.repo_root), foreground=C_OK)
        else:
            self._repo_lbl.configure(
                text="(not found -- click Browse)", foreground=C_ERR)

    def _browse_procmon_csv(self):
        path = filedialog.askopenfilename(
            title="Select Procmon CSV export",
            filetypes=[("CSV files", "*.csv"), ("All files", "*.*")])
        if path:
            self._procmon_csv.set(path)

    def _run_ingest_procmon(self):
        if not self.repo_root:
            messagebox.showerror("No repo", "Browse to repo root first.")
            return
        sid = self._procmon_sid.get().strip()
        csv_path = self._procmon_csv.get().strip()
        if not sid:
            messagebox.showerror("Missing", "Enter a Sample ID (e.g. sample_07).")
            return
        if not csv_path:
            messagebox.showerror("Missing", "Browse to a Procmon CSV file.")
            return
        script_path = self.repo_root / "30_scripts" / "ingest-procmon.ps1"
        extra = ["-SampleId", sid, "-ProcmonCsv", csv_path,
                 "-Root", str(self.repo_root)]
        if self._procmon_filter.get().strip():
            extra += ["-ProcessFilter", self._procmon_filter.get().strip()]
        if self._procmon_dryrun.get():
            extra += ["-DryRun"]
        self._run_ps_script("ingest-procmon.ps1", extra_args=extra)

    def _browse_repo(self, update_settings: bool = False):
        path = filedialog.askdirectory(
            title="Select repo root (the folder containing samples_tracker.csv)")
        if not path:
            return
        p = Path(path)
        if not (p / "samples_tracker.csv").exists():
            messagebox.showwarning(
                "Not a repo root",
                "samples_tracker.csv not found.\n"
                "Select the root of the labs repo (e.g. C:\\...\\labs).")
            return
        self.repo_root = p
        self.cfg["repo_root"] = str(p)
        save_config(self.cfg)
        self._refresh_repo_label()
        if update_settings and "repo_root" in self._set:
            self._set["repo_root"].set(str(p))
        self._log(f"Repo root: {p}")

    def _save_settings(self):
        analyst  = self._set["analyst"].get().strip()
        repo_str = self._set["repo_root"].get().strip()
        self.cfg["analyst"] = analyst
        if repo_str:
            p = Path(repo_str)
            if p.is_dir():
                self.cfg["repo_root"] = repo_str
                found = find_repo_root(p)
                if found:
                    self.repo_root = found
                    self._refresh_repo_label()
        save_config(self.cfg)
        if "analyst" in self._ns:
            self._ns["analyst"].set(analyst)
        self._log("Settings saved.")
        messagebox.showinfo("Saved", "Settings saved successfully.")

    def _log(self, msg: str):
        self._status_var.set(msg)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=APP_TITLE)
    parser.add_argument("--repo", metavar="PATH",
                        help="Path to labs repo root (overrides auto-detect and config)")
    args = parser.parse_args()
    app = WorkflowApp(cli_repo=args.repo)
    app.mainloop()


if __name__ == "__main__":
    main()
