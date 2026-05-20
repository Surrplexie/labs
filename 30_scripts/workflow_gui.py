#!/usr/bin/env python3
"""
workflow_gui.py  --  Cross-platform labs engagement assistant.

Malware triage (file) is the primary use case; CTF, lab, and hunt share the same forms.
Paste values once; phase files are filled automatically (v3.1+: kind-specific UI, Tools tab).

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
import shutil
import subprocess
import sys
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, scrolledtext, simpledialog, ttk

# PIL is optional -- used for thumbnail preview in Screenshots tab
try:
    from PIL import Image, ImageTk
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

APP_TITLE   = "Workflow HUD -- Labs Engagement Assistant"
APP_VERSION = "3.1.0"
CONFIG_FILE = Path(__file__).parent / ".workflow_gui_config.json"

VERDICTS     = ["suspicious", "malicious", "benign", "unknown"]
CONFIDENCES  = ["high", "medium-high", "medium", "low"]
SAMPLE_TYPES = ["PE", "Office", "Script", "Archive"]

ENGAGEMENT_KINDS = ["file", "ctf", "lab", "hunt"]
KIND_STATUSES = {
    "file":  ["queued", "static", "dynamic", "done"],
    "ctf":   ["assigned", "recon", "stuck", "solved", "writeup_done"],
    "lab":   ["not_started", "in_progress", "objectives_met", "reviewed"],
    "hunt":  ["scoped", "collecting", "analyzing", "closed"],
}
ALL_STATUSES = sorted({s for ss in KIND_STATUSES.values() for s in ss})

CTF_PLATFORMS    = ["HackTheBox", "TryHackMe", "PicoCTF", "CTFtime", "SANS", "PortSwigger",
                    "PNPT", "internal", "other"]
CTF_CATEGORIES   = ["web", "pwn", "rev", "crypto", "forensics", "misc", "osint", "network", "other"]
CTF_DIFFICULTIES = ["easy", "medium", "hard", "insane"]

LAB_PLATFORMS = ["TryHackMe", "HackTheBox", "SANS", "Offensive Security", "TCM Security",
                 "Cybrary", "PNPT", "INE", "PortSwigger", "employer", "internal", "other"]

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
KIND_TAG_HINTS = {
    "ctf":  "ctf",
    "lab":  "lab, hands-on",
    "hunt": "hunt, detection, siem",
}
KIND_SKILL_HINTS = {
    "ctf":  "e.g. web-enumeration, privilege-escalation, buffer-overflow",
    "lab":  "e.g. linux-fundamentals, network-scanning, active-directory",
    "hunt": "e.g. threat-hunting, siem-queries, log-analysis, sigma-rules",
}

# Dark theme
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
C_TEAL   = "#89dceb"

MONO_FONT = ("Consolas", 9)       if sys.platform == "win32" else ("DejaVu Sans Mono", 9)
UI_FONT   = ("Segoe UI", 10)      if sys.platform == "win32" else ("DejaVu Sans", 10)
HDR_FONT  = ("Segoe UI Semibold", 12) if sys.platform == "win32" else ("DejaVu Sans Bold", 12)
SEC_FONT  = ("Segoe UI Semibold", 9)  if sys.platform == "win32" else ("DejaVu Sans Bold", 9)
SMALL_FONT = (UI_FONT[0], 8)

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".heic", ".bmp", ".gif", ".webp"}

# ---------------------------------------------------------------------------
# Data helpers
# ---------------------------------------------------------------------------

def today() -> str:
    return datetime.date.today().isoformat()

def pad2(n: int) -> str:
    return f"{n:02d}"

def find_repo_root(start: Path) -> "Path | None":
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

TRACKER_ENCODING = "utf-8-sig"


def normalise_tracker_row(row: dict) -> dict:
    return {
        k.lstrip("\ufeff").strip().strip('"'): (v if v is not None else "")
        for k, v in row.items()
    }


def read_tracker_rows(root: Path) -> list:
    tracker = root / "samples_tracker.csv"
    if not tracker.exists():
        return []
    try:
        with open(tracker, newline="", encoding=TRACKER_ENCODING) as f:
            return [normalise_tracker_row(row) for row in csv.DictReader(f)]
    except Exception:
        return []


def next_sample_number(root: Path) -> int:
    """First tracker row with status empty; otherwise max slot + 1."""
    slots = []
    for row in read_tracker_rows(root):
        sid = row.get("sample_id", "").strip()
        m = re.match(r"sample_(\d+)", sid)
        if not m:
            continue
        status = row.get("status", "empty").strip().lower()
        slots.append((int(m.group(1)), status))
    if not slots:
        return 1
    for n, status in sorted(slots):
        if status == "empty":
            return n
    return max(n for n, _ in slots) + 1


def list_tracker_rows(root: Path) -> list:
    """Tracker rows with status other than empty (in-use engagements)."""
    return [
        row for row in read_tracker_rows(root)
        if row.get("sample_id", "").strip()
        and row.get("status", "empty").strip().lower() != "empty"
    ]

def list_active_sample_ids(root: Path) -> list:
    return [r["sample_id"] for r in list_tracker_rows(root)]

def get_kind_for_slot(root: Path, sid: str) -> str:
    for row in read_tracker_rows(root):
        if row.get("sample_id", "").strip() == sid:
            return row.get("engagement_kind", "file").strip() or "file"
    return "file"

def read_frontmatter(findings_path: Path) -> dict:
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
    for key in ("tags", "mitre_techniques", "skills"):
        block = re.search(rf"^{key}:\n((?:  - [^\n]+\n?)+)", fm, re.MULTILINE)
        if block:
            items = re.findall(r"^\s+-\s+(.+)$", block.group(1), re.MULTILINE)
            out[key] = ", ".join(i.split("#")[0].strip() for i in items)
    return out

def patch_frontmatter(findings_path: Path, updates: dict) -> bool:
    """
    Update specific key: value lines inside an existing YAML frontmatter block.
    Updates is a dict of {key: new_value}. List fields use list syntax.
    Returns True on success.
    """
    if not findings_path.exists():
        return False
    content = findings_path.read_text(encoding="utf-8", errors="replace")
    m = re.match(r"^(---\n)(.*?)(\n---)", content, re.DOTALL)
    if not m:
        return False

    fm_text = m.group(2)
    rest    = content[m.end():]

    for key, value in updates.items():
        if value is None or value == "":
            continue
        if isinstance(value, list):
            items = [v.strip() for v in value if v.strip()]
            if not items:
                continue
            yaml_list = "\n".join(f"  - {i}" for i in items)
            new_block  = f"{key}:\n{yaml_list}"
            # Replace existing list block if present
            existing = re.search(
                rf"^{re.escape(key)}:\n((?:  - [^\n]+\n?)*)",
                fm_text, re.MULTILINE)
            if existing:
                fm_text = fm_text[:existing.start()] + new_block + fm_text[existing.end():]
            else:
                fm_text = fm_text.rstrip() + f"\n{new_block}"
        else:
            new_line = f"{key}: {value}"
            # Replace existing scalar
            replaced = re.sub(
                rf"^{re.escape(key)}:.*$", new_line, fm_text, flags=re.MULTILINE)
            if replaced == fm_text:
                # Key not found -- append
                fm_text = fm_text.rstrip() + f"\n{new_line}"
            else:
                fm_text = replaced

    new_content = m.group(1) + fm_text + m.group(3) + rest
    findings_path.write_text(new_content, encoding="utf-8")
    return True

def set_tracker_status(root: Path, sid: str, status: str) -> None:
    tracker = root / "samples_tracker.csv"
    rows = read_tracker_rows(root)
    if not rows:
        return
    fieldnames = list(rows[0].keys())
    for row in rows:
        if row.get("sample_id", "").strip() == sid:
            row["status"] = status
    with open(tracker, "w", newline="", encoding=TRACKER_ENCODING) as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)

# ---------------------------------------------------------------------------
# Template builders
# ---------------------------------------------------------------------------

def _tag_yaml(raw: str, indent: str = "  ") -> str:
    items = [t.strip() for t in re.split(r"[,\n]+", raw) if t.strip()]
    return "\n".join(f"{indent}- {t}" for t in items) if items else f"{indent}- PENDING"

def _ioc_rows_md(v: dict) -> str:
    rows = []
    if v.get("sha256"):  rows.append(f"| sha256 | {v['sha256']} | Primary sample |")
    if v.get("md5"):     rows.append(f"| md5    | {v['md5']} | Full-file hash |")
    if v.get("sha1"):    rows.append(f"| sha1   | {v['sha1']} | |")
    if v.get("filename"):rows.append(f"| filename | {v['filename']} | Claimed name |")
    return "\n".join(rows) if rows else "| PENDING | PENDING | PENDING |"

def build_shot_index(v: dict) -> str:
    sid     = v["sample_id"]
    analyst = v.get("analyst") or "Surrplexie"
    date    = v.get("date_acquired") or today()
    return (
        f"SHOT_INDEX -- {sid}\n"
        f"Analyst: {analyst}\n"
        f"Date: {date}\n\n"
        f"FORMAT: filename -- tool -- what is captured\n"
        f"------------------------------------------------------------\n"
        f"(add rows as you take screenshots)\n\n"
        f"EVIDENCE HYGIENE CHECKLIST\n"
        f"[ ] VM username/hostname NOT visible\n"
        f"[ ] Analyst host paths NOT in any screenshot\n"
        f"[ ] No personal information visible\n"
        f"[ ] EXIF stripped: run 30_scripts\\strip-exif.ps1 -SampleId {sid}\n"
        f"[ ] HEIC converted to PNG before committing\n"
        f"[ ] Redact check passed: 30_scripts\\redact-check.ps1 -SampleId {sid}\n"
    )

# ---------------------------------------------------------------------------
# GUI helpers
# ---------------------------------------------------------------------------

def _scrollable_frame(parent) -> "tuple[tk.Canvas, ttk.Frame]":
    canvas = tk.Canvas(parent, bg=C_BG, highlightthickness=0)
    sb = ttk.Scrollbar(parent, orient="vertical", command=canvas.yview)
    canvas.configure(yscrollcommand=sb.set)
    sb.pack(side="right", fill="y")
    canvas.pack(side="left", fill="both", expand=True)
    frame = ttk.Frame(canvas)
    win_id = canvas.create_window((0, 0), window=frame, anchor="nw")

    def _on_frame_resize(e): canvas.configure(scrollregion=canvas.bbox("all"))
    def _on_canvas_resize(e): canvas.itemconfig(win_id, width=e.width)
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
    w = ttk.Label(parent, text=text, **kw)
    w.grid(row=row, column=col, sticky="e", padx=(12, 6), pady=3)
    return w

def _entry(parent, var, row, col=1, width=None, **kw):
    e = ttk.Entry(parent, textvariable=var, **({"width": width} if width else {}), **kw)
    e.grid(row=row, column=col, sticky="ew", padx=(0, 12), pady=3)
    return e

def _combo(parent, var, values, row, col=1):
    c = ttk.Combobox(parent, textvariable=var, values=values, state="readonly")
    c.grid(row=row, column=col, sticky="ew", padx=(0, 12), pady=3)
    return c

def _hint(parent, text, row):
    ttk.Label(parent, text=text, style="Dim.TLabel",
              font=SMALL_FONT).grid(row=row, column=2, sticky="w", padx=4)

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
        self.geometry("900x780")
        self.minsize(750, 600)
        self.configure(bg=C_BG)

        self.cfg       = load_config()
        self.repo_root = None

        search_paths = []
        if cli_repo:               search_paths.append(Path(cli_repo))
        if self.cfg.get("repo_root"): search_paths.append(Path(self.cfg["repo_root"]))
        search_paths += [Path(__file__).parent.parent, Path.cwd()]

        for sp in search_paths:
            found = find_repo_root(sp)
            if found:
                self.repo_root = found
                break

        # Screenshot manager state
        self._shot_files: list = []      # list of [Path, caption, status]
        self._shot_thumbs: list = []     # held refs so GC doesn't collect them

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
        s.configure("TNotebook.Tab", background=C_PANEL, foreground=C_DIM, padding=[14, 6])
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
        s.configure("Warn.TButton", background="#f9e2af", foreground="#1e1e2e")
        s.configure("Green.TButton", background="#a6e3a1", foreground="#1e1e2e")
        s.configure("TSeparator", background=C_PANEL)
        s.configure("TScrollbar", background=C_PANEL, troughcolor=C_BG,
                    arrowcolor=C_DIM, borderwidth=0)
        s.configure("TCheckbutton", background=C_BG, foreground=C_FG)
        s.configure("Treeview", background=C_ENTRY, foreground=C_FG,
                    fieldbackground=C_ENTRY, rowheight=22)
        s.configure("Treeview.Heading", background=C_PANEL, foreground=C_FG)
        s.map("Treeview", background=[("selected", C_ACCENT)],
              foreground=[("selected", C_WHITE)])

    # -----------------------------------------------------------------------
    # Top-level UI
    # -----------------------------------------------------------------------

    def _build_ui(self):
        hdr = ttk.Frame(self)
        hdr.pack(fill="x", padx=14, pady=(10, 0))
        ttk.Label(hdr, text=APP_TITLE, font=HDR_FONT).pack(side="left")
        ttk.Label(hdr, text=f"v{APP_VERSION}",
                  style="Dim.TLabel").pack(side="left", padx=(8, 0), pady=(2, 0))

        rbar = ttk.Frame(self)
        rbar.pack(fill="x", padx=14, pady=(4, 2))
        ttk.Label(rbar, text="Repo:", style="Dim.TLabel").pack(side="left")
        self._repo_lbl = ttk.Label(rbar, text="(searching...)", style="Dim.TLabel")
        self._repo_lbl.pack(side="left", padx=(6, 10))
        ttk.Button(rbar, text="Browse...", command=self._browse_repo).pack(side="left")

        ttk.Separator(self, orient="horizontal").pack(fill="x", padx=14, pady=4)

        self._nb = ttk.Notebook(self)
        self._nb.pack(fill="both", expand=True, padx=14, pady=(0, 4))

        self._build_new_engagement_tab()
        self._build_screenshots_tab()
        self._build_update_tab()
        self._build_tools_tab()
        self._build_settings_tab()

        self._status_var = tk.StringVar(value="Ready.")
        ttk.Label(self, textvariable=self._status_var,
                  style="Dim.TLabel").pack(side="left", padx=14, pady=(0, 8))

    # -----------------------------------------------------------------------
    # Tab: New Engagement
    # -----------------------------------------------------------------------

    def _build_new_engagement_tab(self):
        outer = ttk.Frame(self._nb)
        self._nb.add(outer, text="  New Engagement  ")
        _, frame = _scrollable_frame(outer)
        frame.columnconfigure(1, weight=1)

        self._ns = {}
        R = 0

        # ---- Identity ----
        _section_label(frame, "ENGAGEMENT IDENTITY", R); R += 2

        _lbl(frame, "Slot #", R)
        nf = ttk.Frame(frame)
        nf.grid(row=R, column=1, sticky="ew", padx=(0, 12), pady=3)
        self._ns["num"] = tk.StringVar()
        ttk.Entry(nf, textvariable=self._ns["num"], width=6).pack(side="left")
        ttk.Button(nf, text="Auto-detect",
                   command=self._auto_detect_num).pack(side="left", padx=(8, 0))
        R += 1

        _lbl(frame, "Engagement kind", R)
        self._ns["kind"] = tk.StringVar(value="file")
        _combo(frame, self._ns["kind"], ENGAGEMENT_KINDS, R)
        _hint(frame, "file=malware  ctf=challenge  lab=training  hunt=detection", R)
        self._ns["kind"].trace_add("write", self._on_kind_change)
        R += 1

        _lbl(frame, "Title / tag", R)
        self._ns["title"] = tk.StringVar()
        _entry(frame, self._ns["title"], R)
        _hint(frame, "CTF name, lab module, hunt hypothesis summary, or file tag", R)
        R += 1

        _lbl(frame, "Analyst", R)
        self._ns["analyst"] = tk.StringVar(value=self.cfg.get("analyst", "Surrplexie"))
        _entry(frame, self._ns["analyst"], R); R += 1

        # ---- File-kind type ----
        self._ns["_type_lbl"]   = _lbl(frame, "File sample type", R)
        self._ns["sample_type"] = tk.StringVar(value="PE")
        self._ns["_type_combo"] = _combo(frame, self._ns["sample_type"], SAMPLE_TYPES, R)
        self._ns["_type_hint"]  = ttk.Label(
            frame, text="PE=exe/dll  Office=doc  Script=ps1/vbs/js  Archive=zip/iso",
            style="Dim.TLabel", font=SMALL_FONT)
        self._ns["_type_hint"].grid(row=R, column=2, sticky="w", padx=4)
        self._ns["sample_type"].trace_add("write", self._on_type_change)
        R += 1

        # ---- CTF/Lab platform ----
        self._ns["_plat_lbl"]   = _lbl(frame, "Platform", R)
        self._ns["platform"]    = tk.StringVar()
        self._ns["_plat_combo"] = ttk.Combobox(
            frame, textvariable=self._ns["platform"],
            values=CTF_PLATFORMS + [p for p in LAB_PLATFORMS if p not in CTF_PLATFORMS])
        self._ns["_plat_combo"].grid(row=R, column=1, sticky="ew", padx=(0, 12), pady=3)
        _hint(frame, "HackTheBox, TryHackMe, TCM Security, SANS, etc.", R)
        R += 1

        # ---- CTF-specific ----
        self._ns["_cat_lbl"]       = _lbl(frame, "CTF Category", R)
        self._ns["ctf_category"]   = tk.StringVar()
        self._ns["_cat_combo"]     = _combo(frame, self._ns["ctf_category"],
                                            [""] + CTF_CATEGORIES, R)
        R += 1
        self._ns["_diff_lbl"]      = _lbl(frame, "Difficulty", R)
        self._ns["ctf_difficulty"] = tk.StringVar()
        self._ns["_diff_combo"]    = _combo(frame, self._ns["ctf_difficulty"],
                                            [""] + CTF_DIFFICULTIES, R)
        R += 1
        self._ns["_pts_lbl"]    = _lbl(frame, "Points", R)
        self._ns["ctf_points"]  = tk.StringVar()
        self._ns["_pts_entry"]  = _entry(frame, self._ns["ctf_points"], R)
        _hint(frame, "Numeric points value (optional)", R)
        R += 1
        self._ns["_solved_lbl"]   = _lbl(frame, "Solved?", R)
        self._ns["ctf_solved"]    = tk.BooleanVar()
        self._ns["_solved_chk"]   = ttk.Checkbutton(
            frame, text="Yes -- flag captured",
            variable=self._ns["ctf_solved"])
        self._ns["_solved_chk"].grid(row=R, column=1, sticky="w", padx=(0, 12), pady=3)
        R += 1
        self._ns["_pub_lbl"]      = _lbl(frame, "Public writeup safe?", R)
        self._ns["ctf_public"]    = tk.BooleanVar()
        self._ns["_pub_chk"]      = ttk.Checkbutton(
            frame, text="Yes -- okay to publish writeup",
            variable=self._ns["ctf_public"])
        self._ns["_pub_chk"].grid(row=R, column=1, sticky="w", padx=(0, 12), pady=3)
        R += 1

        # ---- Lab-specific ----
        self._ns["_course_lbl"]   = _lbl(frame, "Course / provider", R)
        self._ns["lab_course"]    = tk.StringVar()
        self._ns["_course_entry"] = _entry(frame, self._ns["lab_course"], R)
        _hint(frame, "e.g. Practical Ethical Hacking, OSCP, THM path name", R)
        R += 1
        self._ns["_module_lbl"]   = _lbl(frame, "Module / section", R)
        self._ns["lab_module"]    = tk.StringVar()
        self._ns["_module_entry"] = _entry(frame, self._ns["lab_module"], R)
        _hint(frame, "e.g. Module 8 -- Active Directory Attacks", R)
        R += 1
        self._ns["_obj_lbl"]      = _lbl(frame, "Objectives", R)
        self._ns["lab_objectives"] = scrolledtext.ScrolledText(
            frame, height=3, bg=C_ENTRY, fg=C_FG, insertbackground=C_FG,
            relief="flat", font=MONO_FONT)
        self._ns["lab_objectives"].grid(
            row=R, column=1, columnspan=2, sticky="ew", padx=(0, 12), pady=3)
        self._ns["lab_objectives"].insert("end", "- Objective 1\n- Objective 2")
        R += 1
        self._ns["_objmet_lbl"]   = _lbl(frame, "Objectives met?", R)
        self._ns["lab_objmet"]    = tk.BooleanVar()
        self._ns["_objmet_chk"]   = ttk.Checkbutton(
            frame, text="Yes -- all objectives completed",
            variable=self._ns["lab_objmet"])
        self._ns["_objmet_chk"].grid(row=R, column=1, sticky="w", padx=(0, 12), pady=3)
        R += 1

        # ---- Hunt-specific ----
        self._ns["_hyp_lbl"]       = _lbl(frame, "Hypothesis", R)
        self._ns["hunt_hypothesis"] = tk.StringVar()
        self._ns["_hyp_entry"]     = _entry(frame, self._ns["hunt_hypothesis"], R)
        _hint(frame, "Falsifiable one-liner: Attacker used X to achieve Y on Z", R)
        R += 1
        self._ns["_ds_lbl"]        = _lbl(frame, "Data sources", R)
        self._ns["hunt_datasources"] = tk.StringVar()
        self._ns["_ds_entry"]      = _entry(frame, self._ns["hunt_datasources"], R)
        _hint(frame, "e.g. Sysmon Event 1/3/10, Security 4688, Elastic SIEM", R)
        R += 1
        self._ns["_tb_lbl"]        = _lbl(frame, "Timebox", R)
        self._ns["hunt_timebox"]   = tk.StringVar()
        self._ns["_tb_entry"]      = _entry(frame, self._ns["hunt_timebox"], R)
        _hint(frame, "e.g. 30 days (2026-04-11 to 2026-05-11)", R)
        R += 1
        self._ns["_det_lbl"]       = _lbl(frame, "Detections found?", R)
        self._ns["hunt_detections"] = tk.BooleanVar()
        self._ns["_det_chk"]       = ttk.Checkbutton(
            frame, text="Yes -- confirmed detections",
            variable=self._ns["hunt_detections"])
        self._ns["_det_chk"].grid(row=R, column=1, sticky="w", padx=(0, 12), pady=3)
        R += 1

        # ---- Dates (all kinds) ----
        _section_label(frame, "DATES", R); R += 2
        for label, key, default in [
            ("Date started",           "date_acquired", today()),
            ("Date analyzed / closed", "date_analyzed", today()),
        ]:
            _lbl(frame, label, R)
            self._ns[key] = tk.StringVar(value=default)
            _entry(frame, self._ns[key], R); R += 1

        self._ns["_bazaar_panel"] = ttk.Frame(frame)
        self._ns["_bazaar_panel"].grid(row=R, column=0, columnspan=3, sticky="ew")
        self._ns["_bazaar_panel"].columnconfigure(1, weight=1)
        _lbl(self._ns["_bazaar_panel"], "First seen (Bazaar UTC)", 0)
        self._ns["first_seen"] = tk.StringVar(value="")
        _entry(self._ns["_bazaar_panel"], self._ns["first_seen"], 0)
        R += 1

        # ---- File-only block (hashes, file info, YARA) ----
        self._ns["_file_panel"] = ttk.Frame(frame)
        self._ns["_file_panel"].grid(row=R, column=0, columnspan=3, sticky="ew")
        fp = self._ns["_file_panel"]
        fp.columnconfigure(1, weight=1)
        fR = 0
        _section_label(fp, "HASHES  (file kind -- paste from MalwareBazaar)", fR); fR += 2
        for label, key in [("SHA256", "sha256"), ("SHA1", "sha1"), ("MD5", "md5")]:
            _lbl(fp, label, fR)
            self._ns[key] = tk.StringVar()
            _entry(fp, self._ns[key], fR); fR += 1
        self._ns["sha256"].trace_add("write", self._on_sha256_change)

        _section_label(fp, "FILE INFO", fR); fR += 2
        for label, key in [
            ("Filename (claimed)", "filename"),
            ("MIME type",          "mime"),
            ("Size (bytes)",       "size"),
            ("MB URL",             "mb_url"),
        ]:
            _lbl(fp, label, fR)
            self._ns[key] = tk.StringVar()
            _entry(fp, self._ns[key], fR); fR += 1
        _hint(fp, "MB URL auto-fills when SHA256 is 64 hex chars", fR - 1)

        _section_label(fp, "YARA RULES  (file kind -- one pipe row per line)", fR); fR += 2
        _lbl(fp, "YARA rows", fR)
        self._ns["yara_txt"] = scrolledtext.ScrolledText(
            fp, height=3, bg=C_ENTRY, fg=C_FG, insertbackground=C_FG,
            relief="flat", font=MONO_FONT)
        self._ns["yara_txt"].grid(row=fR, column=1, columnspan=2,
                                   sticky="ew", padx=(0, 12), pady=3)
        self._ns["yara_txt"].insert("end",
            "| RuleName | Author | What it flags |\n"
            "| RuleName2 | Author2 | What it flags |")
        R += 1

        # ---- Analysis metadata ----
        _section_label(frame, "ANALYSIS / OUTCOME METADATA", R); R += 2

        # File verdict/confidence/family
        self._ns["_verdict_lbl"] = _lbl(frame, "Verdict", R)
        self._ns["verdict"]      = tk.StringVar(value=VERDICTS[0])
        self._ns["_verdict_combo"] = _combo(frame, self._ns["verdict"], VERDICTS, R); R += 1

        self._ns["_conf_lbl"]    = _lbl(frame, "Confidence", R)
        self._ns["confidence"]   = tk.StringVar(value=CONFIDENCES[0])
        self._ns["_conf_combo"]  = _combo(frame, self._ns["confidence"], CONFIDENCES, R); R += 1

        self._ns["_fam_lbl"]  = _lbl(frame, "Family guess", R)
        self._ns["family"]    = tk.StringVar()
        self._ns["_fam_entry"] = _entry(frame, self._ns["family"], R); R += 1

        self._ns["_flags_lbl"] = _lbl(frame, "Flags", R)
        chkf = ttk.Frame(frame)
        chkf.grid(row=R, column=1, sticky="w", padx=(0, 12), pady=3)
        self._ns["procmon_run"]      = tk.BooleanVar()
        self._ns["dynamic_complete"] = tk.BooleanVar()
        ttk.Checkbutton(chkf, text="Procmon run",
                        variable=self._ns["procmon_run"]).pack(side="left")
        ttk.Checkbutton(chkf, text="Dynamic complete",
                        variable=self._ns["dynamic_complete"]).pack(side="left", padx=(14, 0))
        self._ns["_flags_frame"] = chkf
        R += 1

        # Outcome (non-file) -- one-liner summary
        self._ns["_outcome_lbl"]  = _lbl(frame, "Outcome summary", R)
        self._ns["outcome"]       = tk.StringVar()
        self._ns["_outcome_entry"] = _entry(frame, self._ns["outcome"], R)
        _hint(frame, "One-liner for INDEX.md outcome column", R)
        R += 1

        # ---- Skills (non-file) ----
        self._ns["_skills_lbl"]  = _lbl(frame, "Skills demonstrated", R)
        self._ns["skills"]       = tk.StringVar()
        self._ns["_skills_entry"] = _entry(frame, self._ns["skills"], R)
        self._ns["_skills_hint"] = ttk.Label(
            frame, text="comma-separated: web-enumeration, privilege-escalation",
            style="Dim.TLabel", font=SMALL_FONT)
        self._ns["_skills_hint"].grid(row=R, column=2, sticky="w", padx=4)
        R += 1

        # ---- Tags / MITRE ----
        _section_label(frame, "TAGS AND MITRE TECHNIQUES", R); R += 2

        _lbl(frame, "Tags", R)
        self._ns["tags"] = tk.StringVar()
        _entry(frame, self._ns["tags"], R)
        _hint(frame, "comma-separated: nsis, fake-alert, installer", R)
        R += 1

        self._ns["_mitre_lbl"]  = _lbl(frame, "MITRE IDs", R)
        self._ns["mitre"]       = tk.StringVar()
        self._ns["_mitre_entry"] = _entry(frame, self._ns["mitre"], R)
        _hint(frame, "comma-separated: T1036, T1027, T1547.001", R)
        R += 1

        # ---- Action ----
        _section_label(frame, "", R); R += 2
        bf = ttk.Frame(frame)
        bf.grid(row=R, column=0, columnspan=3, pady=(8, 20))
        self._ns["_create_btn"] = ttk.Button(
            bf, text="   CREATE ENGAGEMENT   ", command=self._on_create_sample)
        self._ns["_create_btn"].pack(side="left", padx=6)
        ttk.Button(bf, text="  Clear Form  ",
                   command=self._clear_ns_form).pack(side="left", padx=6)

        # Initial show/hide pass
        self._on_kind_change()

    # -----------------------------------------------------------------------
    # Tab: Screenshots
    # -----------------------------------------------------------------------

    def _build_screenshots_tab(self):
        outer = ttk.Frame(self._nb)
        self._nb.add(outer, text="  Screenshots  ")

        top = ttk.Frame(outer)
        top.pack(fill="x", padx=14, pady=(10, 4))

        ttk.Label(top, text="Target engagement:").pack(side="left")
        self._shot_slot_var = tk.StringVar()
        self._shot_slot_combo = ttk.Combobox(
            top, textvariable=self._shot_slot_var, state="readonly", width=16)
        self._shot_slot_combo.pack(side="left", padx=(6, 10))
        ttk.Button(top, text="Refresh",
                   command=self._refresh_shot_slots).pack(side="left")

        ttk.Label(top, text="  Next # starts at:").pack(side="left", padx=(16, 0))
        self._shot_start_var = tk.StringVar(value="auto")
        ttk.Entry(top, textvariable=self._shot_start_var, width=6).pack(side="left", padx=(4, 0))
        ttk.Label(top, text="(auto = detect from folder)",
                  style="Dim.TLabel", font=SMALL_FONT).pack(side="left", padx=4)

        # Buttons row
        brow = ttk.Frame(outer)
        brow.pack(fill="x", padx=14, pady=(0, 4))
        ttk.Button(brow, text="  Add Images...  ",
                   command=self._shot_add_images).pack(side="left", padx=(0, 6))
        ttk.Button(brow, text="Clear List",
                   command=self._shot_clear, style="Warn.TButton").pack(side="left", padx=(0, 16))

        ttk.Label(brow, text="Caption for selected:",
                  style="Dim.TLabel").pack(side="left")
        self._shot_caption_var = tk.StringVar()
        cap_entry = ttk.Entry(brow, textvariable=self._shot_caption_var, width=36)
        cap_entry.pack(side="left", padx=(4, 6))
        ttk.Button(brow, text="Set",
                   command=self._shot_set_caption).pack(side="left")

        # Treeview
        tree_frame = ttk.Frame(outer)
        tree_frame.pack(fill="both", expand=True, padx=14, pady=(4, 0))
        tree_frame.columnconfigure(0, weight=1)
        tree_frame.rowconfigure(0, weight=1)

        cols = ("#", "source", "caption", "status")
        self._shot_tree = ttk.Treeview(tree_frame, columns=cols, show="headings",
                                        selectmode="browse", height=10)
        self._shot_tree.heading("#", text="#")
        self._shot_tree.heading("source", text="Source filename")
        self._shot_tree.heading("caption", text="Caption / description")
        self._shot_tree.heading("status", text="Status")
        self._shot_tree.column("#", width=36, stretch=False)
        self._shot_tree.column("source", width=200)
        self._shot_tree.column("caption", width=280)
        self._shot_tree.column("status", width=80, stretch=False)

        sb = ttk.Scrollbar(tree_frame, orient="vertical",
                           command=self._shot_tree.yview)
        self._shot_tree.configure(yscrollcommand=sb.set)
        self._shot_tree.grid(row=0, column=0, sticky="nsew")
        sb.grid(row=0, column=1, sticky="ns")
        self._shot_tree.bind("<<TreeviewSelect>>", self._shot_on_select)

        # Thumbnail preview (if PIL available)
        if PIL_AVAILABLE:
            self._shot_thumb_lbl = ttk.Label(tree_frame, text="[preview]",
                                              style="Dim.TLabel")
            self._shot_thumb_lbl.grid(row=0, column=2, sticky="nsew",
                                       padx=(8, 0), pady=2)

        # Copy / action row
        act_row = ttk.Frame(outer)
        act_row.pack(fill="x", padx=14, pady=6)
        ttk.Button(
            act_row,
            text="  Copy & Rename into 50_screenshots/slot/  ",
            command=self._shot_copy_and_rename,
            style="Green.TButton",
        ).pack(side="left", padx=(0, 10))
        ttk.Button(
            act_row, text="  Update SHOT_INDEX.txt  ",
            command=self._shot_update_index,
        ).pack(side="left", padx=(0, 10))
        ttk.Button(
            act_row, text="  Strip EXIF  ",
            command=self._shot_strip_exif,
        ).pack(side="left")

        self._shot_lbl_info = ttk.Label(
            act_row, text="", style="Dim.TLabel", font=SMALL_FONT)
        self._shot_lbl_info.pack(side="left", padx=10)

        ttk.Label(outer,
                  text=(
                      "Note: HEIC files are flagged -- convert to PNG first (see strip-exif.ps1 notes). "
                      "PIL not installed" if not PIL_AVAILABLE else ""
                  ),
                  style="Dim.TLabel", font=SMALL_FONT,
                  ).pack(padx=14, anchor="w", pady=(0, 4))

    # -----------------------------------------------------------------------
    # Tab: Update Sample
    # -----------------------------------------------------------------------

    def _build_update_tab(self):
        outer = ttk.Frame(self._nb)
        self._nb.add(outer, text="  Update Engagement  ")

        frame = ttk.Frame(outer)
        frame.pack(fill="both", expand=True, padx=14, pady=14)
        frame.columnconfigure(1, weight=1)

        self._up = {}
        R = 0

        _lbl(frame, "Engagement ID", R)
        self._up["id"] = tk.StringVar()
        id_cb = ttk.Combobox(frame, textvariable=self._up["id"], state="readonly")
        id_cb.grid(row=R, column=1, sticky="ew", padx=(0, 8), pady=4)
        self._up["id_combo"] = id_cb
        ttk.Button(frame, text="Refresh list",
                   command=self._refresh_sample_list).grid(
            row=R, column=2, padx=(0, 12), pady=4)
        self._up["id"].trace_add("write", self._up_on_id_change)
        R += 1

        _lbl(frame, "Kind (detected)", R)
        self._up["kind_lbl"] = ttk.Label(frame, text="(select ID first)",
                                          style="Dim.TLabel")
        self._up["kind_lbl"].grid(row=R, column=1, sticky="w", padx=(0, 12), pady=3)
        R += 1

        _lbl(frame, "New status", R)
        self._up["status"] = tk.StringVar(value=KIND_STATUSES["file"][0])
        self._up["status_combo"] = ttk.Combobox(
            frame, textvariable=self._up["status"],
            values=KIND_STATUSES["file"], state="readonly")
        self._up["status_combo"].grid(
            row=R, column=1, sticky="ew", padx=(0, 12), pady=3)
        R += 1

        # File fields
        self._up["_verdict_lbl"]  = _lbl(frame, "Verdict", R)
        self._up["verdict"]       = tk.StringVar(value=VERDICTS[0])
        self._up["_verdict_combo"] = _combo(frame, self._up["verdict"], VERDICTS, R); R += 1

        self._up["_conf_lbl"]    = _lbl(frame, "Confidence", R)
        self._up["confidence"]   = tk.StringVar(value=CONFIDENCES[0])
        self._up["_conf_combo"]  = _combo(frame, self._up["confidence"], CONFIDENCES, R); R += 1

        self._up["_mitre_lbl"]   = _lbl(frame, "MITRE IDs", R)
        self._up["mitre"]        = tk.StringVar()
        self._up["_mitre_entry"] = _entry(frame, self._up["mitre"], R); R += 1

        # CTF fields
        self._up["_solved_lbl"]  = _lbl(frame, "Solved?", R)
        self._up["solved"]       = tk.BooleanVar()
        self._up["_solved_chk"]  = ttk.Checkbutton(
            frame, text="Yes", variable=self._up["solved"])
        self._up["_solved_chk"].grid(row=R, column=1, sticky="w", pady=3)
        R += 1
        self._up["_pub_lbl"]     = _lbl(frame, "Public writeup safe?", R)
        self._up["public_safe"]  = tk.BooleanVar()
        self._up["_pub_chk"]     = ttk.Checkbutton(
            frame, text="Yes", variable=self._up["public_safe"])
        self._up["_pub_chk"].grid(row=R, column=1, sticky="w", pady=3)
        R += 1

        # Lab fields
        self._up["_objmet_lbl"]  = _lbl(frame, "Objectives met?", R)
        self._up["objectives_met"] = tk.BooleanVar()
        self._up["_objmet_chk"]  = ttk.Checkbutton(
            frame, text="Yes", variable=self._up["objectives_met"])
        self._up["_objmet_chk"].grid(row=R, column=1, sticky="w", pady=3)
        R += 1

        # Hunt fields
        self._up["_det_lbl"]      = _lbl(frame, "Detections found?", R)
        self._up["detections"]    = tk.BooleanVar()
        self._up["_det_chk"]      = ttk.Checkbutton(
            frame, text="Yes", variable=self._up["detections"])
        self._up["_det_chk"].grid(row=R, column=1, sticky="w", pady=3)
        R += 1

        # Common
        _lbl(frame, "Tags (comma-separated)", R)
        self._up["tags"] = tk.StringVar()
        _entry(frame, self._up["tags"], R); R += 1

        self._up["_skills_lbl"]  = _lbl(frame, "Skills (comma-separated)", R)
        self._up["skills"]       = tk.StringVar()
        self._up["_skills_entry"] = _entry(frame, self._up["skills"], R); R += 1

        _lbl(frame, "Outcome (one-liner)", R)
        self._up["outcome"] = tk.StringVar()
        _entry(frame, self._up["outcome"], R); R += 1

        bf = ttk.Frame(frame)
        bf.grid(row=R, column=0, columnspan=3, pady=12)
        ttk.Button(bf, text="  UPDATE ENGAGEMENT  ",
                   command=self._on_update_sample).pack(side="left", padx=6)
        ttk.Button(bf, text="  Load existing values  ",
                   command=self._load_existing_values).pack(side="left", padx=6)
        R += 1

        self._up["output"] = scrolledtext.ScrolledText(
            frame, height=10, bg=C_ENTRY, fg=C_FG, insertbackground=C_FG,
            relief="flat", state="disabled", font=MONO_FONT)
        self._up["output"].grid(row=R, column=0, columnspan=3,
                                 sticky="nsew", padx=0, pady=(4, 0))
        frame.rowconfigure(R, weight=1)

        # Show only file fields by default; kind changes on ID select
        self._up_set_kind("file")

    # -----------------------------------------------------------------------
    # Tab: Tools
    # -----------------------------------------------------------------------

    def _build_tools_tab(self):
        outer = ttk.Frame(self._nb)
        self._nb.add(outer, text="  Tools  ")

        ttk.Label(outer, text="Run automation scripts from the repo root.",
                  style="Dim.TLabel").pack(padx=14, pady=(12, 4), anchor="w")

        ctx = ttk.Frame(outer)
        ctx.pack(fill="x", padx=14, pady=(0, 6))
        ttk.Label(ctx, text="Context sample ID:", style="Dim.TLabel").pack(side="left")
        self._tools_ctx_sid = tk.StringVar()
        ttk.Entry(ctx, textvariable=self._tools_ctx_sid, width=14).pack(side="left", padx=(4, 8))
        ttk.Button(ctx, text="From Screenshots tab",
                   command=self._tools_use_shot_slot).pack(side="left", padx=(0, 8))
        ttk.Button(ctx, text="Refresh kind",
                   command=self._tools_on_ctx_change).pack(side="left")
        self._tools_kind_lbl = ttk.Label(
            ctx, text="Kind: (enter sample_XX)", style="Dim.TLabel", font=SMALL_FONT)
        self._tools_kind_lbl.pack(side="left", padx=(12, 0))
        self._tools_ctx_sid.trace_add("write", self._tools_on_ctx_change)

        tool_frame = ttk.Frame(outer)
        tool_frame.pack(fill="x", padx=14, pady=4)

        tools = [
            ("Validate",             "validate.ps1",        "18 structural / kind-aware integrity checks."),
            ("Export / Regen INDEX", "export-summary.ps1",  "Rebuild INDEX.md, summary.json, portfolio.json."),
            ("Redact Check",         "redact-check.ps1",    "Scan for PII and host-machine identity leaks."),
            ("Strip EXIF",           "strip-exif.ps1",      "Strip metadata from 50_screenshots/ images."),
        ]
        for label, script, desc in tools:
            rf = ttk.Frame(tool_frame)
            rf.pack(fill="x", pady=5)
            ttk.Button(rf, text=f"  {label}  ",
                       command=lambda s=script: self._run_ps_script(s)).pack(side="left")
            ttk.Label(rf, text=desc, style="Dim.TLabel").pack(side="left", padx=12)

        # ---- Hunt ingest (shown first when kind=hunt) ----
        self._tools_hunt_frame = ttk.LabelFrame(
            tool_frame, text="  Threat hunt -- event ingest & query library  ", padding=8)
        ttk.Label(self._tools_hunt_frame,
                  text="Parse SIEM/Sysmon CSV into 02_dynamic. Store reusable queries under 45_hunt_queries/.",
                  style="Dim.TLabel").pack(anchor="w", pady=(0, 6))
        ef = ttk.Frame(self._tools_hunt_frame); ef.pack(fill="x", pady=3)
        ttk.Label(ef, text="Sample ID:", style="Dim.TLabel").pack(side="left")
        self._events_sid = tk.StringVar()
        ttk.Entry(ef, textvariable=self._events_sid, width=12).pack(side="left", padx=(4, 10))
        ttk.Label(ef, text="Event CSV:", style="Dim.TLabel").pack(side="left")
        self._events_csv = tk.StringVar()
        ttk.Entry(ef, textvariable=self._events_csv, width=34).pack(side="left", padx=(4, 6))
        ttk.Button(ef, text="Browse", command=self._browse_events_csv).pack(side="left")
        ef2 = ttk.Frame(self._tools_hunt_frame); ef2.pack(fill="x", pady=(2, 3))
        ttk.Label(ef2, text="Host filter:", style="Dim.TLabel").pack(side="left")
        self._events_hostfilter = tk.StringVar()
        ttk.Entry(ef2, textvariable=self._events_hostfilter, width=20).pack(side="left", padx=(4, 10))
        ttk.Label(ef2, text="EventID filter:", style="Dim.TLabel").pack(side="left")
        self._events_eidfilter = tk.StringVar(value="1,3,10,11,13")
        ttk.Entry(ef2, textvariable=self._events_eidfilter, width=16).pack(side="left", padx=(4, 10))
        ef3 = ttk.Frame(self._tools_hunt_frame); ef3.pack(fill="x", pady=(0, 4))
        ttk.Button(ef3, text="  Ingest Events  ",
                   command=self._run_ingest_events).pack(side="left")
        self._events_dryrun = tk.BooleanVar()
        ttk.Checkbutton(ef3, text="Dry run",
                        variable=self._events_dryrun).pack(side="left", padx=(12, 0))
        hf = ttk.Frame(self._tools_hunt_frame); hf.pack(fill="x", pady=(4, 0))
        ttk.Button(hf, text="  New hunt query (scaffold)  ",
                   command=self._tools_scaffold_hunt_query).pack(side="left", padx=(0, 8))
        ttk.Label(hf, text="45_hunt_queries/ -- see README",
                  style="Dim.TLabel", font=SMALL_FONT).pack(side="left")

        # ---- Procmon ingest (file kind only) ----
        self._tools_procmon_frame = ttk.LabelFrame(
            tool_frame, text="  Malware file -- Procmon ingest  ", padding=8)
        ttk.Label(self._tools_procmon_frame,
                  text="Requires Procmon CSV from isolated VM. Fills 02_dynamic tables.",
                  style="Dim.TLabel").pack(anchor="w", pady=(0, 6))
        pf = ttk.Frame(self._tools_procmon_frame); pf.pack(fill="x", pady=3)
        ttk.Label(pf, text="Sample ID:", style="Dim.TLabel").pack(side="left")
        self._procmon_sid = tk.StringVar()
        ttk.Entry(pf, textvariable=self._procmon_sid, width=12).pack(side="left", padx=(4, 10))
        ttk.Label(pf, text="Procmon CSV:", style="Dim.TLabel").pack(side="left")
        self._procmon_csv = tk.StringVar()
        ttk.Entry(pf, textvariable=self._procmon_csv, width=34).pack(side="left", padx=(4, 6))
        ttk.Button(pf, text="Browse", command=self._browse_procmon_csv).pack(side="left")
        pf2 = ttk.Frame(self._tools_procmon_frame); pf2.pack(fill="x", pady=(2, 3))
        ttk.Label(pf2, text="Process filter:", style="Dim.TLabel").pack(side="left")
        self._procmon_filter = tk.StringVar()
        ttk.Entry(pf2, textvariable=self._procmon_filter, width=36).pack(side="left", padx=(4, 10))
        ttk.Label(pf2, text="e.g. malware.exe,cmd.exe  (blank=all)",
                  style="Dim.TLabel").pack(side="left")
        pf3 = ttk.Frame(self._tools_procmon_frame); pf3.pack(fill="x", pady=(0, 0))
        ttk.Button(pf3, text="  Ingest Procmon  ",
                   command=self._run_ingest_procmon).pack(side="left")
        self._procmon_dryrun = tk.BooleanVar()
        ttk.Checkbutton(pf3, text="Dry run (preview only)",
                        variable=self._procmon_dryrun).pack(side="left", padx=(12, 0))

        self._tools_kind_note = ttk.Label(
            tool_frame,
            text="CTF/lab: use New/Update Engagement tabs. No Procmon or event ingest here.",
            style="Dim.TLabel", font=SMALL_FONT)
        self._tools_kind_note.pack(anchor="w", pady=(6, 0))

        self._tools_apply_kind_visibility("file")

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
            _entry(frame, self._set[key], R); R += 1

        bf = ttk.Frame(frame)
        bf.grid(row=R, column=0, columnspan=3, pady=10)
        ttk.Button(bf, text="  Save Settings  ",
                   command=self._save_settings).pack(side="left", padx=6)
        ttk.Button(bf, text="  Browse repo...  ",
                   command=lambda: self._browse_repo(update_settings=True)).pack(side="left", padx=6)
        R += 1

        ttk.Separator(frame, orient="horizontal").grid(
            row=R, column=0, columnspan=3, sticky="ew", padx=0, pady=12); R += 1

        info = (
            f"workflow_gui.py  v{APP_VERSION}\n"
            f"Config file: {CONFIG_FILE}\n\n"
            f"Compile to executable:\n"
            f"  Windows  ->  powershell -File .\\30_scripts\\build_exe.ps1\n"
            f"  Linux    ->  bash ./30_scripts/build_linux.sh\n\n"
            f"PIL (thumbnail support): {'installed' if PIL_AVAILABLE else 'NOT installed (pip install pillow)'}\n"
        )
        ttk.Label(frame, text=info, style="Dim.TLabel",
                  justify="left").grid(row=R, column=0, columnspan=3, sticky="w")

    # -----------------------------------------------------------------------
    # New Engagement -- kind-change wiring
    # -----------------------------------------------------------------------

    def _on_sha256_change(self, *_):
        sha = self._ns["sha256"].get().strip()
        if len(sha) == 64 and re.fullmatch(r"[0-9a-fA-F]+", sha):
            if not self._ns["mb_url"].get().strip():
                self._ns["mb_url"].set(f"https://bazaar.abuse.ch/sample/{sha}/")

    def _on_kind_change(self, *_):
        kind    = self._ns.get("kind", tk.StringVar()).get()
        is_file = kind == "file"
        is_ctf  = kind == "ctf"
        is_lab  = kind == "lab"
        is_hunt = kind == "hunt"
        is_non_file = not is_file

        def show(w_key): self._show_ns(w_key, True)
        def hide(w_key): self._show_ns(w_key, False)

        # File-only panel (hashes, file info, YARA) and Bazaar date row
        for panel_key in ("_file_panel", "_bazaar_panel"):
            panel = self._ns.get(panel_key)
            if panel is not None:
                try:
                    if is_file:
                        panel.grid()
                    else:
                        panel.grid_remove()
                except Exception:
                    pass

        for k in ("_type_lbl", "_type_combo", "_type_hint",
                  "_verdict_lbl", "_verdict_combo",
                  "_conf_lbl", "_conf_combo",
                  "_fam_lbl", "_fam_entry",
                  "_flags_lbl", "_flags_frame",
                  ):
            self._show_ns(k, is_file)

        # CTF fields
        for k in ("_plat_lbl", "_plat_combo",
                  "_cat_lbl", "_cat_combo",
                  "_diff_lbl", "_diff_combo",
                  "_pts_lbl", "_pts_entry",
                  "_solved_lbl", "_solved_chk",
                  "_pub_lbl", "_pub_chk",
                  ):
            self._show_ns(k, is_ctf)

        # Lab fields
        for k in ("_course_lbl", "_course_entry",
                  "_module_lbl", "_module_entry",
                  "_obj_lbl", "lab_objectives",
                  "_objmet_lbl", "_objmet_chk",
                  ):
            self._show_ns(k, is_lab)

        # Lab platform row (lab uses same platform widget as ctf)
        for k in ("_plat_lbl", "_plat_combo"):
            self._show_ns(k, is_ctf or is_lab)

        # Hunt fields
        for k in ("_hyp_lbl", "_hyp_entry",
                  "_ds_lbl", "_ds_entry",
                  "_tb_lbl", "_tb_entry",
                  "_det_lbl", "_det_chk",
                  ):
            self._show_ns(k, is_hunt)

        # Non-file: outcome, skills, tags still shown
        for k in ("_outcome_lbl", "_outcome_entry",
                  "_skills_lbl", "_skills_entry", "_skills_hint"):
            self._show_ns(k, is_non_file)

        # MITRE: file and hunt
        for k in ("_mitre_lbl", "_mitre_entry"):
            self._show_ns(k, is_file or is_hunt)

        # Seed tag hints
        if kind in KIND_TAG_HINTS:
            tag_var = self._ns.get("tags")
            if tag_var and not tag_var.get():
                tag_var.set(KIND_TAG_HINTS[kind])
        elif is_file:
            self._on_type_change()

        if kind in KIND_SKILL_HINTS:
            sv = self._ns.get("skills")
            if sv and not sv.get():
                sv.set(KIND_SKILL_HINTS[kind])

        lbl = {
            "file": "   CREATE FILE ENGAGEMENT   ",
            "ctf":  "   CREATE CTF ENGAGEMENT   ",
            "lab":  "   CREATE LAB ENGAGEMENT   ",
            "hunt": "   CREATE HUNT ENGAGEMENT   ",
        }.get(kind, "   CREATE ENGAGEMENT   ")
        btn = self._ns.get("_create_btn")
        if btn:
            btn.configure(text=lbl)

    def _show_ns(self, key: str, visible: bool) -> None:
        w = self._ns.get(key)
        if w is None:
            return
        try:
            if visible:
                w.grid()
            else:
                w.grid_remove()
        except Exception:
            pass

    def _on_type_change(self, *_):
        t = self._ns["sample_type"].get()
        current_tags  = self._ns["tags"].get().strip()
        current_mitre = self._ns["mitre"].get().strip()
        hint_tags  = TYPE_TAG_HINTS.get(t, "")
        hint_mitre = TYPE_MITRE_HINTS.get(t, "")
        all_hints_t = set(TYPE_TAG_HINTS.values())
        all_hints_m = set(TYPE_MITRE_HINTS.values())
        if not current_tags or current_tags in all_hints_t:
            self._ns["tags"].set(hint_tags)
        if not current_mitre or current_mitre in all_hints_m:
            self._ns["mitre"].set(hint_mitre)

    def _auto_detect_num(self):
        if not self.repo_root:
            self._log("No repo root set.")
            return
        n = next_sample_number(self.repo_root)
        self._ns["num"].set(str(n))
        self._log(f"Next open reserve slot: sample_{pad2(n)}")

    # -----------------------------------------------------------------------
    # New Engagement -- create
    # -----------------------------------------------------------------------

    def _on_create_sample(self):
        if not self.repo_root:
            messagebox.showerror("No repo", "Browse to the repo root first.")
            return
        num_str = self._ns["num"].get().strip()
        if not num_str.isdigit():
            messagebox.showerror("Invalid #", "Slot # must be a whole number.")
            return

        n    = int(num_str)
        sid  = f"sample_{pad2(n)}"
        kind = self._ns.get("kind", tk.StringVar()).get() or "file"

        eng_script = self.repo_root / "30_scripts" / "new_engagement.ps1"
        if not eng_script.exists():
            messagebox.showerror("Missing script",
                "30_scripts/new_engagement.ps1 not found.")
            return

        analyst  = self._ns["analyst"].get().strip() or "Surrplexie"
        title    = self._ns.get("title", tk.StringVar()).get().strip()
        platform = self._ns.get("platform", tk.StringVar()).get().strip()
        stype    = self._ns["sample_type"].get() if kind == "file" else "PE"

        args = [
            "powershell", "-ExecutionPolicy", "Bypass",
            "-File", str(eng_script),
            "-NextNumber", str(n),
            "-Kind", kind,
            "-Analyst", analyst,
        ]
        if kind == "file": args += ["-Type", stype]
        if title:          args += ["-Title", title]
        if platform:       args += ["-Platform", platform]

        self._log(f"Scaffolding {sid} (kind={kind})...")
        try:
            result = subprocess.run(
                args, cwd=str(self.repo_root),
                capture_output=True, text=True, timeout=60)
            if result.returncode != 0:
                self._log(result.stdout)
                self._log(result.stderr)
                messagebox.showerror("Script error",
                    f"new_engagement.ps1 exited {result.returncode}.\nSee log panel.")
                return
            self._log(result.stdout.strip())
        except Exception as exc:
            messagebox.showerror("Error", str(exc))
            self._log(f"Error: {exc}")
            return

        # Patch 03_findings frontmatter with all additional values
        try:
            self._patch_after_create(sid, kind)
        except Exception as exc:
            self._log(f"Warning: frontmatter patch failed: {exc}")

        messagebox.showinfo("Created",
            f"{sid} scaffolded ({kind}).\n\n"
            f"Frontmatter patched with entered values.\n"
            f"Open phase files to fill remaining PENDING fields.")
        self._log(f"Created {sid} (kind={kind}).")
        self._refresh_sample_list()
        self._refresh_shot_slots()

    def _patch_after_create(self, sid: str, kind: str) -> None:
        """Patch 03_findings frontmatter with form values after scaffold."""
        findings = self.repo_root / "03_findings" / f"{sid}.md"
        if not findings.exists():
            return

        updates = {}
        analyst = self._ns["analyst"].get().strip()
        if analyst: updates["analyst"] = analyst

        tags_raw = self._ns["tags"].get().strip()
        if tags_raw:
            updates["tags"] = [t.strip() for t in tags_raw.split(",") if t.strip()]

        outcome = self._ns.get("outcome", tk.StringVar()).get().strip()
        if outcome: updates["outcome"] = f'"{outcome}"'

        if kind == "file":
            sha = self._ns["sha256"].get().strip()
            if sha:
                updates["sha256"] = sha
            updates["verdict"]           = self._ns["verdict"].get()
            updates["family_confidence"] = self._ns["confidence"].get()
            fam = self._ns["family"].get().strip()
            if fam: updates["family_guess"] = f'"{fam}"'
            mitre_raw = self._ns["mitre"].get().strip()
            if mitre_raw:
                updates["mitre_techniques"] = [
                    m.strip() for m in mitre_raw.split(",") if m.strip()]
            updates["procmon_run"]      = "true" if self._ns["procmon_run"].get() else "false"
            updates["dynamic_complete"] = "true" if self._ns["dynamic_complete"].get() else "false"

        elif kind == "ctf":
            plat = self._ns.get("platform", tk.StringVar()).get().strip()
            cat  = self._ns.get("ctf_category", tk.StringVar()).get().strip()
            diff = self._ns.get("ctf_difficulty", tk.StringVar()).get().strip()
            pts  = self._ns.get("ctf_points", tk.StringVar()).get().strip()
            if plat: updates["platform"]   = f'"{plat}"'
            if cat:  updates["category"]   = f'"{cat}"'
            if diff: updates["difficulty"] = f'"{diff}"'
            if pts:  updates["points"]     = pts
            updates["solved"]              = "true" if self._ns["ctf_solved"].get()  else "false"
            updates["public_writeup_safe"] = "true" if self._ns["ctf_public"].get()  else "false"
            skills_raw = self._ns.get("skills", tk.StringVar()).get().strip()
            if skills_raw:
                updates["skills"] = [s.strip() for s in skills_raw.split(",") if s.strip()]

        elif kind == "lab":
            plat   = self._ns.get("platform", tk.StringVar()).get().strip()
            course = self._ns.get("lab_course", tk.StringVar()).get().strip()
            module = self._ns.get("lab_module", tk.StringVar()).get().strip()
            if plat:   updates["platform"] = f'"{plat}"'
            if course: updates["course"]   = f'"{course}"'
            if module: updates["module"]   = f'"{module}"'
            # Objectives from multiline text
            obj_raw = self._ns["lab_objectives"].get("1.0", "end").strip()
            if obj_raw:
                obj_items = [
                    l.strip().lstrip("- ").strip()
                    for l in obj_raw.splitlines() if l.strip()
                ]
                if obj_items:
                    updates["objectives"] = obj_items
            updates["objectives_met"] = "true" if self._ns["lab_objmet"].get() else "false"
            skills_raw = self._ns.get("skills", tk.StringVar()).get().strip()
            if skills_raw:
                updates["skills"] = [s.strip() for s in skills_raw.split(",") if s.strip()]

        elif kind == "hunt":
            hyp  = self._ns.get("hunt_hypothesis", tk.StringVar()).get().strip()
            ds   = self._ns.get("hunt_datasources", tk.StringVar()).get().strip()
            tb   = self._ns.get("hunt_timebox", tk.StringVar()).get().strip()
            if hyp: updates["hypothesis"]   = f'"{hyp}"'
            if ds:  updates["data_sources"] = f'"{ds}"'
            if tb:  updates["timebox"]      = f'"{tb}"'
            updates["detections_found"] = "true" if self._ns["hunt_detections"].get() else "false"
            mitre_raw = self._ns.get("mitre", tk.StringVar()).get().strip()
            if mitre_raw:
                updates["mitre_techniques"] = [
                    m.strip() for m in mitre_raw.split(",") if m.strip()]
            skills_raw = self._ns.get("skills", tk.StringVar()).get().strip()
            if skills_raw:
                updates["skills"] = [s.strip() for s in skills_raw.split(",") if s.strip()]

        if updates:
            patch_frontmatter(findings, updates)
            self._log(f"Patched {findings.name} with {len(updates)} field(s).")

    def _clear_ns_form(self):
        for key in ("sha256", "sha1", "md5", "filename", "mime",
                    "size", "first_seen", "mb_url", "tags", "mitre",
                    "family", "skills", "outcome",
                    "hunt_hypothesis", "hunt_datasources", "hunt_timebox",
                    "lab_course", "lab_module", "platform",
                    "ctf_points", "title"):
            v = self._ns.get(key)
            if v: v.set("")
        self._ns["verdict"].set(VERDICTS[0])
        self._ns["confidence"].set(CONFIDENCES[0])
        self._ns["ctf_category"].set("")
        self._ns["ctf_difficulty"].set("")
        self._ns["ctf_solved"].set(False)
        self._ns["ctf_public"].set(False)
        self._ns["lab_objmet"].set(False)
        self._ns["hunt_detections"].set(False)
        self._ns["procmon_run"].set(False)
        self._ns["dynamic_complete"].set(False)
        self._ns["date_acquired"].set(today())
        self._ns["date_analyzed"].set(today())
        self._ns["yara_txt"].delete("1.0", "end")
        self._ns["yara_txt"].insert("end",
            "| RuleName | Author | What it flags |\n"
            "| RuleName2 | Author2 | What it flags |")
        self._ns["lab_objectives"].delete("1.0", "end")
        self._ns["lab_objectives"].insert("end", "- Objective 1\n- Objective 2")
        self._log("Form cleared.")

    # -----------------------------------------------------------------------
    # Screenshots tab handlers
    # -----------------------------------------------------------------------

    def _refresh_shot_slots(self):
        if not self.repo_root:
            return
        ids = list_active_sample_ids(self.repo_root)
        self._shot_slot_combo.configure(values=ids)
        if ids and not self._shot_slot_var.get():
            self._shot_slot_var.set(ids[-1])

    def _shot_add_images(self):
        paths = filedialog.askopenfilenames(
            title="Select screenshot images",
            filetypes=[
                ("Images", "*.png *.jpg *.jpeg *.heic *.bmp *.gif *.webp"),
                ("All files", "*.*"),
            ])
        if not paths:
            return
        for p in paths:
            src = Path(p)
            ext = src.suffix.lower()
            status = "HEIC -- convert first" if ext == ".heic" else "ready"
            self._shot_files.append([src, "", status])
            idx = len(self._shot_files)
            self._shot_tree.insert("", "end",
                values=(idx, src.name, "", status))
        self._shot_lbl_info.configure(
            text=f"{len(self._shot_files)} image(s) in list")
        self._log(f"Added {len(paths)} image(s) to screenshot queue.")

    def _shot_clear(self):
        self._shot_files.clear()
        self._shot_thumbs.clear()
        for item in self._shot_tree.get_children():
            self._shot_tree.delete(item)
        self._shot_lbl_info.configure(text="")
        self._log("Screenshot list cleared.")

    def _shot_on_select(self, event=None):
        sel = self._shot_tree.selection()
        if not sel:
            return
        item = sel[0]
        idx  = int(self._shot_tree.item(item, "values")[0]) - 1
        if 0 <= idx < len(self._shot_files):
            caption = self._shot_files[idx][1]
            self._shot_caption_var.set(caption)
            # Thumbnail
            if PIL_AVAILABLE and self._shot_files[idx][2] != "HEIC -- convert first":
                try:
                    src = self._shot_files[idx][0]
                    img = Image.open(str(src))
                    img.thumbnail((120, 90))
                    tk_img = ImageTk.PhotoImage(img)
                    self._shot_thumbs = [tk_img]  # keep ref
                    self._shot_thumb_lbl.configure(image=tk_img, text="")
                except Exception:
                    self._shot_thumb_lbl.configure(image="", text="[preview failed]")

    def _shot_set_caption(self):
        sel = self._shot_tree.selection()
        if not sel:
            return
        item    = sel[0]
        values  = list(self._shot_tree.item(item, "values"))
        idx     = int(values[0]) - 1
        caption = self._shot_caption_var.get().strip()
        if 0 <= idx < len(self._shot_files):
            self._shot_files[idx][1] = caption
            values[2] = caption
            self._shot_tree.item(item, values=values)

    def _shot_copy_and_rename(self):
        if not self.repo_root:
            messagebox.showerror("No repo", "Browse to repo root first.")
            return
        slot = self._shot_slot_var.get().strip()
        if not slot:
            messagebox.showerror("No slot", "Select a target engagement slot.")
            return
        if not self._shot_files:
            messagebox.showinfo("Nothing to do", "Add images first.")
            return

        dest_dir = self.repo_root / "50_screenshots" / slot
        dest_dir.mkdir(parents=True, exist_ok=True)

        # Determine starting number
        start_str = self._shot_start_var.get().strip()
        if start_str == "auto":
            existing = sorted(dest_dir.glob("shot_*.png")) + \
                       sorted(dest_dir.glob("shot_*.jpg"))
            nums = []
            for f in existing:
                m = re.match(r"shot_(\d+)", f.stem)
                if m: nums.append(int(m.group(1)))
            next_n = (max(nums) + 1) if nums else 1
        else:
            next_n = int(start_str) if start_str.isdigit() else 1

        copied = []
        for i, (src, caption, status) in enumerate(self._shot_files):
            if status == "HEIC -- convert first":
                self._log(f"Skipping HEIC: {src.name}")
                continue
            ext = src.suffix.lower()
            out_ext = ".png" if ext not in (".jpg", ".jpeg") else ".jpg"
            out_name = f"shot_{next_n:03d}{out_ext}"
            dest     = dest_dir / out_name
            shutil.copy2(str(src), str(dest))
            copied.append((next_n, out_name, caption))
            # Update tree status
            item = self._shot_tree.get_children()[i]
            vals = list(self._shot_tree.item(item, "values"))
            vals[3] = f"copied -> {out_name}"
            self._shot_tree.item(item, values=vals)
            next_n += 1

        messagebox.showinfo("Done",
            f"{len(copied)} image(s) copied to:\n{dest_dir}")
        self._log(f"Copied {len(copied)} images to {dest_dir}")

        # Auto-update SHOT_INDEX if captions provided
        captioned = [(n, name, cap) for n, name, cap in copied if cap]
        if captioned:
            self._shot_write_index_entries(slot, captioned)

    def _shot_update_index(self):
        if not self.repo_root:
            return
        slot = self._shot_slot_var.get().strip()
        if not slot:
            messagebox.showerror("No slot", "Select a target slot.")
            return
        entries = []
        for n, (src, caption, status) in enumerate(self._shot_files):
            if caption:
                ext = src.suffix.lower()
                out_ext = ".png" if ext not in (".jpg", ".jpeg") else ".jpg"
                num  = n + 1
                # Try to infer actual name from tree
                items = self._shot_tree.get_children()
                if n < len(items):
                    st = self._shot_tree.item(items[n], "values")[3]
                    m = re.search(r"shot_(\d+)", st)
                    if m: num = int(m.group(1))
                name = f"shot_{num:03d}{out_ext}"
                entries.append((num, name, caption))
        if entries:
            self._shot_write_index_entries(slot, entries)
        else:
            messagebox.showinfo("Nothing to do",
                "No captions set. Set captions first.")

    def _shot_write_index_entries(self, slot: str, entries: list) -> None:
        index_path = self.repo_root / "50_screenshots" / slot / "SHOT_INDEX.txt"
        if not index_path.exists():
            v = {"sample_id": slot, "analyst": self.cfg.get("analyst", "Surrplexie")}
            index_path.write_text(build_shot_index(v), encoding="utf-8")

        existing = index_path.read_text(encoding="utf-8", errors="replace")
        added = []
        for num, name, caption in entries:
            line = f"{name} -- {caption}"
            if line not in existing:
                added.append(line)

        if added:
            with open(index_path, "a", encoding="utf-8") as f:
                for line in added:
                    f.write(line + "\n")
            self._log(f"Updated SHOT_INDEX.txt with {len(added)} entry/entries.")

    def _shot_strip_exif(self):
        slot = self._shot_slot_var.get().strip()
        if not slot:
            messagebox.showerror("No slot", "Select a slot first.")
            return
        self._run_ps_script("strip-exif.ps1",
                            extra_args=["-SampleId", slot,
                                        "-Root", str(self.repo_root)])

    # -----------------------------------------------------------------------
    # Update tab handlers
    # -----------------------------------------------------------------------

    def _up_on_id_change(self, *_):
        sid = self._up["id"].get().strip()
        if not sid or not self.repo_root:
            return
        kind = get_kind_for_slot(self.repo_root, sid)
        self._up["kind_lbl"].configure(text=kind)
        self._up_set_kind(kind)
        if hasattr(self, "_tools_ctx_sid"):
            self._tools_ctx_sid.set(sid)
            self._tools_on_ctx_change()

    def _up_set_kind(self, kind: str):
        statuses = KIND_STATUSES.get(kind, KIND_STATUSES["file"])
        self._up["status_combo"].configure(values=statuses)
        self._up["status"].set(statuses[0])

        is_file = kind == "file"
        is_ctf  = kind == "ctf"
        is_lab  = kind == "lab"
        is_hunt = kind == "hunt"

        def sv(key, visible):
            w = self._up.get(key)
            if w is None: return
            try:
                if visible: w.grid()
                else:       w.grid_remove()
            except Exception:
                pass

        sv("_verdict_lbl",  is_file); sv("_verdict_combo", is_file)
        sv("_conf_lbl",     is_file); sv("_conf_combo",    is_file)
        sv("_mitre_lbl",    is_file or is_hunt); sv("_mitre_entry", is_file or is_hunt)
        sv("_solved_lbl",   is_ctf);  sv("_solved_chk",   is_ctf)
        sv("_pub_lbl",      is_ctf);  sv("_pub_chk",      is_ctf)
        sv("_objmet_lbl",   is_lab);  sv("_objmet_chk",   is_lab)
        sv("_det_lbl",      is_hunt); sv("_det_chk",      is_hunt)
        sv("_skills_lbl",   not is_file); sv("_skills_entry", not is_file)

    def _refresh_sample_list(self):
        if not self.repo_root:
            return
        ids = list_active_sample_ids(self.repo_root)
        self._up["id_combo"].configure(values=ids)
        if ids:
            self._up["id"].set(ids[-1])
        self._log(f"Loaded {len(ids)} engagement ID(s).")

    def _load_existing_values(self):
        sid = self._up["id"].get().strip()
        if not sid or not self.repo_root:
            return
        path = self.repo_root / "03_findings" / f"{sid}.md"
        fm = read_frontmatter(path)
        if not fm:
            self._log(f"No frontmatter in {path.name}"); return
        kind = fm.get("engagement_kind", "file")

        self._up["tags"].set(fm.get("tags", ""))
        self._up["outcome"].set(fm.get("outcome", ""))
        if kind == "file":
            self._up["verdict"].set(fm.get("verdict", VERDICTS[0]))
            self._up["confidence"].set(fm.get("family_confidence", CONFIDENCES[0]))
            self._up["mitre"].set(fm.get("mitre_techniques", ""))
        elif kind == "ctf":
            self._up["solved"].set(fm.get("solved", "false") == "true")
            self._up["public_safe"].set(fm.get("public_writeup_safe", "false") == "true")
            self._up["skills"].set(fm.get("skills", ""))
        elif kind == "lab":
            self._up["objectives_met"].set(fm.get("objectives_met", "false") == "true")
            self._up["skills"].set(fm.get("skills", ""))
        elif kind == "hunt":
            self._up["detections"].set(fm.get("detections_found", "false") == "true")
            self._up["mitre"].set(fm.get("mitre_techniques", ""))
            self._up["skills"].set(fm.get("skills", ""))
        self._log(f"Loaded frontmatter from {path.name}")

    def _on_update_sample(self):
        if not self.repo_root:
            messagebox.showerror("No repo", "Browse to repo root first."); return
        sid = self._up["id"].get().strip()
        if not sid:
            messagebox.showerror("No engagement", "Select an engagement ID first."); return

        kind = get_kind_for_slot(self.repo_root, sid) if self.repo_root else "file"
        new_status = self._up["status"].get()
        set_tracker_status(self.repo_root, sid, new_status)

        updates = {"status": new_status}
        outcome = self._up["outcome"].get().strip()
        if outcome: updates["outcome"] = f'"{outcome}"'
        tags_raw = self._up["tags"].get().strip()
        if tags_raw:
            updates["tags"] = [t.strip() for t in tags_raw.split(",") if t.strip()]

        if kind == "file":
            updates["verdict"]           = self._up["verdict"].get()
            updates["family_confidence"] = self._up["confidence"].get()
            mitre_raw = self._up["mitre"].get().strip()
            if mitre_raw:
                updates["mitre_techniques"] = [m.strip() for m in mitre_raw.split(",") if m.strip()]
        elif kind == "ctf":
            updates["solved"]              = "true" if self._up["solved"].get()      else "false"
            updates["public_writeup_safe"] = "true" if self._up["public_safe"].get() else "false"
            skills_raw = self._up["skills"].get().strip()
            if skills_raw:
                updates["skills"] = [s.strip() for s in skills_raw.split(",") if s.strip()]
        elif kind == "lab":
            updates["objectives_met"] = "true" if self._up["objectives_met"].get() else "false"
            skills_raw = self._up["skills"].get().strip()
            if skills_raw:
                updates["skills"] = [s.strip() for s in skills_raw.split(",") if s.strip()]
        elif kind == "hunt":
            updates["detections_found"] = "true" if self._up["detections"].get() else "false"
            mitre_raw = self._up["mitre"].get().strip()
            if mitre_raw:
                updates["mitre_techniques"] = [m.strip() for m in mitre_raw.split(",") if m.strip()]
            skills_raw = self._up["skills"].get().strip()
            if skills_raw:
                updates["skills"] = [s.strip() for s in skills_raw.split(",") if s.strip()]

        findings = self.repo_root / "03_findings" / f"{sid}.md"
        if findings.exists():
            patch_frontmatter(findings, updates)

        msg = f"Updated {sid} [{kind}] -> {new_status}\n  {len(updates)} field(s) patched\n\n"
        _append(self._up["output"], msg)
        self._log(f"Updated {sid} -> {new_status}")

    # -----------------------------------------------------------------------
    # Tools handlers
    # -----------------------------------------------------------------------

    def _tools_on_ctx_change(self, *_):
        sid = self._tools_ctx_sid.get().strip() if hasattr(self, "_tools_ctx_sid") else ""
        kind = "file"
        if sid and self.repo_root and re.fullmatch(r"sample_\d{2}", sid):
            kind = get_kind_for_slot(self.repo_root, sid)
            self._procmon_sid.set(sid)
            self._events_sid.set(sid)
        elif sid:
            kind = "(invalid id)"
        self._tools_kind_lbl.configure(
            text=f"Kind: {kind}" + (f"  ({sid})" if sid else ""))
        if isinstance(kind, str) and kind not in ("(invalid id)", ""):
            self._tools_apply_kind_visibility(kind)

    def _tools_use_shot_slot(self):
        slot = self._shot_slot_var.get().strip() if hasattr(self, "_shot_slot_var") else ""
        if slot:
            self._tools_ctx_sid.set(slot)
            self._tools_on_ctx_change()

    def _tools_apply_kind_visibility(self, kind: str) -> None:
        """Show kind-relevant ingest panels on the Tools tab."""
        for frame in (self._tools_hunt_frame, self._tools_procmon_frame, self._tools_kind_note):
            frame.pack_forget()

        if kind == "hunt":
            self._tools_hunt_frame.pack(fill="x", pady=(10, 4))
            self._tools_kind_note.configure(
                text="Hunt mode: event ingest + 45_hunt_queries/ library.")
        elif kind == "file":
            self._tools_procmon_frame.pack(fill="x", pady=(10, 4))
            self._tools_kind_note.configure(
                text="File mode: Procmon ingest only (malware dynamic triage).")
        else:
            self._tools_kind_note.configure(
                text="CTF/lab: use New/Update Engagement tabs. No Procmon or event ingest here.")
        self._tools_kind_note.pack(anchor="w", pady=(6, 0))

    def _tools_scaffold_hunt_query(self):
        if not self.repo_root:
            messagebox.showerror("No repo", "Browse to repo root first.")
            return
        qid = simpledialog.askstring(
            "New hunt query",
            "Query ID (kebab-case, e.g. schtasks-persistence):",
            parent=self)
        if not qid or not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", qid.strip()):
            messagebox.showerror("Invalid", "Use kebab-case letters and numbers only.")
            return
        title = simpledialog.askstring(
            "New hunt query", "Short title:", parent=self) or qid
        extra = ["-QueryId", qid.strip(), "-Title", title.strip(), "-Platform", "kql"]
        self._run_ps_script("new_hunt_query.ps1", extra_args=extra)

    def _run_ps_script(self, script: str, extra_args: list = None):
        if not self.repo_root:
            messagebox.showerror("No repo", "Browse to repo root first."); return
        script_path = self.repo_root / "30_scripts" / script
        if not script_path.exists():
            _append(self._tools_out, f"Script not found: {script_path}\n"); return

        cmd = (["powershell", "-ExecutionPolicy", "Bypass", "-File", str(script_path)]
               if sys.platform == "win32"
               else ["pwsh", "-File", str(script_path)])
        cmd += (extra_args or [])

        _append(self._tools_out, f"\n--- Running {script} ---\n")
        try:
            result = subprocess.run(
                cmd, capture_output=True, text=True,
                cwd=str(self.repo_root), timeout=120)
            out = (result.stdout or "") + (result.stderr or "")
            _append(self._tools_out, out or "(no output)\n")
            _append(self._tools_out, f"--- Exit code: {result.returncode} ---\n")
            self._log(f"{script} done (exit {result.returncode})")
        except FileNotFoundError:
            _append(self._tools_out,
                "PowerShell / pwsh not found.\n"
                "Windows: built-in. Linux: install pwsh (PowerShell Core).\n")
        except subprocess.TimeoutExpired:
            _append(self._tools_out, "Timed out (120 s).\n")

    def _browse_procmon_csv(self):
        p = filedialog.askopenfilename(
            title="Select Procmon CSV export",
            filetypes=[("CSV files", "*.csv"), ("All files", "*.*")])
        if p: self._procmon_csv.set(p)

    def _run_ingest_procmon(self):
        if not self.repo_root:
            messagebox.showerror("No repo", "Browse to repo root first."); return
        sid      = self._procmon_sid.get().strip()
        csv_path = self._procmon_csv.get().strip()
        if not sid:      messagebox.showerror("Missing", "Enter a Sample ID."); return
        if get_kind_for_slot(self.repo_root, sid) != "file":
            messagebox.showwarning(
                "Wrong kind",
                f"{sid} is not a file engagement. Procmon ingest is for malware (file) slots only.")
            return
        if not csv_path: messagebox.showerror("Missing", "Browse to Procmon CSV."); return
        extra = ["-SampleId", sid, "-ProcmonCsv", csv_path, "-Root", str(self.repo_root)]
        if self._procmon_filter.get().strip():
            extra += ["-ProcessFilter", self._procmon_filter.get().strip()]
        if self._procmon_dryrun.get():
            extra += ["-DryRun"]
        self._run_ps_script("ingest-procmon.ps1", extra_args=extra)

    def _browse_events_csv(self):
        p = filedialog.askopenfilename(
            title="Select SIEM/Sysmon event CSV export",
            filetypes=[("CSV files", "*.csv"), ("All files", "*.*")])
        if p: self._events_csv.set(p)

    def _run_ingest_events(self):
        if not self.repo_root:
            messagebox.showerror("No repo", "Browse to repo root first."); return
        sid      = self._events_sid.get().strip()
        csv_path = self._events_csv.get().strip()
        if not sid:      messagebox.showerror("Missing", "Enter a Sample ID."); return
        if get_kind_for_slot(self.repo_root, sid) != "hunt":
            messagebox.showwarning(
                "Wrong kind",
                f"{sid} is not a hunt engagement. Event ingest is for hunt slots only.")
            return
        if not csv_path: messagebox.showerror("Missing", "Browse to Event CSV."); return
        extra = ["-SampleId", sid, "-EventCsv", csv_path, "-Root", str(self.repo_root)]
        hf = self._events_hostfilter.get().strip()
        ef = self._events_eidfilter.get().strip()
        if hf: extra += ["-HostFilter", hf]
        if ef: extra += ["-EventIdFilter", ef]
        if self._events_dryrun.get(): extra += ["-DryRun"]
        self._run_ps_script("ingest-events.ps1", extra_args=extra)

    # -----------------------------------------------------------------------
    # Utility
    # -----------------------------------------------------------------------

    def _refresh_repo_label(self):
        if self.repo_root:
            self._repo_lbl.configure(text=str(self.repo_root), foreground=C_OK)
        else:
            self._repo_lbl.configure(
                text="(not found -- click Browse)", foreground=C_ERR)

    def _browse_repo(self, update_settings: bool = False):
        path = filedialog.askdirectory(
            title="Select repo root (folder containing samples_tracker.csv)")
        if not path: return
        p = Path(path)
        if not (p / "samples_tracker.csv").exists():
            messagebox.showwarning("Not a repo root",
                "samples_tracker.csv not found. Select the labs root."); return
        self.repo_root = p
        self.cfg["repo_root"] = str(p)
        save_config(self.cfg)
        self._refresh_repo_label()
        if update_settings and "repo_root" in self._set:
            self._set["repo_root"].set(str(p))
        self._refresh_shot_slots()
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
        messagebox.showinfo("Saved", "Settings saved.")

    def _log(self, msg: str):
        self._status_var.set(msg)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description=APP_TITLE)
    parser.add_argument("--repo", metavar="PATH",
                        help="Path to labs repo root (overrides auto-detect)")
    args = parser.parse_args()
    app = WorkflowApp(cli_repo=args.repo)
    app.mainloop()


if __name__ == "__main__":
    main()
